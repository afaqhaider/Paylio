import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../Auth/auth_provider.dart' as ledgix_auth;
import '../Transactions/transactions_screen.dart';
import '../Accounts/accounts_screen.dart';
import '../Budgets/budgets_screen.dart';
import '../Budgets/add_budget_screen.dart';
import '../Accounts/add_account_screen.dart';
import '../Settings/settings_screen.dart';
import '../Categories/categories_screen.dart';
import '../People/people_screen.dart';
import '../Transactions/add_expense_screen.dart';
import '../Commitments/commitments_screen.dart';
import '../Transactions/import_data_screen.dart';
import '../Stats/expense_reports_page.dart';
import '../Stats/income_reports_page.dart';
import '../Stats/financial_health_page.dart';
import '../Goals/goals_screen.dart';
import '../Goals/add_goal_screen.dart';
import '../../Core/backup_service.dart';
import 'dashboard_screen.dart';
import '../../shared/widgets/app_fab.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  int selectedIndex = 0;
  final GlobalKey<ScaffoldState> _scaffoldKey = GlobalKey<ScaffoldState>();
  final ValueNotifier<int> _drawerPage = ValueNotifier<int>(0);

  @override
  void initState() {
    super.initState();
    _loadUserProfile();
  }

  void _loadUserProfile() {
    Future.microtask(() {
      if (mounted) {
        final authProvider = Provider.of<ledgix_auth.LedGixAuthProvider>(context, listen: false);
        final currentUser = FirebaseAuth.instance.currentUser;
        if (currentUser != null && authProvider.user == null) {
          authProvider.fetchUserProfile(currentUser.uid);
        }
      }
    });
  }

  void _changeTab(int index) {
    setState(() {
      selectedIndex = index;
    });
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    final screens = [
      DashboardScreen(onTabChange: _changeTab, scaffoldKey: _scaffoldKey),
      const TransactionsScreen(),
      const BudgetsScreen(),
      const AccountsScreen(),
    ];

    return Scaffold(
      key: _scaffoldKey,
      drawer: _buildDrawer(),
      body: IndexedStack(
        index: selectedIndex,
        children: screens,
      ),
      floatingActionButtonLocation: FloatingActionButtonLocation.centerDocked,
      floatingActionButton: AppFab(
        onPressed: _onFabPressed,
      ),
      bottomNavigationBar: BottomAppBar(
        shape: const CircularNotchedRectangle(),
        notchMargin: 8.0,
        padding: EdgeInsets.zero,
        height: 70,
        color: theme.colorScheme.surface,
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceAround,
          children: [
            _buildNavItem(0, Icons.dashboard_rounded, 'Home'),
            _buildNavItem(1, Icons.receipt_long_rounded, 'Activity'),
            const SizedBox(width: 48), // Space for FAB
            _buildNavItem(2, Icons.pie_chart_rounded, 'Budgets'),
            _buildNavItem(3, Icons.account_balance_wallet_rounded, 'Accounts'),
          ],
        ),
      ),
    );
  }

  void _onFabPressed() {
    switch (selectedIndex) {
      case 0:
      case 1:
        Navigator.push(
          context,
          MaterialPageRoute(builder: (context) => const AddExpenseScreen()),
        );
        break;
      case 2:
        Navigator.push(
          context,
          MaterialPageRoute(builder: (context) => const AddBudgetScreen()),
        );
        break;
      case 3:
        Navigator.push(
          context,
          MaterialPageRoute(builder: (context) => const AddAccountScreen()),
        );
        break;
    }
  }

  Widget _buildNavItem(int index, IconData icon, String label) {
    final theme = Theme.of(context);
    final isSelected = selectedIndex == index;
    return InkWell(
      onTap: () => _changeTab(index),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            icon,
            color: isSelected ? theme.colorScheme.primary : theme.colorScheme.onSurface.withOpacity(0.4),
            size: 24,
          ),
          const SizedBox(height: 4),
          Text(
            label,
            style: TextStyle(
              color: isSelected ? theme.colorScheme.primary : theme.colorScheme.onSurface.withOpacity(0.4),
              fontSize: 10,
              fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDrawer() {
    final theme = Theme.of(context);
    final authProvider = Provider.of<ledgix_auth.LedGixAuthProvider>(context);
    final user = authProvider.user;

    return Drawer(
      backgroundColor: theme.colorScheme.surface,
      child: ValueListenableBuilder<int>(
        valueListenable: _drawerPage,
        builder: (context, page, child) {
          return AnimatedSwitcher(
            duration: const Duration(milliseconds: 300),
            transitionBuilder: (child, animation) {
              final offset = page == 0 ? const Offset(-1, 0) : const Offset(1, 0);
              return SlideTransition(
                position: Tween<Offset>(begin: offset, end: Offset.zero).animate(animation),
                child: child,
              );
            },
            child: _getDrawerPage(page, theme, authProvider, user),
          );
        },
      ),
    );
  }

  Widget _getDrawerPage(int page, ThemeData theme, ledgix_auth.LedGixAuthProvider authProvider, dynamic user) {
    switch (page) {
      case 1: return _buildReportsSubmenu(theme);
      case 2: return _buildImportsSubmenu(theme);
      case 3: return _buildExportsSubmenu(theme);
      case 4: return _buildGoalsSubmenu(theme);
      default: return _buildMainMenu(theme, authProvider, user);
    }
  }

  Widget _buildMainMenu(ThemeData theme, ledgix_auth.LedGixAuthProvider authProvider, dynamic user) {
    return Column(
      key: const ValueKey(0),
      children: [
        _buildDrawerHeader(theme, user),
        Expanded(
          child: ListView(
            padding: EdgeInsets.zero,
            children: [
              _drawerItem(Icons.analytics_outlined, 'Reports', () => _drawerPage.value = 1, hasSubmenu: true),
              _drawerItem(Icons.file_download_outlined, 'Imports', () => _drawerPage.value = 2, hasSubmenu: true),
              _drawerItem(Icons.file_upload_outlined, 'Exports', () => _drawerPage.value = 3, hasSubmenu: true),
              _drawerItem(Icons.people_outline, 'People', () {
                Navigator.pop(context);
                Navigator.push(context, MaterialPageRoute(builder: (context) => const PeopleScreen()));
              }),
              _drawerItem(Icons.category_outlined, 'Categories', () {
                Navigator.pop(context);
                Navigator.push(context, MaterialPageRoute(builder: (context) => const CategoriesScreen()));
              }),
              _drawerItem(Icons.event_repeat_rounded, 'Recurring', () {
                Navigator.pop(context);
                Navigator.push(context, MaterialPageRoute(builder: (context) => const CommitmentsScreen()));
              }),
              _drawerItem(Icons.track_changes_rounded, 'Goals', () => _drawerPage.value = 4, hasSubmenu: true),
              _drawerItem(Icons.document_scanner_outlined, 'Scan Receipt', () {
                 Navigator.pop(context);
                 ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Scan Receipt coming soon')));
              }),
              _drawerItem(Icons.filter_list_rounded, 'Filter', () {
                 Navigator.pop(context);
                 _changeTab(1); 
              }),
              const Divider(),
              _drawerItem(Icons.settings_outlined, 'Settings', () {
                Navigator.pop(context);
                Navigator.push(context, MaterialPageRoute(builder: (context) => const SettingsScreen()));
              }),
              _drawerItem(Icons.help_outline, 'Support', () {
                Navigator.pop(context);
                ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Support coming soon')));
              }),
              _drawerItem(Icons.info_outline_rounded, 'About LedGix', () {
                Navigator.pop(context);
                ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('LedGix v2.0.2+2')));
              }),
            ],
          ),
        ),
        const Divider(),
        _drawerItem(Icons.logout_rounded, 'Logout', () async {
          await authProvider.logout();
        }, color: Colors.red),
        const SizedBox(height: 20),
      ],
    );
  }

  Widget _buildDrawerHeader(ThemeData theme, dynamic user) {
    return UserAccountsDrawerHeader(
      decoration: BoxDecoration(color: theme.colorScheme.surface),
      currentAccountPicture: CircleAvatar(
        backgroundColor: theme.colorScheme.primary,
        child: Text(
          user?.name.substring(0, 1).toUpperCase() ?? 'U',
          style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 24),
        ),
      ),
      accountName: Text(user?.name ?? 'User', style: theme.textTheme.titleMedium),
      accountEmail: Text(user?.email ?? '', style: theme.textTheme.bodySmall),
    );
  }

  Widget _buildSubmenuHeader(String title, ThemeData theme) {
    return Container(
      padding: const EdgeInsets.only(top: 60, bottom: 20, left: 8, right: 16),
      color: theme.colorScheme.surface,
      child: Row(
        children: [
          IconButton(
            icon: const Icon(Icons.arrow_back_ios_new_rounded),
            onPressed: () => _drawerPage.value = 0,
          ),
          const SizedBox(width: 8),
          Text(title, style: theme.textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold)),
        ],
      ),
    );
  }

  Widget _buildReportsSubmenu(ThemeData theme) {
    return Column(
      key: const ValueKey(1),
      children: [
        _buildSubmenuHeader('Reports', theme),
        Expanded(
          child: ListView(
            padding: EdgeInsets.zero,
            children: [
              _drawerItem(Icons.trending_down_rounded, 'Expense Reports', () {
                Navigator.pop(context);
                Navigator.push(context, MaterialPageRoute(builder: (context) => const ExpenseReportsPage()));
              }),
              _drawerItem(Icons.trending_up_rounded, 'Income Reports', () {
                Navigator.pop(context);
                Navigator.push(context, MaterialPageRoute(builder: (context) => const IncomeReportsPage()));
              }),
              _drawerItem(Icons.health_and_safety_outlined, 'Financial Health', () {
                Navigator.pop(context);
                Navigator.push(context, MaterialPageRoute(builder: (context) => const FinancialHealthPage()));
              }),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildImportsSubmenu(ThemeData theme) {
    return Column(
      key: const ValueKey(2),
      children: [
        _buildSubmenuHeader('Imports', theme),
        Expanded(
          child: ListView(
            padding: EdgeInsets.zero,
            children: [
              _drawerItem(Icons.receipt_long_rounded, 'Import Transactions', () {
                 Navigator.pop(context);
                 Navigator.push(context, MaterialPageRoute(builder: (context) => const ImportDataScreen(initialType: ImportType.transactions)));
              }),
              _drawerItem(Icons.category_rounded, 'Import Categories', () {
                 Navigator.pop(context);
                 Navigator.push(context, MaterialPageRoute(builder: (context) => const ImportDataScreen(initialType: ImportType.categories)));
              }),
              _drawerItem(Icons.account_balance_wallet_rounded, 'Import Accounts', () {
                 Navigator.pop(context);
                 Navigator.push(context, MaterialPageRoute(builder: (context) => const ImportDataScreen(initialType: ImportType.accounts)));
              }),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildExportsSubmenu(ThemeData theme) {
    return Column(
      key: const ValueKey(3),
      children: [
        _buildSubmenuHeader('Exports', theme),
        Expanded(
          child: ListView(
            padding: EdgeInsets.zero,
            children: [
              _drawerItem(Icons.table_rows_rounded, 'Export CSV', () async {
                 Navigator.pop(context);
                 try {
                   await BackupService.exportTransactionsCsv();
                 } catch (e) {
                   if (mounted) {
                     ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Export failed: $e')));
                   }
                 }
              }),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildGoalsSubmenu(ThemeData theme) {
    return Column(
      key: const ValueKey(4),
      children: [
        _buildSubmenuHeader('Goals', theme),
        Expanded(
          child: ListView(
            padding: EdgeInsets.zero,
            children: [
              _drawerItem(Icons.track_changes_rounded, 'Savings Goals', () {
                 Navigator.pop(context);
                 Navigator.push(context, MaterialPageRoute(builder: (context) => const GoalsScreen()));
              }),
              _drawerItem(Icons.pie_chart_rounded, 'Budgets', () {
                 Navigator.pop(context);
                 _changeTab(2);
              }),
              _drawerItem(Icons.add_task_rounded, 'New Goal', () {
                 Navigator.pop(context);
                 Navigator.push(context, MaterialPageRoute(builder: (context) => const AddGoalScreen()));
              }),
            ],
          ),
        ),
      ],
    );
  }

  Widget _drawerItem(IconData icon, String title, VoidCallback onTap, {Color? color, bool hasSubmenu = false}) {
    return ListTile(
      leading: Icon(icon, color: color ?? Theme.of(context).colorScheme.onSurface.withOpacity(0.7)),
      title: Text(title, style: TextStyle(color: color, fontWeight: FontWeight.w600)),
      trailing: hasSubmenu ? const Icon(Icons.chevron_right_rounded, size: 20) : null,
      onTap: onTap,
      dense: true,
      visualDensity: VisualDensity.compact,
    );
  }

  Widget _drawerSubItem(String title, VoidCallback onTap) {
    return ListTile(
      contentPadding: const EdgeInsets.only(left: 72),
      title: Text(title, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w500)),
      onTap: onTap,
      dense: true,
      visualDensity: VisualDensity.compact,
    );
  }
}
