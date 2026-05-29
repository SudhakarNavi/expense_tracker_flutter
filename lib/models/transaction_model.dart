class TransactionModel {
  final String id;
  final double amount;
  final String category;
  final String note;
  final DateTime date;
  final String paymentType;
  final bool isIncome;

  TransactionModel({
    required this.id,
    required this.amount,
    required this.category,
    required this.note,
    required this.date,
    required this.paymentType,
    required this.isIncome,
  });

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'amount': amount,
      'category': category,
      'note': note,
      'date': date.toIso8601String(),
      'paymentType': paymentType,
      'isIncome': isIncome,
    };
  }

  factory TransactionModel.fromMap(Map map) {
    return TransactionModel(
      id: map['id'],
      amount: map['amount'],
      category: map['category'],
      note: map['note'] ?? map['title'] ?? '',
      date: DateTime.parse(map['date']),
      paymentType: map['paymentType'] ?? 'Cash',
      isIncome: map['isIncome'],
    );
  }
}
