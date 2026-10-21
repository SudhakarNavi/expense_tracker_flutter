import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../models/transaction_model.dart';
import '../providers/settings_provider.dart';
import '../providers/transaction_provider.dart';
import '../screens/transaction_form_screen.dart';
import '../utils/date_utils.dart';
import 'common.dart';

class TransactionTile extends StatelessWidget {
  const TransactionTile({super.key, required this.tx, this.showDate = false});

  final TransactionModel tx;
  final bool showDate;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final settings = context.watch<SettingsProvider>();
    final title = tx.note.trim().isEmpty ? tx.category : tx.note.trim();
    final details = [
      if (tx.note.trim().isNotEmpty) tx.category,
      tx.paymentType,
      if (showDate) formatDate(tx.date),
    ].join(' · ');
    final semantic =
        '${tx.isIncome ? 'Income' : 'Expense'}, $title, '
        '${settings.format(tx.amountMinor)}, ${tx.category}, ${formatDate(tx.date)}';

    return Semantics(
      container: true,
      label: semantic,
      button: true,
      hint: 'Opens the transaction for editing',
      excludeSemantics: true,
      child: InkWell(
        onTap: () => openTransactionForm(context, existing: tx),
        borderRadius: BorderRadius.circular(16),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
          child: Row(
            children: [
              CategoryAvatar(tx.category),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontWeight: FontWeight.w600,
                        fontSize: 15,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      details,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        color: scheme.onSurfaceVariant,
                        fontSize: 13,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 12),
              Flexible(
                flex: 0,
                child: ConstrainedBox(
                  constraints: BoxConstraints(
                    maxWidth: MediaQuery.sizeOf(context).width * 0.42,
                  ),
                  child: AmountText(
                    tx.amountMinor,
                    isIncome: tx.isIncome,
                    style: const TextStyle(
                      fontWeight: FontWeight.w700,
                      fontSize: 15,
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Asks for confirmation, deletes, and offers Undo. Returns true if deleted.
Future<bool> deleteTransactionWithUndo(
  BuildContext context,
  TransactionModel tx,
) async {
  final provider = context.read<TransactionProvider>();
  final messenger = ScaffoldMessenger.of(context);
  final settings = context.read<SettingsProvider>();
  final confirmed = await confirmAction(
    context,
    title: 'Delete transaction?',
    message:
        '${tx.isIncome ? 'Income' : 'Expense'} of ${settings.format(tx.amountMinor)} '
        'on ${formatDate(tx.date)} will be removed.',
    confirmLabel: 'Delete',
  );
  if (!confirmed || !context.mounted) return false;
  try {
    await provider.delete(tx.id);
  } catch (_) {
    if (context.mounted) {
      showMessage(context, 'Could not delete. Please try again.', error: true);
    }
    return false;
  }
  messenger.hideCurrentSnackBar();
  messenger.showSnackBar(
    SnackBar(
      content: const Text('Transaction deleted'),
      action: SnackBarAction(
        label: 'Undo',
        onPressed: () async {
          try {
            await provider.save(tx);
          } catch (_) {
            messenger.showSnackBar(
              const SnackBar(
                content: Text('Could not restore the transaction.'),
              ),
            );
          }
        },
      ),
    ),
  );
  return true;
}
