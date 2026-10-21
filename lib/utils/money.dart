/// Money helpers.
///
/// All amounts are handled as integers in minor units (paise, cents) so that
/// sums never pick up floating-point drift. Every supported currency uses two
/// decimal places.

enum DigitGrouping { western, indian }

class Currency {
  final String code;
  final String symbol;
  final String name;
  final DigitGrouping grouping;

  const Currency(this.code, this.symbol, this.name, this.grouping);
}

const List<Currency> supportedCurrencies = [
  Currency('INR', '₹', 'Indian Rupee', DigitGrouping.indian),
  Currency('USD', r'$', 'US Dollar', DigitGrouping.western),
  Currency('EUR', '€', 'Euro', DigitGrouping.western),
  Currency('GBP', '£', 'British Pound', DigitGrouping.western),
  Currency('AED', 'AED ', 'UAE Dirham', DigitGrouping.western),
  Currency('SGD', r'S$', 'Singapore Dollar', DigitGrouping.western),
  Currency('AUD', r'A$', 'Australian Dollar', DigitGrouping.western),
  Currency('CAD', r'C$', 'Canadian Dollar', DigitGrouping.western),
];

Currency currencyForCode(String? code) {
  return supportedCurrencies.firstWhere(
    (c) => c.code == code,
    orElse: () => supportedCurrencies.first,
  );
}

enum AmountError { empty, invalid, tooManyDecimals, notPositive, tooLarge }

class AmountParseResult {
  final int? minor;
  final AmountError? error;

  const AmountParseResult.ok(int this.minor) : error = null;
  const AmountParseResult.fail(AmountError this.error) : minor = null;

  bool get isValid => minor != null;

  String? get message {
    switch (error) {
      case null:
        return null;
      case AmountError.empty:
        return 'Enter an amount';
      case AmountError.invalid:
        return 'Enter a valid number, e.g. 250 or 99.50';
      case AmountError.tooManyDecimals:
        return 'Use at most 2 decimal places';
      case AmountError.notPositive:
        return 'Amount must be greater than zero';
      case AmountError.tooLarge:
        return 'Amount is too large';
    }
  }
}

class Money {
  Money._();

  /// 999,999,999,999.99 — far above any personal transaction and well inside
  /// the range where doubles (used for the legacy `amount` field) are exact
  /// to the paisa.
  static const int maxMinor = 99999999999999;

  static final RegExp _plain = RegExp(r'^\d+(\.\d+)?$');

  /// Parses user input into minor units.
  ///
  /// Accepts grouping commas/spaces ("1,25,000.50", "1 000") and a single
  /// decimal comma when there is no dot and it is followed by 1–2 digits
  /// ("12,5"). Rejects signs, exponents, NaN/Infinity and zero.
  static AmountParseResult parse(String input) {
    var text = input.trim().replaceAll(RegExp(r'[\s ]'), '');
    if (text.isEmpty) return const AmountParseResult.fail(AmountError.empty);

    if (!text.contains('.') && RegExp(r'^\d+,\d{1,2}$').hasMatch(text)) {
      text = text.replaceFirst(',', '.');
    } else {
      text = text.replaceAll(',', '');
    }

    if (!_plain.hasMatch(text)) {
      return const AmountParseResult.fail(AmountError.invalid);
    }

    final parts = text.split('.');
    final whole = parts[0].replaceFirst(RegExp(r'^0+(?=\d)'), '');
    final fraction = parts.length > 1 ? parts[1] : '';
    if (fraction.length > 2) {
      return const AmountParseResult.fail(AmountError.tooManyDecimals);
    }
    // Longest valid whole part is 12 digits; checking length first avoids
    // integer overflow on absurd input.
    if (whole.length > 12) {
      return const AmountParseResult.fail(AmountError.tooLarge);
    }

    final minor = int.parse(whole) * 100 + int.parse(fraction.padRight(2, '0'));
    if (minor <= 0) {
      return const AmountParseResult.fail(AmountError.notPositive);
    }
    if (minor > maxMinor) {
      return const AmountParseResult.fail(AmountError.tooLarge);
    }
    return AmountParseResult.ok(minor);
  }

  /// Converts a legacy floating-point amount (as stored by v1 of the app) to
  /// minor units. Returns null for NaN/Infinity.
  static int? fromLegacyDouble(num value) {
    if (value is int) return value * 100;
    final d = value.toDouble();
    if (!d.isFinite || d.abs() > maxMinor / 100) return null;
    return (d * 100).round();
  }

  static double toDouble(int minor) => minor / 100;

  /// Plain editable representation, e.g. 12550 -> "125.5", 1000 -> "10".
  static String toInput(int minor) {
    final whole = minor ~/ 100;
    final cents = minor.abs() % 100;
    if (cents == 0) return '$whole';
    final frac = cents
        .toString()
        .padLeft(2, '0')
        .replaceFirst(RegExp(r'0$'), '');
    return '$whole.$frac';
  }

  /// Full formatting: "₹1,23,456.78", "-$1,234.00".
  /// With [signed], positive values get a leading "+".
  static String format(int minor, Currency currency, {bool signed = false}) {
    final negative = minor < 0;
    final abs = minor.abs();
    final whole = _group((abs ~/ 100).toString(), currency.grouping);
    final cents = (abs % 100).toString().padLeft(2, '0');
    final sign = negative ? '-' : (signed && minor > 0 ? '+' : '');
    return '$sign${currency.symbol}$whole.$cents';
  }

  /// Short form for chart axes and tight spaces: "₹1.2L", "$3.4K", "₹950".
  static String compact(int minor, Currency currency) {
    final negative = minor < 0;
    final value = minor.abs() / 100;
    String body;
    if (currency.grouping == DigitGrouping.indian) {
      if (value >= 1e7) {
        body = '${_trim(value / 1e7)}Cr';
      } else if (value >= 1e5) {
        body = '${_trim(value / 1e5)}L';
      } else if (value >= 1e3) {
        body = '${_trim(value / 1e3)}K';
      } else {
        body = value.round().toString();
      }
    } else {
      if (value >= 1e9) {
        body = '${_trim(value / 1e9)}B';
      } else if (value >= 1e6) {
        body = '${_trim(value / 1e6)}M';
      } else if (value >= 1e3) {
        body = '${_trim(value / 1e3)}K';
      } else {
        body = value.round().toString();
      }
    }
    return '${negative ? '-' : ''}${currency.symbol}$body';
  }

  static String _trim(double v) {
    final s = v.toStringAsFixed(v >= 100 ? 0 : 1);
    return s.endsWith('.0') ? s.substring(0, s.length - 2) : s;
  }

  static String _group(String digits, DigitGrouping grouping) {
    if (digits.length <= 3) return digits;
    final last3 = digits.substring(digits.length - 3);
    var rest = digits.substring(0, digits.length - 3);
    final groupSize = grouping == DigitGrouping.indian ? 2 : 3;
    final groups = <String>[];
    while (rest.length > groupSize) {
      groups.insert(0, rest.substring(rest.length - groupSize));
      rest = rest.substring(0, rest.length - groupSize);
    }
    if (rest.isNotEmpty) groups.insert(0, rest);
    return '${groups.join(',')},$last3';
  }
}
