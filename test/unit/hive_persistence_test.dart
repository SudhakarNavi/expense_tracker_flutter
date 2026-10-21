import 'dart:io';

import 'package:expense_tracker/models/transaction_model.dart';
import 'package:expense_tracker/providers/budget_provider.dart';
import 'package:expense_tracker/providers/category_provider.dart';
import 'package:expense_tracker/providers/settings_provider.dart';
import 'package:expense_tracker/providers/transaction_provider.dart';
import 'package:expense_tracker/services/hive_service.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hive/hive.dart';

/// Uses real Hive files in a throwaway temp directory — never user data.
void main() {
  late Directory dir;

  setUp(() async {
    dir = await Directory.systemTemp.createTemp('expense_tracker_test_');
    Hive.init(dir.path);
  });

  tearDown(() async {
    await Hive.close();
    await dir.delete(recursive: true);
  });

  Future<AppStores> restart() async {
    await Hive.close();
    Hive.init(dir.path);
    return HiveService.openStores();
  }

  test(
    'transactions, categories, budgets and settings survive a restart',
    () async {
      var stores = await HiveService.openStores();
      final txs = TransactionProvider(stores.transactions)..load();
      final cats = CategoryProvider(stores.categories);
      await cats.load();
      final budgets = BudgetProvider(stores.budgets)..load();
      final settings = SettingsProvider(stores.settings)..load();

      await txs.save(
        TransactionModel(
          id: 'p1',
          amountMinor: 123456,
          category: 'Food',
          note: 'Groceries',
          date: DateTime(2025, 12, 31, 23, 59),
          paymentType: 'UPI',
          isIncome: false,
          bankAccount: 'Bank account',
        ),
      );
      await txs.save(
        TransactionModel(
          id: 'p2',
          amountMinor: 5000000,
          category: 'Salary',
          note: '',
          date: DateTime(2026, 1, 1),
          paymentType: 'Net Banking',
          isIncome: true,
        ),
      );
      await txs.delete('p2');
      await cats.add(
        name: 'Pets',
        type: cats.byName('Food')!.type,
        iconKey: 'pets',
        colorValue: 7,
      );
      await budgets.setBudget('Food', 99900);
      await settings.setThemeMode(ThemeMode.dark);

      stores = await restart();
      final txs2 = TransactionProvider(stores.transactions)..load();
      final cats2 = CategoryProvider(stores.categories);
      await cats2.load(usedNames: txs2.usedCategories);
      final budgets2 = BudgetProvider(stores.budgets)..load();
      final settings2 = SettingsProvider(stores.settings)..load();

      expect(txs2.transactions.length, 1);
      final t = txs2.byId('p1')!;
      expect(t.amountMinor, 123456);
      expect(t.note, 'Groceries');
      expect(t.date, DateTime(2025, 12, 31, 23, 59));
      expect(t.bankAccount, 'Bank account');
      expect(txs2.byId('p2'), isNull, reason: 'deleted record stays deleted');
      expect(cats2.byName('Pets'), isNotNull);
      expect(budgets2.forCategory('Food')!.limitMinor, 99900);
      expect(settings2.themeMode, ThemeMode.dark);
    },
  );

  test(
    'a box written by the original app (v1 schema) opens and reads correctly',
    () async {
      // Exactly what v1 wrote: an untyped box "transactions" of plain maps
      // with double amounts.
      final legacy = await Hive.openBox(HiveService.boxName);
      await legacy.put('u1', {
        'id': 'u1',
        'amount': 249.5,
        'category': 'Food',
        'note': 'Pizza',
        'date': DateTime(2025, 8, 15, 20).toIso8601String(),
        'paymentType': 'Card',
        'isIncome': false,
        'bankAccount': 'Axis Bank - 1234',
      });
      await legacy.put('u2', {
        'id': 'u2',
        'amount': 45000.0,
        'category': 'Salary',
        'note': 'August pay',
        'date': DateTime(2025, 8, 1).toIso8601String(),
        'paymentType': 'Net Banking',
        'isIncome': true,
        'bankAccount': 'SBI - 9012',
      });

      final stores = await restart();
      final txs = TransactionProvider(stores.transactions)..load();
      expect(txs.unreadableRecords, 0);
      expect(txs.allTimeSummary.expenseMinor, 24950);
      expect(txs.allTimeSummary.incomeMinor, 4500000);
      expect(
        txs.byId('u1')!.bankAccount,
        'Axis Bank - 1234',
        reason: 'old values kept',
      );

      // Merely loading must not rewrite legacy records.
      final raw = Map<String, dynamic>.from(
        stores.transactions.get('u1') as Map,
      );
      expect(raw.containsKey('amountMinor'), isFalse);

      // Editing writes the new field while keeping the legacy one.
      await txs.save(txs.byId('u1')!.copyWith(note: 'Pizza night'));
      final edited = Map<String, dynamic>.from(
        stores.transactions.get('u1') as Map,
      );
      expect(edited['amountMinor'], 24950);
      expect(edited['amount'], 249.5);
      expect(edited['note'], 'Pizza night');

      final cats = CategoryProvider(stores.categories);
      await cats.load(usedNames: txs.usedCategories);
      expect(cats.byName('Food'), isNotNull);
      expect(cats.byName('Salary'), isNotNull);
    },
  );
}
