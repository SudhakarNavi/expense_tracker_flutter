import 'package:expense_tracker/app.dart';
import 'package:expense_tracker/models/transaction_model.dart';
import 'package:expense_tracker/services/hive_service.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

/// Pumps the full app on isolated in-memory stores (never real data).
Future<AppStores> pumpApp(
  WidgetTester t, {
  AppStores? stores,
  Size size = const Size(412, 892),
  double textScale = 1.0,
}) async {
  t.view.physicalSize = size;
  t.view.devicePixelRatio = 1.0;
  t.platformDispatcher.textScaleFactorTestValue = textScale;
  addTearDown(t.view.reset);
  addTearDown(t.platformDispatcher.clearTextScaleFactorTestValue);
  final s = stores ?? AppStores.memory();
  await t.pumpWidget(ExpenseTrackerApp(key: UniqueKey(), stores: s));
  await t.pumpAndSettle();
  return s;
}

Future<void> seed(AppStores stores, List<TransactionModel> txs) async {
  for (final tx in txs) {
    await stores.transactions.put(tx.id, tx.toMap());
  }
}

TransactionModel sampleTx(
  String id,
  int minor, {
  bool income = false,
  String category = 'Food',
  String note = '',
  DateTime? date,
}) => TransactionModel(
  id: id,
  amountMinor: minor,
  category: category,
  note: note,
  date: date ?? DateTime.now(),
  paymentType: 'Cash',
  isIncome: income,
);

Finder navItem(String label) =>
    find.descendant(of: find.byType(NavigationBar), matching: find.text(label));

Future<void> goToTab(WidgetTester t, String label) async {
  await t.tap(navItem(label));
  await t.pumpAndSettle();
}

/// Lets snackbar timers run out so no timers are pending at test end.
Future<void> drain(WidgetTester t) async {
  await t.pump(const Duration(seconds: 10));
  await t.pumpAndSettle();
}

Future<void> tapVisible(WidgetTester t, Finder f) async {
  await t.ensureVisible(f);
  await t.pumpAndSettle();
  await t.tap(f);
  await t.pumpAndSettle();
}
