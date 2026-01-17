import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../data/db/app_database.dart';
import '../../data/providers.dart';

class ProgramsScreen extends ConsumerWidget {
  const ProgramsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final programsAsync = ref.watch(programsStreamProvider);
    final activeProgramId = ref.watch(settingsStreamProvider).maybeWhen(
          data: (settings) => settings?.activeProgramId,
          orElse: () => null,
        );

    return Scaffold(
      appBar: AppBar(
        title: const Text('Programs'),
        actions: [
          IconButton(
            onPressed: () => context.push('/programs/exercises'),
            icon: const Icon(Icons.fitness_center),
            tooltip: 'Exercise Library',
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _createProgram(context, ref),
        icon: const Icon(Icons.add),
        label: const Text('New Program'),
      ),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: programsAsync.when(
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (error, stack) => const Center(
            child: Text('Failed to load programs.'),
          ),
          data: (programs) {
            if (programs.isEmpty) {
              return const Center(child: Text('No programs yet.'));
            }

            return ListView.separated(
              itemCount: programs.length,
              separatorBuilder: (_, _) => const Divider(height: 1),
              itemBuilder: (context, index) {
                final program = programs[index];
                final isActive = activeProgramId == program.id;

                return ListTile(
                  title: Text(program.name),
                  subtitle: isActive ? const Text('Active program') : null,
                  onTap: () => context.push('/programs/${program.id}'),
                  trailing: Wrap(
                    spacing: 8,
                    crossAxisAlignment: WrapCrossAlignment.center,
                    children: [
                      if (isActive)
                        const Chip(label: Text('Active'))
                      else
                        TextButton(
                          onPressed: () => ref
                              .read(programRepositoryProvider)
                              .setActiveProgram(program.id),
                          child: const Text('Set Active'),
                        ),
                      PopupMenuButton<_ProgramAction>(
                        onSelected: (action) {
                          switch (action) {
                            case _ProgramAction.rename:
                              _renameProgram(context, ref, program);
                              break;
                            case _ProgramAction.delete:
                              _deleteProgram(context, ref, program);
                              break;
                          }
                        },
                        itemBuilder: (context) => const [
                          PopupMenuItem(
                            value: _ProgramAction.rename,
                            child: Text('Rename'),
                          ),
                          PopupMenuItem(
                            value: _ProgramAction.delete,
                            child: Text('Delete'),
                          ),
                        ],
                      ),
                    ],
                  ),
                );
              },
            );
          },
        ),
      ),
    );
  }

  Future<void> _createProgram(BuildContext context, WidgetRef ref) async {
    final name = await _promptForName(context, title: 'New Program');
    if (name == null || name.isEmpty) {
      return;
    }
    await ref.read(programRepositoryProvider).createProgram(name);
  }

  Future<void> _renameProgram(
    BuildContext context,
    WidgetRef ref,
    Program program,
  ) async {
    final name = await _promptForName(
      context,
      title: 'Rename Program',
      initialValue: program.name,
    );
    if (name == null || name.isEmpty) {
      return;
    }
    await ref.read(programRepositoryProvider).renameProgram(program.id, name);
  }

  Future<void> _deleteProgram(
    BuildContext context,
    WidgetRef ref,
    Program program,
  ) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text('Delete program?'),
          content: Text('This will remove "${program.name}" and its days.'),
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
        );
      },
    );

    if (confirmed == true) {
      await ref.read(programRepositoryProvider).deleteProgram(program.id);
    }
  }

  Future<String?> _promptForName(
    BuildContext context, {
    required String title,
    String? initialValue,
  }) {
    final controller = TextEditingController(text: initialValue ?? '');

    return showDialog<String>(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: Text(title),
          content: TextField(
            controller: controller,
            autofocus: true,
            textInputAction: TextInputAction.done,
            decoration: const InputDecoration(labelText: 'Name'),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('Cancel'),
            ),
            FilledButton(
              onPressed: () => Navigator.of(context).pop(
                controller.text.trim(),
              ),
              child: const Text('Save'),
            ),
          ],
        );
      },
    );
  }
}

enum _ProgramAction { rename, delete }
