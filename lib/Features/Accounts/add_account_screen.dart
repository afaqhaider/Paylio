import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import '../../Core/settings_provider.dart';
import 'account_model.dart';
import 'account_provider.dart';
import '../../shared/widgets/app_button.dart';

class AddAccountScreen extends StatefulWidget {
  final String? initialName;
  const AddAccountScreen({super.key, this.initialName});

  @override
  State<AddAccountScreen> createState() => _AddAccountScreenState();
}

class _AddAccountScreenState extends State<AddAccountScreen> {
  final nameController = TextEditingController();
  final balanceController = TextEditingController(text: "0.00");
  final limitController = TextEditingController(text: "0.00");

  String selectedType = 'Bank';
  bool hasDirectDebit = false;

  final accountTypes = [
    'Bank',
    'Cash',
    'Credit Card',
    'Savings',
    'Investment',
    'Loan',
  ];

  @override
  void initState() {
    super.initState();
    if (widget.initialName != null) {
      nameController.text = widget.initialName!;
    }
  }

  @override
  Widget build(BuildContext context) {
    final settings = Provider.of<SettingsProvider>(context);
    final String currency = settings.currency;
    final theme = Theme.of(context);

    return Scaffold(
      backgroundColor: theme.scaffoldBackgroundColor,
      appBar: AppBar(
        title: const Text('Add Account', style: TextStyle(fontWeight: FontWeight.w900)),
        centerTitle: true,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'ACCOUNT IDENTITY',
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.onSurface.withOpacity(0.4),
                fontWeight: FontWeight.w900,
                letterSpacing: 1.5,
              ),
            ),
            const SizedBox(height: 24),
            TextField(
              controller: nameController,
              style: const TextStyle(fontWeight: FontWeight.bold),
              decoration: const InputDecoration(
                labelText: 'Account Name',
                hintText: 'e.g. Emirates NBD, Personal Cash',
              ),
            ),

            const SizedBox(height: 24),

            DropdownButtonFormField<String>(
              initialValue: selectedType,
              decoration: const InputDecoration(
                labelText: 'Account Type',
              ),
              items: accountTypes.map((type) {
                return DropdownMenuItem(
                  value: type,
                  child: Text(type),
                );
              }).toList(),
              onChanged: (value) {
                setState(() {
                  selectedType = value!;
                });
              },
            ),

            if (selectedType == 'Credit Card') ...[
              const SizedBox(height: 32),
              Text(
                'CREDIT FACILITY',
                style: theme.textTheme.bodySmall?.copyWith(
                  color: Colors.redAccent.withOpacity(0.7),
                  fontWeight: FontWeight.w900,
                  letterSpacing: 1.5,
                ),
              ),
              const SizedBox(height: 16),
              TextField(
                controller: limitController,
                keyboardType: TextInputType.number,
                inputFormatters: [
                  FilteringTextInputFormatter.digitsOnly,
                  CurrencyInputFormatter(),
                ],
                style: TextStyle(fontSize: 32, fontWeight: FontWeight.w900, color: theme.colorScheme.onSurface),
                textAlign: TextAlign.center,
                decoration: InputDecoration(
                  labelText: 'Credit Limit',
                  prefixText: '$currency ',
                  floatingLabelBehavior: FloatingLabelBehavior.always,
                ),
              ),
              const SizedBox(height: 12),
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  _quickAmountButton(limitController, '00', theme),
                  const SizedBox(width: 16),
                  _quickAmountButton(limitController, '000', theme),
                ],
              ),
            ],

            if (selectedType == 'Bank' || selectedType == 'Savings') ...[
              const SizedBox(height: 16),
              SwitchListTile(
                title: const Text('Direct Debit Enabled', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
                subtitle: const Text('Allow recurring commitments from this account', style: TextStyle(fontSize: 12)),
                value: hasDirectDebit,
                activeColor: theme.colorScheme.primary,
                onChanged: (val) => setState(() => hasDirectDebit = val),
              ),
            ],

            const SizedBox(height: 32),
            Text(
              'INITIAL STATUS',
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.primary.withOpacity(0.7),
                fontWeight: FontWeight.w900,
                letterSpacing: 1.5,
              ),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: balanceController,
              keyboardType: TextInputType.number,
              inputFormatters: [
                FilteringTextInputFormatter.digitsOnly,
                CurrencyInputFormatter(),
              ],
              style: TextStyle(fontSize: 32, fontWeight: FontWeight.w900, color: theme.colorScheme.primary),
              textAlign: TextAlign.center,
              decoration: InputDecoration(
                labelText: 'Opening Balance',
                prefixText: '$currency ',
                floatingLabelBehavior: FloatingLabelBehavior.always,
              ),
            ),

            const SizedBox(height: 12),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                _quickAmountButton(balanceController, '00', theme),
                const SizedBox(width: 16),
                _quickAmountButton(balanceController, '000', theme),
              ],
            ),

            const SizedBox(height: 48),

            AppButton(
              label: 'Initialize Account',
              onPressed: () async {
                if (nameController.text.trim().isEmpty) {
                  ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Please enter account name')));
                  return;
                }

                double limit = double.tryParse(limitController.text.replaceAll(',', '')) ?? 0;
                if (selectedType == 'Credit Card' && limit <= 0) {
                  ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Please enter a valid credit card limit')));
                  return;
                }

                final newAccount = AccountModel(
                  name: nameController.text.trim(),
                  type: selectedType,
                  openingBalance: double.tryParse(balanceController.text.replaceAll(',', '')) ?? 0,
                  creditLimit: selectedType == 'Credit Card' ? limit : null,
                  hasDirectDebit: hasDirectDebit,
                );

                await Provider.of<AccountProvider>(context, listen: false).saveAccount(newAccount);

                if (mounted) Navigator.pop(context, newAccount.name);
              },
            ),
            const SizedBox(height: 40),
          ],
        ),
      ),
    );
  }

  Widget _quickAmountButton(TextEditingController controller, String label, ThemeData theme) {
    return OutlinedButton(
      onPressed: () {
        String currentText = controller.text.replaceAll(RegExp(r'[^0-9]'), '');
        if (currentText.length > 12) return;
        String newText = currentText + label;
        double value = double.tryParse(newText) ?? 0;
        final formatted = NumberFormat("#,##0.00", "en_US").format(value / 100);
        setState(() {
          controller.text = formatted;
          controller.selection = TextSelection.collapsed(offset: formatted.length);
        });
      },
      style: OutlinedButton.styleFrom(
        side: BorderSide(color: theme.colorScheme.outline),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
      ),
      child: Text(
        '+$label',
        style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: theme.colorScheme.onSurface.withOpacity(0.6)),
      ),
    );
  }
}

class CurrencyInputFormatter extends TextInputFormatter {
  @override
  TextEditingValue formatEditUpdate(TextEditingValue oldValue, TextEditingValue newValue) {
    if (newValue.text.isEmpty) {
      return newValue.copyWith(text: "0.00", selection: const TextSelection.collapsed(offset: 4));
    }

    String digits = newValue.text.replaceAll(RegExp(r'[^0-9]'), '');
    double value = double.tryParse(digits) ?? 0;
    final formatter = NumberFormat("#,##0.00", "en_US");
    String newText = formatter.format(value / 100);

    return newValue.copyWith(
      text: newText,
      selection: TextSelection.collapsed(offset: newText.length),
    );
  }
}
