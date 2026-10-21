import 'dart:io';

import 'package:expense_tracker/app.dart';
import 'package:expense_tracker/services/hive_service.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hive/hive.dart';
import 'package:integration_test/integration_test.dart';

/// On-device smoke test. Run with:
///   flutter test integration_test/app_test.dart -d <device-id>
///
/// Uses a fresh temporary Hive directory, never the app's real data box.
void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  late Directory dir;

  setUp(() async {
    dir = await Directory.systemTemp.createTemp('it_');
    Hive.init(dir.path);
  });

  tearDown(() async {
    await Hive.close();
    await dir.delete(recursive: true);
  });

  testWidgets('add income and expense, verify, restart, verify', (t) async {
    var stores = await HiveService.openStores();
    await t.pumpWidget(ExpenseTrackerApp(key: UniqueKey(), stores: stores));
    await t.pumpAndSettle();
    expect(find.text('Start tracking'), findsOneWidget);

    Future<void> add(
      String amount,
      String category, {
      bool income = false,
    }) async {
      await t.tap(find.byTooltip('Add transaction'));
      await t.pumpAndSettle();
      if (income) {
        await t.tap(find.text('Income'));
        await t.pumpAndSettle();
      }
      await t.enterText(find.byKey(const Key('amountField')), amount);
      await t.ensureVisible(find.widgetWithText(ChoiceChip, category));
      await t.tap(find.widgetWithText(ChoiceChip, category));
      await t.tap(find.byKey(const Key('saveButton')));
      await t.pumpAndSettle();
    }

    await add('1000', 'Salary', income: true);
    await add('250.75', 'Food');
    expect(find.text('₹749.25'), findsWidgets);

    // Simulated restart: close and reopen the same Hive files.
    await t.pumpWidget(const SizedBox());
    await Hive.close();
    Hive.init(dir.path);
    stores = await HiveService.openStores();
    await t.pumpWidget(ExpenseTrackerApp(key: UniqueKey(), stores: stores));
    await t.pumpAndSettle();
    expect(find.text('₹749.25'), findsWidgets);
  });
}
