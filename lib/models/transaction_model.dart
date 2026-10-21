import '../utils/money.dart';

class TransactionModel {
  static const int schemaVersion = 2;

  final String id;

  /// Exact amount in minor units (paise/cents). Always positive for records
  /// created by this version; legacy records are converted as-is on read.
  final int amountMinor;
  final String category;
  final String note;
  final DateTime date;
  final String paymentType;
  final bool isIncome;
  final String? bankAccount;
  final DateTime? createdAt;
  final DateTime? updatedAt;

  /// Fields found in storage that this version does not understand. They are
  /// written back unchanged so editing a record never drops data.
  final Map<String, dynamic> extras;

  const TransactionModel({
    required this.id,
    required this.amountMinor,
    required this.category,
    required this.note,
    required this.date,
    required this.paymentType,
    required this.isIncome,
    this.bankAccount,
    this.createdAt,
    this.updatedAt,
    this.extras = const {},
  });

  double get amount => Money.toDouble(amountMinor);

  /// Expense amounts as negative, income as positive.
  int get signedMinor => isIncome ? amountMinor : -amountMinor;

  static const _known = {
    'id',
    'amount',
    'amountMinor',
    'category',
    'note',
    'date',
    'paymentType',
    'isIncome',
    'bankAccount',
    'createdAt',
    'updatedAt',
    'schemaVersion',
  };

  Map<String, dynamic> toMap() {
    return {
      ...extras,
      'id': id,
      // Kept so that older builds of the app can still read the record.
      'amount': amount,
      'amountMinor': amountMinor,
      'category': category,
      'note': note,
      'date': date.toIso8601String(),
      'paymentType': paymentType,
      'isIncome': isIncome,
      'bankAccount': bankAccount,
      if (createdAt != null) 'createdAt': createdAt!.toIso8601String(),
      if (updatedAt != null) 'updatedAt': updatedAt!.toIso8601String(),
      'schemaVersion': schemaVersion,
    };
  }

  /// Strict-but-forgiving reader used for storage and backups.
  ///
  /// Returns null when a record cannot be interpreted without guessing at
  /// financial values (missing/invalid amount, type or date). Such records
  /// are left untouched in storage and reported to the user instead of
  /// crashing the app.
  static TransactionModel? tryFromMap(
    Map<dynamic, dynamic> map, {
    String? fallbackId,
  }) {
    final id = map['id'] is String && (map['id'] as String).isNotEmpty
        ? map['id'] as String
        : fallbackId;
    if (id == null) return null;

    int? minor;
    final rawMinor = map['amountMinor'];
    final rawAmount = map['amount'];
    if (rawMinor is int) {
      minor = rawMinor;
    } else if (rawAmount is num) {
      minor = Money.fromLegacyDouble(rawAmount);
    } else if (rawAmount is String) {
      final parsed = double.tryParse(rawAmount);
      if (parsed != null) minor = Money.fromLegacyDouble(parsed);
    }
    if (minor == null || minor.abs() > Money.maxMinor) return null;

    final rawIncome = map['isIncome'];
    final bool isIncome;
    if (rawIncome is bool) {
      isIncome = rawIncome;
    } else if (rawIncome == 'true' || rawIncome == 1) {
      isIncome = true;
    } else if (rawIncome == 'false' || rawIncome == 0) {
      isIncome = false;
    } else {
      return null;
    }

    final date = _parseDate(map['date']);
    if (date == null) return null;

    final extras = <String, dynamic>{};
    map.forEach((key, value) {
      if (key is String && !_known.contains(key)) extras[key] = value;
    });

    final category = map['category'];
    final note = map['note'] ?? map['title'];
    final payment = map['paymentType'];
    final bank = map['bankAccount'];

    return TransactionModel(
      id: id,
      amountMinor: minor,
      category: category is String && category.trim().isNotEmpty
          ? category
          : 'Other',
      note: note is String ? note : '',
      date: date,
      paymentType: payment is String && payment.isNotEmpty ? payment : 'Cash',
      isIncome: isIncome,
      bankAccount: bank is String ? bank : null,
      createdAt: _parseDate(map['createdAt']),
      updatedAt: _parseDate(map['updatedAt']),
      extras: extras,
    );
  }

  static DateTime? _parseDate(Object? value) {
    if (value is DateTime) return value;
    if (value is String) return DateTime.tryParse(value);
    return null;
  }

  TransactionModel copyWith({
    int? amountMinor,
    String? category,
    String? note,
    DateTime? date,
    String? paymentType,
    bool? isIncome,
    String? bankAccount,
    DateTime? updatedAt,
  }) {
    return TransactionModel(
      id: id,
      amountMinor: amountMinor ?? this.amountMinor,
      category: category ?? this.category,
      note: note ?? this.note,
      date: date ?? this.date,
      paymentType: paymentType ?? this.paymentType,
      isIncome: isIncome ?? this.isIncome,
      bankAccount: bankAccount ?? this.bankAccount,
      createdAt: createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      extras: extras,
    );
  }

  /// Text used by search.
  String get searchText =>
      '$note $category $paymentType ${bankAccount ?? ''}'.toLowerCase();
}
