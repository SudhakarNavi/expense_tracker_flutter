import 'dart:convert';
import 'dart:io';

import 'package:expense_tracker/models/budget_model.dart';
import 'package:expense_tracker/models/transaction_model.dart';
import 'package:expense_tracker/providers/budget_provider.dart';
import 'package:expense_tracker/providers/category_provider.dart';
import 'package:expense_tracker/providers/transaction_provider.dart';
import 'package:expense_tracker/services/backup_service.dart';
import 'package:expense_tracker/services/key_value_store.dart';
import 'package:expense_tracker/services/pdf_report_service.dart';
import 'package:expense_tracker/utils/app_constants.dart';
import 'package:expense_tracker/utils/money.dart';
import 'package:flutter_test/flutter_test.dart';

TransactionModel tx(
  String id,
  int minor, {
  String category = 'Food',
  bool income = false,
}) => TransactionModel(
  id: id,
  amountMinor: minor,
  category: category,
  note: 'note $id',
  date: DateTime(2026, 4, 30, 22),
  paymentType: 'UPI',
  isIncome: income,
);

void main() {
  group('backup', () {
    late TransactionProvider txs;
    late CategoryProvider cats;
    late BudgetProvider budgets;

    Future<void> fresh() async {
      txs = TransactionProvider(MemoryStore())..load();
      cats = CategoryProvider(MemoryStore());
      await cats.load();
      budgets = BudgetProvider(MemoryStore())..load();
    }

    setUp(fresh);

    test(
      'export then import into an empty device restores everything',
      () async {
        await txs.saveAll([
          tx('1', 12345),
          tx('2', 500000, category: 'Salary', income: true),
        ]);
        await cats.add(
          name: 'Pets',
          type: cats.byName('Food')!.type,
          iconKey: 'pets',
          colorValue: 1,
        );
        await budgets.setBudget('Food', 100000);
        final json = BackupService.encode(
          transactions: txs.transactions,
          categories: cats.categories,
          budgets: budgets.all,
        );

        final summaryBefore = txs.allTimeSummary;
        await fresh();
        final result = await BackupService.importInto(
          BackupService.decode(json),
          transactions: txs,
          categories: cats,
          budgets: budgets,
        );
        expect(result.added, 2);
        expect(result.skippedExisting, 0);
        expect(txs.allTimeSummary.incomeMinor, summaryBefore.incomeMinor);
        expect(txs.allTimeSummary.expenseMinor, summaryBefore.expenseMinor);
        expect(txs.byId('1')!.note, 'note 1');
        expect(txs.byId('1')!.date, DateTime(2026, 4, 30, 22));
        expect(cats.byName('Pets'), isNotNull);
        expect(budgets.forCategory('Food')!.limitMinor, 100000);
      },
    );

    test('import merges: existing records are kept, nothing deleted', () async {
      await txs.saveAll([tx('1', 100), tx('local', 999)]);
      final backup = BackupService.encode(
        transactions: [tx('1', 777777), tx('new', 50)],
        categories: const [],
        budgets: const [BudgetModel(category: 'Food', limitMinor: 1)],
      );
      await budgets.setBudget('Food', 5000);
      final result = await BackupService.importInto(
        BackupService.decode(backup),
        transactions: txs,
        categories: cats,
        budgets: budgets,
      );
      expect(result.added, 1);
      expect(result.skippedExisting, 1);
      expect(txs.byId('1')!.amountMinor, 100, reason: 'local version wins');
      expect(txs.byId('local'), isNotNull);
      expect(txs.byId('new'), isNotNull);
      expect(budgets.forCategory('Food')!.limitMinor, 5000);
    });

    test(
      'importing the same backup twice adds nothing the second time',
      () async {
        final backup = BackupService.decode(
          BackupService.encode(
            transactions: [tx('a', 1), tx('b', 2)],
            categories: const [],
            budgets: const [],
          ),
        );
        await BackupService.importInto(
          backup,
          transactions: txs,
          categories: cats,
          budgets: budgets,
        );
        final second = await BackupService.importInto(
          backup,
          transactions: txs,
          categories: cats,
          budgets: budgets,
        );
        expect(second.added, 0);
        expect(txs.transactions.length, 2);
      },
    );

    test('unknown categories on imported transactions are created', () async {
      final backup = BackupService.decode(
        BackupService.encode(
          transactions: [tx('a', 1, category: 'Garden')],
          categories: const [],
          budgets: const [],
        ),
      );
      await BackupService.importInto(
        backup,
        transactions: txs,
        categories: cats,
        budgets: budgets,
      );
      expect(cats.byName('Garden'), isNotNull);
    });

    test('rejects files that are not backups', () {
      expect(
        () => BackupService.decode('not json'),
        throwsA(isA<BackupFormatException>()),
      );
      expect(
        () => BackupService.decode('{}'),
        throwsA(isA<BackupFormatException>()),
      );
      expect(
        () => BackupService.decode('[1,2]'),
        throwsA(isA<BackupFormatException>()),
      );
      expect(
        () => BackupService.decode(
          jsonEncode({
            'format': BackupService.formatId,
            'version': 99,
            'transactions': [],
          }),
        ),
        throwsA(isA<BackupFormatException>()),
      );
      expect(
        () => BackupService.decode(
          jsonEncode({'format': BackupService.formatId, 'version': 1}),
        ),
        throwsA(isA<BackupFormatException>()),
      );
    });

    test('bad rows are counted, good rows still imported', () {
      final data = BackupService.decode(
        jsonEncode({
          'format': BackupService.formatId,
          'version': 1,
          'transactions': [
            tx('ok', 5).toMap(),
            {'id': 'bad'},
            'garbage',
          ],
        }),
      );
      expect(data.transactions.length, 1);
      expect(data.unreadableTransactions, 2);
    });
  });

  group('PDF report', () {
    test('produces a valid PDF for data and for an empty period', () async {
      for (final list in [
        [tx('1', 12345), tx('2', 500000, income: true, category: 'Salary')],
        <TransactionModel>[],
      ]) {
        final bytes = await PdfReportService.build(
          transactions: list,
          currency: currencyForCode('INR'),
          periodLabel: 'April 2026',
          generatedAt: DateTime(2026, 5, 1, 9, 5),
        );
        expect(String.fromCharCodes(bytes.take(5)), '%PDF-');
        expect(bytes.length, greaterThan(500));
      }
    });

    test('non-Latin notes do not crash generation', () async {
      final bytes = await PdfReportService.build(
        transactions: [
          TransactionModel(
            id: 'h',
            amountMinor: 100,
            category: 'Food',
            note: 'चाय और नाश्ता',
            date: DateTime(2026, 1, 1),
            paymentType: 'Cash',
            isIncome: false,
          ),
        ],
        currency: currencyForCode('INR'),
        periodLabel: 'January 2026',
      );
      expect(String.fromCharCodes(bytes.take(5)), '%PDF-');
    });
  });

  test('appVersion matches pubspec.yaml', () {
    final pubspec = File('pubspec.yaml').readAsStringSync();
    final version = RegExp(
      r'^version:\s*([^+\s]+)',
      multiLine: true,
    ).firstMatch(pubspec)!.group(1);
    expect(appVersion, version);
  });

  test('every supported currency formats with its symbol', () {
    for (final c in supportedCurrencies) {
      expect(Money.format(100, c), startsWith(c.symbol));
    }
  });
}
