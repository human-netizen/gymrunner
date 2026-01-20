import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:share_plus/share_plus.dart';

import '../../data/providers.dart';
import '../../services/backup_pro_service.dart';

class BackupManagerScreen extends ConsumerWidget {
  const BackupManagerScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final backupsAsync = ref.watch(localBackupsProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('Manage Backups')),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: backupsAsync.when(
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (error, stack) => Center(
            child: Text('Failed to load backups: $error'),
          ),
          data: (backups) {
            if (backups.isEmpty) {
              return const Center(child: Text('No local backups found.'));
            }

            final latest = backups.first;

            return Column(
              children: [
                FilledButton.icon(
                  onPressed: () => _restoreBackup(context, ref, latest),
                  icon: const Icon(Icons.restore),
                  label: const Text('Quick restore latest'),
                ),
                const SizedBox(height: 12),
                Expanded(
                  child: ListView.separated(
                    itemCount: backups.length,
                    separatorBuilder: (_, _) => const Divider(height: 1),
                    itemBuilder: (context, index) {
                      final backup = backups[index];
                      final dateLabel =
                          _formatDateTime(context, backup.modifiedAt);
                      final sizeLabel = _formatBytes(backup.sizeBytes);
                      final badges = _buildBadges(backup);

                      return ListTile(
                        title: Text(dateLabel),
                        subtitle: Text('$sizeLabel${badges.isEmpty ? '' : ' | $badges'}'),
                        trailing: Wrap(
                          spacing: 4,
                          children: [
                            IconButton(
                              onPressed: () => _shareBackup(backup.file),
                              icon: const Icon(Icons.share),
                              tooltip: 'Share',
                            ),
                            IconButton(
                              onPressed: () => _restoreBackup(
                                context,
                                ref,
                                backup,
                              ),
                              icon: const Icon(Icons.restore),
                              tooltip: 'Restore',
                            ),
                            IconButton(
                              onPressed: () => _deleteBackup(
                                context,
                                ref,
                                backup,
                              ),
                              icon: const Icon(Icons.delete_outline),
                              tooltip: 'Delete',
                            ),
                          ],
                        ),
                      );
                    },
                  ),
                ),
              ],
            );
          },
        ),
      ),
    );
  }

  String _formatDateTime(BuildContext context, DateTime dateTime) {
    final localizations = MaterialLocalizations.of(context);
    final date = localizations.formatShortDate(dateTime);
    final time = localizations.formatTimeOfDay(
      TimeOfDay.fromDateTime(dateTime),
      alwaysUse24HourFormat: false,
    );
    return '$date - $time';
  }

  String _formatBytes(int bytes) {
    if (bytes < 1024) {
      return '$bytes B';
    }
    if (bytes < 1024 * 1024) {
      return '${(bytes / 1024).toStringAsFixed(1)} KB';
    }
    return '${(bytes / (1024 * 1024)).toStringAsFixed(1)} MB';
  }

  String _buildBadges(LocalBackupInfo backup) {
    final parts = <String>[];
    if (backup.encrypted) {
      parts.add('Encrypted');
    }
    final trigger = (backup.trigger ?? 'manual').toLowerCase();
    if (trigger == 'auto') {
      parts.add('Auto');
    } else if (trigger == 'manual') {
      parts.add('Manual');
    }
    return parts.join(' | ');
  }

  Future<void> _shareBackup(File file) async {
    await Share.shareXFiles([XFile(file.path)]);
  }

  Future<void> _restoreBackup(
    BuildContext context,
    WidgetRef ref,
    LocalBackupInfo backup,
  ) async {
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
    if (!context.mounted) {
      return;
    }

    try {
      final passphrase = await _resolvePassphraseIfNeeded(
        context,
        ref,
        backup.encrypted,
      );
      if (backup.encrypted && passphrase == null) {
        return;
      }
      await ref
          .read(backupProServiceProvider)
          .restoreBackupFromFile(
            backup.file,
            passphraseIfNeeded: passphrase,
          );
      if (!context.mounted) {
        return;
      }
      _invalidateAfterRestore(context, ref);
    } catch (error) {
      if (!context.mounted) {
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

  Future<void> _deleteBackup(
    BuildContext context,
    WidgetRef ref,
    LocalBackupInfo backup,
  ) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete backup?'),
        content: const Text('This cannot be undone.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
    if (confirmed != true) {
      return;
    }

    await ref.read(backupProServiceProvider).deleteBackup(backup.file);
    if (!context.mounted) {
      return;
    }
    ref.invalidate(localBackupsProvider);
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Backup deleted.')),
    );
  }

  Future<String?> _resolvePassphraseIfNeeded(
    BuildContext context,
    WidgetRef ref,
    bool encrypted,
  ) async {
    if (!encrypted) {
      return null;
    }
    final stored =
        await ref.read(backupProServiceProvider).readStoredPassphrase();
    if (stored != null && stored.isNotEmpty) {
      return stored;
    }
    if (!context.mounted) {
      return null;
    }
    return _promptPassphrase(context);
  }

  Future<String?> _promptPassphrase(BuildContext context) async {
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

  void _invalidateAfterRestore(BuildContext context, WidgetRef ref) {
    ref.invalidate(settingsStreamProvider);
    ref.invalidate(programsStreamProvider);
    ref.invalidate(workoutDaysProvider);
    ref.invalidate(exercisesStreamProvider);
    ref.invalidate(prescriptionsProvider);
    ref.invalidate(activeSessionProvider);
    ref.invalidate(activeSessionBundleProvider);
    ref.invalidate(recentSessionsProvider);
    ref.invalidate(reviewSummaryProvider);
    ref.invalidate(localBackupsProvider);

    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Backup restored.')),
    );
  }
}
