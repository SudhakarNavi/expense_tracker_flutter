import 'package:expense_tracker/utils/money.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  final inr = currencyForCode('INR');
  final usd = currencyForCode('USD');

  group('Money.parse', () {
    test('accepts integers and up to two decimals', () {
      expect(Money.parse('250').minor, 25000);
      expect(Money.parse('99.5').minor, 9950);
      expect(Money.parse('99.50').minor, 9950);
      expect(Money.parse('0.01').minor, 1);
      expect(Money.parse('.5').isValid, isFalse);
      expect(Money.parse('007').minor, 700);
    });

    test('accepts grouping separators and spaces', () {
      expect(Money.parse('1,25,000.75').minor, 12500075);
      expect(Money.parse('1,000').minor, 100000);
      expect(Money.parse(' 1 000 ').minor, 100000);
    });

    test('treats a lone comma followed by 1-2 digits as decimal comma', () {
      expect(Money.parse('12,5').minor, 1250);
      expect(Money.parse('12,50').minor, 1250);
    });

    test('rejects empty, zero, negative, NaN, Infinity, exponents', () {
      expect(Money.parse('').error, AmountError.empty);
      expect(Money.parse('   ').error, AmountError.empty);
      expect(Money.parse('0').error, AmountError.notPositive);
      expect(Money.parse('0.00').error, AmountError.notPositive);
      expect(Money.parse('-50').error, AmountError.invalid);
      expect(Money.parse('NaN').error, AmountError.invalid);
      expect(Money.parse('Infinity').error, AmountError.invalid);
      expect(Money.parse('1e5').error, AmountError.invalid);
      expect(Money.parse('12.3.4').error, AmountError.invalid);
      expect(Money.parse('abc').error, AmountError.invalid);
    });

    test('rejects more than two decimals', () {
      expect(Money.parse('1.005').error, AmountError.tooManyDecimals);
    });

    test('enforces the maximum amount', () {
      expect(Money.parse('999999999999.99').minor, Money.maxMinor);
      expect(Money.parse('1000000000000').error, AmountError.tooLarge);
      expect(
        Money.parse('99999999999999999999999').error,
        AmountError.tooLarge,
      );
    });

    test('every error has a user-facing message', () {
      for (final e in AmountError.values) {
        expect(AmountParseResult.fail(e).message, isNotEmpty);
      }
    });
  });

  group('Money.format', () {
    test('Indian grouping for INR', () {
      expect(Money.format(0, inr), '₹0.00');
      expect(Money.format(5, inr), '₹0.05');
      expect(Money.format(99999, inr), '₹999.99');
      expect(Money.format(100000, inr), '₹1,000.00');
      expect(Money.format(12345678, inr), '₹1,23,456.78');
      expect(Money.format(Money.maxMinor, inr), '₹9,99,99,99,99,999.99');
    });

    test('Western grouping for USD', () {
      expect(Money.format(12345678, usd), r'$123,456.78');
      expect(Money.format(100000000, usd), r'$1,000,000.00');
    });

    test('signs', () {
      expect(Money.format(-2550, inr), '-₹25.50');
      expect(Money.format(2550, inr, signed: true), '+₹25.50');
      expect(Money.format(0, inr, signed: true), '₹0.00');
    });

    test('compact', () {
      expect(Money.compact(95000, inr), '₹950');
      expect(Money.compact(1250000, inr), '₹12.5K');
      expect(Money.compact(15000000, inr), '₹1.5L');
      expect(Money.compact(2500000000, inr), '₹2.5Cr');
      expect(Money.compact(250000000, usd), r'$2.5M');
    });
  });

  group('conversions', () {
    test('legacy doubles convert to the nearest minor unit', () {
      expect(Money.fromLegacyDouble(12.5), 1250);
      expect(Money.fromLegacyDouble(0.1 + 0.2), 30);
      expect(Money.fromLegacyDouble(19.99), 1999);
      expect(Money.fromLegacyDouble(100), 10000);
      expect(Money.fromLegacyDouble(double.nan), isNull);
      expect(Money.fromLegacyDouble(double.infinity), isNull);
    });

    test('toInput round-trips through parse', () {
      for (final minor in [1, 10, 100, 1250, 1205, 999999, Money.maxMinor]) {
        expect(Money.parse(Money.toInput(minor)).minor, minor);
      }
      expect(Money.toInput(1250), '12.5');
      expect(Money.toInput(1000), '10');
    });

    test('integer sums do not drift', () {
      var total = 0;
      for (var i = 0; i < 3; i++) {
        total += Money.parse('0.1').minor!;
      }
      expect(total, 30);
      expect(Money.format(total, inr), '₹0.30');
    });
  });
}
