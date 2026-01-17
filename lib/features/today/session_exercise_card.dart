import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/providers.dart';
import '../../data/repositories/session_repository.dart';
import '../../state/rest_timer.dart';

class SessionExerciseCard extends ConsumerStatefulWidget {
  const SessionExerciseCard({super.key, required this.data});

  final SessionExerciseWithExerciseAndSets data;

  @override
  ConsumerState<SessionExerciseCard> createState() =>
      _SessionExerciseCardState();
}

class _SessionExerciseCardState extends ConsumerState<SessionExerciseCard> {
  final TextEditingController _weightController = TextEditingController();
  final TextEditingController _repsController = TextEditingController();
  int _lastSetCount = -1;
  bool _hasPrefilled = false;
  bool _updatingWeight = false;
  bool _userEditedWeight = false;

  @override
  void initState() {
    super.initState();
    _weightController.addListener(() {
      if (!_updatingWeight) {
        _userEditedWeight = true;
      }
    });
  }

  @override
  void dispose() {
    _weightController.dispose();
    _repsController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final exercise = widget.data.exercise;
    final sessionExercise = widget.data.sessionExercise;
    final sets = widget.data.sets;
    final lastPerformanceAsync =
        ref.watch(lastPerformanceProvider(exercise.id));
    final lastPerformance = lastPerformanceAsync.asData?.value;

    _maybePrefill(lastPerformance);

    final targetDone = sets.length >= sessionExercise.setsTarget;
    final restSeconds = sessionExercise.restSeconds;
    final repRange = '${sessionExercise.repMin}-${sessionExercise.repMax}';

    return Card(
      elevation: 0,
      child: ExpansionTile(
        title: Row(
          children: [
            Expanded(
              child: Text(
                exercise.name,
                style: Theme.of(context).textTheme.titleMedium,
              ),
            ),
            if (targetDone)
              Text(
                'Target done ✓',
                style: Theme.of(context).textTheme.labelMedium?.copyWith(
                      color: Theme.of(context).colorScheme.primary,
                    ),
              ),
          ],
        ),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              '${sessionExercise.setsTarget} x $repRange · Rest ${restSeconds}s',
            ),
            const SizedBox(height: 4),
            Text(
              lastPerformanceAsync.when(
                data: (performance) =>
                    performance?.toSummaryLine() ?? 'No history yet',
                loading: () => 'Loading history...',
                error: (error, stack) => 'No history yet',
              ),
            ),
          ],
        ),
        children: [
          if (sets.isEmpty)
            const Padding(
              padding: EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              child: Text('No sets logged yet.'),
            )
          else
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Column(
                children: sets
                    .map(
                      (set) => Align(
                        alignment: Alignment.centerLeft,
                        child: Padding(
                          padding: const EdgeInsets.symmetric(vertical: 4),
                          child: Text(
                            'Set ${set.setIndex}: ${set.weightKg.toStringAsFixed(1)} x ${set.reps}',
                          ),
                        ),
                      ),
                    )
                    .toList(),
              ),
            ),
          const SizedBox(height: 12),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _weightController,
                    decoration: const InputDecoration(labelText: 'Weight (kg)'),
                    keyboardType: const TextInputType.numberWithOptions(
                      decimal: true,
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: TextField(
                    controller: _repsController,
                    decoration: const InputDecoration(labelText: 'Reps'),
                    keyboardType: TextInputType.number,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 12),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Row(
              children: [
                Expanded(
                  child: FilledButton(
                    onPressed: () => _saveSet(context, sessionExercise.id),
                    child: const Text('Save Set'),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: OutlinedButton(
                    onPressed: sets.isEmpty
                        ? null
                        : () => _deleteLastSet(sessionExercise.id),
                    child: const Text('Undo Last Set'),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 12),
        ],
      ),
    );
  }

  void _maybePrefill(LastPerformance? lastPerformance) {
    final sets = widget.data.sets;
    final sessionExercise = widget.data.sessionExercise;

    if (sets.isNotEmpty && sets.length != _lastSetCount) {
      _setWeightText(sets.last.weightKg);
      _setRepsText(sets.last.reps);
      _lastSetCount = sets.length;
      _hasPrefilled = true;
      _userEditedWeight = false;
      return;
    }

    if (sets.isEmpty) {
      final lastWeight = lastPerformance?.firstWeight;
      if (!_userEditedWeight) {
        if (lastWeight != null) {
          _setWeightText(lastWeight);
          _hasPrefilled = true;
        } else if (!_hasPrefilled) {
          _setWeightText(20.0);
          _hasPrefilled = true;
        }
      }
      if (_repsController.text.isEmpty) {
        _setRepsText(sessionExercise.repMax);
      }
    }

    _lastSetCount = sets.length;
  }

  void _setWeightText(double weight) {
    _updatingWeight = true;
    _weightController.text = weight.toStringAsFixed(1);
    _updatingWeight = false;
  }

  void _setRepsText(int reps) {
    _repsController.text = reps.toString();
  }

  Future<void> _saveSet(BuildContext context, int sessionExerciseId) async {
    final weightText = _weightController.text.trim();
    final repsText = _repsController.text.trim();
    final weight = double.tryParse(weightText);
    final reps = int.tryParse(repsText);

    if (weight == null || reps == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Enter a weight and reps.')),
      );
      return;
    }

    await ref
        .read(sessionRepositoryProvider)
        .addSet(sessionExerciseId, weight, reps);
    ref
        .read(restTimerProvider.notifier)
        .start(widget.data.sessionExercise.restSeconds);
  }

  Future<void> _deleteLastSet(int sessionExerciseId) async {
    await ref.read(sessionRepositoryProvider).deleteLastSet(sessionExerciseId);
  }
}
