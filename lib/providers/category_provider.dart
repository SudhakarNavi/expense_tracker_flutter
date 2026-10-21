import 'package:flutter/foundation.dart';
import 'package:uuid/uuid.dart';

import '../models/category_model.dart';
import '../services/key_value_store.dart';
import '../utils/app_constants.dart';

class CategoryValidationException implements Exception {
  final String message;
  CategoryValidationException(this.message);
  @override
  String toString() => message;
}

class CategoryProvider extends ChangeNotifier {
  CategoryProvider(this._store);

  final KeyValueStore _store;
  List<CategoryModel> _items = [];

  static const int maxNameLength = 30;

  List<CategoryModel> get categories => List.unmodifiable(_items);

  /// Loads categories, seeding defaults on first run and adding any
  /// category names that only exist on stored transactions so nothing
  /// becomes orphaned.
  Future<void> load({Set<String> usedNames = const {}}) async {
    final items = <CategoryModel>[];
    _store.readAll().forEach((key, value) {
      final c = value is Map ? CategoryModel.tryFromMap(value) : null;
      if (c != null) items.add(c);
    });

    final toWrite = <CategoryModel>[];
    if (items.isEmpty) {
      toWrite.addAll(defaultCategoryModels);
      items.addAll(defaultCategoryModels);
    }
    if (!items.any((c) => _same(c.name, otherCategory))) {
      final other = defaultCategoryModels.firstWhere((c) => c.id == 'other');
      toWrite.add(other);
      items.add(other);
    }
    var colorIndex = 0;
    for (final name in usedNames) {
      if (!items.any((c) => c.name == name)) {
        final c = CategoryModel(
          id: const Uuid().v4(),
          name: name,
          type: CategoryType.both,
          iconKey: 'category',
          colorValue: categoryColors[colorIndex++ % categoryColors.length],
        );
        toWrite.add(c);
        items.add(c);
      }
    }
    if (toWrite.isNotEmpty) {
      await _store.putAll({for (final c in toWrite) c.id: c.toMap()});
    }
    _items = items;
    _sort();
    notifyListeners();
  }

  void _sort() {
    _items.sort((a, b) {
      // "Other" always last.
      if (_same(a.name, otherCategory)) return 1;
      if (_same(b.name, otherCategory)) return -1;
      return a.name.toLowerCase().compareTo(b.name.toLowerCase());
    });
  }

  static bool _same(String a, String b) =>
      a.trim().toLowerCase() == b.trim().toLowerCase();

  bool isProtected(CategoryModel c) => _same(c.name, otherCategory);

  CategoryModel? byName(String name) {
    for (final c in _items) {
      if (c.name == name) return c;
    }
    return null;
  }

  List<CategoryModel> forType({required bool isIncome}) =>
      _items.where((c) => c.appliesTo(isIncome: isIncome)).toList();

  /// Returns an error message, or null when [name] is acceptable.
  String? validateName(String name, {String? excludingId}) {
    final trimmed = name.trim();
    if (trimmed.isEmpty) return 'Enter a name';
    if (trimmed.length > maxNameLength) {
      return 'Use at most $maxNameLength characters';
    }
    final clash = _items.any(
      (c) => c.id != excludingId && _same(c.name, trimmed),
    );
    if (clash) return 'A category with this name already exists';
    return null;
  }

  Future<CategoryModel> add({
    required String name,
    required CategoryType type,
    required String iconKey,
    required int colorValue,
  }) async {
    final error = validateName(name);
    if (error != null) throw CategoryValidationException(error);
    final c = CategoryModel(
      id: const Uuid().v4(),
      name: name.trim(),
      type: type,
      iconKey: iconKey,
      colorValue: colorValue,
    );
    await _store.put(c.id, c.toMap());
    _items.add(c);
    _sort();
    notifyListeners();
    return c;
  }

  /// Saves edits. Renaming is coordinated by the caller (transactions and
  /// budgets reference categories by name).
  Future<void> update(CategoryModel updated) async {
    final error = validateName(updated.name, excludingId: updated.id);
    if (error != null) throw CategoryValidationException(error);
    final existing = _items.firstWhere((c) => c.id == updated.id);
    if (isProtected(existing) && !_same(updated.name, otherCategory)) {
      throw CategoryValidationException('"Other" cannot be renamed');
    }
    final clean = updated.copyWith(name: updated.name.trim());
    await _store.put(clean.id, clean.toMap());
    _items[_items.indexWhere((c) => c.id == clean.id)] = clean;
    _sort();
    notifyListeners();
  }

  Future<void> delete(CategoryModel c) async {
    if (isProtected(c)) {
      throw CategoryValidationException('"Other" cannot be deleted');
    }
    await _store.delete(c.id);
    _items.removeWhere((e) => e.id == c.id);
    notifyListeners();
  }

  /// Adds categories from a backup that do not exist yet (matched by name).
  Future<int> mergeFrom(Iterable<CategoryModel> incoming) async {
    final toAdd = <CategoryModel>[];
    for (final c in incoming) {
      final exists =
          _items.any((e) => _same(e.name, c.name)) ||
          toAdd.any((e) => _same(e.name, c.name));
      if (!exists) {
        final id = _items.any((e) => e.id == c.id) ? const Uuid().v4() : c.id;
        toAdd.add(
          CategoryModel(
            id: id,
            name: c.name,
            type: c.type,
            iconKey: c.iconKey,
            colorValue: c.colorValue,
          ),
        );
      }
    }
    if (toAdd.isEmpty) return 0;
    await _store.putAll({for (final c in toAdd) c.id: c.toMap()});
    _items.addAll(toAdd);
    _sort();
    notifyListeners();
    return toAdd.length;
  }
}
