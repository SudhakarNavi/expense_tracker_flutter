import 'package:flutter/material.dart';

import '../services/key_value_store.dart';
import '../utils/money.dart';

class SettingsProvider extends ChangeNotifier {
  SettingsProvider(this._store);

  final KeyValueStore _store;

  static const _themeKey = 'themeMode';
  static const _currencyKey = 'currencyCode';

  ThemeMode _themeMode = ThemeMode.system;
  Currency _currency = supportedCurrencies.first;

  ThemeMode get themeMode => _themeMode;
  Currency get currency => _currency;

  void load() {
    final theme = _store.get(_themeKey);
    _themeMode = ThemeMode.values.firstWhere(
      (m) => m.name == theme,
      orElse: () => ThemeMode.system,
    );
    _currency = currencyForCode(_store.get(_currencyKey) as String?);
    notifyListeners();
  }

  Future<void> setThemeMode(ThemeMode mode) async {
    await _store.put(_themeKey, mode.name);
    _themeMode = mode;
    notifyListeners();
  }

  Future<void> setCurrency(Currency currency) async {
    await _store.put(_currencyKey, currency.code);
    _currency = currency;
    notifyListeners();
  }

  Map<String, dynamic> toBackup() => {
    _themeKey: _themeMode.name,
    _currencyKey: _currency.code,
  };

  String format(int minor, {bool signed = false}) =>
      Money.format(minor, _currency, signed: signed);

  String compact(int minor) => Money.compact(minor, _currency);
}
