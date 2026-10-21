import 'package:hive_flutter/hive_flutter.dart';

import 'key_value_store.dart';

class HiveStore implements KeyValueStore {
  HiveStore(this.box);

  final Box box;

  @override
  Map<String, dynamic> readAll() {
    final result = <String, dynamic>{};
    for (final key in box.keys) {
      result[key.toString()] = box.get(key);
    }
    return result;
  }

  @override
  dynamic get(String key) => box.get(key);

  @override
  Future<void> put(String key, Object? value) => box.put(key, value);

  @override
  Future<void> putAll(Map<String, Object?> entries) => box.putAll(entries);

  @override
  Future<void> delete(String key) => box.delete(key);

  @override
  Future<void> deleteAll(Iterable<String> keys) => box.deleteAll(keys);
}

/// All persistent stores used by the app.
class AppStores {
  final KeyValueStore transactions;
  final KeyValueStore categories;
  final KeyValueStore budgets;
  final KeyValueStore settings;

  const AppStores({
    required this.transactions,
    required this.categories,
    required this.budgets,
    required this.settings,
  });

  factory AppStores.memory() => AppStores(
    transactions: MemoryStore(),
    categories: MemoryStore(),
    budgets: MemoryStore(),
    settings: MemoryStore(),
  );
}

class HiveService {
  /// Box name used since v1 of the app; must never change or existing
  /// transactions would become invisible.
  static const String boxName = 'transactions';
  static const String categoriesBox = 'categories';
  static const String budgetsBox = 'budgets';
  static const String settingsBox = 'settings';

  static Future<AppStores> init() async {
    await Hive.initFlutter();
    return openStores();
  }

  /// Opens the boxes in an already-initialised Hive (tests call
  /// `Hive.init(tempDir)` first).
  static Future<AppStores> openStores() async {
    final boxes = await Future.wait([
      Hive.openBox(boxName),
      Hive.openBox(categoriesBox),
      Hive.openBox(budgetsBox),
      Hive.openBox(settingsBox),
    ]);
    return AppStores(
      transactions: HiveStore(boxes[0]),
      categories: HiveStore(boxes[1]),
      budgets: HiveStore(boxes[2]),
      settings: HiveStore(boxes[3]),
    );
  }
}
