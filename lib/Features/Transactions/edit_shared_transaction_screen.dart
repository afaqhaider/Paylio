import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'shared_transaction_model.dart';
import 'shared_transaction_provider.dart';

class EditSharedTransactionScreen extends StatefulWidget {
  final SharedTransactionModel transaction;
  const EditSharedTransactionScreen({super.key, required this.transaction});

  @override
  State<EditSharedTransactionScreen> createState() => _EditSharedTransactionScreenState();
}

class _EditSharedTransactionScreenState extends State<EditSharedTransactionScreen> {
  late TextEditingController amountController;
  late TextEditingController rateController;
  late TextEditingController noteController;

  @override
  void initState() {
    super.initState();
    amountController = TextEditingController(text: widget.transaction.convertedAmount.toStringAsFixed(2));
    rateController = TextEditingController(text: widget.transaction.exchangeRate.toStringAsFixed(4));
    noteController = TextEditingController(text: widget.transaction.description);
  }

  @override
  Widget build(BuildContext context) {
    final sharedProvider = Provider.of<SharedTransactionProvider>(context, listen: false);

    return Scaffold(
      appBar: AppBar(title: const Text('Edit Shared Transaction')),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Original Amount: ${widget.transaction.originalCurrency} ${widget.transaction.originalAmount}', 
                 style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.grey)),
            const SizedBox(height: 20),
            TextField(
              controller: amountController,
              keyboardType: const TextInputType.numberWithOptions(decimal: true),
              decoration: InputDecoration(
                labelText: 'Received Amount (${widget.transaction.receiverCurrency})',
                border: const OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 20),
            TextField(
              controller: rateController,
              keyboardType: const TextInputType.numberWithOptions(decimal: true),
              decoration: const InputDecoration(
                labelText: 'Exchange Rate',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 20),
            TextField(
              controller: noteController,
              decoration: const InputDecoration(
                labelText: 'Note',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 40),
            SizedBox(
              width: double.infinity,
              height: 50,
              child: ElevatedButton(
                onPressed: () async {
                  final newAmount = double.tryParse(amountController.text) ?? widget.transaction.convertedAmount;
                  final newRate = double.tryParse(rateController.text) ?? widget.transaction.exchangeRate;
                  
                  await sharedProvider.editAndApprove(
                    widget.transaction,
                    newAmount,
                    newRate,
                    noteController.text,
                  );
                  
                  if (mounted) {
                    Navigator.pop(context);
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('Changes sent to sender for confirmation')),
                    );
                  }
                },
                child: const Text('Send Counter Offer'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
