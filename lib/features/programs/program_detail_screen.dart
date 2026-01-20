import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../app/weekday_labels.dart';
import '../../data/db/app_database.dart';
import '../../data/providers.dart';
import '../../services/mentzer_cycle_service.dart';
import '../../templates/mentzer_hit_cycle.dart';

class ProgramDetailScreen extends ConsumerWidget {
  const ProgramDetailScreen({super.key, required this.programId});

  final int programId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final programAsync = ref.watch(programProvider(programId));
    final daysAsync = ref.watch(workoutDaysProvider(programId));
    final mentzerService = ref.watch(mentzerCycleServiceProvider);
    final programName = programAsync.maybeWhen(
      data: (program) => program?.name ?? 'Program',
      orElse: () => 'Program',
    );
    final program = programAsync.asData?.value;
    final isMentzer = program != null &&
        mentzerService.isMentzerProgramName(program.name);

    return Scaffold(
      appBar: AppBar(
        title: Text(programName),
        actions: [
          if (!isMentzer)
            IconButton(
              onPressed: () {
                final program = programAsync.asData?.value;
                if (program != null) {
                  _renameProgram(context, ref, program);
                }
              },
              icon: const Icon(Icons.edit),
              tooltip: 'Rename Program',
            ),
        ],
      ),
      floatingActionButton: isMentzer
          ? null
          : FloatingActionButton.extended(
              onPressed: () async {
                final days = daysAsync.asData?.value ?? const <WorkoutDay>[];
                await _addWorkoutDay(context, ref, days);
              },
              icon: const Icon(Icons.add),
              label: const Text('Add Workout Day'),
            ),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: isMentzer
            ? _MentzerProgramBody(
                programId: programId,
                daysAsync: daysAsync,
              )
            : Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Workout Days',
                    style: Theme.of(context).textTheme.titleLarge,
                  ),
                  const SizedBox(height: 12),
                  Expanded(
                    child: daysAsync.when(
                      loading: () =>
                          const Center(child: CircularProgressIndicator()),
                      error: (error, stack) => const Center(
                        child: Text('Failed to load workout days.'),
                      ),
                      data: (days) {
                        if (days.isEmpty) {
                          return const Center(
                            child: Text('No workout days yet.'),
                          );
                        }

                        return ListView.separated(
                          itemCount: days.length,
                          separatorBuilder: (_, _) => const Divider(height: 1),
                          itemBuilder: (context, index) {
                            final day = days[index];
                            return ListTile(
                              title: Text(day.name),
                              subtitle: Text(weekdayLabel(day.weekday)),
                              onTap: () => context.push(
                                '/programs/$programId/day/${day.id}',
                              ),
                              trailing: IconButton(
                                icon: const Icon(Icons.edit_outlined),
                                onPressed: () =>
                                    _editWorkoutDay(context, ref, day, days),
                              ),
                            );
                          },
                        );
                      },
                    ),
                  ),
                ],
              ),
      ),
    );
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
    if (!context.mounted) {
      return;
    }
    if (name == null || name.isEmpty) {
      return;
    }
    await ref.read(programRepositoryProvider).renameProgram(program.id, name);
  }

  Future<void> _addWorkoutDay(
    BuildContext context,
    WidgetRef ref,
    List<WorkoutDay> existingDays,
  ) async {
    final result = await _showDayDialog(context, title: 'New Workout Day');
    if (!context.mounted) {
      return;
    }
    if (result == null) {
      return;
    }
    if (result.name.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Day name cannot be empty.')),
      );
      return;
    }

    if (existingDays.any((day) => day.weekday == result.weekday)) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('That weekday already has a workout.')),
      );
      return;
    }

    await ref.read(programRepositoryProvider).createOrUpdateWorkoutDay(
          programId: programId,
          weekday: result.weekday,
          name: result.name,
        );
  }

  Future<void> _editWorkoutDay(
    BuildContext context,
    WidgetRef ref,
    WorkoutDay day,
    List<WorkoutDay> existingDays,
  ) async {
    final result = await _showDayDialog(
      context,
      title: 'Edit Workout Day',
      initialName: day.name,
      initialWeekday: day.weekday,
    );
    if (!context.mounted) {
      return;
    }
    if (result == null) {
      return;
    }
    if (result.name.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Day name cannot be empty.')),
      );
      return;
    }

    final duplicate = existingDays.any(
      (other) => other.weekday == result.weekday && other.id != day.id,
    );
    if (duplicate) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('That weekday is already taken.')),
      );
      return;
    }

    await ref.read(programRepositoryProvider).updateWorkoutDay(
          dayId: day.id,
          name: result.name,
          weekday: result.weekday,
        );
  }

  Future<String?> _promptForName(
    BuildContext context, {
    required String title,
    String? initialValue,
  }) {
    final controller = TextEditingController(text: initialValue ?? '');
    return showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(title),
        content: TextField(
          controller: controller,
          autofocus: true,
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
      ),
    );
  }

  Future<_DayFormResult?> _showDayDialog(
    BuildContext context, {
    required String title,
    String? initialName,
    int? initialWeekday,
  }) {
    final nameController = TextEditingController(text: initialName ?? '');
    var selectedWeekday = initialWeekday ?? DateTime.monday;

    return showDialog<_DayFormResult>(
      context: context,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setState) {
            return AlertDialog(
              title: Text(title),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  TextField(
                    controller: nameController,
                    decoration: const InputDecoration(labelText: 'Day Name'),
                  ),
                  const SizedBox(height: 12),
                  DropdownButtonFormField<int>(
                    initialValue: selectedWeekday,
                    decoration: const InputDecoration(labelText: 'Weekday'),
                    items: List.generate(7, (index) {
                      final weekday = index + 1;
                      return DropdownMenuItem(
                        value: weekday,
                        child: Text(weekdayLabel(weekday)),
                      );
                    }),
                    onChanged: (value) {
                      if (value == null) {
                        return;
                      }
                      setState(() => selectedWeekday = value);
                    },
                  ),
                ],
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.of(context).pop(),
                  child: const Text('Cancel'),
                ),
                FilledButton(
                  onPressed: () => Navigator.of(context).pop(
                    _DayFormResult(
                      nameController.text.trim(),
                      selectedWeekday,
                    ),
                  ),
                  child: const Text('Save'),
                ),
              ],
            );
          },
        );
      },
    );
  }
}

class _DayFormResult {
  const _DayFormResult(this.name, this.weekday);

  final String name;
  final int weekday;
}

class _MentzerProgramBody extends StatelessWidget {
  const _MentzerProgramBody({
    required this.programId,
    required this.daysAsync,
  });

  final int programId;
  final AsyncValue<List<WorkoutDay>> daysAsync;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    return daysAsync.when(
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (error, stack) => const Center(
        child: Text('Failed to load workouts.'),
      ),
      data: (days) {
        if (days.isEmpty) {
          return const Center(child: Text('No workouts found.'));
        }

        final ordered = [...days]
          ..sort((a, b) => a.orderIndex.compareTo(b.orderIndex));

        return ListView(
          children: [
            Text(
              'Cycle Workouts',
              style: textTheme.titleLarge,
            ),
            const SizedBox(height: 8),
            Card(
              child: ExpansionTile(
                title: const Text('Program notes'),
                childrenPadding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
                children: [
                  Text(
                    mentzerHitCycleTemplate.programNotes,
                    style: textTheme.bodyMedium,
                  ),
                ],
              ),
            ),
            const SizedBox(height: 12),
            ...ordered.map((day) {
              final workout =
                  mentzerHitCycleTemplate.workoutForIndex(day.orderIndex);
              return Card(
                child: ListTile(
                  title: Text(day.name),
                  subtitle: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const SizedBox(height: 4),
                      const Text('Rest 4–7 days after'),
                      const SizedBox(height: 4),
                      Text(mentzerSnippet(workout.sideNotes)),
                      Align(
                        alignment: Alignment.centerLeft,
                        child: TextButton(
                          onPressed: () => _showNotesSheet(
                            context,
                            title: day.name,
                            notes: workout.sideNotes,
                          ),
                          child: const Text('More'),
                        ),
                      ),
                    ],
                  ),
                  onTap: () =>
                      context.push('/programs/$programId/day/${day.id}'),
                ),
              );
            }),
          ],
        );
      },
    );
  }

  void _showNotesSheet(
    BuildContext context, {
    required String title,
    required String notes,
  }) {
    showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      builder: (context) => Padding(
        padding: const EdgeInsets.fromLTRB(16, 0, 16, 24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(title, style: Theme.of(context).textTheme.titleLarge),
            const SizedBox(height: 12),
            Text(notes),
          ],
        ),
      ),
    );
  }
}
