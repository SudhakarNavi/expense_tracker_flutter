import 'package:flutter/foundation.dart';

import '../models/budget_model.dart';
import '../services/key_value_store.dart';

class BudgetProvider extends ChangeNotifier {
  BudgetProvider(this._store);

  final KeyValueStore _store;
  Map<String, BudgetModel> _budgets = {};

  BudgetModel? get overall => _budgets[BudgetModel.overallKey];

  /// Category budgets sorted by name.
  List<BudgetModel> get categoryBudgets {
    final list = _budgets.values.where((b) => !b.isOverall).toList()
      ..sort(
        (a, b) => a.category.toLowerCase().compareTo(b.category.toLowerCase()),
      );
    return list;
  }

  List<BudgetModel> get all => _budgets.values.toList();

  bool get isEmpty => _budgets.isEmpty;

  BudgetModel? forCategory(String category) => _budgets[category];

  void load() {
    final map = <String, BudgetModel>{};
    _store.readAll().forEach((key, value) {
      final b = value is Map ? BudgetModel.tryFromMap(value) : null;
      if (b != null) map[b.category] = b;
    });
    _budgets = map;
    notifyListeners();
  }

  Future<void> setBudget(String category, int limitMinor) async {
    if (limitMinor <= 0) {
      throw ArgumentError.value(limitMinor, 'limitMinor', 'must be positive');
    }
    final b = BudgetModel(category: category, limitMinor: limitMinor);
    await _store.put(category, b.toMap());
    _budgets[category] = b;
    notifyListeners();
  }

  Future<void> remove(String category) async {
    if (!_budgets.containsKey(category)) return;
    await _store.delete(category);
    _budgets.remove(category);
    notifyListeners();
  }

  /// Follows a category rename. If the target already has a budget, the
  /// existing target budget is kept and the old one removed.
  Future<void> renameCategory(String from, String to) async {
    final b = _budgets[from];
    if (b == null || from == to) return;
    if (!_budgets.containsKey(to)) {
      await setBudget(to, b.limitMinor);
    }
    await remove(from);
  }

  Future<void> deleteAll() async {
    await _store.deleteAll(_budgets.keys.toList());
    _budgets = {};
    notifyListeners();
  }

  /// Adds budgets from a backup for categories that have none yet.
  Future<int> mergeFrom(Iterable<BudgetModel> incoming) async {
    var added = 0;
    for (final b in incoming) {
      if (_budgets.containsKey(b.category)) continue;
      await setBudget(b.category, b.limitMinor);
      added++;
    }
    return added;
  }
}
