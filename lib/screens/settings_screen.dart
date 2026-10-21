import 'dart:convert';
import 'dart:typed_data';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../providers/budget_provider.dart';
import '../providers/category_provider.dart';
import '../providers/settings_provider.dart';
import '../providers/transaction_provider.dart';
import '../services/backup_service.dart';
import '../utils/app_constants.dart';
import '../utils/date_utils.dart';
import '../utils/money.dart';
import '../widgets/common.dart';
import 'categories_screen.dart';

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  bool _busy = false;

  Future<void> _run(Future<void> Function() action) async {
    if (_busy) return;
    setState(() => _busy = true);
    try {
      await action();
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _chooseCurrency() async {
    final settings = context.read<SettingsProvider>();
    final picked = await showDialog<Currency>(
      context: context,
      builder: (context) => SimpleDialog(
        title: const Text('Currency'),
        children: [
          const Padding(
            padding: EdgeInsets.fromLTRB(24, 0, 24, 8),
            child: Text(
              'Changes the symbol and number grouping only. Amounts are not converted.',
              style: TextStyle(fontSize: 13),
            ),
          ),
          RadioGroup<String>(
            groupValue: settings.currency.code,
            onChanged: (code) => Navigator.pop(context, currencyForCode(code)),
            child: Column(
              children: [
                for (final c in supportedCurrencies)
                  RadioListTile<String>(
                    value: c.code,
                    title: Text('${c.name} (${c.symbol.trim()})'),
                    subtitle: Text(Money.format(123456789, c)),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
    if (picked != null) {
      try {
        await settings.setCurrency(picked);
      } catch (_) {
        if (mounted) {
          showMessage(context, 'Could not save the setting.', error: true);
        }
      }
    }
  }

  Future<void> _exportBackup() => _run(() async {
    final txs = context.read<TransactionProvider>();
    final json = BackupService.encode(
      transactions: txs.transactions,
      categories: context.read<CategoryProvider>().categories,
      budgets: context.read<BudgetProvider>().all,
      settings: context.read<SettingsProvider>().toBackup(),
    );
    final now = DateTime.now();
    final name =
        'expense_tracker_backup_${now.year}'
        '${now.month.toString().padLeft(2, '0')}${now.day.toString().padLeft(2, '0')}.json';
    try {
      final uri = await FilePicker.saveFile(
        fileName: name,
        bytes: Uint8List.fromList(utf8.encode(json)),
        mimeType: 'application/json',
        dialogTitle: 'Save backup',
        type: FileType.custom,
        allowedExtensions: const ['json'],
      );
      if (uri != null && mounted) {
        showMessage(
          context,
          'Backup saved (${txs.transactions.length} transactions). Keep it somewhere safe.',
        );
      }
    } catch (_) {
      if (mounted) {
        showMessage(context, 'Could not save the backup.', error: true);
      }
    }
  });

  Future<void> _restoreBackup() => _run(() async {
    final List<PlatformFile> files;
    try {
      files = await FilePicker.pickFiles(dialogTitle: 'Choose a backup file');
    } catch (_) {
      if (mounted) {
        showMessage(context, 'Could not open the file picker.', error: true);
      }
      return;
    }
    if (files.isEmpty || !mounted) return;

    final BackupData data;
    try {
      final size = await files.first.length();
      if (size != null && size > BackupService.maxBytes) {
        throw BackupFormatException('This file is too large to be a backup.');
      }
      final bytes = await files.first.readAsBytes();
      data = BackupService.decode(utf8.decode(bytes, allowMalformed: false));
    } on BackupFormatException catch (e) {
      if (mounted) showMessage(context, e.message, error: true);
      return;
    } catch (_) {
      if (mounted) {
        showMessage(context, 'Could not read this file.', error: true);
      }
      return;
    }
    if (!mounted) return;

    final ok = await confirmAction(
      context,
      title: 'Restore backup?',
      message:
          '${data.exportedAt != null ? 'Backup from ${formatDate(data.exportedAt!)}. ' : ''}'
          'It contains ${data.transactions.length} transactions. '
          'Only transactions missing on this device are added — nothing here is changed or deleted.',
      confirmLabel: 'Restore',
      destructive: false,
    );
    if (!ok || !mounted) return;
    try {
      final result = await BackupService.importInto(
        data,
        transactions: context.read<TransactionProvider>(),
        categories: context.read<CategoryProvider>(),
        budgets: context.read<BudgetProvider>(),
      );
      if (mounted) showMessage(context, result.summary);
    } catch (_) {
      if (mounted) {
        showMessage(
          context,
          'Restore failed part-way. Already-restored items were kept; you can run restore again safely.',
          error: true,
        );
      }
    }
  });

  Future<void> _eraseAll() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => const _EraseDialog(),
    );
    if (confirmed != true || !mounted) return;
    await _run(() async {
      try {
        await context.read<TransactionProvider>().deleteAll();
        if (!mounted) return;
        await context.read<BudgetProvider>().deleteAll();
        if (mounted) {
          showMessage(context, 'All transactions and budgets erased');
        }
      } catch (_) {
        if (mounted) {
          showMessage(context, 'Could not erase all data.', error: true);
        }
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final settings = context.watch<SettingsProvider>();
    final txs = context.watch<TransactionProvider>();
    final scheme = Theme.of(context).colorScheme;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Settings'),
        bottom: _busy
            ? const PreferredSize(
                preferredSize: Size.fromHeight(3),
                child: LinearProgressIndicator(minHeight: 3),
              )
            : null,
      ),
      body: AbsorbPointer(
        absorbing: _busy,
        child: ListView(
          padding: const EdgeInsets.fromLTRB(16, 4, 16, 32),
          children: [
            if (txs.unreadableRecords > 0) ...[
              Card(
                color: scheme.errorContainer,
                child: ListTile(
                  leading: Icon(
                    Icons.warning_amber_rounded,
                    color: scheme.onErrorContainer,
                  ),
                  title: Text(
                    '${txs.unreadableRecords} stored record(s) could not be read',
                    style: TextStyle(color: scheme.onErrorContainer),
                  ),
                  subtitle: Text(
                    'They have been left untouched and are not included in totals.',
                    style: TextStyle(color: scheme.onErrorContainer),
                  ),
                ),
              ),
              const SizedBox(height: 16),
            ],
            const _Header('Appearance'),
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: SegmentedButton<ThemeMode>(
                  segments: const [
                    ButtonSegment(
                      value: ThemeMode.system,
                      label: Text('System'),
                      icon: Icon(Icons.brightness_auto_rounded),
                    ),
                    ButtonSegment(
                      value: ThemeMode.light,
                      label: Text('Light'),
                      icon: Icon(Icons.light_mode_rounded),
                    ),
                    ButtonSegment(
                      value: ThemeMode.dark,
                      label: Text('Dark'),
                      icon: Icon(Icons.dark_mode_rounded),
                    ),
                  ],
                  selected: {settings.themeMode},
                  showSelectedIcon: false,
                  onSelectionChanged: (s) => settings.setThemeMode(s.first),
                ),
              ),
            ),
            const SizedBox(height: 16),
            const _Header('General'),
            Card(
              clipBehavior: Clip.antiAlias,
              child: Column(
                children: [
                  ListTile(
                    leading: const Icon(Icons.currency_exchange_rounded),
                    title: const Text('Currency'),
                    subtitle: Text(
                      '${settings.currency.name} (${settings.currency.symbol.trim()})',
                    ),
                    trailing: const Icon(Icons.chevron_right_rounded),
                    onTap: _chooseCurrency,
                  ),
                  const Divider(indent: 16, endIndent: 16),
                  ListTile(
                    leading: const Icon(Icons.category_outlined),
                    title: const Text('Categories'),
                    subtitle: const Text('Add, rename, recolor or delete'),
                    trailing: const Icon(Icons.chevron_right_rounded),
                    onTap: () => Navigator.of(context).push(
                      MaterialPageRoute(
                        builder: (_) => const CategoriesScreen(),
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),
            const _Header('Backup'),
            Card(
              clipBehavior: Clip.antiAlias,
              child: Column(
                children: [
                  ListTile(
                    leading: const Icon(Icons.upload_file_rounded),
                    title: const Text('Export backup'),
                    subtitle: const Text('Save all data as a JSON file'),
                    onTap: _exportBackup,
                  ),
                  const Divider(indent: 16, endIndent: 16),
                  ListTile(
                    leading: const Icon(Icons.restore_rounded),
                    title: const Text('Restore from backup'),
                    subtitle: const Text(
                      'Adds missing transactions; never deletes',
                    ),
                    onTap: _restoreBackup,
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),
            const _Header('Data'),
            Card(
              clipBehavior: Clip.antiAlias,
              child: ListTile(
                leading: Icon(
                  Icons.delete_forever_outlined,
                  color: scheme.error,
                ),
                title: Text(
                  'Erase all transactions & budgets',
                  style: TextStyle(color: scheme.error),
                ),
                onTap: _eraseAll,
              ),
            ),
            const SizedBox(height: 16),
            const _Header('About & privacy'),
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      '$appName $appVersion',
                      style: TextStyle(fontWeight: FontWeight.w700),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'Your data is stored only on this device. The app has no account, '
                      'no internet permission, no analytics and no ads. Data leaves the device '
                      'only when you export a PDF or backup and choose where to send it. '
                      'Android may include app data in your device backup if that is enabled '
                      'in your phone settings. Uninstalling the app deletes its data.',
                      style: TextStyle(
                        color: scheme.onSurfaceVariant,
                        height: 1.4,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _Header extends StatelessWidget {
  const _Header(this.text);
  final String text;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.fromLTRB(4, 0, 4, 8),
    child: Semantics(
      header: true,
      child: Text(
        text,
        style: Theme.of(context).textTheme.labelLarge?.copyWith(
          color: Theme.of(context).colorScheme.primary,
          fontWeight: FontWeight.w700,
        ),
      ),
    ),
  );
}

/// Owns its controller so it is disposed only after the dialog's exit
/// animation has finished.
class _EraseDialog extends StatefulWidget {
  const _EraseDialog();

  @override
  State<_EraseDialog> createState() => _EraseDialogState();
}

class _EraseDialogState extends State<_EraseDialog> {
  final _controller = TextEditingController();

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return AlertDialog(
      scrollable: true,
      title: const Text('Erase all data?'),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'This permanently deletes every transaction and budget on this device. '
            'Categories and settings are kept. Export a backup first if you might need this data.',
          ),
          const SizedBox(height: 16),
          TextField(
            controller: _controller,
            autofocus: true,
            decoration: const InputDecoration(
              labelText: 'Type DELETE to confirm',
            ),
            onChanged: (_) => setState(() {}),
          ),
        ],
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context, false),
          child: const Text('Cancel'),
        ),
        FilledButton(
          style: FilledButton.styleFrom(
            backgroundColor: scheme.error,
            foregroundColor: scheme.onError,
            minimumSize: const Size(64, 40),
          ),
          onPressed: _controller.text.trim() == 'DELETE'
              ? () => Navigator.pop(context, true)
              : null,
          child: const Text('Erase'),
        ),
      ],
    );
  }
}
