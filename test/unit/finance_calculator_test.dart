import 'package:expense_tracker/models/transaction_model.dart';
import 'package:expense_tracker/services/finance_calculator.dart';
import 'package:expense_tracker/utils/date_utils.dart';
import 'package:flutter_test/flutter_test.dart';

var _n = 0;
TransactionModel tx(
  int minor, {
  bool income = false,
  String category = 'Food',
  DateTime? date,
}) => TransactionModel(
  id: 't${_n++}',
  amountMinor: minor,
  category: category,
  note: '',
  date: date ?? DateTime(2026, 5, 15),
  paymentType: 'Cash',
  isIncome: income,
);

void main() {
  group('summary', () {
    test('empty dataset', () {
      final s = FinanceCalculator.summarize([]);
      expect(s.incomeMinor, 0);
      expect(s.expenseMinor, 0);
      expect(s.netMinor, 0);
      expect(s.count, 0);
      expect(s.savingsRate, isNull);
    });

    test('income, expense, net, balance and savings rate', () {
      final txs = [
        tx(500000, income: true),
        tx(12550),
        tx(7525),
        tx(1, income: true),
      ];
      final s = FinanceCalculator.summarize(txs);
      expect(s.incomeMinor, 500001);
      expect(s.expenseMinor, 20075);
      expect(s.netMinor, 479926);
      expect(FinanceCalculator.balance(txs), 479926);
      expect(s.savingsRate, closeTo(479926 / 500001, 1e-12));
    });

    test('spending more than income gives a negative balance and rate', () {
      final s = FinanceCalculator.summarize([tx(1000, income: true), tx(3000)]);
      expect(s.netMinor, -2000);
      expect(s.savingsRate, -2.0);
    });

    test('many decimal amounts sum exactly', () {
      final txs = List.generate(1000, (_) => tx(10)); // 1000 × 0.10
      expect(FinanceCalculator.summarize(txs).expenseMinor, 10000);
    });

    test('very large valid amounts do not overflow', () {
      const max = 99999999999999;
      final txs = List.generate(1000, (_) => tx(max, income: true));
      expect(FinanceCalculator.summarize(txs).incomeMinor, max * 1000);
    });
  });

  group('date ranges', () {
    test('month-end and next-month-start are attributed correctly', () {
      final txs = [
        tx(100, date: DateTime(2026, 1, 31, 23, 59, 59)),
        tx(200, date: DateTime(2026, 2, 1, 0, 0, 0)),
      ];
      expect(
        FinanceCalculator.summarizeRange(
          txs,
          DateRange.month(2026, 1),
        ).expenseMinor,
        100,
      );
      expect(
        FinanceCalculator.summarizeRange(
          txs,
          DateRange.month(2026, 2),
        ).expenseMinor,
        200,
      );
    });

    test('year-end boundary', () {
      final txs = [
        tx(100, date: DateTime(2025, 12, 31, 23, 59)),
        tx(200, date: DateTime(2026, 1, 1)),
      ];
      expect(
        FinanceCalculator.summarizeRange(
          txs,
          DateRange.year(2025),
        ).expenseMinor,
        100,
      );
      expect(
        FinanceCalculator.summarizeRange(
          txs,
          DateRange.year(2026),
        ).expenseMinor,
        200,
      );
    });

    test('leap day', () {
      final txs = [tx(100, date: DateTime(2024, 2, 29, 12))];
      expect(
        FinanceCalculator.summarizeRange(txs, DateRange.month(2024, 2)).count,
        1,
      );
      expect(
        FinanceCalculator.summarizeRange(txs, DateRange.month(2024, 3)).count,
        0,
      );
    });

    test('monthly totals sum to the yearly total', () {
      final txs = [
        for (var m = 1; m <= 12; m++) ...[
          tx(m * 100, date: DateTime(2026, m, 1)),
          tx(m * 1000, income: true, date: DateTime(2026, m, 28)),
        ],
      ];
      final months = FinanceCalculator.monthlyTotals(
        txs,
        DateTime(2026, 12),
        12,
      );
      expect(months.length, 12);
      expect(months.first.range, DateRange.month(2026, 1));
      final sumExpense = months.fold<int>(
        0,
        (s, p) => s + p.summary.expenseMinor,
      );
      final year = FinanceCalculator.summarizeRange(txs, DateRange.year(2026));
      expect(sumExpense, year.expenseMinor);
      expect(year.expenseMinor, 7800);
    });

    test('monthly totals across a year boundary', () {
      final months = FinanceCalculator.monthlyTotals(
        [],
        DateTime(2026, 2, 10),
        6,
      );
      expect(months.map((m) => m.range.start).toList(), [
        DateTime(2025, 9),
        DateTime(2025, 10),
        DateTime(2025, 11),
        DateTime(2025, 12),
        DateTime(2026, 1),
        DateTime(2026, 2),
      ]);
      expect(months.every((m) => m.summary.count == 0), isTrue);
    });

    test('daily totals cover every day of the month, including leap Feb', () {
      final days = FinanceCalculator.dailyTotals([
        tx(500, date: DateTime(2024, 2, 29, 18)),
      ], DateRange.month(2024, 2));
      expect(days.length, 29);
      expect(days.last.summary.expenseMinor, 500);
      expect(days.first.summary.expenseMinor, 0);
    });
  });

  group('categories', () {
    test('expense by category ignores income and sorts by amount', () {
      final result = FinanceCalculator.expenseByCategory([
        tx(100, category: 'Food'),
        tx(300, category: 'Bills'),
        tx(250, category: 'Food'),
        tx(9999, income: true, category: 'Salary'),
      ]);
      expect(result.map((e) => e.key).toList(), ['Food', 'Bills']);
      expect(result.first.value, 350);
    });

    test('category totals add up to total expenses', () {
      final txs = [
        tx(123, category: 'A'),
        tx(456, category: 'B'),
        tx(789, category: 'C'),
        tx(1, category: 'A'),
      ];
      final sum = FinanceCalculator.expenseByCategory(
        txs,
      ).fold<int>(0, (s, e) => s + e.value);
      expect(sum, FinanceCalculator.summarize(txs).expenseMinor);
    });
  });

  group('budgets', () {
    final may = DateRange.month(2026, 5);

    BudgetStatus status(
      int limit,
      List<TransactionModel> txs, {
      String? category,
    }) => FinanceCalculator.budgetStatus(
      limitMinor: limit,
      txs: txs,
      month: may,
      category: category,
    );

    test('below limit', () {
      final s = status(10000, [tx(5000)]);
      expect(s.state, BudgetState.under);
      expect(s.remainingMinor, 5000);
      expect(s.progress, 0.5);
    });

    test('near limit (>= 80%)', () {
      expect(status(10000, [tx(8000)]).state, BudgetState.near);
      expect(status(10000, [tx(7999)]).state, BudgetState.under);
    });

    test('exactly reached', () {
      final s = status(10000, [tx(4000), tx(6000)]);
      expect(s.state, BudgetState.reached);
      expect(s.remainingMinor, 0);
      expect(s.progress, 1.0);
    });

    test('exceeded by one paisa', () {
      final s = status(10000, [tx(10001)]);
      expect(s.state, BudgetState.exceeded);
      expect(s.remainingMinor, -1);
    });

    test('only counts expenses in the month and category', () {
      final s = status(10000, [
        tx(3000, category: 'Food'),
        tx(4000, category: 'Bills'),
        tx(5000, category: 'Food', date: DateTime(2026, 6, 1)),
        tx(9000, category: 'Food', income: true),
      ], category: 'Food');
      expect(s.spentMinor, 3000);
    });

    test('no spending', () {
      final s = status(10000, []);
      expect(s.spentMinor, 0);
      expect(s.state, BudgetState.under);
    });
  });
}
