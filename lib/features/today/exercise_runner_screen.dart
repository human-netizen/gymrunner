import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../data/providers.dart';
import '../../data/repositories/session_repository.dart';
import '../../services/mentzer_cycle_service.dart';
import '../../state/rest_timer.dart';

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
  final FocusNode _weightFocus = FocusNode();
  final FocusNode _repsFocus = FocusNode();
  final ScrollController _scrollController = ScrollController();
  int _lastSetCount = -1;
  bool _setCurrent = false;
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
    _weightFocus.dispose();
    _repsFocus.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    ref.listen<RestTimerState>(restTimerProvider, (previous, next) {
      if (previous == null) {
        return;
      }
      if (previous.remainingSeconds > 0 && next.remainingSeconds == 0) {
        HapticFeedback.mediumImpact();
      }
    });

    final detailAsync =
        ref.watch(sessionExerciseDetailProvider(widget.sessionExerciseId));
    final settings = ref.watch(settingsStreamProvider).asData?.value;
    final defaultWeight = settings?.barWeightKg ?? 20.0;
    final timerState = ref.watch(restTimerProvider);
    final bottomInset = MediaQuery.viewInsetsOf(context).bottom;
    const actionBarHeight = 72.0;
    final detail = detailAsync.asData?.value;
    final activeSession = ref.watch(activeSessionProvider).asData?.value;
    final mentzerService = ref.watch(mentzerCycleServiceProvider);
    final programAsync = activeSession?.programId == null
        ? const AsyncValue.data(null)
        : ref.watch(programProvider(activeSession!.programId!));
    final isMentzer = programAsync.asData?.value != null &&
        mentzerService.isMentzerProgramName(
          programAsync.asData!.value!.name,
        );
    final workoutDayAsync = isMentzer && activeSession?.workoutDayId != null
        ? ref.watch(workoutDayProvider(activeSession!.workoutDayId!))
        : const AsyncValue.data(null);
    final workoutIndex = workoutDayAsync.asData?.value?.orderIndex ?? 0;

    return Scaffold(
      resizeToAvoidBottomInset: true,
      appBar: AppBar(
        title: const Text('Exercise'),
      ),
      body: SafeArea(
        child: detailAsync.when(
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (error, stack) => _errorView(
            error: error,
            onRetry: () => ref.invalidate(
              sessionExerciseDetailProvider(widget.sessionExerciseId),
            ),
          ),
          data: (detail) {
            if (detail == null) {
              return const Center(child: Text('Exercise not found.'));
            }

            _ensureCurrentExercise(detail);
            final activeSession = ref.watch(activeSessionProvider).asData?.value;
            final isDeloadSession = activeSession?.id ==
                    detail.sessionExercise.sessionId &&
                (activeSession?.isDeload ?? false);

            final lastPerformance =
                ref.watch(lastPerformanceProvider(detail.exercise.id)).asData?.value;
            final bestE1rm = ref
                .watch(exercisePRsProvider(detail.exercise.id))
                .asData
                ?.value
                .bestE1rm
                ?.value;
            final suggestedWeight =
                detail.sessionExercise.suggestedWorkingWeightKg;
            final workingSets = detail.workingSets;
            final notes = detail.sessionExercise.prescriptionNotes?.trim() ?? '';
            final noRestAfterThis = isMentzer &&
                mentzerService.isNoRestAfterThis(
                  workoutIndex: workoutIndex,
                  exerciseName: detail.exercise.name,
                );

            _maybePrefill(detail, defaultWeight);

            final targetLabel =
                '${detail.sessionExercise.setsTarget} x ${detail.sessionExercise.repMin}-${detail.sessionExercise.repMax}';
            final restLabel = 'Rest ${detail.sessionExercise.restSeconds}s';
            final textTheme = Theme.of(context).textTheme;
            String? suggestionLine;
            if (lastPerformance != null &&
                lastPerformance.sets.isNotEmpty) {
              suggestionLine =
                  'Suggested: ${lastPerformance.toSummaryLine().replaceFirst('Last: ', '')}';
            } else if (suggestedWeight != null) {
              suggestionLine =
                  'Suggested: ${suggestedWeight.toStringAsFixed(1)} kg';
            }

            return ListView(
              controller: _scrollController,
              padding: EdgeInsets.fromLTRB(
                16,
                16,
                16,
                actionBarHeight + 16 + bottomInset,
              ),
              children: [
                Row(
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    Expanded(
                      child: Text(
                        detail.exercise.name,
                        style: Theme.of(context)
                            .textTheme
                            .headlineMedium
                            ?.copyWith(fontWeight: FontWeight.w700),
                      ),
                    ),
                    if (isDeloadSession)
                      const Chip(label: Text('Deload')),
                  ],
                ),
                const SizedBox(height: 8),
                Text(
                  '$targetLabel • $restLabel',
                  style: textTheme.titleMedium,
                ),
                if (suggestionLine != null) ...[
                  const SizedBox(height: 4),
                  Text(
                    suggestionLine,
                    style: textTheme.bodySmall,
                  ),
                ],
                if (notes.isNotEmpty) ...[
                  const SizedBox(height: 8),
                  Align(
                    alignment: Alignment.centerLeft,
                    child: TextButton.icon(
                      onPressed: () => _showNotesSheet(
                        context,
                        title: detail.exercise.name,
                        notes: notes,
                      ),
                      icon: const Icon(Icons.notes_outlined),
                      label: const Text('Notes'),
                    ),
                  ),
                ],
                const SizedBox(height: 16),
                Text(
                  'Logged sets',
                  style: textTheme.titleMedium,
                ),
                const SizedBox(height: 8),
                workingSets.isEmpty
                    ? const Text('No sets logged yet.')
                    : Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: workingSets
                            .map(
                              (set) => Padding(
                                padding:
                                    const EdgeInsets.symmetric(vertical: 4),
                                child: Text(
                                  'Set ${set.setIndex}: ${set.weightKg.toStringAsFixed(1)} x ${set.reps}',
                                ),
                              ),
                            )
                            .toList(),
                      ),
                const SizedBox(height: 16),
                Text(
                  'Log set',
                  style: textTheme.titleMedium,
                ),
                const SizedBox(height: 8),
                Row(
                  children: [
                    Expanded(
                      child: TextField(
                        controller: _weightController,
                        focusNode: _weightFocus,
                        decoration:
                            const InputDecoration(labelText: 'Weight (kg)'),
                        keyboardType: const TextInputType.numberWithOptions(
                          decimal: true,
                        ),
                        textInputAction: TextInputAction.next,
                        onSubmitted: (_) => _repsFocus.requestFocus(),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: TextField(
                        controller: _repsController,
                        focusNode: _repsFocus,
                        decoration: const InputDecoration(labelText: 'Reps'),
                        keyboardType: TextInputType.number,
                        textInputAction: TextInputAction.done,
                        onSubmitted: (_) => _saveSet(
                          context,
                          detail.sessionExercise.id,
                          detail.sessionExercise.restSeconds,
                          detail.sessionExercise.repMin,
                          skipRestTimer: noRestAfterThis,
                          previousBestE1rm: bestE1rm,
                        ),
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
                          skipRestTimer: noRestAfterThis,
                          previousBestE1rm: bestE1rm,
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
                const SizedBox(height: 16),
                if (noRestAfterThis && detail.workingSets.isNotEmpty) ...[
                  Text(
                    'Pre-exhaust: move to next now.',
                    style: textTheme.bodySmall?.copyWith(
                      color: Theme.of(context).colorScheme.onSurfaceVariant,
                    ),
                  ),
                  const SizedBox(height: 12),
                ],
                FilledButton(
                  onPressed: () => _goToNextExercise(detail),
                  child: const Text('Next Exercise'),
                ),
                if (timerState.initialSeconds > 0) ...[
                  const SizedBox(height: 16),
                  _RestTimerRow(
                    state: timerState,
                    onPause: () =>
                        ref.read(restTimerProvider.notifier).togglePause(),
                    onReset: () =>
                        ref.read(restTimerProvider.notifier).reset(),
                    onAdd: () =>
                        ref.read(restTimerProvider.notifier).addSeconds(30),
                  ),
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
                          style: OutlinedButton.styleFrom(
                            minimumSize: const Size.fromHeight(48),
                          ),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: FilledButton(
                          onPressed: () => _toggleCompletion(
                            detail.sessionExercise.id,
                            !detail.sessionExercise.isCompleted,
                          ),
                          style: FilledButton.styleFrom(
                            minimumSize: const Size.fromHeight(48),
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

  double _estimateE1rm(double weight, int reps) {
    if (reps <= 1) {
      return weight;
    }
    return weight * (1 + reps / 30.0);
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
    {bool skipRestTimer = false, double? previousBestE1rm}
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
    if (weight <= 0 || reps <= 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Weight and reps must be > 0.')),
      );
      return;
    }

    await _saveSetWithValues(
      context: context,
      sessionExerciseId: sessionExerciseId,
      restSeconds: restSeconds,
      repMin: repMin,
      weight: weight,
      reps: reps,
      skipRestTimer: skipRestTimer,
      previousBestE1rm: previousBestE1rm,
    );
  }

  Future<void> _saveSetWithValues({
    required BuildContext context,
    required int sessionExerciseId,
    required int restSeconds,
    required int repMin,
    required double weight,
    required int reps,
    required bool skipRestTimer,
    double? previousBestE1rm,
  }) async {
    final setLog = await ref
        .read(sessionRepositoryProvider)
        .addSetReturningLog(
          sessionExerciseId,
          weight,
          reps,
        );
    if (skipRestTimer) {
      ref.read(restTimerProvider.notifier).reset();
    } else {
      ref.read(restTimerProvider.notifier).start(restSeconds);
    }
    HapticFeedback.selectionClick();

    if (!context.mounted) {
      return;
    }

    _setRepsText(repMin);
    _userEditedReps = false;

    final currentE1rm = _estimateE1rm(setLog.weightKg, setLog.reps);
    final isPr = previousBestE1rm != null &&
        currentE1rm > previousBestE1rm + 0.01;
    final prText = isPr ? ' • 🔥 NEW PR!' : '';
    ScaffoldMessenger.of(context).hideCurrentSnackBar();
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          'Saved Set ${setLog.setIndex}: ${setLog.weightKg.toStringAsFixed(1)} x ${setLog.reps}$prText',
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

  Widget _errorView({
    required Object error,
    required VoidCallback onRetry,
  }) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text('Error: $error'),
          const SizedBox(height: 12),
          OutlinedButton(
            onPressed: onRetry,
            child: const Text('Retry'),
          ),
        ],
      ),
    );
  }
}

class _RestTimerRow extends StatelessWidget {
  const _RestTimerRow({
    required this.state,
    required this.onPause,
    required this.onReset,
    required this.onAdd,
  });

  final RestTimerState state;
  final VoidCallback onPause;
  final VoidCallback onReset;
  final VoidCallback onAdd;

  @override
  Widget build(BuildContext context) {
    final label = _formatSeconds(state.remainingSeconds);
    final pauseLabel = state.isRunning ? 'Pause' : 'Resume';
    return Row(
      children: [
        Expanded(
          child: Text(
            'Rest: $label',
            style: Theme.of(context).textTheme.titleMedium,
          ),
        ),
        TextButton(onPressed: onPause, child: Text(pauseLabel)),
        TextButton(onPressed: onReset, child: const Text('Reset')),
        TextButton(onPressed: onAdd, child: const Text('+30s')),
      ],
    );
  }

  String _formatSeconds(int seconds) {
    final minutes = seconds ~/ 60;
    final remaining = seconds % 60;
    return '${minutes.toString().padLeft(2, '0')}:${remaining.toString().padLeft(2, '0')}';
  }
}
