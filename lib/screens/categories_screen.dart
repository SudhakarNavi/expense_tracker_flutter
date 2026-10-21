import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../models/category_model.dart';
import '../providers/budget_provider.dart';
import '../providers/category_provider.dart';
import '../providers/transaction_provider.dart';
import '../services/category_actions.dart';
import '../utils/app_constants.dart';
import '../widgets/common.dart';

class CategoriesScreen extends StatefulWidget {
  const CategoriesScreen({super.key});

  @override
  State<CategoriesScreen> createState() => _CategoriesScreenState();
}

class _CategoriesScreenState extends State<CategoriesScreen> {
  bool _income = false;

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<CategoryProvider>();
    final txs = context.watch<TransactionProvider>();
    final list = provider.forType(isIncome: _income);

    return Scaffold(
      appBar: AppBar(title: const Text('Categories')),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _openEditor(context, defaultIncome: _income),
        icon: const Icon(Icons.add_rounded),
        label: const Text('New category'),
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 4, 16, 96),
        children: [
          SegmentedButton<bool>(
            segments: const [
              ButtonSegment(value: false, label: Text('Expense')),
              ButtonSegment(value: true, label: Text('Income')),
            ],
            selected: {_income},
            showSelectedIcon: false,
            onSelectionChanged: (s) => setState(() => _income = s.first),
          ),
          const SizedBox(height: 12),
          Card(
            clipBehavior: Clip.antiAlias,
            child: Column(
              children: [
                for (final c in list)
                  ListTile(
                    leading: CategoryAvatar(c.name, size: 40),
                    title: Text(c.name),
                    subtitle: Text(
                      '${txs.countForCategory(c.name)} transactions'
                      '${c.type == CategoryType.both ? ' · income & expense' : ''}',
                    ),
                    trailing: provider.isProtected(c)
                        ? Tooltip(
                            message: 'Built-in category',
                            child: Icon(
                              Icons.lock_outline_rounded,
                              size: 18,
                              color: Theme.of(
                                context,
                              ).colorScheme.onSurfaceVariant,
                            ),
                          )
                        : const Icon(Icons.chevron_right_rounded),
                    onTap: () => _openEditor(context, existing: c),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  void _openEditor(
    BuildContext context, {
    CategoryModel? existing,
    bool defaultIncome = false,
  }) {
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (_) =>
          _CategoryEditor(existing: existing, defaultIncome: defaultIncome),
    );
  }
}

class _CategoryEditor extends StatefulWidget {
  const _CategoryEditor({this.existing, required this.defaultIncome});
  final CategoryModel? existing;
  final bool defaultIncome;

  @override
  State<_CategoryEditor> createState() => _CategoryEditorState();
}

class _CategoryEditorState extends State<_CategoryEditor> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _name = TextEditingController(
    text: widget.existing?.name ?? '',
  );
  late CategoryType _type =
      widget.existing?.type ??
      (widget.defaultIncome ? CategoryType.income : CategoryType.expense);
  late String _icon = widget.existing?.iconKey ?? 'category';
  late int _color = widget.existing?.colorValue ?? categoryColors.first;
  bool _saving = false;

  bool get _isEdit => widget.existing != null;

  @override
  void dispose() {
    _name.dispose();
    super.dispose();
  }

  CategoryActions _actions() => CategoryActions(
    context.read<CategoryProvider>(),
    context.read<TransactionProvider>(),
    context.read<BudgetProvider>(),
  );

  Future<void> _save() async {
    if (_saving || !_formKey.currentState!.validate()) return;
    final provider = context.read<CategoryProvider>();
    final txs = context.read<TransactionProvider>();
    final original = widget.existing;
    final newName = _name.text.trim();

    if (original != null && original.name != newName) {
      final count = txs.countForCategory(original.name);
      if (count > 0) {
        final ok = await confirmAction(
          context,
          title: 'Rename category?',
          message:
              '$count transaction${count == 1 ? '' : 's'} will move from '
              '"${original.name}" to "$newName".',
          confirmLabel: 'Rename',
          destructive: false,
        );
        if (!ok || !mounted) return;
      }
    }

    setState(() => _saving = true);
    try {
      if (original == null) {
        await provider.add(
          name: newName,
          type: _type,
          iconKey: _icon,
          colorValue: _color,
        );
      } else {
        await _actions().save(
          original,
          original.copyWith(
            name: newName,
            type: _type,
            iconKey: _icon,
            colorValue: _color,
          ),
        );
      }
      if (!mounted) return;
      Navigator.pop(context);
      showMessage(context, _isEdit ? 'Category updated' : 'Category added');
    } on CategoryValidationException catch (e) {
      if (!mounted) return;
      setState(() => _saving = false);
      showMessage(context, e.message, error: true);
    } catch (_) {
      if (!mounted) return;
      setState(() => _saving = false);
      showMessage(context, 'Could not save the category.', error: true);
    }
  }

  Future<void> _delete() async {
    final c = widget.existing!;
    final count = context.read<TransactionProvider>().countForCategory(c.name);
    final ok = await confirmAction(
      context,
      title: 'Delete "${c.name}"?',
      message: count == 0
          ? 'No transactions use this category.'
          : '$count transaction${count == 1 ? '' : 's'} will be moved to "$otherCategory". '
                'Any budget for this category will be removed. Nothing else is deleted.',
      confirmLabel: 'Delete',
    );
    if (!ok || !mounted) return;
    setState(() => _saving = true);
    try {
      final moved = await _actions().delete(c);
      if (!mounted) return;
      Navigator.pop(context);
      showMessage(
        context,
        moved == 0
            ? 'Category deleted'
            : 'Category deleted · $moved moved to $otherCategory',
      );
    } catch (_) {
      if (!mounted) return;
      setState(() => _saving = false);
      showMessage(context, 'Could not delete the category.', error: true);
    }
  }

  @override
  Widget build(BuildContext context) {
    final provider = context.read<CategoryProvider>();
    final protected =
        widget.existing != null && provider.isProtected(widget.existing!);
    final scheme = Theme.of(context).colorScheme;

    return Padding(
      padding: EdgeInsets.only(bottom: MediaQuery.viewInsetsOf(context).bottom),
      child: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                _isEdit ? 'Edit category' : 'New category',
                style: Theme.of(context).textTheme.titleLarge,
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _name,
                enabled: !protected,
                autofocus: !_isEdit,
                textCapitalization: TextCapitalization.words,
                maxLength: CategoryProvider.maxNameLength,
                decoration: InputDecoration(
                  labelText: 'Name',
                  helperText: protected
                      ? '"Other" is built in and cannot be renamed'
                      : null,
                ),
                validator: (v) => provider.validateName(
                  v ?? '',
                  excludingId: widget.existing?.id,
                ),
              ),
              const SizedBox(height: 8),
              SegmentedButton<CategoryType>(
                segments: const [
                  ButtonSegment(
                    value: CategoryType.expense,
                    label: Text('Expense'),
                  ),
                  ButtonSegment(
                    value: CategoryType.income,
                    label: Text('Income'),
                  ),
                  ButtonSegment(value: CategoryType.both, label: Text('Both')),
                ],
                selected: {_type},
                showSelectedIcon: false,
                onSelectionChanged: protected
                    ? null
                    : (s) => setState(() => _type = s.first),
              ),
              const SizedBox(height: 20),
              Text('Icon', style: Theme.of(context).textTheme.labelLarge),
              const SizedBox(height: 8),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  for (final e in categoryIcons.entries)
                    Semantics(
                      label: '${e.key} icon',
                      selected: _icon == e.key,
                      button: true,
                      child: InkWell(
                        borderRadius: BorderRadius.circular(12),
                        onTap: () => setState(() => _icon = e.key),
                        child: Container(
                          width: 48,
                          height: 48,
                          decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(12),
                            color: _icon == e.key
                                ? Color(_color).withValues(alpha: 0.18)
                                : scheme.surfaceContainerHighest,
                            border: _icon == e.key
                                ? Border.all(color: Color(_color), width: 2)
                                : null,
                          ),
                          child: Icon(
                            e.value,
                            color: _icon == e.key
                                ? Color(_color)
                                : scheme.onSurfaceVariant,
                          ),
                        ),
                      ),
                    ),
                ],
              ),
              const SizedBox(height: 20),
              Text('Color', style: Theme.of(context).textTheme.labelLarge),
              const SizedBox(height: 8),
              Wrap(
                spacing: 10,
                runSpacing: 10,
                children: [
                  for (final c in categoryColors)
                    Semantics(
                      label: 'Color option',
                      selected: _color == c,
                      button: true,
                      child: InkWell(
                        customBorder: const CircleBorder(),
                        onTap: () => setState(() => _color = c),
                        child: Container(
                          width: 44,
                          height: 44,
                          decoration: BoxDecoration(
                            color: Color(c),
                            shape: BoxShape.circle,
                            border: Border.all(
                              color: _color == c
                                  ? scheme.onSurface
                                  : Colors.transparent,
                              width: 3,
                            ),
                          ),
                          child: _color == c
                              ? const Icon(
                                  Icons.check_rounded,
                                  color: Colors.white,
                                )
                              : null,
                        ),
                      ),
                    ),
                ],
              ),
              const SizedBox(height: 24),
              FilledButton(
                onPressed: _saving ? null : _save,
                child: Text(_isEdit ? 'Save changes' : 'Add category'),
              ),
              if (_isEdit && !protected) ...[
                const SizedBox(height: 8),
                TextButton.icon(
                  onPressed: _saving ? null : _delete,
                  icon: const Icon(Icons.delete_outline_rounded),
                  label: const Text('Delete category'),
                  style: TextButton.styleFrom(foregroundColor: scheme.error),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}
