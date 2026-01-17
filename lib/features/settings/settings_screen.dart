import 'dart:io';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../data/db/app_database.dart';
import '../../data/providers.dart';
import '../../services/backup_pro_service.dart';
import '../../services/export_service.dart';
import '../../services/rest_notifications_service.dart';

class SettingsScreen extends ConsumerStatefulWidget {
  const SettingsScreen({super.key});

  @override
  ConsumerState<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends ConsumerState<SettingsScreen> {
  final TextEditingController _plateController = TextEditingController();
  bool _plateInitialized = false;

  @override
  void initState() {
    super.initState();
    Future<void>.microtask(() async {
      await ref.read(settingsRepositoryProvider).ensureSingleRow();
    });
  }

  @override
  void dispose() {
    _plateController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    final settingsAsync = ref.watch(settingsStreamProvider);
    final restSettingsAsync = ref.watch(restNotificationSettingsProvider);

    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: settingsAsync.when(
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (error, stack) => const Center(
            child: Text('Failed to load settings.'),
          ),
          data: (settings) {
            _maybeInitPlates(settings);
            final barWeightKg = settings?.barWeightKg;
            final plateCsv = settings?.plateInventoryCsv;
            final autoBackupEnabled = settings?.backupAutoEnabled ?? false;
            final encryptionEnabled =
                settings?.backupEncryptionEnabled ?? false;
            final restSettings = restSettingsAsync.asData?.value;

            return SingleChildScrollView(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Settings',
                    style: textTheme.displaySmall?.copyWith(
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: 12),
                  const Text('Placeholder for settings controls.'),
                  const SizedBox(height: 24),
                  const Text('DB Status: OK'),
                  const SizedBox(height: 8),
                  Text(
                    barWeightKg == null
                        ? 'Bar Weight: --'
                        : 'Bar Weight: ${barWeightKg.toStringAsFixed(1)} kg',
                    style: textTheme.titleLarge,
                  ),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      FilledButton.tonal(
                        onPressed: settings == null
                            ? null
                            : () =>
                                _updateBarWeight(settings.barWeightKg - 2.5),
                        child: const Text('- 2.5 kg'),
                      ),
                      const SizedBox(width: 12),
                      FilledButton.tonal(
                        onPressed: settings == null
                            ? null
                            : () =>
                                _updateBarWeight(settings.barWeightKg + 2.5),
                        child: const Text('+ 2.5 kg'),
                      ),
                    ],
                  ),
                  const SizedBox(height: 24),
                  Text(
                    'Plates',
                    style: textTheme.titleLarge,
                  ),
                  const SizedBox(height: 8),
                  Text(
                    plateCsv == null ? 'Current: --' : 'Current: $plateCsv',
                  ),
                  const SizedBox(height: 8),
                  TextField(
                    controller: _plateController,
                    decoration: const InputDecoration(
                      labelText: 'Plate inventory (kg per side)',
                      hintText: '20,15,10,5,2.5,1.25',
                    ),
                  ),
                  const SizedBox(height: 12),
                  FilledButton(
                    onPressed: settings == null ? null : _savePlateInventory,
                    child: const Text('Save Plates'),
                  ),
                  const SizedBox(height: 24),
                  Text(
                    'Rest Notifications',
                    style: textTheme.titleLarge,
                  ),
                  const SizedBox(height: 8),
                  if (restSettingsAsync.isLoading)
                    const LinearProgressIndicator(),
                  SwitchListTile(
                    contentPadding: EdgeInsets.zero,
                    title: const Text('Rest notifications'),
                    subtitle: const Text('Alert when rest timer ends'),
                    value: restSettings?.enabled ?? false,
                    onChanged: (value) => _toggleRestNotifications(value),
                  ),
                  SwitchListTile(
                    contentPadding: EdgeInsets.zero,
                    title: const Text('Rest notification sound'),
                    value: restSettings?.soundEnabled ?? true,
                    onChanged: restSettings?.enabled == true
                        ? (value) => _toggleRestSound(value)
                        : null,
                  ),
                  const SizedBox(height: 24),
                  Text(
                    'Backup Pro',
                    style: textTheme.titleLarge,
                  ),
                  const SizedBox(height: 8),
                  SwitchListTile(
                    contentPadding: EdgeInsets.zero,
                    title: const Text('Auto backup'),
                    subtitle: const Text('Creates a daily backup on device'),
                    value: autoBackupEnabled,
                    onChanged: settings == null
                        ? null
                        : (value) => _toggleAutoBackup(value),
                  ),
                  SwitchListTile(
                    contentPadding: EdgeInsets.zero,
                    title: const Text('Encryption'),
                    subtitle: const Text('Protect backups with a passphrase'),
                    value: encryptionEnabled,
                    onChanged: settings == null
                        ? null
                        : (value) => _toggleEncryption(value),
                  ),
                  if (encryptionEnabled)
                    const Padding(
                      padding: EdgeInsets.only(bottom: 8),
                      child: Text(
                        'If you forget this passphrase, encrypted backups cannot be restored.',
                      ),
                    ),
                  const SizedBox(height: 8),
                  FilledButton.icon(
                    onPressed: settings == null ? null : _createBackupNow,
                    icon: const Icon(Icons.save_alt),
                    label: const Text('Create Backup Now'),
                  ),
                  const SizedBox(height: 8),
                  OutlinedButton.icon(
                    onPressed: settings == null ? null : _restoreFromFile,
                    icon: const Icon(Icons.folder_open),
                    label: const Text('Restore from File...'),
                  ),
                  const SizedBox(height: 8),
                  OutlinedButton.icon(
                    onPressed: () => context.push('/settings/backups'),
                    icon: const Icon(Icons.manage_accounts),
                    label: const Text('Manage Local Backups'),
                  ),
                  const SizedBox(height: 24),
                  Text(
                    'Export',
                    style: textTheme.titleLarge,
                  ),
                  const SizedBox(height: 8),
                  FilledButton.icon(
                    onPressed: _exportCsvAll,
                    icon: const Icon(Icons.table_view),
                    label: const Text('Export CSV (All Finished Sessions)'),
                  ),
                  const SizedBox(height: 8),
                  OutlinedButton.icon(
                    onPressed: _exportCsvThisWeek,
                    icon: const Icon(Icons.today),
                    label: const Text('Export CSV (This Week)'),
                  ),
                  const SizedBox(height: 8),
                  OutlinedButton.icon(
                    onPressed: _exportCsvLast4Weeks,
                    icon: const Icon(Icons.calendar_view_month),
                    label: const Text('Export CSV (Last 4 Weeks)'),
                  ),
                ],
              ),
            );
          },
        ),
      ),
    );
  }

  Future<void> _updateBarWeight(double value) async {
    await ref.read(settingsRepositoryProvider).updateBarWeightKg(value);
  }

  void _maybeInitPlates(Setting? settings) {
    if (_plateInitialized || settings == null) {
      return;
    }
    _plateController.text = settings.plateInventoryCsv;
    _plateInitialized = true;
  }

  Future<void> _savePlateInventory() async {
    final raw = _plateController.text.trim();
    final values = <double>[];
    for (final part in raw.split(',')) {
      final parsed = double.tryParse(part.trim());
      if (parsed != null && parsed > 0) {
        values.add(parsed);
      }
    }

    if (values.isEmpty) {
      if (!mounted) {
        return;
      }
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Enter valid plate sizes.')),
      );
      return;
    }

    values.sort((a, b) => b.compareTo(a));
    final normalized = values.map(_formatPlate).join(',');

    await ref
        .read(settingsRepositoryProvider)
        .updatePlateInventoryCsv(normalized);

    if (!mounted) {
      return;
    }
    _plateController.text = normalized;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Plates saved.')),
    );
  }

  String _formatPlate(double value) {
    if (value % 1 == 0) {
      return value.toStringAsFixed(0);
    }
    return value.toString();
  }

  Future<void> _toggleAutoBackup(bool enabled) async {
    await ref.read(backupProServiceProvider).setAutoBackupEnabled(enabled);
  }

  Future<void> _toggleRestNotifications(bool enabled) async {
    if (enabled) {
      final granted = await ref
          .read(restNotificationsServiceProvider)
          .requestPermissionIfNeeded();
      if (!granted) {
        if (!mounted) {
          return;
        }
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Notification permission denied.'),
          ),
        );
        return;
      }
    } else {
      await ref.read(restNotificationsServiceProvider).cancelRestEnd();
    }

    await ref
        .read(restNotificationSettingsProvider.notifier)
        .setEnabled(enabled);
  }

  Future<void> _toggleRestSound(bool enabled) async {
    await ref
        .read(restNotificationSettingsProvider.notifier)
        .setSoundEnabled(enabled);
  }

  Future<void> _toggleEncryption(bool enabled) async {
    if (!enabled) {
      await ref.read(backupProServiceProvider).setEncryptionEnabled(false);
      return;
    }

    final passphrase = await _promptPassphraseConfirm();
    if (passphrase == null) {
      return;
    }

    await ref
        .read(backupProServiceProvider)
        .setEncryptionEnabled(true, passphrase: passphrase);
  }

  Future<void> _createBackupNow() async {
    try {
      final settings =
          await ref.read(settingsRepositoryProvider).ensureSingleRow();
      final encrypted = settings.backupEncryptionEnabled;
      final passphrase = await _resolvePassphraseIfNeeded(encrypted);
      if (encrypted && passphrase == null) {
        return;
      }

      await ref.read(backupProServiceProvider).createBackup(
            encrypted: encrypted,
            passphrase: passphrase,
            trigger: 'manual',
          );
      ref.invalidate(localBackupsProvider);
      if (!mounted) {
        return;
      }
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Backup created.')),
      );
    } catch (error) {
      if (!mounted) {
        return;
      }
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Backup failed: $error')),
      );
    }
  }

  Future<void> _restoreFromFile() async {
    final result = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: const ['json', 'grbk'],
    );
    if (result == null || result.files.isEmpty) {
      return;
    }

    final filePath = result.files.single.path;
    if (filePath == null) {
      return;
    }

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Restore backup?'),
        content: const Text(
          'This will REPLACE your local data. Continue?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('Restore'),
          ),
        ],
      ),
    );
    if (confirmed != true) {
      return;
    }

    final file = File(filePath);
    final storedPassphrase =
        await ref.read(backupProServiceProvider).readStoredPassphrase();

    try {
      await ref.read(backupProServiceProvider).restoreBackupFromFile(
            file,
            passphraseIfNeeded: storedPassphrase,
          );
      _invalidateAfterRestore();
      return;
    } catch (error) {
      if (error.toString().contains('Passphrase required')) {
        final passphrase = await _promptPassphrase();
        if (passphrase == null) {
          return;
        }
        try {
          await ref.read(backupProServiceProvider).restoreBackupFromFile(
                file,
                passphraseIfNeeded: passphrase,
              );
          _invalidateAfterRestore();
          return;
        } catch (retryError) {
          if (!mounted) {
            return;
          }
          final message =
              retryError.toString().contains('Wrong passphrase')
                  ? 'Wrong passphrase.'
                  : 'Restore failed: $retryError';
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text(message)),
          );
          return;
        }
      }

      if (!mounted) {
        return;
      }
      final message = error.toString().contains('Wrong passphrase')
          ? 'Wrong passphrase.'
          : 'Restore failed: $error';
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(message)),
      );
    }
  }

  Future<String?> _resolvePassphraseIfNeeded(bool encrypted) async {
    if (!encrypted) {
      return null;
    }
    final stored =
        await ref.read(backupProServiceProvider).readStoredPassphrase();
    if (stored != null && stored.isNotEmpty) {
      return stored;
    }
    return _promptPassphrase();
  }

  Future<String?> _promptPassphrase() async {
    final controller = TextEditingController();
    final result = await showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Enter passphrase'),
        content: TextField(
          controller: controller,
          obscureText: true,
          decoration: const InputDecoration(labelText: 'Passphrase'),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () =>
                Navigator.of(context).pop(controller.text.trim()),
            child: const Text('Continue'),
          ),
        ],
      ),
    );
    if (result == null || result.isEmpty) {
      return null;
    }
    return result;
  }

  Future<String?> _promptPassphraseConfirm() async {
    final first = TextEditingController();
    final second = TextEditingController();
    final result = await showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Set passphrase'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: first,
              obscureText: true,
              decoration: const InputDecoration(labelText: 'Passphrase'),
            ),
            const SizedBox(height: 8),
            TextField(
              controller: second,
              obscureText: true,
              decoration: const InputDecoration(labelText: 'Confirm passphrase'),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () {
              final passphrase = first.text.trim();
              final confirm = second.text.trim();
              if (passphrase.isEmpty || passphrase != confirm) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Passphrases do not match.')),
                );
                return;
              }
              Navigator.of(context).pop(passphrase);
            },
            child: const Text('Save'),
          ),
        ],
      ),
    );
    return result;
  }

  Future<void> _exportCsvAll() async {
    await _exportCsvRange();
  }

  Future<void> _exportCsvThisWeek() async {
    final range = _buildRangeThisWeek();
    await _exportCsvRange(start: range.start, end: range.end);
  }

  Future<void> _exportCsvLast4Weeks() async {
    final range = _buildRangeLast4Weeks();
    await _exportCsvRange(start: range.start, end: range.end);
  }

  Future<void> _exportCsvRange({DateTime? start, DateTime? end}) async {
    try {
      final service = ref.read(exportServiceProvider);
      final file = await service.exportSetsCsv(start: start, end: end);
      await service.shareFile(file);
      if (!mounted) {
        return;
      }
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('CSV exported.')),
      );
    } catch (error) {
      if (!mounted) {
        return;
      }
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Export failed: $error')),
      );
    }
  }

  _DateRange _buildRangeThisWeek() {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final start = today.subtract(Duration(days: today.weekday - 1));
    return _DateRange(start: start, end: now);
  }

  _DateRange _buildRangeLast4Weeks() {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final startOfWeek = today.subtract(Duration(days: today.weekday - 1));
    final start = startOfWeek.subtract(const Duration(days: 28));
    return _DateRange(start: start, end: now);
  }

  void _invalidateAfterRestore() {
    ref.invalidate(settingsStreamProvider);
    ref.invalidate(programsStreamProvider);
    ref.invalidate(workoutDaysProvider);
    ref.invalidate(exercisesStreamProvider);
    ref.invalidate(prescriptionsProvider);
    ref.invalidate(activeSessionProvider);
    ref.invalidate(activeSessionBundleProvider);
    ref.invalidate(recentSessionsProvider);
    ref.invalidate(reviewSummaryProvider);

    if (!mounted) {
      return;
    }
    setState(() {
      _plateInitialized = false;
    });
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Backup restored.')),
    );
  }
}

class _DateRange {
  const _DateRange({required this.start, required this.end});

  final DateTime start;
  final DateTime end;
}
