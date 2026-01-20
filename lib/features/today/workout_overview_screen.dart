import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../app/weekday_labels.dart';
import '../../data/db/app_database.dart';
import '../../data/providers.dart';
import '../../data/repositories/session_repository.dart';
import '../../services/mentzer_cycle_service.dart';
import '../../state/rest_timer.dart';

class WorkoutOverviewScreen extends ConsumerWidget {
  const WorkoutOverviewScreen({super.key, required this.bundle});

  final ActiveSessionBundle bundle;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final textTheme = Theme.of(context).textTheme;
    final session = bundle.session;
    final exercises = bundle.exercises;
    final workoutDayId = session.workoutDayId;
    final dayAsync = workoutDayId == null
        ? const AsyncValue.data(null)
        : ref.watch(workoutDayProvider(workoutDayId));
    final mentzerService = ref.watch(mentzerCycleServiceProvider);
    final programAsync = session.programId == null
        ? const AsyncValue.data(null)
        : ref.watch(programProvider(session.programId!));
    final isMentzer = programAsync.asData?.value != null &&
        mentzerService.isMentzerProgramName(
          programAsync.asData!.value!.name,
        );

    final resumeId = session.currentSessionExerciseId;
    final canResume = resumeId != null &&
        exercises.any((exercise) => exercise.sessionExerciseId == resumeId);
    SessionExerciseSummary? firstIncomplete;
    for (final exercise in exercises) {
      if (!exercise.isCompleted) {
        firstIncomplete = exercise;
        break;
      }
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Active Workout',
          style: textTheme.displaySmall?.copyWith(fontWeight: FontWeight.w700),
        ),
        const SizedBox(height: 8),
        dayAsync.when(
          data: (day) {
            if (day == null) {
              return Text('Workout session', style: textTheme.titleLarge);
            }
            final title = isMentzer
                ? day.name
                : '${weekdayLabel(day.weekday)} - ${day.name}';
            return Text(title, style: textTheme.titleLarge);
          },
          loading: () => const Text('Loading day...'),
          error: (error, stack) =>
              Text('Workout session', style: textTheme.titleLarge),
        ),
        const SizedBox(height: 16),
        if (canResume)
          FilledButton.tonal(
            onPressed: () =>
                context.push('/today/runner/${session.currentSessionExerciseId}'),
            child: const Text('Resume'),
          ),
        if (canResume) const SizedBox(height: 12),
        if (firstIncomplete != null)
          Builder(
            builder: (context) {
              final target = firstIncomplete;
              if (target == null) {
                return const SizedBox.shrink();
              }
              return OutlinedButton(
                onPressed: () =>
                    context.push('/today/runner/${target.sessionExerciseId}'),
                child: const Text('Jump to first incomplete'),
              );
            },
          ),
        if (canResume || firstIncomplete != null) const SizedBox(height: 16),
        Expanded(
          child: exercises.isEmpty
              ? Center(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Text('No exercises for today.'),
                      const SizedBox(height: 12),
                      OutlinedButton(
                        onPressed: () => context.go('/programs'),
                        child: const Text('Go to Programs'),
                      ),
                    ],
                  ),
                )
              : ListView.separated(
                  itemCount: exercises.length,
                  separatorBuilder: (_, _) => const Divider(height: 1),
                  itemBuilder: (context, index) {
                    final item = exercises[index];
                    final status = _statusFor(item);
                    final actionLabel = _actionLabelFor(item);

                    return ListTile(
                      onTap: () =>
                          context.push('/today/runner/${item.sessionExerciseId}'),
                      leading: _StatusChip(status: status),
                      title: Text(item.exerciseName),
                      subtitle: Text(
                        '${item.loggedSetsCount}/${item.setsTarget} | ${item.repMin}-${item.repMax} | Rest ${item.restSeconds}s',
                      ),
                      trailing: TextButton(
                        onPressed: () =>
                            context.push('/today/runner/${item.sessionExerciseId}'),
                        child: Text(actionLabel),
                      ),
                    );
                  },
                ),
        ),
        const SizedBox(height: 12),
        FilledButton(
          onPressed: () => _finishWorkout(
            context,
            ref,
            session,
          ),
          child: const Text('Finish Workout'),
        ),
        const SizedBox(height: 8),
        TextButton(
          onPressed: () async {
            await ref
                .read(sessionRepositoryProvider)
                .discardSession(session.id);
            ref.read(restTimerProvider.notifier).reset();
          },
          child: const Text('Discard Workout'),
        ),
      ],
    );
  }

  _ExerciseStatus _statusFor(SessionExerciseSummary item) {
    if (item.isCompleted) {
      return _ExerciseStatus.done;
    }
    if (item.loggedSetsCount == 0) {
      return _ExerciseStatus.notStarted;
    }
    return _ExerciseStatus.inProgress;
  }

  String _actionLabelFor(SessionExerciseSummary item) {
    if (item.isCompleted) {
      return 'View';
    }
    if (item.loggedSetsCount == 0) {
      return 'Start';
    }
    return 'Continue';
  }

  Future<void> _finishWorkout(
    BuildContext context,
    WidgetRef ref,
    Session session,
  ) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Finish workout?'),
        content: const Text('This will end the session.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('Finish'),
          ),
        ],
      ),
    );

    if (confirmed != true || !context.mounted) {
      return;
    }

    final finishedAt = DateTime.now();
    await ref.read(sessionRepositoryProvider).finishSession(session.id);
    ref.read(restTimerProvider.notifier).reset();

    if (session.programId != null) {
      final mentzerService = ref.read(mentzerCycleServiceProvider);
      final isMentzerProgram =
          await mentzerService.isMentzerProgramId(session.programId!);
      if (isMentzerProgram) {
        final notifier =
            ref.read(mentzerCycleStateProvider(session.programId!).notifier);
        int? workoutIndex = notifier.activeWorkoutIndex;
        if (workoutIndex == null && session.workoutDayId != null) {
          workoutIndex =
              await mentzerService.workoutIndexForDay(session.workoutDayId!);
        }
        if (workoutIndex == null) {
          final cycle = await ref
              .read(mentzerCycleStateProvider(session.programId!).future);
          workoutIndex = cycle.nextWorkoutIndex;
        }
        final nextState = await notifier.advanceAfterFinish(
          finishedWorkoutIndex: workoutIndex,
          finishedAt: finishedAt,
        );
        if (context.mounted) {
          final nextLabel = nextState.nextWorkoutIndex + 1;
          final remaining = nextState.nextAvailableAt == null
              ? Duration.zero
              : nextState.nextAvailableAt!.difference(DateTime.now());
          final remainingLabel = _formatRemaining(
            remaining.isNegative ? Duration.zero : remaining,
          );
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(
                'Finished W${workoutIndex + 1} → Next W$nextLabel '
                '(available in $remainingLabel)',
              ),
            ),
          );
        }
      }
    }

    ref.invalidate(activeSessionProvider);
    ref.invalidate(activeSessionBundleProvider);
  }
}

enum _ExerciseStatus { notStarted, inProgress, done }

class _StatusChip extends StatelessWidget {
  const _StatusChip({required this.status});

  final _ExerciseStatus status;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final label = switch (status) {
      _ExerciseStatus.notStarted => 'Not started',
      _ExerciseStatus.inProgress => 'In progress',
      _ExerciseStatus.done => 'Done',
    };
    final background = switch (status) {
      _ExerciseStatus.notStarted => colorScheme.surfaceContainerHighest,
      _ExerciseStatus.inProgress => colorScheme.secondaryContainer,
      _ExerciseStatus.done => colorScheme.primaryContainer,
    };
    final foreground = switch (status) {
      _ExerciseStatus.notStarted => colorScheme.onSurfaceVariant,
      _ExerciseStatus.inProgress => colorScheme.onSecondaryContainer,
      _ExerciseStatus.done => colorScheme.onPrimaryContainer,
    };

    return Chip(
      label: Text(label),
      backgroundColor: background,
      labelStyle: TextStyle(color: foreground),
    );
  }
}

String _formatRemaining(Duration remaining) {
  final hours = remaining.inHours;
  final minutes = remaining.inMinutes.remainder(60);
  return '${hours}h ${minutes}m';
}
