/// Minimal persistence interface used by the providers.
///
/// Production code uses [HiveStore]; widget tests use [MemoryStore] so they
/// never touch the file system or real user data.
abstract class KeyValueStore {
  /// Snapshot of every stored entry, keyed by its string key.
  Map<String, dynamic> readAll();

  dynamic get(String key);

  Future<void> put(String key, Object? value);

  Future<void> putAll(Map<String, Object?> entries);

  Future<void> delete(String key);

  Future<void> deleteAll(Iterable<String> keys);
}

class MemoryStore implements KeyValueStore {
  MemoryStore([Map<String, dynamic>? initial]) : _data = {...?initial};

  final Map<String, dynamic> _data;

  /// When set, every write throws this error (used to test failure paths).
  Object? failWritesWith;

  void _check() {
    if (failWritesWith != null) throw failWritesWith!;
  }

  @override
  Map<String, dynamic> readAll() => Map.of(_data);

  @override
  dynamic get(String key) => _data[key];

  @override
  Future<void> put(String key, Object? value) async {
    _check();
    _data[key] = value;
  }

  @override
  Future<void> putAll(Map<String, Object?> entries) async {
    _check();
    _data.addAll(entries);
  }

  @override
  Future<void> delete(String key) async {
    _check();
    _data.remove(key);
  }

  @override
  Future<void> deleteAll(Iterable<String> keys) async {
    _check();
    for (final k in keys.toList()) {
      _data.remove(k);
    }
  }
}
