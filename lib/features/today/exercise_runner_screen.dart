import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../data/db/app_database.dart';
import '../../data/providers.dart';
import '../../data/strength_utils.dart';
import '../../data/repositories/session_repository.dart';
import '../../state/rest_timer.dart';
import 'rest_timer_bar.dart';

class ExerciseRunnerScreen extends ConsumerStatefulWidget {
  const ExerciseRunnerScreen({
    super.key,
    required this.sessionExerciseId,
  });

  final int sessionExerciseId;

  @override
  ConsumerState<ExerciseRunnerScreen> createState() =>
      _ExerciseRunnerScreenState();
}

class _ExerciseRunnerScreenState extends ConsumerState<ExerciseRunnerScreen> {
  final TextEditingController _weightController = TextEditingController();
  final TextEditingController _repsController = TextEditingController();
  int _lastSetCount = -1;
  bool _setCurrent = false;
  List<WarmupSet> _warmupSets = [];
  bool _updatingWeight = false;
  bool _updatingReps = false;
  bool _userEditedWeight = false;
  bool _userEditedReps = false;

  @override
  void initState() {
    super.initState();
    _weightController.addListener(() {
      if (!_updatingWeight) {
        _userEditedWeight = true;
      }
    });
    _repsController.addListener(() {
      if (!_updatingReps) {
        _userEditedReps = true;
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
    final detailAsync =
        ref.watch(sessionExerciseDetailProvider(widget.sessionExerciseId));
    final settings = ref.watch(settingsStreamProvider).asData?.value;
    final defaultWeight = settings?.barWeightKg ?? 20.0;
    final timerState = ref.watch(restTimerProvider);
    final bottomInset = MediaQuery.viewInsetsOf(context).bottom;
    const actionBarHeight = 72.0;
    final detail = detailAsync.asData?.value;

    return Scaffold(
      resizeToAvoidBottomInset: true,
      appBar: AppBar(title: const Text('Exercise')),
      body: SafeArea(
        child: detailAsync.when(
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (error, stack) => const Center(
            child: Text('Failed to load exercise.'),
          ),
          data: (detail) {
            if (detail == null) {
              return const Center(child: Text('Exercise not found.'));
            }

            _ensureCurrentExercise(detail);

            final lastPerformanceAsync =
                ref.watch(lastPerformanceProvider(detail.exercise.id));
            final lastPerformance = lastPerformanceAsync.asData?.value;
            final suggestedWeight =
                detail.sessionExercise.suggestedWorkingWeightKg;
            final warmupSets = detail.warmupSets;
            final workingSets = detail.workingSets;

            _maybePrefill(detail, defaultWeight);

            final targetLabel =
                '${detail.sessionExercise.setsTarget} x ${detail.sessionExercise.repMin}-${detail.sessionExercise.repMax}';
            final restLabel = '${detail.sessionExercise.restSeconds}s rest';
            final nextSet = detail.loggedWorkingSetsCount + 1;
            final suggestionText = suggestedWeight == null
                ? 'Suggested: -- (no history yet)'
                : 'Suggested: ${suggestedWeight.toStringAsFixed(1)} kg (based on last session)';
            final hasWarmups =
                _warmupSets.isNotEmpty || warmupSets.isNotEmpty;

            return ListView(
              padding: EdgeInsets.fromLTRB(
                16,
                16,
                16,
                actionBarHeight + 16 + bottomInset,
              ),
              children: [
                Text(
                  detail.exercise.name,
                  style: Theme.of(context)
                      .textTheme
                      .displaySmall
                      ?.copyWith(fontWeight: FontWeight.w700),
                ),
                const SizedBox(height: 8),
                Text('$targetLabel - $restLabel'),
                const SizedBox(height: 8),
                Row(
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    Expanded(child: Text(suggestionText)),
                    if (suggestedWeight != null)
                      TextButton(
                        onPressed: () {
                          _setWeightText(suggestedWeight);
                          _userEditedWeight = true;
                        },
                        child: const Text('Use'),
                      ),
                    if (suggestedWeight != null)
                      TextButton(
                        onPressed: () => _showSuggestionWhy(
                          context,
                          lastPerformance,
                          detail,
                        ),
                        child: const Text('Why?'),
                      ),
                  ],
                ),
                const SizedBox(height: 8),
                Card(
                  elevation: 0,
                  child: Padding(
                    padding: const EdgeInsets.all(12),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Warm-up',
                          style: Theme.of(context).textTheme.titleMedium,
                        ),
                        const SizedBox(height: 8),
                        OutlinedButton(
                          onPressed: () => _generateWarmups(
                            detail,
                            defaultWeight,
                            suggestedWeight,
                          ),
                          child: const Text('Generate Warm-up'),
                        ),
                        if (!hasWarmups)
                          const Padding(
                            padding: EdgeInsets.only(top: 8),
                            child: Text('No warm-up sets yet.'),
                          ),
                        if (_warmupSets.isNotEmpty) ...[
                          const SizedBox(height: 8),
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: _warmupSets
                                .map(
                                  (warmup) => Row(
                                    children: [
                                      Expanded(
                                        child: Text(
                                          '${warmup.weightKg.toStringAsFixed(1)} kg x ${warmup.reps}',
                                        ),
                                      ),
                                      TextButton(
                                        onPressed: () => _logWarmup(
                                          detail.sessionExercise.id,
                                          warmup,
                                        ),
                                        child: const Text('Log'),
                                      ),
                                    ],
                                  ),
                                )
                                .toList(),
                          ),
                        ],
                        if (warmupSets.isNotEmpty) ...[
                          const SizedBox(height: 8),
                          Text(
                            'Logged warm-up sets',
                            style: Theme.of(context).textTheme.labelLarge,
                          ),
                          const SizedBox(height: 4),
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: warmupSets
                                .map(
                                  (set) => Padding(
                                    padding:
                                        const EdgeInsets.symmetric(vertical: 2),
                                    child: Text(
                                      'Warm-up ${set.setIndex}: ${set.weightKg.toStringAsFixed(1)} x ${set.reps}',
                                    ),
                                  ),
                                )
                                .toList(),
                          ),
                        ],
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 12),
                Text(
                  lastPerformanceAsync.when(
                    data: (performance) =>
                        performance?.toSummaryLine() ?? 'No history yet',
                    loading: () => 'Loading history...',
                    error: (error, stack) => 'No history yet',
                  ),
                ),
                const SizedBox(height: 16),
                Text('Next set: $nextSet'),
                const SizedBox(height: 8),
                if (detail.isTargetReached)
                  Text(
                    'Target reached',
                    style: Theme.of(context).textTheme.labelLarge?.copyWith(
                          color: Theme.of(context).colorScheme.primary,
                        ),
                  ),
                const SizedBox(height: 12),
                Text(
                  'Working sets',
                  style: Theme.of(context).textTheme.titleMedium,
                ),
                const SizedBox(height: 8),
                if (workingSets.isEmpty)
                  const Text('No working sets logged yet.')
                else
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: workingSets
                        .map(
                          (set) => Padding(
                            padding: const EdgeInsets.symmetric(vertical: 2),
                            child: Text(
                              'Set ${set.setIndex}: ${set.weightKg.toStringAsFixed(1)} x ${set.reps}',
                            ),
                          ),
                        )
                        .toList(),
                  ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          TextField(
                            controller: _weightController,
                            decoration: const InputDecoration(
                              labelText: 'Weight (kg)',
                            ),
                            keyboardType: const TextInputType.numberWithOptions(
                              decimal: true,
                            ),
                          ),
                          Align(
                            alignment: Alignment.centerLeft,
                            child: TextButton(
                              onPressed: () =>
                                  _openPlates(context, suggestedWeight),
                              child: const Text('Plates'),
                            ),
                          ),
                        ],
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
                const SizedBox(height: 12),
                Row(
                  children: [
                    Expanded(
                      child: FilledButton(
                        onPressed: () => _saveSet(
                          context,
                          detail.sessionExercise.id,
                          detail.sessionExercise.restSeconds,
                        ),
                        child: const Text('Save Set'),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: OutlinedButton(
                        onPressed: detail.sets.isEmpty
                            ? null
                            : () => _deleteLastSet(detail.sessionExercise.id),
                        child: const Text('Undo Last'),
                      ),
                    ),
                  ],
                ),
                if (timerState.initialSeconds > 0) ...[
                  const SizedBox(height: 12),
                  const RestTimerBar(),
                ],
              ],
            );
          },
        ),
      ),
      bottomNavigationBar: detail == null
          ? null
          : SafeArea(
              top: false,
              child: Padding(
                padding: EdgeInsets.only(bottom: bottomInset),
                child: Container(
                  height: actionBarHeight,
                  padding: const EdgeInsets.all(12),
                  child: Row(
                    children: [
                      Expanded(
                        child: OutlinedButton.icon(
                          onPressed: () => Navigator.of(context).pop(),
                          icon: const Icon(Icons.arrow_back),
                          label: const Text('Back to Overview'),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: FilledButton(
                          onPressed: () => _toggleCompletion(
                            detail.sessionExercise.id,
                            !detail.sessionExercise.isCompleted,
                          ),
                          child: Text(
                            detail.sessionExercise.isCompleted
                                ? 'Mark Not Done'
                                : 'Mark Done',
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
    );
  }

  void _ensureCurrentExercise(SessionExerciseDetail detail) {
    if (_setCurrent) {
      return;
    }
    _setCurrent = true;
    Future<void>.microtask(() async {
      await ref.read(sessionRepositoryProvider).setCurrentExercise(
            detail.sessionExercise.sessionId,
            detail.sessionExercise.id,
          );
    });
  }

  void _maybePrefill(
    SessionExerciseDetail detail,
    double defaultWeight,
  ) {
    final sets = detail.sets;

    if (sets.isNotEmpty && sets.length != _lastSetCount) {
      final lastSet = _latestSet(sets);
      _setWeightText(lastSet.weightKg);
      _setRepsText(lastSet.reps);
      _userEditedWeight = false;
      _userEditedReps = false;
      _lastSetCount = sets.length;
      return;
    }

    if (sets.isEmpty) {
      if (!_userEditedWeight) {
        final suggested = detail.sessionExercise.suggestedWorkingWeightKg;
        if (suggested != null) {
          _setWeightText(suggested);
        } else if (_weightController.text.isEmpty) {
          _setWeightText(defaultWeight);
        }
      }

      if (!_userEditedReps && _repsController.text.isEmpty) {
        _setRepsText(detail.sessionExercise.repMin);
      }
    }

    _lastSetCount = sets.length;
  }

  void _generateWarmups(
    SessionExerciseDetail detail,
    double barWeightKg,
    double? suggestedWeight,
  ) {
    final inputWeight = _parseWeight();
    final workingWeight = suggestedWeight ??
        (inputWeight != null && inputWeight > 0 ? inputWeight : barWeightKg);
    setState(() {
      _warmupSets = generateWarmupSets(
        workingWeightKg: workingWeight,
        barWeightKg: barWeightKg,
      );
    });
  }

  Future<void> _logWarmup(int sessionExerciseId, WarmupSet warmup) async {
    await ref.read(sessionRepositoryProvider).addSet(
          sessionExerciseId,
          warmup.weightKg,
          warmup.reps,
          isWarmup: true,
        );
  }

  void _openPlates(BuildContext context, double? suggestedWeight) {
    final targetWeight =
        _parseWeight() ?? suggestedWeight ?? 0.0;
    final safeTarget = targetWeight <= 0 ? 0.0 : targetWeight;
    context.push('/plates?target=${safeTarget.toStringAsFixed(1)}');
  }

  void _showSuggestionWhy(
    BuildContext context,
    LastPerformance? lastPerformance,
    SessionExerciseDetail detail,
  ) {
    final summary = lastPerformance?.toSummaryLine() ?? 'No history yet';
    final rule =
        'Rule: add ${detail.sessionExercise.incrementKg.toStringAsFixed(1)} kg when the first ${detail.sessionExercise.setsTarget} sets reach ${detail.sessionExercise.repMax} reps.';
    showDialog<void>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Suggestion'),
        content: Text('$summary\n$rule'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('OK'),
          ),
        ],
      ),
    );
  }

  double? _parseWeight() {
    return double.tryParse(_weightController.text.trim());
  }

  SetLog _latestSet(List<SetLog> sets) {
    return sets.reduce(
      (a, b) => a.createdAt.isAfter(b.createdAt) ? a : b,
    );
  }

  void _setWeightText(double weight) {
    _updatingWeight = true;
    _weightController.text = weight.toStringAsFixed(1);
    _updatingWeight = false;
  }

  void _setRepsText(int reps) {
    _updatingReps = true;
    _repsController.text = reps.toString();
    _updatingReps = false;
  }

  Future<void> _saveSet(
    BuildContext context,
    int sessionExerciseId,
    int restSeconds,
  ) async {
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
    ref.read(restTimerProvider.notifier).start(restSeconds);
  }

  Future<void> _deleteLastSet(int sessionExerciseId) async {
    await ref.read(sessionRepositoryProvider).deleteLastSet(sessionExerciseId);
  }

  Future<void> _toggleCompletion(int sessionExerciseId, bool done) async {
    await ref
        .read(sessionRepositoryProvider)
        .toggleExerciseCompleted(sessionExerciseId, done);
  }
}
