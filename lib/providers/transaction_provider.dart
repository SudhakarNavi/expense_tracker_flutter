import 'dart:collection';

import 'package:flutter/foundation.dart';

import '../models/transaction_model.dart';
import '../services/finance_calculator.dart';
import '../services/key_value_store.dart';
import '../utils/date_utils.dart';

enum TypeFilter { all, income, expense }

class TransactionProvider extends ChangeNotifier {
  TransactionProvider(this._store);

  final KeyValueStore _store;

  List<TransactionModel> _items = [];
  int _unreadableRecords = 0;

  /// Newest first.
  UnmodifiableListView<TransactionModel> get transactions =>
      UnmodifiableListView(_items);

  /// Records found in storage that could not be interpreted. They are left
  /// untouched (never deleted) and surfaced in Settings.
  int get unreadableRecords => _unreadableRecords;

  void load() {
    final items = <TransactionModel>[];
    var unreadable = 0;
    _store.readAll().forEach((key, value) {
      final tx = value is Map
          ? TransactionModel.tryFromMap(value, fallbackId: key)
          : null;
      if (tx == null) {
        unreadable++;
      } else {
        items.add(tx);
      }
    });
    _items = items;
    _unreadableRecords = unreadable;
    _sort();
    notifyListeners();
  }

  void _sort() {
    _items.sort((a, b) {
      final byDate = b.date.compareTo(a.date);
      if (byDate != 0) return byDate;
      final ac = a.createdAt, bc = b.createdAt;
      if (ac != null && bc != null) return bc.compareTo(ac);
      return a.id.compareTo(b.id);
    });
  }

  TransactionModel? byId(String id) {
    for (final tx in _items) {
      if (tx.id == id) return tx;
    }
    return null;
  }

  /// Adds or replaces a transaction. Memory is updated only after the write
  /// succeeds; errors propagate to the caller.
  Future<void> save(TransactionModel tx) async {
    await _store.put(tx.id, tx.toMap());
    final index = _items.indexWhere((e) => e.id == tx.id);
    if (index >= 0) {
      _items[index] = tx;
    } else {
      _items.add(tx);
    }
    _sort();
    notifyListeners();
  }

  /// Deletes one transaction and returns it (for undo).
  Future<TransactionModel?> delete(String id) async {
    final existing = byId(id);
    if (existing == null) return null;
    await _store.delete(id);
    _items.removeWhere((e) => e.id == id);
    notifyListeners();
    return existing;
  }

  Future<void> saveAll(Iterable<TransactionModel> txs) async {
    final list = txs.toList();
    if (list.isEmpty) return;
    await _store.putAll({for (final tx in list) tx.id: tx.toMap()});
    final byId = {for (final tx in _items) tx.id: tx};
    for (final tx in list) {
      byId[tx.id] = tx;
    }
    _items = byId.values.toList();
    _sort();
    notifyListeners();
  }

  /// Removes every readable transaction. Unreadable records are kept.
  Future<void> deleteAll() async {
    await _store.deleteAll(_items.map((e) => e.id));
    _items = [];
    notifyListeners();
  }

  int countForCategory(String category) =>
      _items.where((e) => e.category == category).length;

  /// Moves every transaction in [from] to [to] (used by category rename and
  /// delete, both of which the user confirms first).
  Future<int> moveCategory(String from, String to) async {
    final affected = _items.where((e) => e.category == from).toList();
    if (affected.isEmpty) return 0;
    final now = DateTime.now();
    await saveAll(
      affected.map((e) => e.copyWith(category: to, updatedAt: now)),
    );
    return affected.length;
  }

  Set<String> get usedCategories => {for (final tx in _items) tx.category};

  // ---- Derived figures (all delegate to FinanceCalculator) ----

  int get balanceMinor => FinanceCalculator.balance(_items);

  FinanceSummary get allTimeSummary => FinanceCalculator.summarize(_items);

  FinanceSummary summaryFor(DateRange range) =>
      FinanceCalculator.summarizeRange(_items, range);

  List<TransactionModel> recent([int count = 5]) => _items.take(count).toList();

  List<TransactionModel> filter({
    String query = '',
    TypeFilter type = TypeFilter.all,
    String? category,
    DateRange? range,
  }) {
    final q = query.trim().toLowerCase();
    return _items.where((tx) {
      if (type == TypeFilter.income && !tx.isIncome) return false;
      if (type == TypeFilter.expense && tx.isIncome) return false;
      if (category != null && tx.category != category) return false;
      if (range != null && !range.contains(tx.date)) return false;
      if (q.isNotEmpty) {
        final amountText = (tx.amountMinor / 100).toStringAsFixed(2);
        if (!tx.searchText.contains(q) && !amountText.contains(q)) {
          return false;
        }
      }
      return true;
    }).toList();
  }
}
