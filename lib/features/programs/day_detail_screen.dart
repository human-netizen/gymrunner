import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../app/weekday_labels.dart';
import '../../data/db/app_database.dart';
import '../../data/providers.dart';
import '../../data/repositories/prescription_repository.dart';

class DayDetailScreen extends ConsumerWidget {
  const DayDetailScreen({
    super.key,
    required this.programId,
    required this.dayId,
  });

  final int programId;
  final int dayId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final dayAsync = ref.watch(workoutDayProvider(dayId));
    final daysAsync = ref.watch(workoutDaysProvider(programId));
    final prescriptionsAsync = ref.watch(prescriptionsProvider(dayId));

    return Scaffold(
      appBar: AppBar(
        title: Text(
          dayAsync.maybeWhen(
            data: (day) => day?.name ?? 'Workout Day',
            orElse: () => 'Workout Day',
          ),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.edit),
            tooltip: 'Edit day',
            onPressed: () {
              final day = dayAsync.asData?.value;
              final days = daysAsync.asData?.value ?? const <WorkoutDay>[];
              if (day != null) {
                _editWorkoutDay(context, ref, day, days);
              }
            },
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () =>
            context.push('/programs/$programId/day/$dayId/pick'),
        icon: const Icon(Icons.add),
        label: const Text('Add Exercise'),
      ),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            dayAsync.when(
              loading: () => const Text('Loading day...'),
              error: (error, stack) => const Text('Failed to load day.'),
              data: (day) {
                if (day == null) {
                  return const Text('Workout day not found.');
                }
                return Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      day.name,
                      style: Theme.of(context).textTheme.titleLarge,
                    ),
                    const SizedBox(height: 4),
                    Text(weekdayLabel(day.weekday)),
                  ],
                );
              },
            ),
            const SizedBox(height: 16),
            Text(
              'Exercises',
              style: Theme.of(context).textTheme.titleMedium,
            ),
            const SizedBox(height: 8),
            Expanded(
              child: prescriptionsAsync.when(
                loading: () => const Center(child: CircularProgressIndicator()),
                error: (error, stack) => const Center(
                  child: Text('Failed to load exercises.'),
                ),
                data: (prescriptions) {
                  if (prescriptions.isEmpty) {
                    return const Center(child: Text('No exercises yet.'));
                  }

                  return ListView.separated(
                    itemCount: prescriptions.length,
                    separatorBuilder: (_, _) => const Divider(height: 1),
                    itemBuilder: (context, index) {
                      final item = prescriptions[index];
                      final restSeconds = item.prescription.restSeconds ??
                          item.exercise.defaultRestSeconds;
                      final repRange =
                          '${item.prescription.repMin}-${item.prescription.repMax}';

                      return ListTile(
                        title: Text(item.exercise.name),
                        subtitle: Text(
                          '${item.prescription.setsTarget} x $repRange · Rest $restSeconds s',
                        ),
                        onTap: () => context.push(
                          '/programs/$programId/day/$dayId/prescription/${item.prescription.id}',
                        ),
                        trailing: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            IconButton(
                              tooltip: 'Move up',
                              onPressed: index == 0
                                  ? null
                                  : () => _movePrescription(
                                        ref,
                                        prescriptions,
                                        index,
                                        index - 1,
                                      ),
                              icon: const Icon(Icons.arrow_upward),
                            ),
                            IconButton(
                              tooltip: 'Move down',
                              onPressed: index == prescriptions.length - 1
                                  ? null
                                  : () => _movePrescription(
                                        ref,
                                        prescriptions,
                                        index,
                                        index + 1,
                                      ),
                              icon: const Icon(Icons.arrow_downward),
                            ),
                            IconButton(
                              tooltip: 'Remove',
                              onPressed: () => ref
                                  .read(prescriptionRepositoryProvider)
                                  .deletePrescription(item.prescription.id),
                              icon: const Icon(Icons.delete_outline),
                            ),
                          ],
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

  void _movePrescription(
    WidgetRef ref,
    List<PrescriptionWithExercise> items,
    int from,
    int to,
  ) {
    if (to < 0 || to >= items.length) {
      return;
    }

    final orderedIds = items.map((item) => item.prescription.id).toList();
    final moved = orderedIds.removeAt(from);
    orderedIds.insert(to, moved);
    ref
        .read(prescriptionRepositoryProvider)
        .reorderPrescriptions(dayId, orderedIds);
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
    if (result == null || result.name.isEmpty) {
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
