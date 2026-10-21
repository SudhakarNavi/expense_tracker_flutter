import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../providers/settings_provider.dart';
import '../services/finance_calculator.dart';
import '../theme/app_theme.dart';
import 'charts.dart';

/// Progress row shared by the dashboard and budgets screen.
class BudgetProgress extends StatelessWidget {
  const BudgetProgress({super.key, required this.status, required this.label});

  final BudgetStatus status;
  final String label;

  @override
  Widget build(BuildContext context) {
    final colors = AppColors.of(context);
    final scheme = Theme.of(context).colorScheme;
    final settings = context.watch<SettingsProvider>();
    final (Color color, String note) = switch (status.state) {
      BudgetState.exceeded => (
        colors.expense,
        'Over by ${settings.format(-status.remainingMinor)}',
      ),
      BudgetState.reached => (colors.warning, 'Limit reached'),
      BudgetState.near => (
        colors.warning,
        '${settings.format(status.remainingMinor)} left',
      ),
      BudgetState.under => (
        colors.income,
        '${settings.format(status.remainingMinor)} left',
      ),
    };
    return Semantics(
      container: true,
      label:
          '$label budget: spent ${settings.format(status.spentMinor)} of '
          '${settings.format(status.limitMinor)}. $note',
      excludeSemantics: true,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  label,
                  style: const TextStyle(fontWeight: FontWeight.w600),
                ),
              ),
              Text(
                '${(status.progress * 100).round()}%',
                style: TextStyle(color: color, fontWeight: FontWeight.w700),
              ),
            ],
          ),
          const SizedBox(height: 8),
          ProgressBar(value: status.progress, color: color),
          const SizedBox(height: 6),
          Wrap(
            alignment: WrapAlignment.spaceBetween,
            spacing: 12,
            runSpacing: 2,
            children: [
              Text(
                '${settings.format(status.spentMinor)} of ${settings.format(status.limitMinor)}',
                style: TextStyle(color: scheme.onSurfaceVariant, fontSize: 13),
              ),
              Text(
                note,
                style: TextStyle(
                  color: color,
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
