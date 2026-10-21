enum CategoryType { expense, income, both }

class CategoryModel {
  final String id;
  final String name;
  final CategoryType type;
  final String iconKey;
  final int colorValue;

  const CategoryModel({
    required this.id,
    required this.name,
    required this.type,
    required this.iconKey,
    required this.colorValue,
  });

  bool appliesTo({required bool isIncome}) =>
      type == CategoryType.both ||
      (isIncome ? type == CategoryType.income : type == CategoryType.expense);

  Map<String, dynamic> toMap() => {
    'id': id,
    'name': name,
    'type': type.name,
    'iconKey': iconKey,
    'colorValue': colorValue,
  };

  static CategoryModel? tryFromMap(Map<dynamic, dynamic> map) {
    final id = map['id'];
    final name = map['name'];
    if (id is! String || name is! String || name.trim().isEmpty) return null;
    final type = CategoryType.values.firstWhere(
      (t) => t.name == map['type'],
      orElse: () => CategoryType.both,
    );
    final icon = map['iconKey'];
    final color = map['colorValue'];
    return CategoryModel(
      id: id,
      name: name.trim(),
      type: type,
      iconKey: icon is String ? icon : 'category',
      colorValue: color is int ? color : 0xFF64748B,
    );
  }

  CategoryModel copyWith({
    String? name,
    CategoryType? type,
    String? iconKey,
    int? colorValue,
  }) => CategoryModel(
    id: id,
    name: name ?? this.name,
    type: type ?? this.type,
    iconKey: iconKey ?? this.iconKey,
    colorValue: colorValue ?? this.colorValue,
  );
}

/// Seeded on first launch. The first eight names match the categories that
/// earlier versions of the app hard-coded, so existing records keep matching.
const List<CategoryModel> defaultCategoryModels = [
  CategoryModel(
    id: 'food',
    name: 'Food',
    type: CategoryType.expense,
    iconKey: 'restaurant',
    colorValue: 0xFFEA580C,
  ),
  CategoryModel(
    id: 'travel',
    name: 'Travel',
    type: CategoryType.expense,
    iconKey: 'flight',
    colorValue: 0xFF2563EB,
  ),
  CategoryModel(
    id: 'shopping',
    name: 'Shopping',
    type: CategoryType.expense,
    iconKey: 'shopping',
    colorValue: 0xFFDB2777,
  ),
  CategoryModel(
    id: 'bills',
    name: 'Bills',
    type: CategoryType.expense,
    iconKey: 'receipt',
    colorValue: 0xFF4F46E5,
  ),
  CategoryModel(
    id: 'entertainment',
    name: 'Entertainment',
    type: CategoryType.expense,
    iconKey: 'movie',
    colorValue: 0xFF9333EA,
  ),
  CategoryModel(
    id: 'health',
    name: 'Health',
    type: CategoryType.expense,
    iconKey: 'health',
    colorValue: 0xFFDC2626,
  ),
  CategoryModel(
    id: 'salary',
    name: 'Salary',
    type: CategoryType.income,
    iconKey: 'payments',
    colorValue: 0xFF16A34A,
  ),
  CategoryModel(
    id: 'other',
    name: 'Other',
    type: CategoryType.both,
    iconKey: 'category',
    colorValue: 0xFF64748B,
  ),
  CategoryModel(
    id: 'rent',
    name: 'Rent',
    type: CategoryType.expense,
    iconKey: 'home',
    colorValue: 0xFF0891B2,
  ),
  CategoryModel(
    id: 'education',
    name: 'Education',
    type: CategoryType.expense,
    iconKey: 'school',
    colorValue: 0xFFCA8A04,
  ),
  CategoryModel(
    id: 'freelance',
    name: 'Freelance',
    type: CategoryType.income,
    iconKey: 'work',
    colorValue: 0xFF0F766E,
  ),
  CategoryModel(
    id: 'interest',
    name: 'Interest',
    type: CategoryType.income,
    iconKey: 'savings',
    colorValue: 0xFF7C3AED,
  ),
];
