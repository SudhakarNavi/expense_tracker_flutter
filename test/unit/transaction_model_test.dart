import 'package:expense_tracker/models/transaction_model.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('reading records written by the original app (v1)', () {
    test('double amount and all original fields', () {
      final tx = TransactionModel.tryFromMap({
        'id': 'a1',
        'amount': 149.99,
        'category': 'Food',
        'note': 'Dinner',
        'date': '2025-06-30T21:15:00.000',
        'paymentType': 'UPI',
        'isIncome': false,
        'bankAccount': 'HDFC - 5678',
      })!;
      expect(tx.amountMinor, 14999);
      expect(tx.category, 'Food');
      expect(tx.note, 'Dinner');
      expect(tx.date, DateTime(2025, 6, 30, 21, 15));
      expect(tx.paymentType, 'UPI');
      expect(tx.isIncome, isFalse);
      expect(tx.bankAccount, 'HDFC - 5678');
    });

    test('older "title" field is used as the note', () {
      final tx = TransactionModel.tryFromMap({
        'id': 'a2',
        'amount': 10.0,
        'category': 'Travel',
        'title': 'Bus',
        'date': '2024-01-01T00:00:00.000',
        'isIncome': false,
      })!;
      expect(tx.note, 'Bus');
      expect(tx.paymentType, 'Cash');
    });

    test('integer amount (crashed the original app) is accepted', () {
      final tx = TransactionModel.tryFromMap({
        'id': 'a3',
        'amount': 3,
        'category': 'Food',
        'date': '2026-01-01',
        'isIncome': false,
      })!;
      expect(tx.amountMinor, 300);
    });

    test('missing id falls back to the storage key', () {
      final tx = TransactionModel.tryFromMap({
        'amount': 1.0,
        'category': 'Food',
        'date': '2026-01-01',
        'isIncome': true,
      }, fallbackId: 'key-1')!;
      expect(tx.id, 'key-1');
    });
  });

  test('records that cannot be read safely are rejected, not guessed', () {
    Map<String, dynamic> base() => {
      'id': 'x',
      'amount': 5.0,
      'category': 'Food',
      'date': '2026-01-01',
      'isIncome': false,
    };
    expect(TransactionModel.tryFromMap(base()), isNotNull);
    expect(TransactionModel.tryFromMap(base()..remove('isIncome')), isNull);
    expect(TransactionModel.tryFromMap(base()..remove('amount')), isNull);
    expect(
      TransactionModel.tryFromMap(base()..['amount'] = double.nan),
      isNull,
    );
    expect(
      TransactionModel.tryFromMap(base()..['date'] = 'not a date'),
      isNull,
    );
    expect(TransactionModel.tryFromMap(base()..remove('id')), isNull);
  });

  test('round trip preserves values and unknown fields', () {
    final original = TransactionModel.tryFromMap({
      'id': 'r1',
      'amount': 12.5,
      'category': 'Bills',
      'note': 'Power',
      'date': '2026-02-28T09:00:00.000',
      'paymentType': 'Card',
      'isIncome': false,
      'bankAccount': 'Cash',
      'futureField': 'keep me',
    })!;
    final map = original.toMap();
    expect(map['futureField'], 'keep me');
    expect(map['amountMinor'], 1250);
    expect(map['amount'], 12.5, reason: 'kept for older app versions');

    final again = TransactionModel.tryFromMap(map)!;
    expect(again.amountMinor, 1250);
    expect(again.date, original.date);
    expect(again.extras['futureField'], 'keep me');
  });

  test('amountMinor takes precedence over the legacy double', () {
    final tx = TransactionModel.tryFromMap({
      'id': 'p',
      'amount': 0.30000000000000004,
      'amountMinor': 30,
      'category': 'Food',
      'date': '2026-01-01',
      'isIncome': true,
    })!;
    expect(tx.amountMinor, 30);
  });

  test('search text covers note, category, payment and account', () {
    final tx = TransactionModel(
      id: 's',
      amountMinor: 100,
      category: 'Food',
      note: 'Coffee',
      date: DateTime(2026),
      paymentType: 'UPI',
      isIncome: false,
      bankAccount: 'Wallet',
    );
    for (final q in ['coffee', 'food', 'upi', 'wallet']) {
      expect(tx.searchText.contains(q), isTrue, reason: q);
    }
  });
}
