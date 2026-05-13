import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import '../../Core/database_helper.dart';
import '../../Core/settings_provider.dart';
import 'account_model.dart';

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

  String selectedType = 'Cash';

  final accountTypes = [
    'Cash',
    'Bank',
    'Credit Card',
    'Wallet',
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
    final String currency = Provider.of<SettingsProvider>(context).currency;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Add Account'),
        centerTitle: true,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          children: [
            TextField(
              controller: nameController,
              decoration: const InputDecoration(
                labelText: 'Account Name',
                border: OutlineInputBorder(),
              ),
            ),

            const SizedBox(height: 20),

            DropdownButtonFormField<String>(
              value: selectedType,
              decoration: const InputDecoration(
                labelText: 'Account Type',
                border: OutlineInputBorder(),
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
              const SizedBox(height: 20),
              TextField(
                controller: limitController,
                keyboardType: TextInputType.number,
                inputFormatters: [
                  FilteringTextInputFormatter.digitsOnly,
                  CurrencyInputFormatter(),
                ],
                style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: Color(0xFFDC2626)),
                textAlign: TextAlign.center,
                decoration: InputDecoration(
                  labelText: 'Credit Card Limit',
                  prefixText: '$currency ',
                  floatingLabelBehavior: FloatingLabelBehavior.always,
                  border: const OutlineInputBorder(),
                  focusedBorder: const OutlineInputBorder(borderSide: BorderSide(color: Color(0xFFDC2626), width: 2)),
                ),
              ),
              const SizedBox(height: 12),
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  _quickAmountButton(limitController, '00'),
                  const SizedBox(width: 16),
                  _quickAmountButton(limitController, '000'),
                ],
              ),
            ],

            const SizedBox(height: 20),

            TextField(
              controller: balanceController,
              keyboardType: TextInputType.number,
              inputFormatters: [
                FilteringTextInputFormatter.digitsOnly,
                CurrencyInputFormatter(),
              ],
              style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: Color(0xFF0F766E)),
              textAlign: TextAlign.center,
              decoration: InputDecoration(
                labelText: 'Opening Balance',
                prefixText: '$currency ',
                floatingLabelBehavior: FloatingLabelBehavior.always,
                border: const OutlineInputBorder(),
              ),
            ),

            const SizedBox(height: 12),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                _quickAmountButton(balanceController, '00'),
                const SizedBox(width: 16),
                _quickAmountButton(balanceController, '000'),
              ],
            ),

            const SizedBox(height: 30),

            SizedBox(
              width: double.infinity,
              height: 55,
              child: ElevatedButton(
                style: ElevatedButton.styleFrom(backgroundColor: Colors.black),
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
              openingBalance:
              double.tryParse(balanceController.text.replaceAll(',', '')) ?? 0,
              creditLimit: selectedType == 'Credit Card' ? limit : null,
  );

  await DatabaseHelper.instance
      .insertAccount(newAccount);

  if (mounted) Navigator.pop(context, newAccount.name);
},
                child: const Text('Save', style: TextStyle(color: Colors.white)),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _quickAmountButton(TextEditingController controller, String label) {
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
        side: const BorderSide(color: Color(0xFF0F766E)),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 8),
      ),
      child: Text(
        label,
        style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Color(0xFF0F766E)),
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
