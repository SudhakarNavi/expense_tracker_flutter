import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:printing/printing.dart';
import 'package:provider/provider.dart';

import '../models/transaction_model.dart';
import '../providers/category_provider.dart';
import '../providers/settings_provider.dart';
import '../providers/transaction_provider.dart';
import '../services/finance_calculator.dart';
import '../services/pdf_report_service.dart';
import '../theme/app_theme.dart';
import '../utils/date_utils.dart';
import '../widgets/charts.dart';
import '../widgets/common.dart';

class ReportsScreen extends StatefulWidget {
  const ReportsScreen({super.key});

  @override
  State<ReportsScreen> createState() => _ReportsScreenState();
}

class _ReportsScreenState extends State<ReportsScreen> {
  bool _yearMode = false;
  DateTime _anchor = DateTime(DateTime.now().year, DateTime.now().month, 1);
  bool _exporting = false;

  DateRange get _range => _yearMode
      ? DateRange.year(_anchor.year)
      : DateRange.month(_anchor.year, _anchor.month);

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<TransactionProvider>();
    final settings = context.watch<SettingsProvider>();
    final colors = AppColors.of(context);
    final range = _range;
    final periodTxs = provider.filter(range: range);
    final summary = FinanceCalculator.summarize(periodTxs);
    final all = provider.transactions;

    final trend = _yearMode
        ? [
            for (var m = 1; m <= 12; m++)
              PeriodTotals(
                DateRange.month(_anchor.year, m),
                FinanceCalculator.summarizeRange(
                  all,
                  DateRange.month(_anchor.year, m),
                ),
              ),
          ]
        : FinanceCalculator.monthlyTotals(all, _anchor, 6);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Reports'),
        actions: [
          _exporting
              ? const Padding(
                  padding: EdgeInsets.all(16),
                  child: SizedBox.square(
                    dimension: 20,
                    child: CircularProgressIndicator(strokeWidth: 2.5),
                  ),
                )
              : IconButton(
                  tooltip: 'Export PDF',
                  icon: const Icon(Icons.picture_as_pdf_outlined),
                  onPressed: _export,
                ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 0, 16, 32),
        children: [
          SegmentedButton<bool>(
            segments: const [
              ButtonSegment(value: false, label: Text('Month')),
              ButtonSegment(value: true, label: Text('Year')),
            ],
            selected: {_yearMode},
            showSelectedIcon: false,
            onSelectionChanged: (s) => setState(() => _yearMode = s.first),
          ),
          MonthSwitcher(
            month: _anchor,
            yearMode: _yearMode,
            onChanged: (d) => setState(() {
              _anchor = _yearMode ? DateTime(d.year, _anchor.month, 1) : d;
            }),
          ),
          Row(
            children: [
              Expanded(
                child: _StatTile(
                  label: 'Income',
                  minor: summary.incomeMinor,
                  color: colors.income,
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: _StatTile(
                  label: 'Expenses',
                  minor: summary.expenseMinor,
                  color: colors.expense,
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: _StatTile(
                  label: 'Net',
                  minor: summary.netMinor,
                  color: summary.netMinor >= 0 ? colors.income : colors.expense,
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          _CategoryBreakdown(txs: periodTxs),
          const SizedBox(height: 16),
          SectionCard(
            title: _yearMode ? 'Monthly overview' : 'Last 6 months',
            child: Column(
              children: [
                BarChart(
                  groups: [
                    for (final p in trend)
                      BarGroup(shortMonth(p.range.start.month), [
                        p.summary.incomeMinor,
                        p.summary.expenseMinor,
                      ]),
                  ],
                  colors: [colors.income, colors.expense],
                  formatValue: settings.compact,
                  highlightIndex: _yearMode
                      ? _anchor.month - 1
                      : trend.length - 1,
                  semanticsLabel: [
                    for (final p in trend)
                      '${formatMonthYear(p.range.start)}: income ${settings.format(p.summary.incomeMinor)}, '
                          'expenses ${settings.format(p.summary.expenseMinor)}',
                  ].join('. '),
                ),
                const SizedBox(height: 12),
                Wrap(
                  alignment: WrapAlignment.center,
                  spacing: 20,
                  runSpacing: 4,
                  children: [
                    _Legend(color: colors.income, label: 'Income'),
                    _Legend(color: colors.expense, label: 'Expenses'),
                  ],
                ),
              ],
            ),
          ),
          if (!_yearMode) ...[
            const SizedBox(height: 16),
            _DailySpending(range: range, txs: periodTxs),
          ],
        ],
      ),
    );
  }

  Future<void> _export() async {
    final periodLabel = formatRange(_range);
    final choice = await showModalBottomSheet<(bool, bool)>(
      context: context,
      showDragHandle: true,
      builder: (context) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(24, 0, 24, 8),
              child: Text(
                'Export PDF',
                style: Theme.of(context).textTheme.titleLarge,
              ),
            ),
            ListTile(
              leading: const Icon(Icons.share_outlined),
              title: Text('Share $periodLabel'),
              onTap: () => Navigator.pop(context, (false, true)),
            ),
            ListTile(
              leading: const Icon(Icons.save_alt_rounded),
              title: Text('Save $periodLabel'),
              subtitle: const Text('Choose where to save, e.g. Downloads'),
              onTap: () => Navigator.pop(context, (false, false)),
            ),
            const Divider(),
            ListTile(
              leading: const Icon(Icons.share_outlined),
              title: const Text('Share all transactions'),
              onTap: () => Navigator.pop(context, (true, true)),
            ),
            ListTile(
              leading: const Icon(Icons.save_alt_rounded),
              title: const Text('Save all transactions'),
              onTap: () => Navigator.pop(context, (true, false)),
            ),
          ],
        ),
      ),
    );
    if (choice == null || !mounted) return;
    final (allTime, share) = choice;
    final provider = context.read<TransactionProvider>();
    final currency = context.read<SettingsProvider>().currency;
    final List<TransactionModel> txs = allTime
        ? provider.transactions.toList()
        : provider.filter(range: _range);
    final label = allTime ? 'All transactions' : periodLabel;
    final fileName =
        'expenses_${(allTime ? 'all' : periodLabel).toLowerCase().replaceAll(RegExp(r'[^a-z0-9]+'), '_')}.pdf';

    setState(() => _exporting = true);
    try {
      final bytes = await PdfReportService.build(
        transactions: txs,
        currency: currency,
        periodLabel: label,
      );
      if (share) {
        await Printing.sharePdf(bytes: bytes, filename: fileName);
      } else {
        final uri = await FilePicker.saveFile(
          fileName: fileName,
          bytes: bytes,
          mimeType: 'application/pdf',
          dialogTitle: 'Save PDF',
          type: FileType.custom,
          allowedExtensions: const ['pdf'],
        );
        if (uri != null && mounted) showMessage(context, 'PDF saved');
      }
    } catch (_) {
      if (mounted) {
        showMessage(
          context,
          'Could not export the PDF. Please try again.',
          error: true,
        );
      }
    } finally {
      if (mounted) setState(() => _exporting = false);
    }
  }
}

class _StatTile extends StatelessWidget {
  const _StatTile({
    required this.label,
    required this.minor,
    required this.color,
  });

  final String label;
  final int minor;
  final Color color;

  @override
  Widget build(BuildContext context) {
    final settings = context.watch<SettingsProvider>();
    return Semantics(
      container: true,
      label: '$label ${settings.format(minor)}',
      excludeSemantics: true,
      child: Card(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                label,
                style: TextStyle(
                  fontSize: 12,
                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                ),
              ),
              const SizedBox(height: 4),
              FittedBox(
                fit: BoxFit.scaleDown,
                alignment: Alignment.centerLeft,
                child: AmountText(
                  minor,
                  color: color,
                  style: const TextStyle(
                    fontWeight: FontWeight.w700,
                    fontSize: 15,
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

class _Legend extends StatelessWidget {
  const _Legend({required this.color, required this.label});
  final Color color;
  final String label;

  @override
  Widget build(BuildContext context) => Row(
    mainAxisSize: MainAxisSize.min,
    children: [
      Container(
        width: 12,
        height: 12,
        decoration: BoxDecoration(
          color: color,
          borderRadius: BorderRadius.circular(3),
        ),
      ),
      const SizedBox(width: 6),
      Text(label, style: const TextStyle(fontSize: 13)),
    ],
  );
}

String _percent(int part, int total) {
  if (total <= 0) return '0%';
  final p = part * 100 / total;
  if (p > 0 && p < 1) return '<1%';
  return '${p.round()}%';
}

class _CategoryBreakdown extends StatelessWidget {
  const _CategoryBreakdown({required this.txs});
  final List<TransactionModel> txs;

  @override
  Widget build(BuildContext context) {
    final settings = context.watch<SettingsProvider>();
    final cats = context.watch<CategoryProvider>();
    final data = FinanceCalculator.expenseByCategory(txs);
    final total = data.fold<int>(0, (s, e) => s + e.value);
    Color colorOf(String name) =>
        Color(cats.byName(name)?.colorValue ?? 0xFF64748B);

    return SectionCard(
      title: 'Spending by category',
      child: data.isEmpty
          ? const EmptyState(
              compact: true,
              icon: Icons.donut_large_rounded,
              title: 'No expenses in this period',
              message: 'Add expenses to see where your money goes.',
            )
          : Column(
              children: [
                DonutChart(
                  segments: [
                    for (final e in data)
                      DonutSegment(e.key, e.value, colorOf(e.key)),
                  ],
                  semanticsLabel:
                      'Spending by category. ${data.map((e) => '${e.key} ${settings.format(e.value)}, ${_percent(e.value, total)}').join('. ')}',
                  center: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        'Total',
                        style: TextStyle(
                          fontSize: 12,
                          color: Theme.of(context).colorScheme.onSurfaceVariant,
                        ),
                      ),
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 32),
                        child: FittedBox(
                          child: AmountText(
                            total,
                            style: const TextStyle(
                              fontWeight: FontWeight.w800,
                              fontSize: 18,
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 16),
                for (final e in data)
                  Padding(
                    padding: const EdgeInsets.symmetric(vertical: 6),
                    child: Row(
                      children: [
                        Container(
                          width: 12,
                          height: 12,
                          decoration: BoxDecoration(
                            color: colorOf(e.key),
                            borderRadius: BorderRadius.circular(3),
                          ),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Text.rich(
                            TextSpan(
                              text: e.key,
                              children: [
                                TextSpan(
                                  text: '  ${_percent(e.value, total)}',
                                  style: TextStyle(
                                    color: Theme.of(
                                      context,
                                    ).colorScheme.onSurfaceVariant,
                                  ),
                                ),
                              ],
                            ),
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        const SizedBox(width: 12),
                        Flexible(
                          child: AmountText(
                            e.value,
                            fit: true,
                            style: const TextStyle(fontWeight: FontWeight.w600),
                          ),
                        ),
                      ],
                    ),
                  ),
              ],
            ),
    );
  }
}

class _DailySpending extends StatelessWidget {
  const _DailySpending({required this.range, required this.txs});
  final DateRange range;
  final List<TransactionModel> txs;

  @override
  Widget build(BuildContext context) {
    final settings = context.watch<SettingsProvider>();
    final colors = AppColors.of(context);
    final days = FinanceCalculator.dailyTotals(txs, range);
    final now = DateTime.now();
    final todayIndex = range.contains(now) ? now.day - 1 : null;
    final spendDays = days.where((d) => d.summary.expenseMinor > 0).toList();
    final elapsed = todayIndex != null ? todayIndex + 1 : days.length;
    final totalExpense = days.fold<int>(
      0,
      (s, d) => s + d.summary.expenseMinor,
    );
    final perDay = elapsed == 0 ? 0 : totalExpense ~/ elapsed;

    return SectionCard(
      title: 'Daily spending',
      trailing: spendDays.isEmpty
          ? null
          : Text(
              'Avg ${settings.format(perDay)}/day',
              style: TextStyle(
                color: Theme.of(context).colorScheme.onSurfaceVariant,
                fontSize: 13,
              ),
            ),
      child: BarChart(
        height: 160,
        groups: [
          for (final d in days)
            BarGroup('${d.range.start.day}', [d.summary.expenseMinor]),
        ],
        colors: [colors.expense],
        formatValue: settings.compact,
        highlightIndex: todayIndex,
        semanticsLabel: spendDays.isEmpty
            ? 'No spending in this month'
            : 'Daily spending. ${spendDays.map((d) => '${formatDate(d.range.start)} ${settings.format(d.summary.expenseMinor)}').join('. ')}',
      ),
    );
  }
}
