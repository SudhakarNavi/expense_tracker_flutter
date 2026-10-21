import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

import '../models/budget_model.dart';
import '../providers/budget_provider.dart';
import '../providers/category_provider.dart';
import '../providers/settings_provider.dart';
import '../providers/transaction_provider.dart';
import '../services/finance_calculator.dart';
import '../utils/date_utils.dart';
import '../utils/money.dart';
import '../widgets/common.dart';
import '../widgets/budget_progress.dart';

class BudgetsScreen extends StatefulWidget {
  const BudgetsScreen({super.key});

  @override
  State<BudgetsScreen> createState() => _BudgetsScreenState();
}

class _BudgetsScreenState extends State<BudgetsScreen> {
  DateTime _month = DateTime(DateTime.now().year, DateTime.now().month, 1);

  @override
  Widget build(BuildContext context) {
    final budgets = context.watch<BudgetProvider>();
    final txs = context.watch<TransactionProvider>().transactions;
    final range = DateRange.month(_month.year, _month.month);
    final overall = budgets.overall;

    return Scaffold(
      appBar: AppBar(title: const Text('Budgets')),
      floatingActionButton: FloatingActionButton.extended(
        heroTag: 'addBudget',
        onPressed: () => showBudgetEditor(context),
        icon: const Icon(Icons.add_rounded),
        label: const Text('Add budget'),
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 0, 16, 96),
        children: [
          MonthSwitcher(
            month: _month,
            onChanged: (m) => setState(() => _month = m),
          ),
          Padding(
            padding: const EdgeInsets.only(bottom: 12, left: 4, right: 4),
            child: Text(
              'Budgets repeat every month. Spending is counted from expenses dated in ${formatMonthYear(_month)}.',
              style: TextStyle(
                color: Theme.of(context).colorScheme.onSurfaceVariant,
                fontSize: 13,
              ),
            ),
          ),
          if (budgets.isEmpty)
            Card(
              child: EmptyState(
                icon: Icons.savings_outlined,
                title: 'No budgets yet',
                message:
                    'Set a limit for all spending or for individual categories, and track it here every month.',
                actionLabel: 'Add budget',
                onAction: () => showBudgetEditor(context),
              ),
            )
          else ...[
            if (overall != null)
              _BudgetCard(
                budget: overall,
                status: FinanceCalculator.budgetStatus(
                  limitMinor: overall.limitMinor,
                  txs: txs,
                  month: range,
                ),
              ),
            for (final b in budgets.categoryBudgets) ...[
              const SizedBox(height: 12),
              _BudgetCard(
                budget: b,
                status: FinanceCalculator.budgetStatus(
                  limitMinor: b.limitMinor,
                  txs: txs,
                  month: range,
                  category: b.category,
                ),
              ),
            ],
          ],
        ],
      ),
    );
  }
}

class _BudgetCard extends StatelessWidget {
  const _BudgetCard({required this.budget, required this.status});
  final BudgetModel budget;
  final BudgetStatus status;

  @override
  Widget build(BuildContext context) {
    final label = budget.isOverall ? 'All expenses' : budget.category;
    return Card(
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: () => showBudgetEditor(context, existing: budget),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              if (budget.isOverall)
                Container(
                  width: 44,
                  height: 44,
                  decoration: BoxDecoration(
                    color: Theme.of(context).colorScheme.primaryContainer,
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: Icon(
                    Icons.account_balance_wallet_rounded,
                    color: Theme.of(context).colorScheme.onPrimaryContainer,
                  ),
                )
              else
                CategoryAvatar(budget.category),
              const SizedBox(width: 14),
              Expanded(
                child: BudgetProgress(status: status, label: label),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

Future<void> showBudgetEditor(BuildContext context, {BudgetModel? existing}) {
  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    showDragHandle: true,
    builder: (_) => _BudgetEditor(existing: existing),
  );
}

class _BudgetEditor extends StatefulWidget {
  const _BudgetEditor({this.existing});
  final BudgetModel? existing;

  @override
  State<_BudgetEditor> createState() => _BudgetEditorState();
}

class _BudgetEditorState extends State<_BudgetEditor> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _amount = TextEditingController(
    text: widget.existing == null
        ? ''
        : Money.toInput(widget.existing!.limitMinor),
  );
  late String? _target = widget.existing?.category;
  bool _saving = false;

  /// Options are captured once when the sheet opens. Recomputing them on
  /// every build would drop the just-saved category while the sheet is
  /// closing and break the dropdown.
  late final List<String> _targets = _computeTargets();

  List<String> _computeTargets() {
    final budgets = context.read<BudgetProvider>();
    final cats = context.read<CategoryProvider>().forType(isIncome: false);
    final existing = widget.existing?.category;
    if (existing != null) return [existing];
    return [
      if (budgets.overall == null) BudgetModel.overallKey,
      for (final c in cats)
        if (budgets.forCategory(c.name) == null) c.name,
    ];
  }

  @override
  void dispose() {
    _amount.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (_saving || !_formKey.currentState!.validate()) return;
    setState(() => _saving = true);
    final provider = context.read<BudgetProvider>();
    try {
      await provider.setBudget(_target!, Money.parse(_amount.text).minor!);
      if (!mounted) return;
      Navigator.pop(context);
      showMessage(context, 'Budget saved');
    } catch (_) {
      if (!mounted) return;
      setState(() => _saving = false);
      showMessage(context, 'Could not save the budget.', error: true);
    }
  }

  Future<void> _remove() async {
    final ok = await confirmAction(
      context,
      title: 'Remove budget?',
      message: 'Your transactions are not affected.',
      confirmLabel: 'Remove',
    );
    if (!ok || !mounted) return;
    try {
      await context.read<BudgetProvider>().remove(widget.existing!.category);
      if (!mounted) return;
      Navigator.pop(context);
      showMessage(context, 'Budget removed');
    } catch (_) {
      if (mounted) {
        showMessage(context, 'Could not remove the budget.', error: true);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final currency = context.watch<SettingsProvider>().currency;
    final isEdit = widget.existing != null;
    final targets = _targets;

    return Padding(
      padding: EdgeInsets.fromLTRB(
        20,
        0,
        20,
        MediaQuery.viewInsetsOf(context).bottom + 20,
      ),
      child: Form(
        key: _formKey,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              isEdit ? 'Edit budget' : 'New monthly budget',
              style: Theme.of(context).textTheme.titleLarge,
            ),
            const SizedBox(height: 16),
            DropdownButtonFormField<String>(
              isExpanded: true,
              initialValue: _target,
              decoration: const InputDecoration(labelText: 'Applies to'),
              items: [
                for (final t in targets)
                  DropdownMenuItem(
                    value: t,
                    child: Text(
                      t == BudgetModel.overallKey ? 'All expenses' : t,
                    ),
                  ),
              ],
              onChanged: isEdit ? null : (v) => setState(() => _target = v),
              validator: (v) =>
                  v == null ? 'Choose what this budget covers' : null,
            ),
            const SizedBox(height: 16),
            TextFormField(
              controller: _amount,
              autofocus: true,
              keyboardType: const TextInputType.numberWithOptions(
                decimal: true,
              ),
              inputFormatters: [
                FilteringTextInputFormatter.allow(RegExp(r'[0-9.,\s]')),
                LengthLimitingTextInputFormatter(20),
              ],
              decoration: InputDecoration(
                labelText: 'Monthly limit',
                prefixText: currency.symbol,
              ),
              validator: (v) => Money.parse(v ?? '').message,
              onFieldSubmitted: (_) => _save(),
            ),
            const SizedBox(height: 20),
            FilledButton(
              onPressed: _saving ? null : _save,
              child: const Text('Save budget'),
            ),
            if (isEdit) ...[
              const SizedBox(height: 8),
              TextButton.icon(
                onPressed: _saving ? null : _remove,
                icon: const Icon(Icons.delete_outline_rounded),
                label: const Text('Remove budget'),
                style: TextButton.styleFrom(
                  foregroundColor: Theme.of(context).colorScheme.error,
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
