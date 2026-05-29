import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../models/transaction_model.dart';
import '../providers/transaction_provider.dart';
import '../screens/add_transaction_screen.dart';
import '../screens/categories_screen.dart';
import '../screens/reports_screen.dart';
import '../utils/app_constants.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  final searchController = TextEditingController();
  DateTime? startDate;
  DateTime? endDate;
  String selectedCategory = 'All';

  @override
  Widget build(BuildContext context) {
    final provider = Provider.of<TransactionProvider>(context);
    final filtered = provider.filterTransactions(
      query: searchController.text,
      category: selectedCategory,
      startDate: startDate,
      endDate: endDate,
    );

    return Scaffold(
      appBar: AppBar(
        title: const Text('Expense Tracker'),
        actions: [
          IconButton(
            icon: const Icon(Icons.pie_chart),
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const ReportsScreen()),
              );
            },
          ),
          IconButton(
            icon: const Icon(Icons.category),
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const CategoriesScreen()),
              );
            },
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton(
        child: const Icon(Icons.add),
        onPressed: () async {
          await Navigator.push(
            context,
            MaterialPageRoute(builder: (_) => const AddTransactionScreen()),
          );
        },
      ),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            _buildDashboard(provider),
            const SizedBox(height: 16),
            _buildSearchFilters(provider),
            const SizedBox(height: 16),
            Expanded(child: _buildTransactionList(filtered, provider)),
          ],
        ),
      ),
    );
  }

  Widget _buildDashboard(TransactionProvider provider) {
    return Column(
      children: [
        Card(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              children: [
                Row(
                  children: [
                    const Expanded(
                      child: Text(
                        'Total Balance',
                        style: TextStyle(fontSize: 16),
                      ),
                    ),
                    Text(
                      '₹${provider.balance.toStringAsFixed(2)}',
                      style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    _summaryTile('Income', provider.totalIncome, Colors.green),
                    _summaryTile('Expense', provider.totalExpense, Colors.red),
                  ],
                ),
                const SizedBox(height: 16),
                _monthlySummary(provider),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _summaryTile(String title, double amount, Color color) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: color.withAlpha((0.12 * 255).round()),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Column(
          children: [
            Text(title, style: TextStyle(color: color, fontWeight: FontWeight.bold)),
            const SizedBox(height: 6),
            Text('₹${amount.toStringAsFixed(2)}', style: TextStyle(color: color)),
          ],
        ),
      ),
    );
  }

  Widget _monthlySummary(TransactionProvider provider) {
    final monthData = provider.lastSixMonthExpenses.entries.toList();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text('Monthly Summary', style: TextStyle(fontWeight: FontWeight.bold)),
        const SizedBox(height: 8),
        SizedBox(
          height: 80,
          child: ListView.builder(
            scrollDirection: Axis.horizontal,
            itemCount: monthData.length,
            itemBuilder: (context, index) {
              final entry = monthData[index];
              return Container(
                width: 100,
                margin: const EdgeInsets.only(right: 10),
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.grey.shade100,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(entry.key, style: const TextStyle(fontWeight: FontWeight.bold)),
                    const Spacer(),
                    Text('₹${entry.value.toStringAsFixed(0)}'),
                  ],
                ),
              );
            },
          ),
        ),
      ],
    );
  }

  Widget _buildSearchFilters(TransactionProvider provider) {
    return Column(
      children: [
        TextField(
          controller: searchController,
          decoration: InputDecoration(
            hintText: 'Search by note',
            prefixIcon: const Icon(Icons.search),
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
            suffixIcon: IconButton(
              icon: const Icon(Icons.clear),
              onPressed: () {
                searchController.clear();
                setState(() {});
              },
            ),
          ),
          onChanged: (_) => setState(() {}),
        ),
        const SizedBox(height: 12),
        Row(
          children: [
            Expanded(child: _buildCategoryFilter()),
            const SizedBox(width: 12),
            Expanded(child: _buildDateFilter()),
          ],
        ),
      ],
    );
  }

  Widget _buildCategoryFilter() {
    return DropdownButtonFormField<String>(
      initialValue: selectedCategory,
      decoration: const InputDecoration(labelText: 'Category'),
      items: ['All', ...defaultCategories]
          .map((value) => DropdownMenuItem(value: value, child: Text(value)))
          .toList(),
      onChanged: (value) {
        setState(() {
          selectedCategory = value!;
        });
      },
    );
  }

  Widget _buildDateFilter() {
    return Row(
      children: [
        Expanded(
          child: OutlinedButton(
            onPressed: () => _pickDateRange(isStart: true),
            child: Text(startDate == null ? 'Start date' : _formatDate(startDate!)),
          ),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: OutlinedButton(
            onPressed: () => _pickDateRange(isStart: false),
            child: Text(endDate == null ? 'End date' : _formatDate(endDate!)),
          ),
        ),
      ],
    );
  }

  Future<void> _pickDateRange({required bool isStart}) async {
    final initialDate = isStart ? startDate ?? DateTime.now() : endDate ?? DateTime.now();
    final picked = await showDatePicker(
      context: context,
      initialDate: initialDate,
      firstDate: DateTime.now().subtract(const Duration(days: 365)),
      lastDate: DateTime.now().add(const Duration(days: 365)),
    );

    if (picked != null) {
      setState(() {
        if (isStart) {
          startDate = picked;
        } else {
          endDate = picked;
        }
      });
    }
  }

  String _formatDate(DateTime date) {
    return '${date.day}/${date.month}/${date.year}';
  }

  Widget _buildTransactionList(List<TransactionModel> filtered, TransactionProvider provider) {
    if (filtered.isEmpty) {
      return const Center(child: Text('No transactions found.'));
    }

    return ListView.separated(
      itemCount: filtered.length,
      separatorBuilder: (_, __) => const Divider(),
      itemBuilder: (context, index) {
        final tx = filtered[index];
        return ListTile(
          title: Text(tx.note),
          subtitle: Text('${tx.category} • ${tx.paymentType} • ${_formatDate(tx.date)}'),
          trailing: Text(
            tx.isIncome ? '+₹${tx.amount}' : '-₹${tx.amount}',
            style: TextStyle(color: tx.isIncome ? Colors.green : Colors.red),
          ),
          onLongPress: () => _confirmDelete(context, tx.id, provider),
        );
      },
    );
  }

  void _confirmDelete(BuildContext context, String id, TransactionProvider provider) {
    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text('Delete transaction'),
          content: const Text('Are you sure you want to delete this transaction?'),
          actions: [
            TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel')),
            TextButton(
              onPressed: () {
                provider.deleteTransaction(id);
                Navigator.pop(context);
              },
              child: const Text('Delete'),
            ),
          ],
        );
      },
    );
  }
}
