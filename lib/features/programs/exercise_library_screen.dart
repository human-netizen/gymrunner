import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/db/app_database.dart';
import '../../data/providers.dart';

class ExerciseLibraryScreen extends ConsumerWidget {
  const ExerciseLibraryScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final exercisesAsync = ref.watch(exercisesStreamProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('Exercise Library')),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _addExercise(context, ref),
        icon: const Icon(Icons.add),
        label: const Text('Add Exercise'),
      ),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: exercisesAsync.when(
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (error, stack) => const Center(
            child: Text('Failed to load exercises.'),
          ),
          data: (exercises) {
            if (exercises.isEmpty) {
              return const Center(child: Text('No exercises yet.'));
            }

            return ListView.separated(
              itemCount: exercises.length,
              separatorBuilder: (_, _) => const Divider(height: 1),
              itemBuilder: (context, index) {
                final exercise = exercises[index];
                final subtitle = exercise.secondaryMuscles.isEmpty
                    ? exercise.primaryMuscle
                    : '${exercise.primaryMuscle} · ${exercise.secondaryMuscles}';

                return ListTile(
                  title: Text(exercise.name),
                  subtitle: Text(subtitle),
                  trailing: IconButton(
                    icon: const Icon(Icons.delete_outline),
                    tooltip: 'Delete',
                    onPressed: () => _deleteExercise(context, ref, exercise),
                  ),
                );
              },
            );
          },
        ),
      ),
    );
  }

  Future<void> _addExercise(BuildContext context, WidgetRef ref) async {
    final result = await _showExerciseDialog(context);
    if (result == null) {
      return;
    }

    final repo = ref.read(exerciseRepositoryProvider);
    final id = await repo.createExercise(
      name: result.name,
      primaryMuscle: result.primaryMuscle,
      secondaryMuscles: result.secondaryMuscles,
      defaultRestSeconds: result.defaultRestSeconds,
      defaultIncrementKg: result.defaultIncrementKg,
    );

    if (id == null && context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Exercise already exists.')),
      );
    }
  }

  Future<void> _deleteExercise(
    BuildContext context,
    WidgetRef ref,
    Exercise exercise,
  ) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text('Delete exercise?'),
          content: Text('Remove "${exercise.name}" from the library?'),
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

    if (confirmed != true) {
      return;
    }

    try {
      await ref.read(exerciseRepositoryProvider).deleteExercise(exercise.id);
    } catch (_) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Exercise is in use.')),
        );
      }
    }
  }

  Future<_ExerciseFormResult?> _showExerciseDialog(BuildContext context) {
    final nameController = TextEditingController();
    final secondaryController = TextEditingController();
    final restController = TextEditingController();
    final incrementController = TextEditingController(text: '2.5');
    var primaryMuscle = _primaryMuscles.first;

    return showDialog<_ExerciseFormResult>(
      context: context,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setState) {
            return AlertDialog(
              title: const Text('New Exercise'),
              content: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    TextField(
                      controller: nameController,
                      decoration: const InputDecoration(labelText: 'Name'),
                    ),
                    const SizedBox(height: 12),
                    DropdownButtonFormField<String>(
                      initialValue: primaryMuscle,
                      decoration:
                          const InputDecoration(labelText: 'Primary muscle'),
                      items: _primaryMuscles
                          .map(
                            (muscle) => DropdownMenuItem(
                              value: muscle,
                              child: Text(muscle),
                            ),
                          )
                          .toList(),
                      onChanged: (value) {
                        if (value == null) {
                          return;
                        }
                        setState(() => primaryMuscle = value);
                      },
                    ),
                    const SizedBox(height: 12),
                    TextField(
                      controller: secondaryController,
                      decoration: const InputDecoration(
                        labelText: 'Secondary muscles (comma separated)',
                      ),
                    ),
                    const SizedBox(height: 12),
                    TextField(
                      controller: restController,
                      decoration: const InputDecoration(
                        labelText: 'Default rest seconds',
                      ),
                      keyboardType: TextInputType.number,
                    ),
                    const SizedBox(height: 12),
                    TextField(
                      controller: incrementController,
                      decoration: const InputDecoration(
                        labelText: 'Default increment (kg)',
                      ),
                      keyboardType:
                          const TextInputType.numberWithOptions(decimal: true),
                    ),
                  ],
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.of(context).pop(),
                  child: const Text('Cancel'),
                ),
                FilledButton(
                  onPressed: () {
                    final name = nameController.text.trim();
                    if (name.isEmpty) {
                      Navigator.of(context).pop();
                      return;
                    }

                    final rest = int.tryParse(restController.text.trim());
                    final increment =
                        double.tryParse(incrementController.text.trim());

                    Navigator.of(context).pop(
                      _ExerciseFormResult(
                        name: name,
                        primaryMuscle: primaryMuscle,
                        secondaryMuscles: secondaryController.text.trim(),
                        defaultRestSeconds: rest,
                        defaultIncrementKg: increment,
                      ),
                    );
                  },
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

class _ExerciseFormResult {
  const _ExerciseFormResult({
    required this.name,
    required this.primaryMuscle,
    required this.secondaryMuscles,
    required this.defaultRestSeconds,
    required this.defaultIncrementKg,
  });

  final String name;
  final String primaryMuscle;
  final String secondaryMuscles;
  final int? defaultRestSeconds;
  final double? defaultIncrementKg;
}

const List<String> _primaryMuscles = [
  'chest',
  'back',
  'shoulders',
  'biceps',
  'triceps',
  'legs',
  'abs',
];
