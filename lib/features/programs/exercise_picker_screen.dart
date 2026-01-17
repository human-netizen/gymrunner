import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/providers.dart';

class ExercisePickerScreen extends ConsumerStatefulWidget {
  const ExercisePickerScreen({super.key, required this.dayId});

  final int dayId;

  @override
  ConsumerState<ExercisePickerScreen> createState() =>
      _ExercisePickerScreenState();
}

class _ExercisePickerScreenState
    extends ConsumerState<ExercisePickerScreen> {
  final TextEditingController _searchController = TextEditingController();

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final exercisesAsync = ref.watch(exercisesStreamProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('Pick Exercise')),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            TextField(
              controller: _searchController,
              decoration: const InputDecoration(
                labelText: 'Search exercises',
                prefixIcon: Icon(Icons.search),
              ),
              onChanged: (_) => setState(() {}),
            ),
            const SizedBox(height: 12),
            Expanded(
              child: exercisesAsync.when(
                loading: () => const Center(child: CircularProgressIndicator()),
                error: (error, stack) => const Center(
                  child: Text('Failed to load exercises.'),
                ),
                data: (exercises) {
                  final query = _searchController.text.trim().toLowerCase();
                  final filtered = query.isEmpty
                      ? exercises
                      : exercises
                          .where(
                            (exercise) =>
                                exercise.name.toLowerCase().contains(query),
                          )
                          .toList();

                  if (filtered.isEmpty) {
                    return const Center(child: Text('No matches found.'));
                  }

                  return ListView.separated(
                    itemCount: filtered.length,
                    separatorBuilder: (_, _) => const Divider(height: 1),
                    itemBuilder: (context, index) {
                      final exercise = filtered[index];
                      return ListTile(
                        title: Text(exercise.name),
                        subtitle: Text(exercise.primaryMuscle),
                        onTap: () async {
                          await ref
                              .read(prescriptionRepositoryProvider)
                              .addPrescription(widget.dayId, exercise.id);
                          if (!context.mounted) {
                            return;
                          }
                          Navigator.of(context).pop();
                        },
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
}
