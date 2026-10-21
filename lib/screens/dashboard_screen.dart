import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../models/transaction_model.dart';
import '../providers/budget_provider.dart';
import '../providers/category_provider.dart';
import '../providers/settings_provider.dart';
import '../providers/transaction_provider.dart';
import '../services/finance_calculator.dart';
import '../theme/app_theme.dart';
import '../utils/date_utils.dart';
import '../widgets/budget_progress.dart';
import '../widgets/charts.dart';
import '../widgets/common.dart';
import '../widgets/transaction_tile.dart';
import 'settings_screen.dart';
import 'transaction_form_screen.dart';

class DashboardScreen extends StatefulWidget {
  const DashboardScreen({super.key, required this.onNavigate});

  /// Switches the bottom-navigation tab (1 = transactions, 2 = reports,
  /// 3 = budgets).
  final ValueChanged<int> onNavigate;

  @override
  State<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends State<DashboardScreen> {
  DateTime _month = DateTime(DateTime.now().year, DateTime.now().month, 1);

  @override
  Widget build(BuildContext context) {
    final txProvider = context.watch<TransactionProvider>();
    final range = DateRange.month(_month.year, _month.month);
    final monthTxs = txProvider.filter(range: range);
    final summary = FinanceCalculator.summarize(monthTxs);
    final hasAny = txProvider.transactions.isNotEmpty;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Overview'),
        actions: [
          IconButton(
            tooltip: 'Settings',
            icon: const Icon(Icons.settings_outlined),
            onPressed: () => Navigator.of(
              context,
            ).push(MaterialPageRoute(builder: (_) => const SettingsScreen())),
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 0, 16, 96),
        children: [
          MonthSwitcher(
            month: _month,
            onChanged: (m) => setState(() => _month = m),
          ),
          const SizedBox(height: 4),
          _BalanceCard(balanceMinor: txProvider.balanceMinor, month: summary),
          const SizedBox(height: 16),
          if (!hasAny)
            Card(
              child: EmptyState(
                icon: Icons.account_balance_wallet_outlined,
                title: 'Start tracking',
                message:
                    'Add your first income or expense. Everything stays on this device.',
                actionLabel: 'Add transaction',
                onAction: () => openTransactionForm(context),
              ),
            )
          else ...[
            _BudgetSummaryCard(
              monthTxs: monthTxs,
              range: range,
              onOpen: () => widget.onNavigate(3),
            ),
            const SizedBox(height: 16),
            _TopSpendingCard(
              monthTxs: monthTxs,
              onOpen: () => widget.onNavigate(2),
            ),
            const SizedBox(height: 16),
            SectionCard(
              title: 'Recent transactions',
              padding: const EdgeInsets.fromLTRB(6, 16, 6, 8),
              trailing: TextButton(
                onPressed: () => widget.onNavigate(1),
                child: const Text('See all'),
              ),
              child: Column(
                children: [
                  for (final tx in txProvider.recent())
                    TransactionTile(tx: tx, showDate: true),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _BalanceCard extends StatelessWidget {
  const _BalanceCard({required this.balanceMinor, required this.month});

  final int balanceMinor;
  final FinanceSummary month;

  @override
  Widget build(BuildContext context) {
    final colors = AppColors.of(context);
    final settings = context.watch<SettingsProvider>();
    final rate = month.savingsRate;
    final onHero = colors.onHero;
    final muted = onHero.withValues(alpha: 0.75);

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(24),
        gradient: LinearGradient(
          colors: [colors.heroAccent, colors.hero],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Total balance', style: TextStyle(color: muted, fontSize: 14)),
          const SizedBox(height: 4),
          Semantics(
            container: true,
            label: 'Total balance ${settings.format(balanceMinor)}',
            excludeSemantics: true,
            child: FittedBox(
              fit: BoxFit.scaleDown,
              alignment: Alignment.centerLeft,
              child: AmountText(
                balanceMinor,
                color: onHero,
                style: const TextStyle(
                  fontSize: 34,
                  fontWeight: FontWeight.w800,
                  letterSpacing: -0.5,
                ),
              ),
            ),
          ),
          Text(
            'All-time income minus expenses',
            style: TextStyle(color: muted, fontSize: 12),
          ),
          const SizedBox(height: 18),
          Row(
            children: [
              Expanded(
                child: _HeroStat(
                  label: 'Income',
                  icon: Icons.south_west_rounded,
                  minor: month.incomeMinor,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _HeroStat(
                  label: 'Expenses',
                  icon: Icons.north_east_rounded,
                  minor: month.expenseMinor,
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          Semantics(
            container: true,
            label: 'Net savings this month ${settings.format(month.netMinor)}',
            excludeSemantics: true,
            child: Wrap(
              spacing: 8,
              crossAxisAlignment: WrapCrossAlignment.center,
              children: [
                Text('Net savings', style: TextStyle(color: muted)),
                AmountText(
                  month.netMinor,
                  color: onHero,
                  style: const TextStyle(fontWeight: FontWeight.w700),
                ),
                if (rate != null)
                  Text(
                    '· ${(rate * 100).round()}% of income',
                    style: TextStyle(color: muted),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _HeroStat extends StatelessWidget {
  const _HeroStat({
    required this.label,
    required this.icon,
    required this.minor,
  });

  final String label;
  final IconData icon;
  final int minor;

  @override
  Widget build(BuildContext context) {
    final colors = AppColors.of(context);
    final settings = context.watch<SettingsProvider>();
    return Semantics(
      container: true,
      label: '$label this month ${settings.format(minor)}',
      excludeSemantics: true,
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: Colors.white.withValues(alpha: 0.12),
          borderRadius: BorderRadius.circular(16),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(icon, size: 16, color: colors.onHero),
                const SizedBox(width: 6),
                Flexible(
                  child: Text(
                    label,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      color: colors.onHero.withValues(alpha: 0.85),
                      fontSize: 13,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 6),
            FittedBox(
              fit: BoxFit.scaleDown,
              alignment: Alignment.centerLeft,
              child: AmountText(
                minor,
                color: colors.onHero,
                style: const TextStyle(
                  fontSize: 17,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _BudgetSummaryCard extends StatelessWidget {
  const _BudgetSummaryCard({
    required this.monthTxs,
    required this.range,
    required this.onOpen,
  });

  final List<TransactionModel> monthTxs;
  final DateRange range;
  final VoidCallback onOpen;

  @override
  Widget build(BuildContext context) {
    final budgets = context.watch<BudgetProvider>();
    final colors = AppColors.of(context);
    final scheme = Theme.of(context).colorScheme;

    if (budgets.isEmpty) {
      return Card(
        child: ListTile(
          contentPadding: const EdgeInsets.symmetric(
            horizontal: 18,
            vertical: 6,
          ),
          leading: Icon(Icons.savings_outlined, color: scheme.primary),
          title: const Text('Set a monthly budget'),
          subtitle: const Text('Get warned before you overspend.'),
          trailing: const Icon(Icons.chevron_right_rounded),
          onTap: onOpen,
        ),
      );
    }

    final overall = budgets.overall;
    final statuses = [
      for (final b in budgets.categoryBudgets)
        FinanceCalculator.budgetStatus(
          limitMinor: b.limitMinor,
          txs: monthTxs,
          month: range,
          category: b.category,
        ),
    ];
    final over = statuses.where((s) => s.state == BudgetState.exceeded).length;

    return SectionCard(
      title: 'Budget',
      trailing: TextButton(onPressed: onOpen, child: const Text('Manage')),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (overall != null) ...[
            Builder(
              builder: (context) {
                final s = FinanceCalculator.budgetStatus(
                  limitMinor: overall.limitMinor,
                  txs: monthTxs,
                  month: range,
                );
                return BudgetProgress(status: s, label: 'All expenses');
              },
            ),
          ],
          if (statuses.isNotEmpty) ...[
            if (overall != null) const SizedBox(height: 12),
            Row(
              children: [
                Icon(
                  over > 0
                      ? Icons.warning_amber_rounded
                      : Icons.check_circle_outline,
                  size: 18,
                  color: over > 0 ? colors.expense : colors.income,
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    over > 0
                        ? '$over of ${statuses.length} category budgets exceeded'
                        : 'All ${statuses.length} category budgets on track',
                  ),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }
}

class _TopSpendingCard extends StatelessWidget {
  const _TopSpendingCard({required this.monthTxs, required this.onOpen});

  final List<TransactionModel> monthTxs;
  final VoidCallback onOpen;

  @override
  Widget build(BuildContext context) {
    final byCategory = FinanceCalculator.expenseByCategory(monthTxs);
    final total = byCategory.fold<int>(0, (s, e) => s + e.value);
    final cats = context.watch<CategoryProvider>();

    return SectionCard(
      title: 'Top spending',
      trailing: TextButton(onPressed: onOpen, child: const Text('Reports')),
      child: byCategory.isEmpty
          ? const EmptyState(
              compact: true,
              icon: Icons.pie_chart_outline_rounded,
              title: 'No expenses this month',
              message: 'Spending by category will appear here.',
            )
          : Column(
              children: [
                for (final e in byCategory.take(5))
                  Padding(
                    padding: const EdgeInsets.symmetric(vertical: 6),
                    child: Row(
                      children: [
                        CategoryAvatar(e.key, size: 36),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.stretch,
                            children: [
                              Row(
                                children: [
                                  Expanded(
                                    child: Text(
                                      e.key,
                                      overflow: TextOverflow.ellipsis,
                                      style: const TextStyle(
                                        fontWeight: FontWeight.w600,
                                      ),
                                    ),
                                  ),
                                  const SizedBox(width: 8),
                                  Flexible(
                                    child: AmountText(
                                      e.value,
                                      fit: true,
                                      style: const TextStyle(
                                        fontWeight: FontWeight.w600,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 6),
                              ProgressBar(
                                value: total == 0 ? 0 : e.value / total,
                                color: Color(
                                  cats.byName(e.key)?.colorValue ?? 0xFF64748B,
                                ),
                                height: 6,
                              ),
                            ],
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
