/// A recurring monthly spending limit, either for one expense category or
/// for all expenses ([overallKey]).
class BudgetModel {
  static const String overallKey = '__overall__';

  /// Category name, or [overallKey].
  final String category;
  final int limitMinor;

  const BudgetModel({required this.category, required this.limitMinor});

  bool get isOverall => category == overallKey;

  Map<String, dynamic> toMap() => {
    'category': category,
    'limitMinor': limitMinor,
  };

  static BudgetModel? tryFromMap(Map<dynamic, dynamic> map) {
    final category = map['category'];
    final limit = map['limitMinor'];
    if (category is! String || category.isEmpty) return null;
    if (limit is! int || limit <= 0) return null;
    return BudgetModel(category: category, limitMinor: limit);
  }
}
