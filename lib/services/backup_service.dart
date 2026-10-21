import 'dart:convert';

import '../models/budget_model.dart';
import '../models/category_model.dart';
import '../models/transaction_model.dart';
import '../providers/budget_provider.dart';
import '../providers/category_provider.dart';
import '../providers/transaction_provider.dart';

class BackupFormatException implements Exception {
  final String message;
  BackupFormatException(this.message);
  @override
  String toString() => message;
}

class BackupData {
  final List<TransactionModel> transactions;
  final List<CategoryModel> categories;
  final List<BudgetModel> budgets;
  final int unreadableTransactions;
  final DateTime? exportedAt;

  const BackupData({
    required this.transactions,
    required this.categories,
    required this.budgets,
    required this.unreadableTransactions,
    this.exportedAt,
  });
}

class ImportResult {
  final int added;
  final int skippedExisting;
  final int unreadable;
  final int categoriesAdded;
  final int budgetsAdded;

  const ImportResult({
    required this.added,
    required this.skippedExisting,
    required this.unreadable,
    required this.categoriesAdded,
    required this.budgetsAdded,
  });

  String get summary {
    final parts = <String>[
      '$added transaction${added == 1 ? '' : 's'} restored',
    ];
    if (skippedExisting > 0) parts.add('$skippedExisting already present');
    if (unreadable > 0) parts.add('$unreadable unreadable skipped');
    if (categoriesAdded > 0) parts.add('$categoriesAdded categories added');
    if (budgetsAdded > 0) parts.add('$budgetsAdded budgets added');
    return parts.join(' · ');
  }
}

/// JSON backup. Restoring only *adds* data: records whose id already exists
/// on the device are kept as they are, and nothing is ever deleted.
class BackupService {
  BackupService._();

  static const String formatId = 'expense_tracker_backup';
  static const int formatVersion = 1;

  /// Hard cap to avoid freezing the UI on a wrong, huge file.
  static const int maxBytes = 50 * 1024 * 1024;

  static String encode({
    required Iterable<TransactionModel> transactions,
    required Iterable<CategoryModel> categories,
    required Iterable<BudgetModel> budgets,
    Map<String, dynamic> settings = const {},
    DateTime? now,
  }) {
    final data = {
      'format': formatId,
      'version': formatVersion,
      'exportedAt': (now ?? DateTime.now()).toIso8601String(),
      'settings': settings,
      'categories': [for (final c in categories) c.toMap()],
      'budgets': [for (final b in budgets) b.toMap()],
      'transactions': [for (final t in transactions) t.toMap()],
    };
    return const JsonEncoder.withIndent('  ').convert(data);
  }

  static BackupData decode(String text) {
    final Object? root;
    try {
      root = jsonDecode(text);
    } on FormatException {
      throw BackupFormatException(
        'This file is not a valid backup (not JSON).',
      );
    }
    if (root is! Map || root['format'] != formatId) {
      throw BackupFormatException(
        'This file is not an Expense Tracker backup.',
      );
    }
    final version = root['version'];
    if (version is! int || version > formatVersion) {
      throw BackupFormatException(
        'This backup was made by a newer version of the app. Please update the app first.',
      );
    }

    final txs = <TransactionModel>[];
    var unreadable = 0;
    final rawTxs = root['transactions'];
    if (rawTxs is! List) {
      throw BackupFormatException('Backup has no transaction list.');
    }
    for (final raw in rawTxs) {
      final tx = raw is Map ? TransactionModel.tryFromMap(raw) : null;
      if (tx == null) {
        unreadable++;
      } else {
        txs.add(tx);
      }
    }

    final cats = <CategoryModel>[];
    final rawCats = root['categories'];
    if (rawCats is List) {
      for (final raw in rawCats) {
        final c = raw is Map ? CategoryModel.tryFromMap(raw) : null;
        if (c != null) cats.add(c);
      }
    }

    final budgets = <BudgetModel>[];
    final rawBudgets = root['budgets'];
    if (rawBudgets is List) {
      for (final raw in rawBudgets) {
        final b = raw is Map ? BudgetModel.tryFromMap(raw) : null;
        if (b != null) budgets.add(b);
      }
    }

    final exportedAt = root['exportedAt'];
    return BackupData(
      transactions: txs,
      categories: cats,
      budgets: budgets,
      unreadableTransactions: unreadable,
      exportedAt: exportedAt is String ? DateTime.tryParse(exportedAt) : null,
    );
  }

  static Future<ImportResult> importInto(
    BackupData data, {
    required TransactionProvider transactions,
    required CategoryProvider categories,
    required BudgetProvider budgets,
  }) async {
    final existingIds = {for (final t in transactions.transactions) t.id};
    final seen = <String>{};
    final toAdd = <TransactionModel>[];
    var skipped = 0;
    for (final tx in data.transactions) {
      if (existingIds.contains(tx.id) || !seen.add(tx.id)) {
        skipped++;
      } else {
        toAdd.add(tx);
      }
    }

    final before = categories.categories.length;
    await categories.mergeFrom(data.categories);
    // Make sure every imported transaction has a matching category.
    final missing = {
      for (final tx in toAdd)
        if (categories.byName(tx.category) == null) tx.category,
    };
    if (missing.isNotEmpty) {
      await categories.load(usedNames: missing);
    }
    final categoriesAdded = categories.categories.length - before;

    await transactions.saveAll(toAdd);
    final budgetsAdded = await budgets.mergeFrom(data.budgets);

    return ImportResult(
      added: toAdd.length,
      skippedExisting: skipped,
      unreadable: data.unreadableTransactions,
      categoriesAdded: categoriesAdded,
      budgetsAdded: budgetsAdded,
    );
  }
}
