import 'package:expense_tracker/models/budget_model.dart';
import 'package:expense_tracker/models/category_model.dart';
import 'package:expense_tracker/models/transaction_model.dart';
import 'package:expense_tracker/providers/budget_provider.dart';
import 'package:expense_tracker/providers/category_provider.dart';
import 'package:expense_tracker/providers/settings_provider.dart';
import 'package:expense_tracker/providers/transaction_provider.dart';
import 'package:expense_tracker/services/category_actions.dart';
import 'package:expense_tracker/services/key_value_store.dart';
import 'package:expense_tracker/utils/date_utils.dart';
import 'package:expense_tracker/utils/money.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

TransactionModel tx(
  String id,
  int minor, {
  bool income = false,
  String category = 'Food',
  DateTime? date,
  String note = '',
}) => TransactionModel(
  id: id,
  amountMinor: minor,
  category: category,
  note: note,
  date: date ?? DateTime(2026, 5, 10),
  paymentType: 'Cash',
  isIncome: income,
);

void main() {
  group('TransactionProvider', () {
    late MemoryStore store;
    late TransactionProvider p;

    setUp(() {
      store = MemoryStore();
      p = TransactionProvider(store)..load();
    });

    test('add, edit and delete keep storage and totals in sync', () async {
      await p.save(tx('a', 100000, income: true, category: 'Salary'));
      await p.save(tx('b', 2550));
      expect(p.balanceMinor, 97450);
      expect(store.readAll().keys, containsAll(['a', 'b']));

      await p.save(p.byId('b')!.copyWith(amountMinor: 5000));
      expect(p.transactions.length, 2, reason: 'edit must not duplicate');
      expect(p.balanceMinor, 95000);
      expect((store.get('b') as Map)['amountMinor'], 5000);

      final removed = await p.delete('b');
      expect(removed!.id, 'b');
      expect(p.balanceMinor, 100000);
      expect(store.get('b'), isNull);
      expect(store.get('a'), isNotNull, reason: 'unrelated record untouched');
    });

    test('changing type from expense to income updates totals', () async {
      await p.save(tx('a', 1000));
      expect(p.balanceMinor, -1000);
      await p.save(p.byId('a')!.copyWith(isIncome: true));
      expect(p.balanceMinor, 1000);
    });

    test('saving the same transaction twice never duplicates it', () async {
      final t = tx('dup', 500);
      await Future.wait([p.save(t), p.save(t)]);
      expect(p.transactions.length, 1);
      expect(store.readAll().length, 1);
    });

    test(
      'a failed write leaves memory unchanged and reports the error',
      () async {
        await p.save(tx('a', 100));
        store.failWritesWith = Exception('disk full');
        await expectLater(p.save(tx('b', 200)), throwsException);
        await expectLater(p.delete('a'), throwsException);
        expect(p.transactions.map((e) => e.id), ['a']);
        expect(p.balanceMinor, -100);
      },
    );

    test('unreadable stored records are counted and left untouched', () {
      final s = MemoryStore({
        'good': tx('good', 100).toMap(),
        'bad': {'id': 'bad', 'amount': 'abc'},
        'junk': 42,
      });
      final provider = TransactionProvider(s)..load();
      expect(provider.transactions.length, 1);
      expect(provider.unreadableRecords, 2);
      expect(s.readAll().length, 3);
    });

    test(
      'reloading from the same store restores everything (restart)',
      () async {
        await p.save(
          tx('a', 1234, note: 'Lunch', date: DateTime(2024, 2, 29, 13)),
        );
        final again = TransactionProvider(store)..load();
        final t = again.byId('a')!;
        expect(t.amountMinor, 1234);
        expect(t.note, 'Lunch');
        expect(t.date, DateTime(2024, 2, 29, 13));
      },
    );

    test('sorted newest first', () async {
      await p.save(tx('old', 1, date: DateTime(2025, 1, 1)));
      await p.save(tx('new', 1, date: DateTime(2026, 1, 1)));
      await p.save(tx('mid', 1, date: DateTime(2025, 6, 1)));
      expect(p.transactions.map((e) => e.id), ['new', 'mid', 'old']);
    });

    test('filter by query, type, category and inclusive date range', () async {
      await p.saveAll([
        tx('1', 1000, note: 'Coffee beans', date: DateTime(2026, 3, 1)),
        tx(
          '2',
          250000,
          income: true,
          category: 'Salary',
          date: DateTime(2026, 3, 31, 23, 30),
        ),
        tx(
          '3',
          4500,
          category: 'Bills',
          note: 'Electricity',
          date: DateTime(2026, 4, 1),
        ),
      ]);
      expect(p.filter(query: 'COFFEE').map((e) => e.id), ['1']);
      expect(p.filter(query: 'bills').map((e) => e.id), ['3']);
      expect(p.filter(query: '45.00').map((e) => e.id), ['3']);
      expect(p.filter(type: TypeFilter.income).map((e) => e.id), ['2']);
      expect(p.filter(type: TypeFilter.expense).length, 2);
      expect(p.filter(category: 'Salary').length, 1);
      expect(
        p.filter(range: DateRange.month(2026, 3)).map((e) => e.id).toSet(),
        {'1', '2'},
      );
      expect(p.filter(query: 'nothing matches').isEmpty, isTrue);
    });

    test('moveCategory updates only matching transactions', () async {
      await p.saveAll([
        tx('1', 1, category: 'Food'),
        tx('2', 1, category: 'Bills'),
      ]);
      final moved = await p.moveCategory('Food', 'Groceries');
      expect(moved, 1);
      expect(p.byId('1')!.category, 'Groceries');
      expect(p.byId('2')!.category, 'Bills');
      expect((store.get('1') as Map)['category'], 'Groceries');
    });

    test('deleteAll removes readable records only', () async {
      store = MemoryStore({
        'bad': {'nope': true},
      });
      p = TransactionProvider(store)..load();
      await p.save(tx('a', 1));
      await p.deleteAll();
      expect(p.transactions, isEmpty);
      expect(store.readAll().keys, ['bad']);
    });
  });

  group('CategoryProvider', () {
    test(
      'seeds defaults once and adopts categories used by old records',
      () async {
        final store = MemoryStore();
        final c = CategoryProvider(store);
        await c.load(usedNames: {'Food', 'Pets'});
        expect(c.byName('Food'), isNotNull);
        expect(c.byName('Pets')!.type, CategoryType.both);
        expect(c.categories.last.name, 'Other');
        final count = c.categories.length;

        final again = CategoryProvider(store);
        await again.load(usedNames: {'Food', 'Pets'});
        expect(again.categories.length, count, reason: 'no duplicate seeding');
      },
    );

    test('name validation', () async {
      final c = CategoryProvider(MemoryStore());
      await c.load();
      expect(c.validateName(''), isNotNull);
      expect(c.validateName('   '), isNotNull);
      expect(
        c.validateName('food'),
        isNotNull,
        reason: 'case-insensitive duplicate',
      );
      expect(c.validateName('x' * 31), isNotNull);
      expect(c.validateName('Groceries'), isNull);
      final food = c.byName('Food')!;
      expect(c.validateName('Food', excludingId: food.id), isNull);
    });

    test('"Other" cannot be renamed or deleted', () async {
      final c = CategoryProvider(MemoryStore());
      await c.load();
      final other = c.byName('Other')!;
      expect(
        () => c.delete(other),
        throwsA(isA<CategoryValidationException>()),
      );
      expect(
        () => c.update(other.copyWith(name: 'Misc')),
        throwsA(isA<CategoryValidationException>()),
      );
    });
  });

  group('CategoryActions', () {
    late TransactionProvider txs;
    late CategoryProvider cats;
    late BudgetProvider budgets;
    late CategoryActions actions;

    setUp(() async {
      txs = TransactionProvider(MemoryStore())..load();
      cats = CategoryProvider(MemoryStore());
      await cats.load();
      budgets = BudgetProvider(MemoryStore())..load();
      actions = CategoryActions(cats, txs, budgets);
      await txs.saveAll([
        tx('1', 100, category: 'Food'),
        tx('2', 200, category: 'Food'),
        tx('3', 300, category: 'Bills'),
      ]);
      await budgets.setBudget('Food', 5000);
    });

    test('rename moves transactions and budget', () async {
      final food = cats.byName('Food')!;
      final moved = await actions.save(food, food.copyWith(name: 'Dining'));
      expect(moved, 2);
      expect(cats.byName('Food'), isNull);
      expect(txs.countForCategory('Dining'), 2);
      expect(budgets.forCategory('Dining')!.limitMinor, 5000);
      expect(budgets.forCategory('Food'), isNull);
      expect(txs.allTimeSummary.expenseMinor, 600, reason: 'totals unchanged');
    });

    test('delete moves transactions to Other and removes the budget', () async {
      final moved = await actions.delete(cats.byName('Food')!);
      expect(moved, 2);
      expect(txs.countForCategory('Other'), 2);
      expect(txs.countForCategory('Bills'), 1);
      expect(budgets.forCategory('Food'), isNull);
      expect(txs.transactions.length, 3, reason: 'no transaction deleted');
    });
  });

  group('BudgetProvider', () {
    test('set, update, remove and persist', () async {
      final store = MemoryStore();
      final b = BudgetProvider(store)..load();
      await b.setBudget(BudgetModel.overallKey, 2000000);
      await b.setBudget('Food', 500000);
      await b.setBudget('Food', 600000);
      expect(b.categoryBudgets.single.limitMinor, 600000);
      expect(b.overall!.limitMinor, 2000000);

      final reloaded = BudgetProvider(store)..load();
      expect(reloaded.all.length, 2);

      await reloaded.remove('Food');
      expect(reloaded.forCategory('Food'), isNull);
      expect(() => reloaded.setBudget('X', 0), throwsArgumentError);
    });
  });

  group('SettingsProvider', () {
    test('defaults and persistence', () async {
      final store = MemoryStore();
      final s = SettingsProvider(store)..load();
      expect(s.themeMode, ThemeMode.system);
      expect(s.currency.code, 'INR');
      await s.setThemeMode(ThemeMode.dark);
      await s.setCurrency(currencyForCode('USD'));
      final again = SettingsProvider(store)..load();
      expect(again.themeMode, ThemeMode.dark);
      expect(again.currency.code, 'USD');
    });

    test('unknown stored values fall back to defaults', () {
      final s = SettingsProvider(
        MemoryStore({'themeMode': 'neon', 'currencyCode': 'XXX'}),
      )..load();
      expect(s.themeMode, ThemeMode.system);
      expect(s.currency.code, 'INR');
    });
  });
}
