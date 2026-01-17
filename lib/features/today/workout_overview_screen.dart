import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../app/weekday_labels.dart';
import '../../data/providers.dart';
import '../../data/repositories/session_repository.dart';
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

    final resumeId = session.currentSessionExerciseId;
    final canResume = resumeId != null &&
        exercises.any((exercise) => exercise.sessionExerciseId == resumeId);

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
            return Text(
              '${weekdayLabel(day.weekday)} - ${day.name}',
              style: textTheme.titleLarge,
            );
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
        if (canResume) const SizedBox(height: 16),
        Expanded(
          child: exercises.isEmpty
              ? const Center(child: Text('No exercises in this session.'))
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
          onPressed: () => _finishWorkout(context, ref, session.id),
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
    int sessionId,
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

    await ref.read(sessionRepositoryProvider).finishSession(sessionId);
    ref.read(restTimerProvider.notifier).reset();
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
