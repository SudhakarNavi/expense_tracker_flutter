import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../providers/category_provider.dart';
import '../providers/settings_provider.dart';
import '../theme/app_theme.dart';
import '../utils/app_constants.dart';
import '../utils/date_utils.dart';

/// Formatted amount with tabular figures. With [isIncome] set, the amount is
/// colored and prefixed with +/−.
class AmountText extends StatelessWidget {
  const AmountText(
    this.minor, {
    super.key,
    this.isIncome,
    this.style,
    this.color,
    this.compact = false,
    this.fit = false,
  });

  final int minor;
  final bool? isIncome;
  final TextStyle? style;
  final Color? color;
  final bool compact;

  /// Scale the text down to fit instead of truncating it. Amounts should
  /// never be cut off, so rows that might be tight use this.
  final bool fit;

  @override
  Widget build(BuildContext context) {
    final settings = context.watch<SettingsProvider>();
    final colors = AppColors.of(context);
    String text = compact ? settings.compact(minor) : settings.format(minor);
    Color? c = color;
    if (isIncome != null) {
      text = '${isIncome! ? '+' : '−'}$text';
      c ??= isIncome! ? colors.income : colors.expense;
    }
    final widget = Text(
      text,
      maxLines: 1,
      softWrap: false,
      overflow: fit ? TextOverflow.visible : TextOverflow.ellipsis,
      style: (style ?? const TextStyle()).copyWith(
        color: c,
        fontFeatures: tabularFigures,
      ),
    );
    return fit
        ? FittedBox(
            fit: BoxFit.scaleDown,
            alignment: AlignmentDirectional.centerEnd,
            child: widget,
          )
        : widget;
  }
}

class CategoryAvatar extends StatelessWidget {
  const CategoryAvatar(this.category, {super.key, this.size = 44});

  final String category;
  final double size;

  @override
  Widget build(BuildContext context) {
    final model = context.select<CategoryProvider, (String?, int?)>((p) {
      final c = p.byName(category);
      return (c?.iconKey, c?.colorValue);
    });
    final color = Color(model.$2 ?? 0xFF64748B);
    return ExcludeSemantics(
      child: Container(
        width: size,
        height: size,
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.15),
          borderRadius: BorderRadius.circular(size * 0.32),
        ),
        child: Icon(iconForKey(model.$1), color: color, size: size * 0.52),
      ),
    );
  }
}

class EmptyState extends StatelessWidget {
  const EmptyState({
    super.key,
    required this.icon,
    required this.title,
    required this.message,
    this.actionLabel,
    this.onAction,
    this.compact = false,
  });

  final IconData icon;
  final String title;
  final String message;
  final String? actionLabel;
  final VoidCallback? onAction;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Padding(
      padding: EdgeInsets.symmetric(
        horizontal: 24,
        vertical: compact ? 16 : 40,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            padding: EdgeInsets.all(compact ? 12 : 18),
            decoration: BoxDecoration(
              color: scheme.primaryContainer.withValues(alpha: 0.6),
              shape: BoxShape.circle,
            ),
            child: Icon(icon, size: compact ? 28 : 40, color: scheme.primary),
          ),
          const SizedBox(height: 14),
          Text(
            title,
            textAlign: TextAlign.center,
            style: Theme.of(
              context,
            ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: 6),
          Text(
            message,
            textAlign: TextAlign.center,
            style: TextStyle(color: scheme.onSurfaceVariant),
          ),
          if (actionLabel != null && onAction != null) ...[
            const SizedBox(height: 16),
            FilledButton.tonalIcon(
              onPressed: onAction,
              icon: const Icon(Icons.add_rounded),
              label: Text(actionLabel!),
            ),
          ],
        ],
      ),
    );
  }
}

class SectionCard extends StatelessWidget {
  const SectionCard({
    super.key,
    required this.title,
    required this.child,
    this.trailing,
    this.padding = const EdgeInsets.fromLTRB(18, 16, 18, 18),
  });

  final String title;
  final Widget child;
  final Widget? trailing;
  final EdgeInsets padding;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: padding,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                Expanded(
                  child: Semantics(
                    header: true,
                    child: Text(
                      title,
                      style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                ),
                if (trailing != null) Flexible(child: trailing!),
              ],
            ),
            const SizedBox(height: 12),
            child,
          ],
        ),
      ),
    );
  }
}

/// "‹ October 2026 ›" month switcher.
class MonthSwitcher extends StatelessWidget {
  const MonthSwitcher({
    super.key,
    required this.month,
    required this.onChanged,
    this.yearMode = false,
  });

  /// Any date within the selected month (or year in [yearMode]).
  final DateTime month;
  final ValueChanged<DateTime> onChanged;
  final bool yearMode;

  @override
  Widget build(BuildContext context) {
    final label = yearMode ? '${month.year}' : formatMonthYear(month);
    DateTime shift(int delta) => yearMode
        ? DateTime(month.year + delta, 1, 1)
        : DateTime(month.year, month.month + delta, 1);
    final now = DateTime.now();
    final isCurrent = yearMode
        ? month.year == now.year
        : month.year == now.year && month.month == now.month;
    return Row(
      children: [
        IconButton(
          tooltip: yearMode ? 'Previous year' : 'Previous month',
          onPressed: () => onChanged(shift(-1)),
          icon: const Icon(Icons.chevron_left_rounded),
        ),
        Expanded(
          child: TextButton(
            onPressed: isCurrent
                ? null
                : () => onChanged(
                    DateTime(now.year, yearMode ? 1 : now.month, 1),
                  ),
            child: AnimatedSwitcher(
              duration: const Duration(milliseconds: 200),
              child: Text(
                label,
                key: ValueKey(label),
                style: Theme.of(context).textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.w700,
                  color: Theme.of(context).colorScheme.onSurface,
                ),
              ),
            ),
          ),
        ),
        IconButton(
          tooltip: yearMode ? 'Next year' : 'Next month',
          onPressed: () => onChanged(shift(1)),
          icon: const Icon(Icons.chevron_right_rounded),
        ),
      ],
    );
  }
}

Future<bool> confirmAction(
  BuildContext context, {
  required String title,
  required String message,
  required String confirmLabel,
  bool destructive = true,
}) async {
  final result = await showDialog<bool>(
    context: context,
    builder: (context) {
      final scheme = Theme.of(context).colorScheme;
      return AlertDialog(
        title: Text(title),
        content: Text(message),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            style: destructive
                ? FilledButton.styleFrom(
                    backgroundColor: scheme.error,
                    foregroundColor: scheme.onError,
                    minimumSize: const Size(64, 40),
                  )
                : FilledButton.styleFrom(minimumSize: const Size(64, 40)),
            onPressed: () => Navigator.pop(context, true),
            child: Text(confirmLabel),
          ),
        ],
      );
    },
  );
  return result ?? false;
}

void showMessage(
  BuildContext context,
  String message, {
  bool error = false,
  SnackBarAction? action,
}) {
  final messenger = ScaffoldMessenger.of(context);
  final scheme = Theme.of(context).colorScheme;
  messenger.hideCurrentSnackBar();
  messenger.showSnackBar(
    SnackBar(
      content: Row(
        children: [
          Icon(
            error
                ? Icons.error_outline_rounded
                : Icons.check_circle_outline_rounded,
            color: error ? scheme.onErrorContainer : scheme.onInverseSurface,
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              message,
              style: TextStyle(color: error ? scheme.onErrorContainer : null),
            ),
          ),
        ],
      ),
      backgroundColor: error ? scheme.errorContainer : null,
      action: action,
      duration: Duration(seconds: action != null ? 5 : 3),
    ),
  );
}
