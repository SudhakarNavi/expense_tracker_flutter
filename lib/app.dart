import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'providers/budget_provider.dart';
import 'providers/category_provider.dart';
import 'providers/settings_provider.dart';
import 'providers/transaction_provider.dart';
import 'screens/shell_screen.dart';
import 'services/hive_service.dart';
import 'theme/app_theme.dart';
import 'utils/app_constants.dart';

class ExpenseTrackerApp extends StatefulWidget {
  const ExpenseTrackerApp({super.key, required this.stores});

  final AppStores stores;

  @override
  State<ExpenseTrackerApp> createState() => _ExpenseTrackerAppState();
}

class _ExpenseTrackerAppState extends State<ExpenseTrackerApp> {
  late final TransactionProvider _transactions;
  late final CategoryProvider _categories;
  late final BudgetProvider _budgets;
  late final SettingsProvider _settings;
  late Future<void> _ready;

  @override
  void initState() {
    super.initState();
    _transactions = TransactionProvider(widget.stores.transactions);
    _categories = CategoryProvider(widget.stores.categories);
    _budgets = BudgetProvider(widget.stores.budgets);
    _settings = SettingsProvider(widget.stores.settings);
    _ready = _load();
  }

  Future<void> _load() async {
    _settings.load();
    _transactions.load();
    _budgets.load();
    await _categories.load(usedNames: _transactions.usedCategories);
  }

  @override
  void dispose() {
    _transactions.dispose();
    _categories.dispose();
    _budgets.dispose();
    _settings.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        ChangeNotifierProvider.value(value: _settings),
        ChangeNotifierProvider.value(value: _transactions),
        ChangeNotifierProvider.value(value: _categories),
        ChangeNotifierProvider.value(value: _budgets),
      ],
      child: Consumer<SettingsProvider>(
        builder: (context, settings, _) => MaterialApp(
          title: appName,
          debugShowCheckedModeBanner: false,
          theme: AppTheme.light(),
          darkTheme: AppTheme.dark(),
          themeMode: settings.themeMode,
          home: FutureBuilder<void>(
            future: _ready,
            builder: (context, snapshot) {
              if (snapshot.hasError) {
                return StartupErrorScreen(
                  onRetry: () => setState(() => _ready = _load()),
                );
              }
              if (snapshot.connectionState != ConnectionState.done) {
                return const Scaffold(
                  body: Center(child: CircularProgressIndicator()),
                );
              }
              return const ShellScreen();
            },
          ),
        ),
      ),
    );
  }
}

/// Shown when storage cannot be opened. Never deletes anything.
class StartupErrorScreen extends StatelessWidget {
  const StartupErrorScreen({super.key, required this.onRetry});

  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Icon(
                Icons.error_outline_rounded,
                size: 56,
                color: Theme.of(context).colorScheme.error,
              ),
              const SizedBox(height: 16),
              Text(
                'Could not open your data',
                textAlign: TextAlign.center,
                style: Theme.of(context).textTheme.titleLarge,
              ),
              const SizedBox(height: 8),
              const Text(
                'Nothing has been deleted. Please close and reopen the app, '
                'and make sure your device has free storage space.',
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 24),
              FilledButton(onPressed: onRetry, child: const Text('Try again')),
            ],
          ),
        ),
      ),
    );
  }
}
