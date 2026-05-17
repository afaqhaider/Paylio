import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import '../../Core/settings_provider.dart';
import '../Auth/auth_provider.dart' as ledgix_auth;
import '../Auth/user_model.dart';
import '../Transactions/transaction_provider.dart';
import '../Transactions/transaction_model.dart';
import 'person_provider.dart';
import 'person_detail_screen.dart';
import 'connection_request_model.dart';
import 'user_connection_model.dart';

class PeopleScreen extends StatefulWidget {
  const PeopleScreen({super.key});

  @override
  State<PeopleScreen> createState() => _PeopleScreenState();
}

class _PeopleScreenState extends State<PeopleScreen> with SingleTickerProviderStateMixin {
  late TabController _tabController;
  final TextEditingController _searchController = TextEditingController();
  UserModel? _foundUser;
  bool _isSearching = false;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    _searchController.dispose();
    super.dispose();
  }

  Map<String, double> _calculatePersonSummary(String personId, List<TransactionModel> transactions) {
    double lent = 0;
    double borrowed = 0;
    double repaidReceived = 0;
    double repaidPaid = 0;
    
    for (var tx in transactions) {
      if (tx.status != 'approved' && tx.status != 'confirmed') continue;

      if (tx.personId == personId) {
        if (tx.type == 'lend') {
          lent += tx.amount;
        } else if (tx.type == 'borrow') borrowed += tx.amount;
        else if (tx.type == 'repayment_received') repaidReceived += tx.amount;
        else if (tx.type == 'repayment_paid') repaidPaid += tx.amount;
      }
    }
    
    return {
      'lent': lent,
      'borrowed': borrowed,
      'repaidReceived': repaidReceived,
      'repaidPaid': repaidPaid,
      'netBalance': (lent - repaidReceived) - (borrowed - repaidPaid),
    };
  }

  Future<void> _handleSearch() async {
    final email = _searchController.text.trim();
    if (email.isEmpty) return;

    setState(() => _isSearching = true);
    final personProvider = Provider.of<PersonProvider>(context, listen: false);
    final authProvider = Provider.of<ledgix_auth.LedGixAuthProvider>(context, listen: false);

    if (email.toLowerCase() == authProvider.user?.email.toLowerCase()) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("You cannot add yourself")),
      );
      setState(() => _isSearching = false);
      return;
    }

    final user = await personProvider.searchUser(email);
    setState(() {
      _foundUser = user;
      _isSearching = false;
    });

    if (user == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("User not found")),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final currency = Provider.of<SettingsProvider>(context).currency;
    final personProvider = Provider.of<PersonProvider>(context);
    final authProvider = Provider.of<ledgix_auth.LedGixAuthProvider>(context);
    final txProvider = Provider.of<TransactionProvider>(context);
    
    return Scaffold(
      appBar: AppBar(
        title: const Text('People'),
        bottom: TabBar(
          controller: _tabController,
          tabs: [
            Tab(
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Text('Contacts'),
                  if (personProvider.incomingRequests.isNotEmpty) ...[
                    const SizedBox(width: 8),
                    Badge(label: Text(personProvider.incomingRequests.length.toString())),
                  ]
                ],
              ),
            ),
            const Tab(text: 'Connections'),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: [
          _buildContactsTab(personProvider, txProvider, currency),
          _buildConnectionsTab(personProvider, authProvider),
        ],
      ),
    );
  }

  Widget _buildContactsTab(PersonProvider personProvider, TransactionProvider txProvider, String currency) {
    final theme = Theme.of(context);
    final format = NumberFormat('#,##0.00');
    final people = personProvider.people;

    if (txProvider.isLoading) return const Center(child: CircularProgressIndicator());
    if (people.isEmpty) return const Center(child: Text('No contacts added yet', style: TextStyle(color: Colors.grey)));

    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: people.length,
      itemBuilder: (context, index) {
        final person = people[index];
        final summary = _calculatePersonSummary(person.id ?? '', txProvider.transactions);
        final netBalance = summary['netBalance'] ?? 0;

        return Card(
          margin: const EdgeInsets.only(bottom: 12),
          child: ListTile(
            onTap: () async {
              await Navigator.push(
                context,
                MaterialPageRoute(builder: (context) => PersonDetailScreen(person: person)),
              );
            },
            leading: CircleAvatar(
              backgroundColor: theme.colorScheme.primary.withOpacity(0.1),
              child: Text(
                person.name.isNotEmpty ? person.name[0].toUpperCase() : '?',
                style: TextStyle(color: theme.colorScheme.primary, fontWeight: FontWeight.bold),
              ),
            ),
            title: Text(person.name, style: const TextStyle(fontWeight: FontWeight.bold)),
            subtitle: Text(
              netBalance == 0
                  ? 'Settled'
                  : netBalance > 0
                      ? 'Owes you $currency ${format.format(netBalance)}'
                      : 'You owe $currency ${format.format(netBalance.abs())}',
              style: TextStyle(
                color: netBalance == 0
                    ? Colors.grey
                    : netBalance > 0
                        ? const Color(0xFF10B981)
                        : const Color(0xFFEF4444),
                fontSize: 12,
                fontWeight: FontWeight.w600,
              ),
            ),
            trailing: const Icon(Icons.chevron_right, size: 20),
          ),
        );
      },
    );
  }

  Widget _buildConnectionsTab(PersonProvider personProvider, ledgix_auth.LedGixAuthProvider authProvider) {
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.all(16.0),
          child: Row(
            children: [
              Expanded(
                child: TextField(
                  controller: _searchController,
                  decoration: InputDecoration(
                    hintText: 'Search user by email',
                    prefixIcon: const Icon(Icons.search),
                    suffixIcon: _isSearching 
                        ? const SizedBox(width: 20, height: 20, child: Padding(padding: EdgeInsets.all(10), child: CircularProgressIndicator(strokeWidth: 2)))
                        : IconButton(icon: const Icon(Icons.send), onPressed: _handleSearch),
                  ),
                  onSubmitted: (_) => _handleSearch(),
                ),
              ),
            ],
          ),
        ),
        if (_foundUser != null) _buildFoundUserCard(personProvider, authProvider),
        Expanded(
          child: ListView(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            children: [
              if (personProvider.incomingRequests.isNotEmpty) ...[
                const Text('Pending Requests', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                const SizedBox(height: 8),
                ...personProvider.incomingRequests.map((req) => _buildRequestCard(req, personProvider, authProvider)),
                const Divider(height: 32),
              ],
              const Text('Connected People', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
              const SizedBox(height: 8),
              if (personProvider.connections.isEmpty)
                const Padding(
                  padding: EdgeInsets.symmetric(vertical: 20),
                  child: Center(child: Text('No connections yet', style: TextStyle(color: Colors.grey))),
                ),
              ...personProvider.connections.map((conn) => _buildConnectionCard(conn, personProvider)),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildFoundUserCard(PersonProvider personProvider, ledgix_auth.LedGixAuthProvider authProvider) {
    final isAlreadyConnected = personProvider.connections.any((c) => c.connectedUserId == _foundUser!.ledgixId);
    final isAlreadySent = personProvider.sentRequests.any((r) => r.receiverId == _foundUser!.ledgixId && r.status == 'pending');

    final theme = Theme.of(context);
    return Card(
      color: theme.colorScheme.primary.withOpacity(0.05),
      child: ListTile(
        title: Text(_foundUser!.name, style: const TextStyle(fontWeight: FontWeight.bold)),
        subtitle: Text(_foundUser!.email),
        trailing: isAlreadyConnected
            ? const Text('Connected', style: TextStyle(color: Colors.grey))
            : isAlreadySent
                ? const Text('Request Sent', style: TextStyle(color: Colors.orange))
                : ElevatedButton(
                    onPressed: () async {
                      if (authProvider.user != null) {
                        await personProvider.sendRequest(_foundUser!, authProvider.user!);
                        setState(() => _foundUser = null);
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(content: Text("Request sent!")),
                        );
                      }
                    },
                    style: ElevatedButton.styleFrom(minimumSize: const Size(80, 36)),
                    child: const Text('Add'),
                  ),
      ),
    );
  }

  Widget _buildRequestCard(ConnectionRequestModel request, PersonProvider personProvider, ledgix_auth.LedGixAuthProvider authProvider) {
    return Card(
      child: ListTile(
        title: Text(request.senderName, style: const TextStyle(fontWeight: FontWeight.bold)),
        subtitle: Text(request.senderEmail),
        trailing: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            IconButton(
              icon: const Icon(Icons.check_circle, color: Colors.green),
              onPressed: () => personProvider.acceptRequest(request, authProvider.user?.name ?? 'User'),
            ),
            IconButton(
              icon: const Icon(Icons.cancel, color: Colors.red),
              onPressed: () => personProvider.rejectRequest(request.id!),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildConnectionCard(UserConnectionModel connection, PersonProvider personProvider) {
    final theme = Theme.of(context);
    return Card(
      child: ListTile(
        leading: CircleAvatar(
          backgroundColor: theme.colorScheme.primary.withOpacity(0.1),
          child: Text(connection.connectedUserName[0].toUpperCase(), style: TextStyle(color: theme.colorScheme.primary, fontWeight: FontWeight.bold)),
        ),
        title: Text(connection.connectedUserName, style: const TextStyle(fontWeight: FontWeight.bold)),
        subtitle: Text(connection.connectedUserEmail),
        trailing: IconButton(
          icon: const Icon(Icons.person_remove, color: Colors.grey, size: 20),
          onPressed: () => _showRemoveDialog(connection, personProvider),
        ),
      ),
    );
  }

  void _showRemoveDialog(UserConnectionModel connection, PersonProvider personProvider) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Remove Connection'),
        content: Text('Are you sure you want to remove ${connection.connectedUserName}?'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel')),
          TextButton(
            onPressed: () {
              personProvider.removeConnection(connection);
              Navigator.pop(context);
            },
            child: const Text('Remove', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );
  }
}
