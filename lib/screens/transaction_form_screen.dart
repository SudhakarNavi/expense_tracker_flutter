import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:uuid/uuid.dart';

import '../models/transaction_model.dart';
import '../providers/category_provider.dart';
import '../providers/settings_provider.dart';
import '../providers/transaction_provider.dart';
import '../theme/app_theme.dart';
import '../utils/app_constants.dart';
import '../utils/date_utils.dart';
import '../utils/money.dart';
import '../widgets/common.dart';
import '../widgets/transaction_tile.dart';

Future<void> openTransactionForm(
  BuildContext context, {
  TransactionModel? existing,
  bool isIncome = false,
}) {
  return Navigator.of(context).push(
    MaterialPageRoute(
      builder: (_) =>
          TransactionFormScreen(existing: existing, initialIsIncome: isIncome),
    ),
  );
}

class TransactionFormScreen extends StatefulWidget {
  const TransactionFormScreen({
    super.key,
    this.existing,
    this.initialIsIncome = false,
  });

  final TransactionModel? existing;
  final bool initialIsIncome;

  @override
  State<TransactionFormScreen> createState() => _TransactionFormScreenState();
}

class _TransactionFormScreenState extends State<TransactionFormScreen> {
  static const int maxNoteLength = 120;

  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _amount;
  late final TextEditingController _note;
  late bool _isIncome;
  late String _category;
  late DateTime _date;
  late String _paymentType;
  late String _account;
  bool _saving = false;
  bool _dirty = false;
  late final String _initialAmount;
  late final String _initialNote;

  bool get _isEdit => widget.existing != null;

  @override
  void initState() {
    super.initState();
    final e = widget.existing;
    _amount = TextEditingController(
      text: e == null ? '' : Money.toInput(e.amountMinor),
    );
    _note = TextEditingController(text: e?.note ?? '');
    _isIncome = e?.isIncome ?? widget.initialIsIncome;
    _date = e?.date ?? DateTime.now();
    _paymentType = e?.paymentType ?? paymentTypes.first;
    _account = e?.bankAccount ?? bankAccounts.first;
    _category = e?.category ?? '';
    _initialAmount = _amount.text;
    _initialNote = _note.text;
    _amount.addListener(_onTextChanged);
    _note.addListener(_onTextChanged);
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_category.isEmpty) {
      final options = context.read<CategoryProvider>().forType(
        isIncome: _isIncome,
      );
      _category = options.isNotEmpty ? options.first.name : otherCategory;
    }
  }

  @override
  void dispose() {
    _amount.dispose();
    _note.dispose();
    super.dispose();
  }

  /// Controllers also notify on focus/selection changes, so compare the
  /// actual text before treating the form as edited.
  void _onTextChanged() {
    if (_dirty) return;
    if (_amount.text != _initialAmount || _note.text != _initialNote) {
      setState(() => _dirty = true);
    }
  }

  void _update(VoidCallback change) {
    setState(() {
      change();
      _dirty = true;
    });
  }

  void _setType(bool income) {
    _update(() {
      _isIncome = income;
      final cats = context.read<CategoryProvider>();
      final current = cats.byName(_category);
      if (current == null || !current.appliesTo(isIncome: income)) {
        final options = cats.forType(isIncome: income);
        _category = options.isNotEmpty ? options.first.name : otherCategory;
      }
    });
  }

  Future<void> _pickDate() async {
    final now = DateTime.now();
    final picked = await showDatePicker(
      context: context,
      initialDate: _date,
      firstDate: DateTime(2000),
      lastDate: DateTime(now.year + 1, now.month, now.day),
      helpText: 'Transaction date',
    );
    if (picked == null) return;
    // Keep the original time of day so ordering within a day is stable.
    _update(() {
      _date = DateTime(
        picked.year,
        picked.month,
        picked.day,
        _date.hour,
        _date.minute,
        _date.second,
        _date.millisecond,
      );
    });
  }

  Future<void> _save() async {
    if (_saving) return;
    FocusScope.of(context).unfocus();
    if (!_formKey.currentState!.validate()) return;
    final minor = Money.parse(_amount.text).minor!;
    final now = DateTime.now();
    final tx = _isEdit
        ? widget.existing!.copyWith(
            amountMinor: minor,
            category: _category,
            note: _note.text.trim(),
            date: _date,
            paymentType: _paymentType,
            isIncome: _isIncome,
            bankAccount: _account,
            updatedAt: now,
          )
        : TransactionModel(
            id: const Uuid().v4(),
            amountMinor: minor,
            category: _category,
            note: _note.text.trim(),
            date: _date,
            paymentType: _paymentType,
            isIncome: _isIncome,
            bankAccount: _account,
            createdAt: now,
            updatedAt: now,
          );

    setState(() => _saving = true);
    try {
      await context.read<TransactionProvider>().save(tx);
      if (!mounted) return;
      showMessage(
        context,
        _isEdit ? 'Transaction updated' : 'Transaction added',
      );
      _dirty = false;
      Navigator.of(context).pop();
    } catch (_) {
      if (!mounted) return;
      setState(() => _saving = false);
      showMessage(
        context,
        'Could not save. Your entry is still here — please try again.',
        error: true,
      );
    }
  }

  Future<void> _delete() async {
    final deleted = await deleteTransactionWithUndo(context, widget.existing!);
    if (deleted && mounted) {
      _dirty = false;
      Navigator.of(context).pop();
    }
  }

  Future<void> _handlePop(bool didPop, Object? result) async {
    if (didPop) return;
    final discard = await confirmAction(
      context,
      title: 'Discard changes?',
      message: 'Your unsaved changes will be lost.',
      confirmLabel: 'Discard',
    );
    if (discard && mounted) {
      _dirty = false;
      Navigator.of(context).pop();
    }
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final colors = AppColors.of(context);
    final currency = context.watch<SettingsProvider>().currency;
    final categories = context.watch<CategoryProvider>().forType(
      isIncome: _isIncome,
    );
    final categoryNames = {for (final c in categories) c.name};
    final accounts = [
      ...bankAccounts,
      if (!bankAccounts.contains(_account)) _account,
    ];
    final payments = [
      ...paymentTypes,
      if (!paymentTypes.contains(_paymentType)) _paymentType,
    ];
    final accent = _isIncome ? colors.income : colors.expense;

    return PopScope(
      canPop: !_dirty || _saving,
      onPopInvokedWithResult: _handlePop,
      child: Scaffold(
        appBar: AppBar(
          title: Text(_isEdit ? 'Edit transaction' : 'New transaction'),
          actions: [
            if (_isEdit)
              IconButton(
                tooltip: 'Delete transaction',
                onPressed: _saving ? null : _delete,
                icon: const Icon(Icons.delete_outline_rounded),
              ),
          ],
        ),
        body: Form(
          key: _formKey,
          // Not lazy: every field must exist for Form.validate() to see it.
          child: SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                SegmentedButton<bool>(
                  segments: const [
                    ButtonSegment(
                      value: false,
                      label: Text('Expense'),
                      icon: Icon(Icons.north_east_rounded),
                    ),
                    ButtonSegment(
                      value: true,
                      label: Text('Income'),
                      icon: Icon(Icons.south_west_rounded),
                    ),
                  ],
                  selected: {_isIncome},
                  onSelectionChanged: (s) => _setType(s.first),
                  showSelectedIcon: false,
                ),
                const SizedBox(height: 20),
                TextFormField(
                  key: const Key('amountField'),
                  controller: _amount,
                  autofocus: !_isEdit,
                  keyboardType: const TextInputType.numberWithOptions(
                    decimal: true,
                  ),
                  textInputAction: TextInputAction.next,
                  inputFormatters: [
                    FilteringTextInputFormatter.allow(RegExp(r'[0-9.,\s]')),
                    LengthLimitingTextInputFormatter(20),
                  ],
                  style: TextStyle(
                    fontSize: 32,
                    fontWeight: FontWeight.w700,
                    color: accent,
                    fontFeatures: tabularFigures,
                  ),
                  decoration: InputDecoration(
                    labelText: 'Amount',
                    prefixText: currency.symbol,
                    prefixStyle: TextStyle(
                      fontSize: 32,
                      fontWeight: FontWeight.w700,
                      color: accent,
                    ),
                    hintText: '0.00',
                  ),
                  validator: (v) => Money.parse(v ?? '').message,
                ),
                const SizedBox(height: 24),
                const _Label('Category'),
                const SizedBox(height: 8),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    for (final name in [
                      ...categoryNames,
                      if (!categoryNames.contains(_category)) _category,
                    ])
                      ChoiceChip(
                        avatar: CategoryAvatar(name, size: 22),
                        label: Text(name),
                        selected: _category == name,
                        onSelected: (_) => _update(() => _category = name),
                      ),
                  ],
                ),
                const SizedBox(height: 24),
                const _Label('Date'),
                const SizedBox(height: 8),
                OutlinedButton.icon(
                  onPressed: _pickDate,
                  icon: const Icon(Icons.calendar_today_rounded),
                  label: Align(
                    alignment: Alignment.centerLeft,
                    child: Text(_dateLabel(_date)),
                  ),
                ),
                if (_date.isAfter(DateTime.now()) &&
                    !isSameDay(_date, DateTime.now()))
                  Padding(
                    padding: const EdgeInsets.only(top: 6, left: 4),
                    child: Text(
                      'This date is in the future.',
                      style: TextStyle(color: colors.warning, fontSize: 13),
                    ),
                  ),
                const SizedBox(height: 24),
                const _Label('Payment method'),
                const SizedBox(height: 8),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    for (final p in payments)
                      ChoiceChip(
                        label: Text(p),
                        selected: _paymentType == p,
                        onSelected: (_) => _update(() => _paymentType = p),
                      ),
                  ],
                ),
                const SizedBox(height: 24),
                DropdownButtonFormField<String>(
                  isExpanded: true,
                  initialValue: _account,
                  decoration: const InputDecoration(
                    labelText: 'Account',
                    prefixIcon: Icon(Icons.account_balance_wallet_outlined),
                  ),
                  items: [
                    for (final a in accounts)
                      DropdownMenuItem(value: a, child: Text(a)),
                  ],
                  onChanged: (v) {
                    if (v != null) _update(() => _account = v);
                  },
                ),
                const SizedBox(height: 16),
                TextFormField(
                  key: const Key('noteField'),
                  controller: _note,
                  textCapitalization: TextCapitalization.sentences,
                  maxLength: maxNoteLength,
                  maxLines: 2,
                  minLines: 1,
                  textInputAction: TextInputAction.done,
                  onFieldSubmitted: (_) => _save(),
                  decoration: const InputDecoration(
                    labelText: 'Note (optional)',
                    hintText: 'e.g. Lunch with team',
                    prefixIcon: Icon(Icons.notes_rounded),
                  ),
                ),
              ],
            ),
          ),
        ),
        bottomNavigationBar: AnimatedPadding(
          duration: const Duration(milliseconds: 150),
          padding: EdgeInsets.only(
            bottom: MediaQuery.viewInsetsOf(context).bottom,
          ),
          child: SafeArea(
            child: Container(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
              decoration: BoxDecoration(
                color: scheme.surface,
                border: Border(top: BorderSide(color: scheme.outlineVariant)),
              ),
              child: FilledButton.icon(
                key: const Key('saveButton'),
                onPressed: _saving ? null : _save,
                icon: _saving
                    ? const SizedBox.square(
                        dimension: 20,
                        child: CircularProgressIndicator(strokeWidth: 2.5),
                      )
                    : const Icon(Icons.check_rounded),
                label: Text(_isEdit ? 'Save changes' : 'Save transaction'),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

String _dateLabel(DateTime d) {
  final header = formatDayHeader(d);
  return header == 'Today' || header == 'Yesterday'
      ? '$header · ${formatDate(d)}'
      : header;
}

class _Label extends StatelessWidget {
  const _Label(this.text);
  final String text;

  @override
  Widget build(BuildContext context) => Text(
    text,
    style: Theme.of(context).textTheme.labelLarge?.copyWith(
      color: Theme.of(context).colorScheme.onSurfaceVariant,
    ),
  );
}
