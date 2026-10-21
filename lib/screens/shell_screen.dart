import 'package:flutter/material.dart';

import 'budgets_screen.dart';
import 'dashboard_screen.dart';
import 'reports_screen.dart';
import 'transaction_form_screen.dart';
import 'transactions_screen.dart';

class ShellScreen extends StatefulWidget {
  const ShellScreen({super.key});

  @override
  State<ShellScreen> createState() => _ShellScreenState();
}

class _ShellScreenState extends State<ShellScreen> {
  int _index = 0;

  void _go(int index) => setState(() => _index = index);

  @override
  Widget build(BuildContext context) {
    final pages = [
      DashboardScreen(onNavigate: _go),
      const TransactionsScreen(),
      const ReportsScreen(),
      const BudgetsScreen(),
    ];
    final showAdd = _index <= 1;

    return PopScope(
      // Back from another tab returns to Overview before leaving the app.
      canPop: _index == 0,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) _go(0);
      },
      child: Scaffold(
        body: IndexedStack(index: _index, children: pages),
        // Removed (not just hidden) on other tabs so screen readers do not
        // announce it; Scaffold animates the change.
        floatingActionButton: showAdd
            ? FloatingActionButton.extended(
                heroTag: 'addTransaction',
                tooltip: 'Add transaction',
                onPressed: () => openTransactionForm(context),
                icon: const Icon(Icons.add_rounded),
                label: const Text('Add'),
              )
            : null,
        bottomNavigationBar: NavigationBar(
          selectedIndex: _index,
          onDestinationSelected: _go,
          destinations: const [
            NavigationDestination(
              icon: Icon(Icons.dashboard_outlined),
              selectedIcon: Icon(Icons.dashboard_rounded),
              label: 'Overview',
            ),
            NavigationDestination(
              icon: Icon(Icons.receipt_long_outlined),
              selectedIcon: Icon(Icons.receipt_long_rounded),
              label: 'Transactions',
            ),
            NavigationDestination(
              icon: Icon(Icons.insights_outlined),
              selectedIcon: Icon(Icons.insights_rounded),
              label: 'Reports',
            ),
            NavigationDestination(
              icon: Icon(Icons.savings_outlined),
              selectedIcon: Icon(Icons.savings_rounded),
              label: 'Budgets',
            ),
          ],
        ),
      ),
    );
  }
}
