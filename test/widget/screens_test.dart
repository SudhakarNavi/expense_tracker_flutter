import 'package:expense_tracker/models/budget_model.dart';
import 'package:expense_tracker/services/hive_service.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'helpers.dart';

const tabs = ['Overview', 'Transactions', 'Reports', 'Budgets'];

Future<AppStores> richData() async {
  final stores = AppStores.memory();
  final now = DateTime.now();
  await seed(stores, [
    sampleTx(
      's',
      8500000,
      income: true,
      category: 'Salary',
      note: 'Salary credited with a very long description that must ellipsize',
    ),
    for (var i = 0; i < 40; i++)
      sampleTx(
        'e$i',
        12345 * (i + 1),
        category: ['Food', 'Bills', 'Travel', 'Shopping', 'Health'][i % 5],
        note: 'Expense number $i',
        date: DateTime(now.year, now.month, (i % 28) + 1),
      ),
    sampleTx(
      'old',
      999999999999,
      category: 'Rent',
      date: DateTime(now.year - 1, 3, 1),
    ),
  ]);
  await stores.budgets.put(
    BudgetModel.overallKey,
    const BudgetModel(
      category: BudgetModel.overallKey,
      limitMinor: 1000000,
    ).toMap(),
  );
  await stores.budgets.put(
    'Food',
    const BudgetModel(category: 'Food', limitMinor: 50000000).toMap(),
  );
  return stores;
}

void main() {
  testWidgets('every tab renders with no data and without errors', (t) async {
    await pumpApp(t);
    for (final tab in tabs) {
      await goToTab(t, tab);
      expect(t.takeException(), isNull, reason: tab);
    }
    // Reports with no data used to fail with NaN bar widths.
    await goToTab(t, 'Reports');
    expect(find.text('No expenses in this period'), findsOneWidget);
    await goToTab(t, 'Budgets');
    expect(find.text('No budgets yet'), findsOneWidget);
    await goToTab(t, 'Transactions');
    expect(find.text('No transactions yet'), findsOneWidget);
  });

  testWidgets('reports year mode and period navigation with data', (t) async {
    await pumpApp(t, stores: await richData());
    await goToTab(t, 'Reports');
    await t.tap(find.byTooltip('Previous month'));
    await t.pumpAndSettle();
    await t.tap(find.text('Year'));
    await t.pumpAndSettle();
    expect(find.text('Monthly overview'), findsOneWidget);
    await t.tap(find.byTooltip('Previous year'));
    await t.pumpAndSettle();
    expect(find.textContaining('Rent', findRichText: true), findsWidgets);
  });

  for (final size in const [Size(320, 568), Size(360, 640), Size(800, 1280)]) {
    for (final scale in const [1.0, 1.5, 2.0]) {
      testWidgets(
        'no overflow at ${size.width.toInt()}x${size.height.toInt()} text ×$scale',
        (t) async {
          await pumpApp(
            t,
            stores: await richData(),
            size: size,
            textScale: scale,
          );
          for (final tab in tabs) {
            await goToTab(t, tab);
            await t.drag(find.byType(Scrollable).first, const Offset(0, -2000));
            await t.pumpAndSettle();
          }
          await goToTab(t, 'Overview');
          await t.tap(find.byTooltip('Add transaction'));
          await t.pumpAndSettle();
          await t.drag(find.byType(Scrollable).first, const Offset(0, -2000));
          await t.pumpAndSettle();
          await t.pageBack();
          await t.pumpAndSettle();
          await t.tap(find.byTooltip('Settings'));
          await t.pumpAndSettle();
          await t.drag(find.byType(Scrollable).first, const Offset(0, -2000));
          await t.pumpAndSettle();
          expect(t.takeException(), isNull);
        },
      );
    }
  }

  testWidgets('dark theme setting applies and persists', (t) async {
    final stores = await pumpApp(t, stores: await richData());
    await t.tap(find.byTooltip('Settings'));
    await t.pumpAndSettle();
    await t.tap(find.text('Dark'));
    await t.pumpAndSettle();
    final app = t.widget<MaterialApp>(find.byType(MaterialApp));
    expect(app.themeMode, ThemeMode.dark);
    expect(
      Theme.of(t.element(find.text('Settings').first)).brightness,
      Brightness.dark,
    );
    expect(stores.settings.get('themeMode'), 'dark');
  });

  testWidgets('currency change updates displayed amounts', (t) async {
    final semantics = t.ensureSemantics();
    final stores = AppStores.memory();
    await seed(stores, [
      sampleTx('a', 123456, income: true, category: 'Salary'),
    ]);
    await pumpApp(t, stores: stores);
    expect(find.bySemanticsLabel('Total balance ₹1,234.56'), findsOneWidget);
    await t.tap(find.byTooltip('Settings'));
    await t.pumpAndSettle();
    await t.tap(find.text('Currency'));
    await t.pumpAndSettle();
    await t.tap(find.textContaining('US Dollar'));
    await t.pumpAndSettle();
    await t.pageBack();
    await t.pumpAndSettle();
    expect(find.bySemanticsLabel(r'Total balance $1,234.56'), findsOneWidget);
    semantics.dispose();
  });

  testWidgets('unreadable stored records are reported, not hidden', (t) async {
    final stores = AppStores.memory();
    await stores.transactions.put('broken', {'id': 'broken', 'amount': 'x'});
    await pumpApp(t, stores: stores);
    await t.tap(find.byTooltip('Settings'));
    await t.pumpAndSettle();
    expect(find.textContaining('could not be read'), findsOneWidget);
    expect(stores.transactions.get('broken'), isNotNull);
  });

  testWidgets('erase all requires typing DELETE', (t) async {
    final stores = await richData();
    await pumpApp(t, stores: stores);
    await t.tap(find.byTooltip('Settings'));
    await t.pumpAndSettle();
    await tapVisible(t, find.text('Erase all transactions & budgets'));
    final erase = find.widgetWithText(FilledButton, 'Erase');
    expect(t.widget<FilledButton>(erase).onPressed, isNull);
    await t.enterText(find.byType(TextField).last, 'delete');
    await t.pump();
    expect(
      t.widget<FilledButton>(erase).onPressed,
      isNull,
      reason: 'case-sensitive',
    );
    await t.tap(find.text('Cancel'));
    await t.pumpAndSettle();
    expect(stores.transactions.readAll().length, 42);

    await tapVisible(t, find.text('Erase all transactions & budgets'));
    await t.enterText(find.byType(TextField).last, 'DELETE');
    await t.pump();
    await t.tap(find.widgetWithText(FilledButton, 'Erase'));
    await t.pumpAndSettle();
    expect(stores.transactions.readAll(), isEmpty);
    expect(stores.budgets.readAll(), isEmpty);
    expect(stores.categories.readAll(), isNotEmpty, reason: 'categories kept');
    await drain(t);
  });

  testWidgets('add, rename and delete a category', (t) async {
    final stores = AppStores.memory();
    await seed(stores, [sampleTx('a', 100, category: 'Food', note: 'Snack')]);
    await pumpApp(t, stores: stores);
    await t.tap(find.byTooltip('Settings'));
    await t.pumpAndSettle();
    await t.tap(find.text('Categories'));
    await t.pumpAndSettle();

    // Duplicate names are rejected.
    await t.tap(find.text('New category'));
    await t.pumpAndSettle();
    await t.enterText(find.widgetWithText(TextFormField, 'Name'), 'food');
    await tapVisible(t, find.text('Add category'));
    expect(
      find.text('A category with this name already exists'),
      findsOneWidget,
    );
    await t.enterText(find.widgetWithText(TextFormField, 'Name'), 'Pets');
    await tapVisible(t, find.text('Add category'));
    expect(find.text('Pets'), findsOneWidget);

    // Rename Food -> Dining moves its transaction.
    await tapVisible(t, find.text('Food'));
    await t.enterText(find.widgetWithText(TextFormField, 'Name'), 'Dining');
    await tapVisible(t, find.text('Save changes'));
    expect(find.text('Rename category?'), findsOneWidget);
    await t.tap(find.text('Rename'));
    await t.pumpAndSettle();
    expect((stores.transactions.get('a') as Map)['category'], 'Dining');

    // Delete Dining -> transaction moves to Other.
    await tapVisible(t, find.text('Dining'));
    await tapVisible(t, find.text('Delete category'));
    await t.tap(find.widgetWithText(FilledButton, 'Delete'));
    await t.pumpAndSettle();
    expect((stores.transactions.get('a') as Map)['category'], 'Other');
    expect(stores.transactions.readAll().length, 1);
    await drain(t);
  });
}
