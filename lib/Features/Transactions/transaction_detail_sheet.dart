import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'transaction_model.dart';
import 'add_expense_screen.dart';

class TransactionDetailSheet extends StatelessWidget {
  final TransactionModel transaction;
  final String currency;

  const TransactionDetailSheet({
    super.key,
    required this.transaction,
    required this.currency,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isIncome = ['income', 'repayment_received', 'borrow', 'loan_received'].contains(transaction.type.toLowerCase());
    final currencyFormat = NumberFormat('#,##0.00');

    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: theme.colorScheme.surface,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(32)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Center(
            child: Container(
              width: 40,
              height: 4,
              margin: const EdgeInsets.only(bottom: 24),
              decoration: BoxDecoration(
                color: theme.colorScheme.outline,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Transaction Details',
                style: theme.textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w900),
              ),
              IconButton(
                onPressed: () => Navigator.pop(context),
                icon: const Icon(Icons.close_rounded),
              ),
            ],
          ),
          const SizedBox(height: 32),
          Center(
            child: Column(
              children: [
                Text(
                  '${isIncome ? "+" : "-"} $currency ${currencyFormat.format(transaction.amount)}',
                  style: theme.textTheme.displaySmall?.copyWith(
                    fontWeight: FontWeight.w900,
                    color: isIncome ? theme.colorScheme.primary : theme.colorScheme.onSurface,
                  ),
                ),
                const SizedBox(height: 8),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  decoration: BoxDecoration(
                    color: theme.colorScheme.primary.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text(
                    transaction.type.toUpperCase(),
                    style: TextStyle(
                      color: theme.colorScheme.primary,
                      fontWeight: FontWeight.w900,
                      fontSize: 10,
                      letterSpacing: 1,
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 40),
          if (transaction.proposedAmount != null && transaction.proposedAmount != transaction.amount) ...[
            _buildDetailRow(context, 'Proposed Amount', '$currency ${currencyFormat.format(transaction.proposedAmount)}', Icons.history_rounded),
            _buildDetailRow(context, 'Approved Amount', '$currency ${currencyFormat.format(transaction.amount)}', Icons.check_circle_outline, color: theme.colorScheme.primary),
          ],
          _buildDetailRow(context, 'Category', transaction.category, Icons.category_outlined),
          _buildDetailRow(context, 'Account', transaction.account, Icons.account_balance_wallet_outlined),
          if (transaction.personId != null)
             _buildDetailRow(context, 'Linked Person', transaction.personId!, Icons.person_outline),
          _buildDetailRow(context, 'Date', DateFormat('EEEE, dd MMMM yyyy').format(transaction.date), Icons.calendar_today_outlined),
          if (transaction.approvedAt != null)
             _buildDetailRow(context, 'Approved At', DateFormat('dd MMM yyyy, hh:mm a').format(transaction.approvedAt!), Icons.verified_user_outlined, color: theme.colorScheme.primary),
          if (transaction.note.isNotEmpty)
            _buildDetailRow(context, 'Note', transaction.note, Icons.notes_rounded),
          if (transaction.status != 'approved')
            _buildDetailRow(context, 'Status', transaction.status.toUpperCase(), Icons.info_outline_rounded, color: Colors.orange),
          
          const SizedBox(height: 32),
          Row(
            children: [
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: () {
                    Navigator.pop(context);
                    Navigator.push(context, MaterialPageRoute(builder: (context) => AddExpenseScreen(transaction: transaction)));
                  },
                  icon: const Icon(Icons.edit_rounded, size: 20),
                  label: const Text('Edit'),
                  style: OutlinedButton.styleFrom(
                    minimumSize: const Size(0, 56),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                  ),
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: ElevatedButton.icon(
                  onPressed: () => Navigator.pop(context),
                  icon: const Icon(Icons.check_rounded, size: 20),
                  label: const Text('Close'),
                  style: ElevatedButton.styleFrom(
                    minimumSize: const Size(0, 56),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 24),
        ],
      ),
    );
  }

  Widget _buildDetailRow(BuildContext context, String label, String value, IconData icon, {Color? color}) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.only(bottom: 20),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: theme.colorScheme.outline.withOpacity(0.1),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(icon, size: 20, color: theme.colorScheme.onSurface.withOpacity(0.6)),
          ),
          const SizedBox(width: 16),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                label,
                style: theme.textTheme.bodySmall?.copyWith(
                  color: theme.colorScheme.onSurface.withOpacity(0.4),
                  fontWeight: FontWeight.bold,
                ),
              ),
              Text(
                value,
                style: theme.textTheme.bodyMedium?.copyWith(
                  fontWeight: FontWeight.w800,
                  color: color,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
