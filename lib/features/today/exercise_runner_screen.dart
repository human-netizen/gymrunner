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
  final ScrollController _scrollController = ScrollController();
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
    _scrollController.dispose();
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
              controller: _scrollController,
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
                                  (set) => ListTile(
                                    contentPadding: EdgeInsets.zero,
                                    title: Text(
                                      'Warm-up ${set.setIndex}: ${set.weightKg.toStringAsFixed(1)} x ${set.reps}',
                                    ),
                                    onTap: () => _showEditSetSheet(set),
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
                          (set) => ListTile(
                            contentPadding: EdgeInsets.zero,
                            title: Text(
                              'Set ${set.setIndex}: ${set.weightKg.toStringAsFixed(1)} x ${set.reps}',
                            ),
                            onTap: () => _showEditSetSheet(set),
                          ),
                        )
                        .toList(),
                  ),
                const SizedBox(height: 12),
                Text(
                  'Log next set',
                  style: Theme.of(context).textTheme.titleMedium,
                ),
                const SizedBox(height: 8),
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
                          Wrap(
                            spacing: 8,
                            runSpacing: 8,
                            children: [
                              OutlinedButton(
                                onPressed: () => _adjustWeight(
                                  -detail.sessionExercise.incrementKg,
                                ),
                                child: Text(
                                  '-${detail.sessionExercise.incrementKg.toStringAsFixed(1)}',
                                ),
                              ),
                              OutlinedButton(
                                onPressed: () => _adjustWeight(
                                  detail.sessionExercise.incrementKg,
                                ),
                                child: Text(
                                  '+${detail.sessionExercise.incrementKg.toStringAsFixed(1)}',
                                ),
                              ),
                              OutlinedButton(
                                onPressed: () => _copyLastWeight(
                                  detail,
                                  suggestedWeight,
                                ),
                                child: const Text('Copy last'),
                              ),
                            ],
                          ),
                          const SizedBox(height: 8),
                          Wrap(
                            spacing: 8,
                            runSpacing: 8,
                            children: [
                              OutlinedButton(
                                onPressed: () => _adjustWeight(2.5),
                                child: const Text('+2.5'),
                              ),
                              OutlinedButton(
                                onPressed: () => _adjustWeight(5),
                                child: const Text('+5'),
                              ),
                              OutlinedButton(
                                onPressed: () => _adjustWeight(10),
                                child: const Text('+10'),
                              ),
                              OutlinedButton(
                                onPressed: () => _adjustWeight(-2.5),
                                child: const Text('-2.5'),
                              ),
                              OutlinedButton(
                                onPressed: () => _adjustWeight(-5),
                                child: const Text('-5'),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          TextField(
                            controller: _repsController,
                            decoration: const InputDecoration(labelText: 'Reps'),
                            keyboardType: TextInputType.number,
                          ),
                          const SizedBox(height: 8),
                          Wrap(
                            spacing: 8,
                            children: [
                              OutlinedButton(
                                onPressed: () => _adjustReps(
                                  -1,
                                  detail.sessionExercise.repMin,
                                ),
                                child: const Text('-1'),
                              ),
                              OutlinedButton(
                                onPressed: () => _adjustReps(
                                  1,
                                  detail.sessionExercise.repMin,
                                ),
                                child: const Text('+1'),
                              ),
                            ],
                          ),
                          const SizedBox(height: 8),
                          Wrap(
                            spacing: 8,
                            runSpacing: 8,
                            children: _repChips(
                              detail.sessionExercise.repMin,
                              detail.sessionExercise.repMax,
                            ),
                          ),
                        ],
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
                          detail.sessionExercise.repMin,
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
                const SizedBox(height: 12),
                OutlinedButton(
                  onPressed: () => _goToNextExercise(detail),
                  child: const Text('Next Exercise'),
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
    final sets = detail.workingSets;

    if (sets.isNotEmpty && sets.length != _lastSetCount) {
      final lastSet = sets.last;
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

  int? _parseReps() {
    return int.tryParse(_repsController.text.trim());
  }

  void _adjustWeight(double delta) {
    final current = _parseWeight() ?? 0.0;
    var next = current + delta;
    if (next < 0) {
      next = 0;
    }
    _setWeightText(next);
    _userEditedWeight = true;
  }

  void _copyLastWeight(
    SessionExerciseDetail detail,
    double? suggestedWeight,
  ) {
    final workingSets = detail.workingSets;
    if (workingSets.isNotEmpty) {
      _setWeightText(workingSets.last.weightKg);
      _userEditedWeight = true;
      return;
    }
    if (suggestedWeight != null) {
      _setWeightText(suggestedWeight);
      _userEditedWeight = true;
    }
  }

  void _adjustReps(int delta, int repMin) {
    final current = _parseReps() ?? repMin;
    var next = current + delta;
    if (next < 0) {
      next = 0;
    }
    _setRepsText(next);
    _userEditedReps = true;
  }

  List<Widget> _repChips(int repMin, int repMax) {
    if (repMax < repMin) {
      return const [];
    }
    return List.generate(repMax - repMin + 1, (index) {
      final value = repMin + index;
      return OutlinedButton(
        onPressed: () {
          _setRepsText(value);
          _userEditedReps = true;
        },
        child: Text(value.toString()),
      );
    });
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

  void _scrollToBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!_scrollController.hasClients) {
        return;
      }
      final position = _scrollController.position.maxScrollExtent;
      _scrollController.animateTo(
        position,
        duration: const Duration(milliseconds: 200),
        curve: Curves.easeOut,
      );
    });
  }

  Future<void> _saveSet(
    BuildContext context,
    int sessionExerciseId,
    int restSeconds,
    int repMin,
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

    final setLog = await ref
        .read(sessionRepositoryProvider)
        .addSetReturningLog(sessionExerciseId, weight, reps);
    ref.read(restTimerProvider.notifier).start(restSeconds);

    if (!mounted) {
      return;
    }

    _setRepsText(repMin);
    _userEditedReps = false;

    ScaffoldMessenger.of(context).hideCurrentSnackBar();
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          'Saved Set ${setLog.setIndex}: ${setLog.weightKg.toStringAsFixed(1)} x ${setLog.reps}',
        ),
        action: SnackBarAction(
          label: 'UNDO',
          onPressed: () {
            ref.read(sessionRepositoryProvider).deleteSetLog(setLog.id);
          },
        ),
      ),
    );

    _scrollToBottom();
  }

  Future<void> _showEditSetSheet(SetLog setLog) async {
    final weightController =
        TextEditingController(text: setLog.weightKg.toStringAsFixed(1));
    final repsController =
        TextEditingController(text: setLog.reps.toString());

    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      builder: (context) {
        return Padding(
          padding: EdgeInsets.fromLTRB(
            16,
            16,
            16,
            16 + MediaQuery.viewInsetsOf(context).bottom,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                setLog.isWarmup ? 'Edit Warm-up Set' : 'Edit Set',
                style: Theme.of(context).textTheme.titleMedium,
              ),
              const SizedBox(height: 12),
              TextField(
                controller: weightController,
                decoration: const InputDecoration(labelText: 'Weight (kg)'),
                keyboardType: const TextInputType.numberWithOptions(
                  decimal: true,
                ),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: repsController,
                decoration: const InputDecoration(labelText: 'Reps'),
                keyboardType: TextInputType.number,
              ),
              const SizedBox(height: 16),
              Row(
                children: [
                  Expanded(
                    child: FilledButton(
                      onPressed: () async {
                        final weight =
                            double.tryParse(weightController.text.trim());
                        final reps =
                            int.tryParse(repsController.text.trim());
                        if (weight == null || reps == null) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(
                              content: Text('Enter a weight and reps.'),
                            ),
                          );
                          return;
                        }

                        await ref
                            .read(sessionRepositoryProvider)
                            .updateSetLog(
                              id: setLog.id,
                              weightKg: weight,
                              reps: reps,
                            );

                        if (!context.mounted) {
                          return;
                        }
                        Navigator.of(context).pop();
                      },
                      child: const Text('Save'),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: OutlinedButton(
                      onPressed: () async {
                        final confirmed = await showDialog<bool>(
                          context: context,
                          builder: (context) => AlertDialog(
                            title: const Text('Delete set?'),
                            content: const Text('This cannot be undone.'),
                            actions: [
                              TextButton(
                                onPressed: () =>
                                    Navigator.of(context).pop(false),
                                child: const Text('Cancel'),
                              ),
                              FilledButton(
                                onPressed: () =>
                                    Navigator.of(context).pop(true),
                                child: const Text('Delete'),
                              ),
                            ],
                          ),
                        );

                        if (confirmed != true) {
                          return;
                        }

                        await ref
                            .read(sessionRepositoryProvider)
                            .deleteSetLog(setLog.id);

                        if (!context.mounted) {
                          return;
                        }
                        Navigator.of(context).pop();
                      },
                      child: const Text('Delete'),
                    ),
                  ),
                ],
              ),
            ],
          ),
        );
      },
    );

    weightController.dispose();
    repsController.dispose();
  }

  Future<void> _goToNextExercise(SessionExerciseDetail detail) async {
    final nextId = await ref
        .read(sessionRepositoryProvider)
        .getNextSessionExerciseId(
          detail.sessionExercise.sessionId,
          detail.sessionExercise.id,
        );

    if (!mounted) {
      return;
    }

    if (nextId == null) {
      Navigator.of(context).pop();
      return;
    }

    context.push('/today/runner/$nextId');
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
