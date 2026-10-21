import 'package:expense_tracker/app.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'helpers.dart';

/// End-to-end user workflow on the real widget tree with isolated in-memory
/// storage. (A device version of this flow lives in integration_test/.)
void main() {
  Finder balance(String text) => find.bySemanticsLabel('Total balance $text');

  Future<void> addTransaction(
    WidgetTester t, {
    required String amount,
    required String category,
    String note = '',
    bool income = false,
  }) async {
    await t.tap(find.byTooltip('Add transaction'));
    await t.pumpAndSettle();
    if (income) {
      await t.tap(find.text('Income'));
      await t.pumpAndSettle();
    }
    await t.enterText(find.byKey(const Key('amountField')), amount);
    await tapVisible(t, find.widgetWithText(ChoiceChip, category));
    if (note.isNotEmpty) {
      await t.ensureVisible(find.byKey(const Key('noteField')));
      await t.enterText(find.byKey(const Key('noteField')), note);
    }
    await t.tap(find.byKey(const Key('saveButton')));
    await t.pumpAndSettle();
  }

  testWidgets('add, edit, delete, undo, restart, search, budget', (t) async {
    final semantics = t.ensureSemantics();
    final stores = await pumpApp(t);

    // 1. Empty state on first launch.
    expect(find.text('Start tracking'), findsOneWidget);
    expect(balance('₹0.00'), findsOneWidget);

    // 2. Add income.
    await addTransaction(
      t,
      amount: '50,000',
      category: 'Salary',
      note: 'October salary',
      income: true,
    );
    expect(find.text('Transaction added'), findsOneWidget);
    expect(balance('₹50,000.00'), findsOneWidget);

    // 3. Add expense with decimals.
    await addTransaction(
      t,
      amount: '1250.50',
      category: 'Food',
      note: 'Groceries',
    );
    expect(balance('₹48,749.50'), findsOneWidget);
    expect(
      find.bySemanticsLabel('Expenses this month ₹1,250.50'),
      findsOneWidget,
    );
    expect(
      find.bySemanticsLabel('Income this month ₹50,000.00'),
      findsOneWidget,
    );

    // 4. Edit the expense.
    await goToTab(t, 'Transactions');
    await t.tap(find.text('Groceries'));
    await t.pumpAndSettle();
    expect(find.text('Edit transaction'), findsOneWidget);
    await t.enterText(find.byKey(const Key('amountField')), '2000');
    await t.tap(find.byKey(const Key('saveButton')));
    await t.pumpAndSettle();
    expect(find.text('Transaction updated'), findsOneWidget);
    await goToTab(t, 'Overview');
    expect(balance('₹48,000.00'), findsOneWidget);
    expect(
      stores.transactions.readAll().length,
      2,
      reason: 'edit did not duplicate',
    );

    // 5. Delete with confirmation, then undo, then delete again.
    await goToTab(t, 'Transactions');
    await t.tap(find.text('Groceries'));
    await t.pumpAndSettle();
    await t.tap(find.byTooltip('Delete transaction'));
    await t.pumpAndSettle();
    expect(find.text('Delete transaction?'), findsOneWidget);
    await t.tap(find.widgetWithText(FilledButton, 'Delete'));
    await t.pumpAndSettle();
    expect(find.text('Transaction deleted'), findsOneWidget);
    await goToTab(t, 'Overview');
    expect(balance('₹50,000.00'), findsOneWidget);
    await t.tap(find.text('Undo'));
    await t.pumpAndSettle();
    expect(balance('₹48,000.00'), findsOneWidget);
    await drain(t);

    // 6. Restart: rebuild the app on the same storage.
    await t.pumpWidget(const SizedBox());
    await t.pumpWidget(ExpenseTrackerApp(key: UniqueKey(), stores: stores));
    await t.pumpAndSettle();
    expect(balance('₹48,000.00'), findsOneWidget);
    expect(find.text('October salary'), findsOneWidget);

    // 7. Search and filters.
    await goToTab(t, 'Transactions');
    await t.enterText(find.byType(TextField).first, 'salary');
    await t.pumpAndSettle();
    expect(find.text('October salary'), findsOneWidget);
    expect(find.text('Groceries'), findsNothing);
    await t.enterText(find.byType(TextField).first, 'zzz-no-match');
    await t.pumpAndSettle();
    expect(find.text('No matches'), findsOneWidget);
    await t.tap(find.widgetWithText(ActionChip, 'Clear'));
    await t.pumpAndSettle();
    await t.tap(find.widgetWithText(ChoiceChip, 'Expenses'));
    await t.pumpAndSettle();
    expect(find.text('Groceries'), findsOneWidget);
    expect(find.text('October salary'), findsNothing);

    // 8. Budget: Food limit 1,500 with 2,000 spent -> exceeded by 500.
    await goToTab(t, 'Budgets');
    expect(find.text('No budgets yet'), findsOneWidget);
    await t.tap(find.widgetWithText(FloatingActionButton, 'Add budget'));
    await t.pumpAndSettle();
    await t.tap(find.byType(DropdownButtonFormField<String>));
    await t.pumpAndSettle();
    await t.tap(find.text('Food').last);
    await t.pumpAndSettle();
    await t.enterText(
      find.widgetWithText(TextFormField, 'Monthly limit'),
      '1500',
    );
    await t.tap(find.text('Save budget'));
    await t.pumpAndSettle();
    expect(find.text('Over by ₹500.00'), findsOneWidget);

    // 9. Reports show the same totals.
    await goToTab(t, 'Reports');
    expect(find.bySemanticsLabel('Income ₹50,000.00'), findsOneWidget);
    expect(find.bySemanticsLabel('Expenses ₹2,000.00'), findsOneWidget);
    expect(find.bySemanticsLabel('Net ₹48,000.00'), findsOneWidget);

    await drain(t);
    semantics.dispose();
  });

  testWidgets('amount validation blocks bad input', (t) async {
    final stores = await pumpApp(t);
    await t.tap(find.byTooltip('Add transaction'));
    await t.pumpAndSettle();

    final save = find.byKey(const Key('saveButton'));
    await t.tap(save);
    await t.pumpAndSettle();
    expect(find.text('Enter an amount'), findsOneWidget);

    await t.enterText(find.byKey(const Key('amountField')), '0');
    await t.tap(save);
    await t.pumpAndSettle();
    expect(find.text('Amount must be greater than zero'), findsOneWidget);

    await t.enterText(find.byKey(const Key('amountField')), '1.005');
    await t.tap(save);
    await t.pumpAndSettle();
    expect(find.text('Use at most 2 decimal places'), findsOneWidget);

    await t.enterText(find.byKey(const Key('amountField')), '9999999999999');
    await t.tap(save);
    await t.pumpAndSettle();
    expect(find.text('Amount is too large'), findsOneWidget);

    // Letters and minus signs cannot even be typed.
    await t.enterText(find.byKey(const Key('amountField')), '-5abc');
    await t.pumpAndSettle();
    expect(find.widgetWithText(TextFormField, '-5abc'), findsNothing);

    expect(stores.transactions.readAll(), isEmpty);
  });

  testWidgets('rapid double tap on Save stores exactly one transaction', (
    t,
  ) async {
    final stores = await pumpApp(t);
    await t.tap(find.byTooltip('Add transaction'));
    await t.pumpAndSettle();
    await t.enterText(find.byKey(const Key('amountField')), '99');
    final save = find.byKey(const Key('saveButton'));
    await t.tap(save);
    await t.tap(save, warnIfMissed: false);
    await t.tap(save, warnIfMissed: false);
    await t.pumpAndSettle();
    expect(stores.transactions.readAll().length, 1);
    expect(
      find.text('Overview'),
      findsWidgets,
      reason: 'home route not popped',
    );
    await drain(t);
  });

  testWidgets('a storage failure keeps the form open with an error', (t) async {
    final stores = await pumpApp(t);
    (stores.transactions as dynamic).failWritesWith = Exception('disk full');
    await t.tap(find.byTooltip('Add transaction'));
    await t.pumpAndSettle();
    await t.enterText(find.byKey(const Key('amountField')), '10');
    await t.tap(find.byKey(const Key('saveButton')));
    await t.pumpAndSettle();
    expect(find.textContaining('Could not save'), findsOneWidget);
    expect(
      find.text('New transaction'),
      findsOneWidget,
      reason: 'entry not lost',
    );
    await drain(t);
  });

  testWidgets('leaving a form with changes asks before discarding', (t) async {
    await pumpApp(t);
    await t.tap(find.byTooltip('Add transaction'));
    await t.pumpAndSettle();
    await t.enterText(find.byKey(const Key('amountField')), '42');
    await t.pumpAndSettle();
    await t.pageBack();
    await t.pumpAndSettle();
    expect(find.text('Discard changes?'), findsOneWidget);
    await t.tap(find.text('Cancel'));
    await t.pumpAndSettle();
    expect(find.text('New transaction'), findsOneWidget);
    await t.pageBack();
    await t.pumpAndSettle();
    await t.tap(find.widgetWithText(FilledButton, 'Discard'));
    await t.pumpAndSettle();
    expect(find.text('Start tracking'), findsOneWidget);
  });

  testWidgets('system back on another tab returns to Overview', (t) async {
    await pumpApp(t);
    await goToTab(t, 'Reports');
    expect(find.text('Spending by category'), findsOneWidget);
    await t.binding.handlePopRoute();
    await t.pumpAndSettle();
    expect(find.text('Start tracking'), findsOneWidget);
  });
}
