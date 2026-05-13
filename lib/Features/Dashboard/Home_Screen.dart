import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../Auth/auth_provider.dart' as paylio_auth;
import '../Transactions/transactions_screen.dart';
import '../Accounts/accounts_screen.dart';
import '../Budgets/budgets_screen.dart';
import '../Settings/settings_screen.dart';
import '../Categories/categories_screen.dart';
import '../People/people_screen.dart';
import 'dashboard_screen.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  int selectedIndex = 0;

  @override
  void initState() {
    super.initState();
    _loadUserProfile();
  }

  void _loadUserProfile() {
    Future.microtask(() {
      if (mounted) {
        final authProvider = Provider.of<paylio_auth.PaylioAuthProvider>(context, listen: false);
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
    final screens = [
      DashboardScreen(onTabChange: _changeTab),
      const TransactionsScreen(),
      const PeopleScreen(),
      const CategoriesScreen(),
      const BudgetsScreen(),
      const AccountsScreen(),
      const SettingsScreen(),
    ];

    return Scaffold(
      body: IndexedStack(
        index: selectedIndex,
        children: screens,
      ),
      bottomNavigationBar: BottomNavigationBar(
        currentIndex: selectedIndex,
        type: BottomNavigationBarType.fixed,
        onTap: _changeTab,
        selectedFontSize: 10,
        unselectedFontSize: 10,
        items: const [
          BottomNavigationBarItem(
            icon: Icon(Icons.dashboard_outlined, size: 20),
            activeIcon: Icon(Icons.dashboard, size: 20),
            label: 'Home',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.receipt_long_outlined, size: 20),
            activeIcon: Icon(Icons.receipt_long, size: 20),
            label: 'Activity',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.people_outline, size: 20),
            activeIcon: Icon(Icons.people, size: 20),
            label: 'People',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.category_outlined, size: 20),
            activeIcon: Icon(Icons.category, size: 20),
            label: 'Categories',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.pie_chart_outline, size: 20),
            activeIcon: Icon(Icons.pie_chart, size: 20),
            label: 'Budgets',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.account_balance_wallet_outlined, size: 20),
            activeIcon: Icon(Icons.account_balance_wallet, size: 20),
            label: 'Accounts',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.settings_outlined, size: 20),
            activeIcon: Icon(Icons.settings, size: 20),
            label: 'Settings',
          ),
        ],
      ),
    );
  }
}
