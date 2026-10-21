import '../models/transaction_model.dart';
import '../utils/date_utils.dart';

/// Financial definitions used by every screen:
///
/// * income   = sum of income amounts in scope
/// * expense  = sum of expense amounts in scope
/// * net      = income − expense (shown as "Net savings" for a period)
/// * balance  = all-time income − all-time expenses (the app has no
///              opening-balance concept)
/// * savings rate = net / income, undefined when income is zero
///
/// All arithmetic is on integer minor units.
class FinanceSummary {
  final int incomeMinor;
  final int expenseMinor;
  final int count;

  const FinanceSummary(this.incomeMinor, this.expenseMinor, this.count);

  static const empty = FinanceSummary(0, 0, 0);

  int get netMinor => incomeMinor - expenseMinor;

  /// Fraction 0..1 (can be negative when spending exceeds income);
  /// null when there is no income.
  double? get savingsRate => incomeMinor == 0 ? null : netMinor / incomeMinor;
}

class PeriodTotals {
  final DateRange range;
  final FinanceSummary summary;

  const PeriodTotals(this.range, this.summary);
}

enum BudgetState { under, near, reached, exceeded }

class BudgetStatus {
  final int limitMinor;
  final int spentMinor;

  const BudgetStatus(this.limitMinor, this.spentMinor);

  /// Spending at or above this share of the limit is flagged as "near".
  static const double nearThreshold = 0.8;

  int get remainingMinor => limitMinor - spentMinor;

  double get progress => limitMinor <= 0 ? 0 : spentMinor / limitMinor;

  BudgetState get state {
    if (spentMinor > limitMinor) return BudgetState.exceeded;
    if (spentMinor == limitMinor) return BudgetState.reached;
    if (progress >= nearThreshold) return BudgetState.near;
    return BudgetState.under;
  }
}

class FinanceCalculator {
  FinanceCalculator._();

  static FinanceSummary summarize(Iterable<TransactionModel> txs) {
    var income = 0;
    var expense = 0;
    var count = 0;
    for (final tx in txs) {
      count++;
      if (tx.isIncome) {
        income += tx.amountMinor;
      } else {
        expense += tx.amountMinor;
      }
    }
    return FinanceSummary(income, expense, count);
  }

  static int balance(Iterable<TransactionModel> txs) => summarize(txs).netMinor;

  static Iterable<TransactionModel> inRange(
    Iterable<TransactionModel> txs,
    DateRange range,
  ) => txs.where((tx) => range.contains(tx.date));

  static FinanceSummary summarizeRange(
    Iterable<TransactionModel> txs,
    DateRange range,
  ) => summarize(inRange(txs, range));

  /// Expense totals per category, largest first.
  static List<MapEntry<String, int>> expenseByCategory(
    Iterable<TransactionModel> txs,
  ) {
    final totals = <String, int>{};
    for (final tx in txs) {
      if (tx.isIncome) continue;
      totals[tx.category] = (totals[tx.category] ?? 0) + tx.amountMinor;
    }
    final list = totals.entries.toList()
      ..sort((a, b) {
        final byValue = b.value.compareTo(a.value);
        return byValue != 0 ? byValue : a.key.compareTo(b.key);
      });
    return list;
  }

  static int expenseForCategory(
    Iterable<TransactionModel> txs,
    String category,
  ) {
    var total = 0;
    for (final tx in txs) {
      if (!tx.isIncome && tx.category == category) total += tx.amountMinor;
    }
    return total;
  }

  /// [count] consecutive months ending with the month containing [end],
  /// oldest first.
  static List<PeriodTotals> monthlyTotals(
    Iterable<TransactionModel> txs,
    DateTime end,
    int count,
  ) {
    final list = txs.toList();
    return [
      for (var i = count - 1; i >= 0; i--)
        () {
          final range = DateRange.month(end.year, end.month - i);
          return PeriodTotals(range, summarizeRange(list, range));
        }(),
    ];
  }

  /// One entry per calendar day in [range], oldest first.
  static List<PeriodTotals> dailyTotals(
    Iterable<TransactionModel> txs,
    DateRange range,
  ) {
    final buckets = <DateTime, List<TransactionModel>>{};
    for (final tx in inRange(txs, range)) {
      buckets.putIfAbsent(dateOnly(tx.date), () => []).add(tx);
    }
    final result = <PeriodTotals>[];
    for (
      var d = range.start;
      d.isBefore(range.end);
      d = DateTime(d.year, d.month, d.day + 1)
    ) {
      result.add(
        PeriodTotals(DateRange.days(d, d), summarize(buckets[d] ?? const [])),
      );
    }
    return result;
  }

  static BudgetStatus budgetStatus({
    required int limitMinor,
    required Iterable<TransactionModel> txs,
    required DateRange month,
    String? category,
  }) {
    final scoped = inRange(txs, month);
    final spent = category == null
        ? summarize(scoped).expenseMinor
        : expenseForCategory(scoped, category);
    return BudgetStatus(limitMinor, spent);
  }
}
