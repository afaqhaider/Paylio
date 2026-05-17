import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import 'commitment_model.dart';
import 'commitment_provider.dart';
import '../Accounts/account_provider.dart';
import '../../shared/widgets/app_button.dart';

class AddCommitmentScreen extends StatefulWidget {
  const AddCommitmentScreen({super.key});

  @override
  State<AddCommitmentScreen> createState() => _AddCommitmentScreenState();
}

class _AddCommitmentScreenState extends State<AddCommitmentScreen> {
  final _formKey = GlobalKey<FormState>();
  
  String _name = '';
  String _type = 'Rent';
  double _amount = 0;
  String? _selectedAccount;
  DateTime _dueDate = DateTime.now();
  String _frequency = 'Monthly';
  String _notes = '';

  // Rent specific
  String _propertyName = '';
  String _landlordName = '';
  int _numCheques = 1;

  // Utility specific
  String _providerName = '';
  String _accountNumber = '';

  // EMI specific
  String _bankName = '';
  double _loanAmount = 0;
  bool _autoDebit = false;

  final List<String> _types = [
    'Rent', 'Utility', 'Phone EMI', 'Car EMI', 'Home Loan EMI', 
    'Personal Loan EMI', 'Credit Card Payment', 'Insurance', 
    'Subscription', 'School Fees', 'Other'
  ];

  final List<String> _frequencies = ['Monthly', 'Weekly', 'Quarterly', 'Yearly', 'One-time'];

  @override
  Widget build(BuildContext context) {
    final accProvider = Provider.of<AccountProvider>(context);
    final commitmentProvider = Provider.of<CommitmentProvider>(context);
    final theme = Theme.of(context);

    return Scaffold(
      backgroundColor: theme.scaffoldBackgroundColor,
      appBar: AppBar(
        title: const Text('Add Commitment', style: TextStyle(fontWeight: FontWeight.w900)),
        centerTitle: true,
      ),
      body: Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.all(24),
          children: [
             Text(
              'GENERAL INFO',
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.onSurface.withOpacity(0.4),
                fontWeight: FontWeight.w900,
                letterSpacing: 1.5,
              ),
            ),
            const SizedBox(height: 24),
            TextFormField(
              style: const TextStyle(fontWeight: FontWeight.bold),
              decoration: const InputDecoration(
                labelText: 'Commitment Name',
                hintText: 'e.g. Monthly Rent, Netflix',
              ),
              validator: (v) => v == null || v.isEmpty ? 'Required' : null,
              onSaved: (v) => _name = v!,
            ),
            const SizedBox(height: 24),
            DropdownButtonFormField<String>(
              initialValue: _type,
              decoration: const InputDecoration(labelText: 'Commitment Type'),
              items: _types.map((t) => DropdownMenuItem(value: t, child: Text(t))).toList(),
              onChanged: (v) => setState(() => _type = v!),
            ),
            const SizedBox(height: 24),
            TextFormField(
              style: TextStyle(fontSize: 24, fontWeight: FontWeight.w900, color: theme.colorScheme.primary),
              decoration: const InputDecoration(
                labelText: 'Amount',
                prefixText: 'AED ',
              ),
              keyboardType: TextInputType.number,
              validator: (v) => v == null || double.tryParse(v) == null ? 'Invalid amount' : null,
              onSaved: (v) => _amount = double.parse(v!),
            ),
            const SizedBox(height: 24),
            DropdownButtonFormField<String>(
              initialValue: _selectedAccount,
              decoration: const InputDecoration(labelText: 'Linked Account'),
              items: accProvider.accounts.map((a) => DropdownMenuItem(value: a.name, child: Text(a.name))).toList(),
              onChanged: (v) => setState(() => _selectedAccount = v),
              validator: (v) => v == null ? 'Required' : null,
            ),
            const SizedBox(height: 24),
            InkWell(
              onTap: () async {
                final d = await showDatePicker(
                  context: context, 
                  initialDate: _dueDate, 
                  firstDate: DateTime.now().subtract(const Duration(days: 365)), 
                  lastDate: DateTime.now().add(const Duration(days: 3650))
                );
                if (d != null) setState(() => _dueDate = d);
              },
              child: InputDecorator(
                decoration: const InputDecoration(labelText: 'Due Date'),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(DateFormat('EEEE, dd MMM yyyy').format(_dueDate), style: const TextStyle(fontWeight: FontWeight.bold)),
                    const Icon(Icons.calendar_today, size: 18),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 24),
            DropdownButtonFormField<String>(
              initialValue: _frequency,
              decoration: const InputDecoration(labelText: 'Frequency'),
              items: _frequencies.map((f) => DropdownMenuItem(value: f, child: Text(f))).toList(),
              onChanged: (v) => setState(() => _frequency = v!),
            ),

            // Type specific fields
            if (_type == 'Rent') ..._buildRentFields(theme),
            if (_type == 'Utility') ..._buildUtilityFields(theme),
            if (_type.contains('EMI') || _type.contains('Loan')) ..._buildEmiFields(theme),

            const SizedBox(height: 32),
            Text(
              'ADDITIONAL NOTES',
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.onSurface.withOpacity(0.4),
                fontWeight: FontWeight.w900,
                letterSpacing: 1.5,
              ),
            ),
            const SizedBox(height: 16),
            TextFormField(
              decoration: const InputDecoration(
                labelText: 'Notes',
                hintText: 'Any extra details...',
              ),
              maxLines: 3,
              onSaved: (v) => _notes = v ?? '',
            ),
            const SizedBox(height: 48),
            AppButton(
              onPressed: () => _save(commitmentProvider),
              label: 'Save Commitment',
            ),
            const SizedBox(height: 40),
          ],
        ),
      ),
    );
  }

  List<Widget> _buildRentFields(ThemeData theme) {
    return [
      const SizedBox(height: 32),
      Text(
        'PROPERTY DETAILS',
        style: theme.textTheme.bodySmall?.copyWith(
          color: theme.colorScheme.onSurface.withOpacity(0.4),
          fontWeight: FontWeight.w900,
          letterSpacing: 1.5,
        ),
      ),
      const SizedBox(height: 24),
      TextFormField(
        decoration: const InputDecoration(labelText: 'Property Name / House #'),
        onSaved: (v) => _propertyName = v ?? '',
      ),
      const SizedBox(height: 24),
      TextFormField(
        decoration: const InputDecoration(labelText: 'Landlord Name'),
        onSaved: (v) => _landlordName = v ?? '',
      ),
      const SizedBox(height: 24),
      TextFormField(
        decoration: const InputDecoration(labelText: 'Number of Cheques'),
        keyboardType: TextInputType.number,
        onSaved: (v) => _numCheques = int.tryParse(v ?? '1') ?? 1,
      ),
    ];
  }

  List<Widget> _buildUtilityFields(ThemeData theme) {
    return [
      const SizedBox(height: 32),
       Text(
        'UTILITY INFO',
        style: theme.textTheme.bodySmall?.copyWith(
          color: theme.colorScheme.onSurface.withOpacity(0.4),
          fontWeight: FontWeight.w900,
          letterSpacing: 1.5,
        ),
      ),
      const SizedBox(height: 24),
      TextFormField(
        decoration: const InputDecoration(labelText: 'Provider Name (DEWA, Etisalat, etc.)'),
        onSaved: (v) => _providerName = v ?? '',
      ),
      const SizedBox(height: 24),
      TextFormField(
        decoration: const InputDecoration(labelText: 'Account / Customer Number'),
        onSaved: (v) => _accountNumber = v ?? '',
      ),
    ];
  }

  List<Widget> _buildEmiFields(ThemeData theme) {
    return [
      const SizedBox(height: 32),
       Text(
        'LOAN & EMI DETAILS',
        style: theme.textTheme.bodySmall?.copyWith(
          color: theme.colorScheme.onSurface.withOpacity(0.4),
          fontWeight: FontWeight.w900,
          letterSpacing: 1.5,
        ),
      ),
      const SizedBox(height: 24),
      TextFormField(
        decoration: const InputDecoration(labelText: 'Bank / Lender Name'),
        onSaved: (v) => _bankName = v ?? '',
      ),
      const SizedBox(height: 24),
      TextFormField(
        decoration: const InputDecoration(labelText: 'Original Loan Amount'),
        keyboardType: TextInputType.number,
        onSaved: (v) => _loanAmount = double.tryParse(v ?? '0') ?? 0,
      ),
      const SizedBox(height: 16),
      SwitchListTile(
        title: const Text('Auto Debit Enabled', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
        value: _autoDebit, 
        activeColor: theme.colorScheme.primary,
        onChanged: (v) => setState(() => _autoDebit = v)
      ),
    ];
  }

  void _save(CommitmentProvider provider) async {
    if (_formKey.currentState!.validate()) {
      _formKey.currentState!.save();
      
      final commitment = CommitmentModel(
        name: _name,
        type: _type,
        amount: _amount,
        linkedAccount: _selectedAccount!,
        dueDate: _dueDate,
        frequency: _frequency,
        notes: _notes,
        propertyName: _propertyName,
        landlordName: _landlordName,
        numberOfCheques: _numCheques,
        providerName: _providerName,
        accountNumber: _accountNumber,
        bankName: _bankName,
        originalLoanAmount: _loanAmount,
        autoDebit: _autoDebit,
        status: 'Upcoming',
      );

      await provider.saveCommitment(commitment);
      if (mounted) Navigator.pop(context);
    }
  }
}
