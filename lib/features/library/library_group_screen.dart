import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../data/providers.dart';
import '../../templates/mentzer_hit_cycle.dart';

class LibraryGroupScreen extends ConsumerWidget {
  const LibraryGroupScreen({super.key, required this.groupKey});

  final String groupKey;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final exercisesAsync = ref.watch(exercisesStreamProvider);
    final label = _labelFor(groupKey);

    return Scaffold(
      appBar: AppBar(title: Text(label)),
      body: exercisesAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (error, stack) => Center(
          child: Text('Error: $error'),
        ),
        data: (exercises) {
          final filtered = exercises.where((exercise) {
            if (!_isAllowedExercise(exercise.name, exercise.gifAssetPath)) {
              return false;
            }
            return _matchesGroup(exercise.name, exercise.primaryMuscle);
          }).toList()
            ..sort((a, b) => a.name.compareTo(b.name));

          if (filtered.isEmpty) {
            return const Center(child: Text('No exercises found.'));
          }

          return ListView.separated(
            padding: const EdgeInsets.all(16),
            itemCount: filtered.length,
            separatorBuilder: (_, _) => const Divider(height: 1),
            itemBuilder: (context, index) {
              final exercise = filtered[index];
              return ListTile(
                title: Text(exercise.name),
                onTap: () =>
                    context.push('/library/exercise/${exercise.id}'),
              );
            },
          );
        },
      ),
    );
  }

  String _labelFor(String key) {
    return _groups[key] ?? 'Library';
  }

  bool _matchesGroup(String name, String primaryMuscle) {
    final group = _groups[groupKey];
    if (group == null) {
      return false;
    }
    final muscle = primaryMuscle.toLowerCase().trim();
    switch (group) {
      case 'Chest':
        return muscle == 'chest';
      case 'Back':
        return muscle == 'back';
      case 'Shoulders':
        return muscle == 'shoulders';
      case 'Biceps':
        return muscle == 'biceps';
      case 'Triceps':
        return muscle == 'triceps';
      case 'Legs':
        return muscle == 'legs';
      case 'Abs':
        return muscle == 'abs';
      case 'Calves':
        return name.toLowerCase().contains('calf');
      case 'Stretching':
        return false;
      case 'Full Body':
        return false;
      default:
        return false;
    }
  }

  bool _isAllowedExercise(String name, String? gifPath) {
    if (gifPath != null && gifPath.isNotEmpty) {
      return true;
    }
    final normalized = name.toLowerCase().trim();
    return _mentzerExerciseNames.contains(normalized);
  }

  static final Map<String, String> _groups = {
    'chest': 'Chest',
    'back': 'Back',
    'shoulders': 'Shoulders',
    'biceps': 'Biceps',
    'triceps': 'Triceps',
    'legs': 'Legs',
    'abs': 'Abs',
    'calves': 'Calves',
    'stretching': 'Stretching',
    'full-body': 'Full Body',
  };

  static final Set<String> _mentzerExerciseNames = {
    for (final workout in mentzerHitCycleTemplate.workouts)
      for (final exercise in workout.exercises)
        exercise.name.toLowerCase().trim(),
  };
}
