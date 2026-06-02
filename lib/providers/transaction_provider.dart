import 'package:flutter/material.dart';

import '../models/transaction_model.dart';
import '../services/hive_service.dart';

class TransactionProvider extends ChangeNotifier {
  List<TransactionModel> transactions = [];

  void loadTransactions() {
    final box = HiveService.getBox();

    transactions = box.values
        .map((e) => TransactionModel.fromMap(Map<String, dynamic>.from(e)))
        .toList();

    notifyListeners();
  }

  void addTransaction(TransactionModel transaction) {
    final box = HiveService.getBox();

    box.put(transaction.id, transaction.toMap());
    transactions.add(transaction);

    notifyListeners();
  }

  void deleteTransaction(String id) {
    final box = HiveService.getBox();
    box.delete(id);
    transactions.removeWhere((element) => element.id == id);
    notifyListeners();
  }

  double get totalIncome {
    return transactions
        .where((e) => e.isIncome)
        .fold(0.0, (sum, item) => sum + item.amount);
  }

  double get totalExpense {
    return transactions
        .where((e) => !e.isIncome)
        .fold(0.0, (sum, item) => sum + item.amount);
  }

  double get balance => totalIncome - totalExpense;

  List<TransactionModel> get recentTransactions {
    final sorted = [...transactions];
    sorted.sort((a, b) => b.date.compareTo(a.date));
    return sorted.take(5).toList();
  }

  Map<String, double> get categoryTotals {
    final totals = <String, double>{};
    for (final tx in transactions.where((e) => !e.isIncome)) {
      totals[tx.category] = (totals[tx.category] ?? 0) + tx.amount;
    }
    return totals;
  }

  Map<String, double> get lastSixMonthExpenses {
    final now = DateTime.now();
    final result = <String, double>{};
    for (int offset = 5; offset >= 0; offset--) {
      final month = DateTime(now.year, now.month - offset, 1);
      final key = '${month.month}/${month.year}';
      final sum = transactions
          .where((tx) => !tx.isIncome && tx.date.year == month.year && tx.date.month == month.month)
          .fold(0.0, (value, element) => value + element.amount);
      result[key] = sum;
    }
    return result;
  }

  Map<String, double> get weeklyExpenseTrend {
    final now = DateTime.now();
    final result = <String, double>{};
    for (int i = 6; i >= 0; i--) {
      final day = now.subtract(Duration(days: i));
      final key = '${day.month}/${day.day}';
      final sum = transactions
          .where((tx) => !tx.isIncome && tx.date.year == day.year && tx.date.month == day.month && tx.date.day == day.day)
          .fold(0.0, (value, element) => value + element.amount);
      result[key] = sum;
    }
    return result;
  }

  List<TransactionModel> filterTransactions({
    String? query,
    String? category,
    DateTime? startDate,
    DateTime? endDate,
  }) {
    final list = transactions.where((tx) {
      final matchesQuery = query == null || query.isEmpty || tx.note.toLowerCase().contains(query.toLowerCase());
      final matchesCategory = category == null || category == 'All' || tx.category == category;
      final matchesStart = startDate == null || !tx.date.isBefore(startDate);
      final matchesEnd = endDate == null || !tx.date.isAfter(endDate);
      return matchesQuery && matchesCategory && matchesStart && matchesEnd;
    }).toList();

    // Ensure ascending order by date (oldest first)
    list.sort((a, b) => a.date.compareTo(b.date));
    return list;
  }
}
