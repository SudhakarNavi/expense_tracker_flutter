import '../models/category_model.dart';
import '../providers/budget_provider.dart';
import '../providers/category_provider.dart';
import '../providers/transaction_provider.dart';
import '../utils/app_constants.dart';

/// Category changes that must stay consistent across transactions and
/// budgets, which reference categories by name.
class CategoryActions {
  CategoryActions(this.categories, this.transactions, this.budgets);

  final CategoryProvider categories;
  final TransactionProvider transactions;
  final BudgetProvider budgets;

  /// Saves [updated]; if the name changed, moves its transactions and budget
  /// to the new name. Returns the number of transactions updated.
  Future<int> save(CategoryModel original, CategoryModel updated) async {
    await categories.update(updated);
    final newName = updated.name.trim();
    if (original.name == newName) return 0;
    final moved = await transactions.moveCategory(original.name, newName);
    await budgets.renameCategory(original.name, newName);
    return moved;
  }

  /// Deletes [category], moving its transactions to "Other" and removing
  /// its budget. Returns the number of transactions moved.
  Future<int> delete(CategoryModel category) async {
    final moved = await transactions.moveCategory(category.name, otherCategory);
    await budgets.remove(category.name);
    await categories.delete(category);
    return moved;
  }
}
