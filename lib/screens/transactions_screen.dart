import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../models/transaction_model.dart';
import '../providers/category_provider.dart';
import '../providers/transaction_provider.dart';
import '../services/finance_calculator.dart';
import '../theme/app_theme.dart';
import '../utils/date_utils.dart';
import '../widgets/common.dart';
import '../widgets/transaction_tile.dart';
import 'transaction_form_screen.dart';

class TransactionsScreen extends StatefulWidget {
  const TransactionsScreen({super.key});

  @override
  State<TransactionsScreen> createState() => _TransactionsScreenState();
}

class _TransactionsScreenState extends State<TransactionsScreen> {
  final _search = TextEditingController();
  TypeFilter _type = TypeFilter.all;
  String? _category;
  DateRange? _range;

  bool get _hasFilters =>
      _search.text.isNotEmpty ||
      _type != TypeFilter.all ||
      _category != null ||
      _range != null;

  @override
  void dispose() {
    _search.dispose();
    super.dispose();
  }

  void _clearFilters() {
    setState(() {
      _search.clear();
      _type = TypeFilter.all;
      _category = null;
      _range = null;
    });
  }

  Future<void> _pickPeriod() async {
    final now = DateTime.now();
    final options = <String, DateRange?>{
      'All time': null,
      'This month': DateRange.month(now.year, now.month),
      'Last month': DateRange.month(now.year, now.month - 1),
      'This year': DateRange.year(now.year),
      'Last year': DateRange.year(now.year - 1),
    };
    final choice = await showModalBottomSheet<Object>(
      context: context,
      showDragHandle: true,
      builder: (context) => SafeArea(
        child: ListView(
          shrinkWrap: true,
          children: [
            for (final e in options.entries)
              ListTile(
                title: Text(e.key),
                trailing: _range == e.value
                    ? const Icon(Icons.check_rounded)
                    : null,
                onTap: () => Navigator.pop(context, e.value ?? 'all'),
              ),
            ListTile(
              leading: const Icon(Icons.date_range_rounded),
              title: const Text('Custom range…'),
              onTap: () => Navigator.pop(context, 'custom'),
            ),
          ],
        ),
      ),
    );
    if (!mounted || choice == null) return;
    if (choice == 'all') {
      setState(() => _range = null);
    } else if (choice is DateRange) {
      setState(() => _range = choice);
    } else if (choice == 'custom') {
      final picked = await showDateRangePicker(
        context: context,
        firstDate: DateTime(2000),
        lastDate: DateTime(now.year + 1, 12, 31),
        initialDateRange: _range == null
            ? null
            : DateTimeRange(start: _range!.start, end: _range!.lastDay),
      );
      if (picked != null && mounted) {
        setState(() => _range = DateRange.days(picked.start, picked.end));
      }
    }
  }

  Future<void> _pickCategory() async {
    final cats = context.read<CategoryProvider>().categories;
    final choice = await showModalBottomSheet<String>(
      context: context,
      showDragHandle: true,
      isScrollControlled: true,
      builder: (context) => DraggableScrollableSheet(
        expand: false,
        initialChildSize: 0.6,
        builder: (context, controller) => ListView(
          controller: controller,
          children: [
            ListTile(
              title: const Text('All categories'),
              trailing: _category == null
                  ? const Icon(Icons.check_rounded)
                  : null,
              onTap: () => Navigator.pop(context, ''),
            ),
            for (final c in cats)
              ListTile(
                leading: CategoryAvatar(c.name, size: 36),
                title: Text(c.name),
                trailing: _category == c.name
                    ? const Icon(Icons.check_rounded)
                    : null,
                onTap: () => Navigator.pop(context, c.name),
              ),
          ],
        ),
      ),
    );
    if (choice != null && mounted) {
      setState(() => _category = choice.isEmpty ? null : choice);
    }
  }

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<TransactionProvider>();
    final items = provider.filter(
      query: _search.text,
      type: _type,
      category: _category,
      range: _range,
    );
    final summary = FinanceCalculator.summarize(items);
    final rows = _buildRows(items);
    final scheme = Theme.of(context).colorScheme;

    return Scaffold(
      appBar: AppBar(title: const Text('Transactions')),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 4, 16, 8),
            child: TextField(
              controller: _search,
              onChanged: (_) => setState(() {}),
              textInputAction: TextInputAction.search,
              decoration: InputDecoration(
                hintText: 'Search notes, categories, amounts',
                prefixIcon: const Icon(Icons.search_rounded),
                suffixIcon: _search.text.isEmpty
                    ? null
                    : IconButton(
                        tooltip: 'Clear search',
                        icon: const Icon(Icons.close_rounded),
                        onPressed: () => setState(_search.clear),
                      ),
              ),
            ),
          ),
          SizedBox(
            height: 48,
            child: ListView(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 16),
              children: [
                // Shown first so it is always visible when filters are on.
                if (_hasFilters) ...[
                  ActionChip(
                    avatar: const Icon(Icons.filter_alt_off_rounded, size: 18),
                    label: const Text('Clear'),
                    onPressed: _clearFilters,
                  ),
                  const SizedBox(width: 8),
                ],
                for (final t in TypeFilter.values) ...[
                  ChoiceChip(
                    label: Text(switch (t) {
                      TypeFilter.all => 'All',
                      TypeFilter.income => 'Income',
                      TypeFilter.expense => 'Expenses',
                    }),
                    selected: _type == t,
                    onSelected: (_) => setState(() => _type = t),
                  ),
                  const SizedBox(width: 8),
                ],
                FilterChip(
                  avatar: const Icon(Icons.calendar_month_rounded, size: 18),
                  label: Text(
                    _range == null ? 'Any date' : formatRange(_range!),
                  ),
                  selected: _range != null,
                  onSelected: (_) => _pickPeriod(),
                ),
                const SizedBox(width: 8),
                FilterChip(
                  avatar: const Icon(Icons.category_outlined, size: 18),
                  label: Text(_category ?? 'Any category'),
                  selected: _category != null,
                  onSelected: (_) => _pickCategory(),
                ),
              ],
            ),
          ),
          if (items.isNotEmpty)
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 4, 20, 4),
              child: _SummaryLine(summary: summary),
            ),
          Expanded(
            child: AnimatedSwitcher(
              duration: const Duration(milliseconds: 200),
              child: items.isEmpty
                  ? SingleChildScrollView(
                      key: const ValueKey('empty'),
                      child: provider.transactions.isEmpty
                          ? EmptyState(
                              icon: Icons.receipt_long_outlined,
                              title: 'No transactions yet',
                              message: 'Tap “Add” to record your first one.',
                              actionLabel: 'Add transaction',
                              onAction: () => openTransactionForm(context),
                            )
                          : const EmptyState(
                              icon: Icons.search_off_rounded,
                              title: 'No matches',
                              message:
                                  'Try a different search or clear the filters.',
                              actionLabel: null,
                              onAction: null,
                            ),
                    )
                  : ListView.builder(
                      key: const ValueKey('list'),
                      padding: const EdgeInsets.fromLTRB(8, 0, 8, 96),
                      itemCount: rows.length,
                      itemBuilder: (context, i) {
                        final row = rows[i];
                        if (row is _DayHeader) {
                          return Padding(
                            padding: const EdgeInsets.fromLTRB(12, 16, 12, 6),
                            child: Row(
                              children: [
                                Expanded(
                                  child: Semantics(
                                    header: true,
                                    child: Text(
                                      formatDayHeader(row.day),
                                      style: TextStyle(
                                        fontWeight: FontWeight.w700,
                                        color: scheme.onSurfaceVariant,
                                      ),
                                    ),
                                  ),
                                ),
                                AmountText(
                                  row.netMinor,
                                  style: TextStyle(
                                    color: scheme.onSurfaceVariant,
                                    fontSize: 13,
                                  ),
                                ),
                              ],
                            ),
                          );
                        }
                        final tx = row as TransactionModel;
                        return _DismissibleTile(tx: tx);
                      },
                    ),
            ),
          ),
        ],
      ),
    );
  }

  /// Interleaves day headers with transactions (already sorted newest first).
  List<Object> _buildRows(List<TransactionModel> items) {
    final rows = <Object>[];
    DateTime? current;
    _DayHeader? header;
    for (final tx in items) {
      final day = dateOnly(tx.date);
      if (day != current) {
        current = day;
        header = _DayHeader(day);
        rows.add(header);
      }
      header!.netMinor += tx.signedMinor;
      rows.add(tx);
    }
    return rows;
  }
}

class _DayHeader {
  _DayHeader(this.day);
  final DateTime day;
  int netMinor = 0;
}

class _SummaryLine extends StatelessWidget {
  const _SummaryLine({required this.summary});
  final FinanceSummary summary;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final style = TextStyle(fontSize: 13, color: scheme.onSurfaceVariant);
    return Row(
      children: [
        Text(
          '${summary.count} item${summary.count == 1 ? '' : 's'}',
          style: style,
        ),
        const Spacer(),
        Flexible(
          child: AmountText(
            summary.incomeMinor,
            isIncome: true,
            style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
          ),
        ),
        const SizedBox(width: 12),
        Flexible(
          child: AmountText(
            summary.expenseMinor,
            isIncome: false,
            style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
          ),
        ),
      ],
    );
  }
}

class _DismissibleTile extends StatelessWidget {
  const _DismissibleTile({required this.tx});
  final TransactionModel tx;

  @override
  Widget build(BuildContext context) {
    final colors = AppColors.of(context);
    return Dismissible(
      key: ValueKey(tx.id),
      direction: DismissDirection.endToStart,
      // The provider removes the row itself, so the Dismissible never has to.
      confirmDismiss: (_) async {
        await deleteTransactionWithUndo(context, tx);
        return false;
      },
      background: Container(
        alignment: Alignment.centerRight,
        padding: const EdgeInsets.only(right: 24),
        decoration: BoxDecoration(
          color: colors.expenseContainer,
          borderRadius: BorderRadius.circular(16),
        ),
        child: Icon(Icons.delete_outline_rounded, color: colors.expense),
      ),
      child: TransactionTile(tx: tx),
    );
  }
}
