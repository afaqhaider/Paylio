import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../Core/settings_provider.dart';
import '../Accounts/account_provider.dart';
import '../Accounts/account_model.dart';
import '../Dashboard/Home_Screen.dart';
import '../../shared/widgets/app_button.dart';

class OnboardingWizard extends StatefulWidget {
  const OnboardingWizard({super.key});

  @override
  State<OnboardingWizard> createState() => _OnboardingWizardState();
}

class _OnboardingWizardState extends State<OnboardingWizard> {
  final PageController _pageController = PageController();
  int _currentPage = 0;

  // State for onboarding data
  String selectedCurrency = 'AED';
  String mainBankName = '';
  double monthlyIncome = 0;
  double savingsGoal = 0;
  double monthlyBudget = 0;

  void _nextPage() {
    if (_currentPage < 10) {
      _pageController.nextPage(duration: const Duration(milliseconds: 400), curve: Curves.easeInOut);
    } else {
      _finishOnboarding();
    }
  }

  void _finishOnboarding() async {
    final settings = Provider.of<SettingsProvider>(context, listen: false);
    final accountProvider = Provider.of<AccountProvider>(context, listen: false);
    
    // Save currency
    await settings.setCurrency(selectedCurrency);

    // Create initial bank account if provided
    if (mainBankName.isNotEmpty) {
      await accountProvider.saveAccount(AccountModel(
        name: mainBankName,
        type: 'Bank Account',
        openingBalance: 0,
      ));
    }

    // Mark onboarding as complete (Logic to be implemented in AuthProvider or Settings)
    if (mounted) {
      Navigator.pushReplacement(context, MaterialPageRoute(builder: (context) => const HomeScreen()));
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      backgroundColor: theme.scaffoldBackgroundColor,
      body: SafeArea(
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(24, 24, 24, 0),
              child: Row(
                children: List.generate(11, (index) => Expanded(
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 300),
                    height: 6,
                    margin: const EdgeInsets.symmetric(horizontal: 3),
                    decoration: BoxDecoration(
                      color: index <= _currentPage ? theme.colorScheme.primary : theme.colorScheme.outline.withOpacity(0.2),
                      borderRadius: BorderRadius.circular(10),
                    ),
                  ),
                )),
              ),
            ),
            Expanded(
              child: PageView(
                controller: _pageController,
                physics: const NeverScrollableScrollPhysics(),
                onPageChanged: (idx) => setState(() => _currentPage = idx),
                children: [
                  _welcomeStep(theme),
                  _currencyStep(theme),
                  _paymentMethodStep(theme),
                  _bankStep(theme),
                  _addAccountsStep(theme),
                  _incomeStep(theme),
                  _savingsStep(theme),
                  _budgetStep(theme),
                  _budgetComponentsStep(theme),
                  _notificationsStep(theme),
                  _reminderStep(theme),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _welcomeStep(ThemeData theme) {
    return Padding(
      padding: const EdgeInsets.all(40.0),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Hero(
            tag: 'logo',
            child: Image.asset('assets/logo/ledgix_logo.png', height: 100, errorBuilder: (c,e,s) => const Icon(Icons.account_balance_wallet_rounded, size: 80, color: Color(0xFF218BFF))),
          ),
          const SizedBox(height: 48),
          Text('Welcome to LedGix', style: theme.textTheme.displaySmall?.copyWith(fontWeight: FontWeight.w900, letterSpacing: -1)),
          const SizedBox(height: 20),
          Text(
            'The professional financial operating system. Let\'s tailor the experience for your lifestyle.',
            textAlign: TextAlign.center,
            style: theme.textTheme.bodyLarge?.copyWith(color: theme.colorScheme.onSurface.withOpacity(0.6), height: 1.5),
          ),
          const Spacer(),
          AppButton(
            onPressed: _nextPage, 
            label: 'Initialize Setup',
          ),
        ],
      ),
    );
  }

  Widget _currencyStep(ThemeData theme) {
    final currencies = ['AED', 'USD', 'PKR', 'INR', 'EUR', 'GBP'];
    return Padding(
      padding: const EdgeInsets.all(32.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const SizedBox(height: 20),
          Text('Select Currency', style: theme.textTheme.headlineMedium?.copyWith(fontWeight: FontWeight.w900)),
          const SizedBox(height: 12),
          Text('All reports and summaries will use this currency.', style: theme.textTheme.bodyMedium),
          const SizedBox(height: 40),
          Expanded(
            child: ListView.separated(
              itemCount: currencies.length,
              separatorBuilder: (c, i) => const SizedBox(height: 12),
              itemBuilder: (context, index) {
                bool isSelected = selectedCurrency == currencies[index];
                return ListTile(
                  onTap: () => setState(() => selectedCurrency = currencies[index]),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(20),
                    side: BorderSide(color: isSelected ? theme.colorScheme.primary : theme.colorScheme.outline, width: isSelected ? 2 : 1),
                  ),
                  tileColor: isSelected ? theme.colorScheme.primary.withOpacity(0.05) : null,
                  title: Text(currencies[index], style: const TextStyle(fontWeight: FontWeight.w800)),
                  trailing: isSelected ? Icon(Icons.check_circle_rounded, color: theme.colorScheme.primary) : null,
                );
              },
            ),
          ),
          AppButton(onPressed: _nextPage, label: 'Confirm & Continue'),
        ],
      ),
    );
  }

  Widget _paymentMethodStep(ThemeData theme) {
    return _stepTemplate(
      theme, 
      'Primary Payment', 
      'What is your most used payment method?', 
      Icons.contactless_rounded, 
      ['Credit Card', 'Debit Card', 'Cash', 'Mobile Wallet'],
      'Continue'
    );
  }

  Widget _bankStep(ThemeData theme) {
    return Padding(
      padding: const EdgeInsets.all(32.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const SizedBox(height: 20),
          Text('Main Bank', style: theme.textTheme.headlineMedium?.copyWith(fontWeight: FontWeight.w900)),
          const SizedBox(height: 12),
          Text('Your primary financial institution for payroll and large expenses.', style: theme.textTheme.bodyMedium),
          const SizedBox(height: 40),
          TextField(
            onChanged: (val) => mainBankName = val,
            style: const TextStyle(fontWeight: FontWeight.bold),
            decoration: const InputDecoration(
              labelText: 'Bank Name',
              hintText: 'e.g. Emirates NBD, RAKBANK',
            ),
          ),
          const Spacer(),
          AppButton(onPressed: _nextPage, label: 'Continue'),
        ],
      ),
    );
  }

  Widget _addAccountsStep(ThemeData theme) {
    return _stepTemplate(
      theme, 
      'Additional Assets', 
      'Would you like to add other accounts now?', 
      Icons.account_balance_wallet_rounded, 
      ['Yes, Add Account', 'Maybe Later'],
      'Continue'
    );
  }

  Widget _incomeStep(ThemeData theme) {
    return Padding(
      padding: const EdgeInsets.all(32.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const SizedBox(height: 20),
          Text('Monthly Income', style: theme.textTheme.headlineMedium?.copyWith(fontWeight: FontWeight.w900)),
          const SizedBox(height: 12),
          Text('Estimate your total net monthly income.', style: theme.textTheme.bodyMedium),
          const SizedBox(height: 40),
          TextField(
            keyboardType: TextInputType.number,
            onChanged: (val) => monthlyIncome = double.tryParse(val) ?? 0,
            style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 24),
            decoration: InputDecoration(
              prefixIcon: Padding(padding: const EdgeInsets.all(16), child: Text(selectedCurrency, style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 18))),
              labelText: 'Income Amount',
            ),
          ),
          const Spacer(),
          AppButton(onPressed: _nextPage, label: 'Continue'),
        ],
      ),
    );
  }

  Widget _savingsStep(ThemeData theme) {
    return Padding(
      padding: const EdgeInsets.all(32.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const SizedBox(height: 20),
          Text('Savings Goal', style: theme.textTheme.headlineMedium?.copyWith(fontWeight: FontWeight.w900)),
          const SizedBox(height: 12),
          Text('Set a monthly target for your savings.', style: theme.textTheme.bodyMedium),
          const SizedBox(height: 40),
          TextField(
            keyboardType: TextInputType.number,
            onChanged: (val) => savingsGoal = double.tryParse(val) ?? 0,
            style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 24),
            decoration: InputDecoration(
              prefixIcon: Padding(padding: const EdgeInsets.all(16), child: Text(selectedCurrency, style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 18))),
              labelText: 'Savings Goal',
            ),
          ),
          const Spacer(),
          AppButton(onPressed: _nextPage, label: 'Set Goal'),
        ],
      ),
    );
  }

  Widget _budgetStep(ThemeData theme) {
    return Padding(
      padding: const EdgeInsets.all(32.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const SizedBox(height: 20),
          Text('Total Budget', style: theme.textTheme.headlineMedium?.copyWith(fontWeight: FontWeight.w900)),
          const SizedBox(height: 12),
          Text('Total monthly spending limit across all categories.', style: theme.textTheme.bodyMedium),
          const SizedBox(height: 40),
          TextField(
            keyboardType: TextInputType.number,
            onChanged: (val) => monthlyBudget = double.tryParse(val) ?? 0,
            style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 24),
            decoration: InputDecoration(
              prefixIcon: Padding(padding: const EdgeInsets.all(16), child: Text(selectedCurrency, style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 18))),
              labelText: 'Monthly Budget',
            ),
          ),
          const Spacer(),
          AppButton(onPressed: _nextPage, label: 'Next Step'),
        ],
      ),
    );
  }

  Widget _budgetComponentsStep(ThemeData theme) {
    return _stepTemplate(
      theme, 
      'Budget Components', 
      'Customize your spending categories.', 
      Icons.dashboard_customize_rounded, 
      ['Essentials', 'Lifestyle', 'Investments', 'Debt'],
      'Continue'
    );
  }

  Widget _notificationsStep(ThemeData theme) {
    return _stepTemplate(
      theme, 
      'Notifications', 
      'Stay updated on important transactions.', 
      Icons.notifications_active_rounded, 
      ['All Alerts', 'Only Approvals', 'Quiet Mode'],
      'Continue'
    );
  }

  Widget _reminderStep(ThemeData theme) {
    return _stepTemplate(
      theme, 
      'Final Reminders', 
      'Set up your EMIs, rent, and recurring payments.', 
      Icons.event_repeat_rounded, 
      ['Setup Now', 'I\'ll do it later'],
      'Finish & Launch'
    );
  }

  Widget _stepTemplate(ThemeData theme, String title, String desc, IconData icon, List<String> options, String buttonText) {
    String? selectedOption;
    return Padding(
      padding: const EdgeInsets.all(32.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const SizedBox(height: 20),
          Icon(icon, size: 48, color: theme.colorScheme.primary),
          const SizedBox(height: 24),
          Text(title, style: theme.textTheme.headlineMedium?.copyWith(fontWeight: FontWeight.w900)),
          const SizedBox(height: 12),
          Text(desc, style: theme.textTheme.bodyLarge?.copyWith(color: theme.colorScheme.onSurface.withOpacity(0.6))),
          const SizedBox(height: 32),
          Expanded(
            child: ListView.separated(
              itemCount: options.length,
              separatorBuilder: (c, i) => const SizedBox(height: 12),
              itemBuilder: (context, index) {
                return ListTile(
                  onTap: () {}, // Just visual for now
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(20),
                    side: BorderSide(color: theme.colorScheme.outline),
                  ),
                  title: Text(options[index], style: const TextStyle(fontWeight: FontWeight.bold)),
                );
              },
            ),
          ),
          const SizedBox(height: 20),
          AppButton(onPressed: _nextPage, label: buttonText),
        ],
      ),
    );
  }
}
