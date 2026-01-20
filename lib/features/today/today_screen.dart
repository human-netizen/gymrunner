import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../app/weekday_labels.dart';
import '../../data/providers.dart';
import '../../services/mentzer_cycle_service.dart';
import '../../templates/mentzer_hit_cycle.dart';
import 'workout_overview_screen.dart';

class TodayScreen extends ConsumerWidget {
  const TodayScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final bundleAsync = ref.watch(activeSessionBundleProvider);

    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: bundleAsync.when(
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (error, stack) => Center(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text('Error: $error'),
                const SizedBox(height: 12),
                OutlinedButton(
                  onPressed: () => ref.invalidate(activeSessionBundleProvider),
                  child: const Text('Retry'),
                ),
              ],
            ),
          ),
          data: (bundle) {
            if (bundle != null) {
              return WorkoutOverviewScreen(bundle: bundle);
            }
            return const TodayPlanView();
          },
        ),
      ),
    );
  }
}

class TodayPlanView extends ConsumerWidget {
  const TodayPlanView({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final textTheme = Theme.of(context).textTheme;
    final weekday = DateTime.now().weekday;
    final settingsAsync = ref.watch(settingsStreamProvider);
    final mentzerService = ref.watch(mentzerCycleServiceProvider);

    return settingsAsync.when(
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (error, stack) => const Center(
        child: Text('Failed to load settings.'),
      ),
      data: (settings) {
        final activeProgramId = settings?.activeProgramId;
        if (activeProgramId == null) {
          return _StatusPanel(
            title: 'No active program',
            message: 'Pick a program to see today\'s plan.',
            textTheme: textTheme,
          );
        }

        final programAsync = ref.watch(programProvider(activeProgramId));
        return programAsync.when(
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (error, stack) => const Center(
            child: Text('Failed to load program.'),
          ),
          data: (program) {
            if (program == null) {
              return _StatusPanel(
                title: 'Program not found',
                message: 'Pick a program to see today\'s plan.',
                textTheme: textTheme,
              );
            }
            if (mentzerService.isMentzerProgramName(program.name)) {
              return _MentzerTodayPlan(
                programId: program.id,
                programName: program.name,
              );
            }
            return _WeekdayTodayPlan(
              programId: activeProgramId,
              weekday: weekday,
              textTheme: textTheme,
            );
          },
        );
      },
    );
  }
}

class _WeekdayTodayPlan extends ConsumerWidget {
  const _WeekdayTodayPlan({
    required this.programId,
    required this.weekday,
    required this.textTheme,
  });

  final int programId;
  final int weekday;
  final TextTheme textTheme;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final dayAsync = ref.watch(
      workoutDayForWeekdayProvider(
        WorkoutDayKey(programId, weekday),
      ),
    );

    return dayAsync.when(
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (error, stack) => const Center(
        child: Text('Failed to load today\'s plan.'),
      ),
      data: (day) {
        if (day == null) {
          return _StatusPanel(
            title: 'Rest day',
            message: 'No workout scheduled for today.',
            textTheme: textTheme,
          );
        }

        final prescriptionsAsync = ref.watch(prescriptionsProvider(day.id));

        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Today',
              style: textTheme.displaySmall?.copyWith(
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              '${weekdayLabel(day.weekday)} · ${day.name}',
              style: textTheme.titleLarge,
            ),
            const SizedBox(height: 16),
            Expanded(
              child: prescriptionsAsync.when(
                loading: () => const Center(child: CircularProgressIndicator()),
                error: (error, stack) => const Center(
                  child: Text('Failed to load exercises.'),
                ),
                data: (prescriptions) {
                  if (prescriptions.isEmpty) {
                    return const Center(
                      child: Text('No exercises added yet.'),
                    );
                  }

                  return ListView.separated(
                    itemCount: prescriptions.length,
                    separatorBuilder: (_, _) => const Divider(height: 1),
                    itemBuilder: (context, index) {
                      final item = prescriptions[index];
                      final restSeconds =
                          item.prescription.restSeconds ??
                              item.exercise.defaultRestSeconds;
                      final repRange =
                          '${item.prescription.repMin}-${item.prescription.repMax}';

                      return ListTile(
                        title: Text(item.exercise.name),
                        subtitle: Text(
                          '${item.prescription.setsTarget} x $repRange · Rest $restSeconds s',
                        ),
                        onTap: () async {
                          final sessionExerciseId = await ref
                              .read(sessionRepositoryProvider)
                              .startSessionForWorkoutDayAndSelectExercise(
                                workoutDayId: day.id,
                                exerciseId: item.exercise.id,
                              );

                          if (!context.mounted) {
                            return;
                          }

                          if (sessionExerciseId == null) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(
                                content:
                                    Text('Unable to start exercise runner.'),
                              ),
                            );
                            return;
                          }

                          context.push(
                            '/today/runner/$sessionExerciseId',
                          );
                        },
                      );
                    },
                  );
                },
              ),
            ),
            const SizedBox(height: 12),
            FilledButton(
              onPressed: () => _startWorkout(context, ref, day.id),
              child: const Text('Start Workout'),
            ),
          ],
        );
      },
    );
  }

  Future<void> _startWorkout(
    BuildContext context,
    WidgetRef ref,
    int workoutDayId,
  ) async {
    final isDeload = await showModalBottomSheet<bool>(
      context: context,
      builder: (context) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              title: const Text('Start Normal'),
              onTap: () => Navigator.of(context).pop(false),
            ),
            ListTile(
              title: const Text('Start Deload'),
              subtitle: const Text('Recommended every 4-6 weeks'),
              onTap: () => Navigator.of(context).pop(true),
            ),
          ],
        ),
      ),
    );

    if (isDeload == null) {
      return;
    }

    await ref
        .read(sessionRepositoryProvider)
        .startSessionForWorkoutDay(workoutDayId, isDeload: isDeload);
  }
}

class _MentzerTodayPlan extends ConsumerWidget {
  const _MentzerTodayPlan({
    required this.programId,
    required this.programName,
  });

  final int programId;
  final String programName;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final textTheme = Theme.of(context).textTheme;
    final cycleAsync = ref.watch(mentzerCycleStateProvider(programId));
    final daysAsync = ref.watch(workoutDaysProvider(programId));
    return cycleAsync.when(
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (error, stack) => const Center(
        child: Text('Failed to load cycle info.'),
      ),
      data: (cycle) {
        return daysAsync.when(
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (error, stack) => const Center(
            child: Text('Failed to load workouts.'),
          ),
          data: (days) {
            if (days.isEmpty) {
              return _StatusPanel(
                title: 'No workouts found',
                message: 'Re-import the Mentzer program.',
                textTheme: textTheme,
              );
            }

            final ordered = [...days]
              ..sort((a, b) => a.orderIndex.compareTo(b.orderIndex));
            final workoutIndex = cycle.nextWorkoutIndex %
                mentzerHitCycleTemplate.workouts.length;
            final nextDay = ordered.firstWhere(
              (day) => day.orderIndex == workoutIndex,
              orElse: () => ordered.first,
            );
            final nextWorkout =
                mentzerHitCycleTemplate.workoutForIndex(workoutIndex);
            final nextAvailableAt = cycle.nextAvailableAt;
            final lastFinishedAt = cycle.lastFinishedAt;
            final remaining = nextAvailableAt == null
                ? Duration.zero
                : nextAvailableAt.difference(DateTime.now());
            final clampedRemaining =
                remaining.isNegative ? Duration.zero : remaining;
            final isResting = clampedRemaining > Duration.zero;
            final totalRest =
                Duration(days: mentzerHitCycleTemplate.restMinDays);

            return Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Today',
                  style: textTheme.displaySmall?.copyWith(
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 8),
                Text(programName, style: textTheme.titleLarge),
                if (lastFinishedAt != null) ...[
                  const SizedBox(height: 12),
                  _RestBanner(
                    totalRest: totalRest,
                    nextAvailableAt: nextAvailableAt,
                  ),
                ] else
                  const SizedBox(height: 12),
                Text(nextWorkout.title, style: textTheme.titleLarge),
                const SizedBox(height: 4),
                Text(mentzerSnippet(nextWorkout.sideNotes)),
                const SizedBox(height: 12),
                Expanded(
                  child: ListView.separated(
                    itemCount: nextWorkout.exercises.length,
                    separatorBuilder: (_, _) => const Divider(height: 1),
                    itemBuilder: (context, index) {
                      final exercise = nextWorkout.exercises[index];
                      final repRange = '${exercise.repMin}-${exercise.repMax}';
                      return ListTile(
                        title: Text(exercise.name),
                        subtitle: Text(
                          '1 x $repRange • ${mentzerSnippet(exercise.notes)}',
                        ),
                      );
                    },
                  ),
                ),
                const SizedBox(height: 12),
                FilledButton(
                  onPressed: isResting
                      ? null
                      : () => _startMentzerWorkout(
                            context,
                            ref,
                            nextDay.id,
                            workoutIndex: workoutIndex,
                            programId: programId,
                          ),
                  child: isResting
                      ? Text(
                          'Available in ${_formatRemaining(clampedRemaining)}',
                        )
                      : const Text('Start Workout'),
                ),
                if (isResting) ...[
                  const SizedBox(height: 8),
                  OutlinedButton(
                    onPressed: () => _startMentzerWorkout(
                      context,
                      ref,
                      nextDay.id,
                      warn: true,
                      remaining: clampedRemaining,
                      workoutIndex: workoutIndex,
                      programId: programId,
                    ),
                    child: const Text('Start anyway'),
                  ),
                ],
              ],
            );
          },
        );
      },
    );
  }

  Future<void> _startMentzerWorkout(
    BuildContext context,
    WidgetRef ref,
    int workoutDayId, {
    bool warn = false,
    Duration? remaining,
    required int workoutIndex,
    required int programId,
  }) async {
    if (warn) {
      final remainingLabel = remaining == null
          ? 'You still have rest remaining. Start anyway?'
          : 'You still have ${_formatRemaining(remaining)} rest remaining. Start anyway?';
      final confirmed = await showDialog<bool>(
        context: context,
        builder: (context) => AlertDialog(
          title: const Text('Start early?'),
          content: Text(remainingLabel),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(false),
              child: const Text('Cancel'),
            ),
            FilledButton(
              onPressed: () => Navigator.of(context).pop(true),
              child: const Text('Start'),
            ),
          ],
        ),
      );
      if (confirmed != true) {
        return;
      }
    }

    ref
        .read(mentzerCycleStateProvider(programId).notifier)
        .setActiveWorkoutIndex(workoutIndex);
    await ref
        .read(sessionRepositoryProvider)
        .startSessionForWorkoutDay(workoutDayId, isDeload: false);
  }
}

class _RestBanner extends StatelessWidget {
  const _RestBanner({
    required this.totalRest,
    required this.nextAvailableAt,
  });

  final Duration totalRest;
  final DateTime? nextAvailableAt;

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<int>(
      stream: Stream.periodic(const Duration(seconds: 1), (value) => value),
      builder: (context, snapshot) {
        final now = DateTime.now();
        final remaining = nextAvailableAt == null
            ? Duration.zero
            : nextAvailableAt!.difference(now);
        final clamped =
            remaining.isNegative ? Duration.zero : remaining;
        final totalSeconds = totalRest.inSeconds;
        final remainingSeconds = clamped.inSeconds;
        final progress = totalSeconds == 0
            ? 1.0
            : 1.0 - (remainingSeconds / totalSeconds);
        final ready = remainingSeconds == 0;
        final label = ready
            ? 'Rest complete: Ready'
            : 'Rest remaining: ${_formatRemaining(clamped)} / ${totalRest.inHours}h';

        return Card(
          child: Padding(
            padding: const EdgeInsets.all(12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: Theme.of(context).textTheme.titleSmall,
                ),
                const SizedBox(height: 8),
                LinearProgressIndicator(value: progress.clamp(0.0, 1.0)),
              ],
            ),
          ),
        );
      },
    );
  }
}

String _formatRemaining(Duration remaining) {
  final hours = remaining.inHours;
  final minutes = remaining.inMinutes.remainder(60);
  return '${hours}h ${minutes}m';
}

class _StatusPanel extends StatelessWidget {
  const _StatusPanel({
    required this.title,
    required this.message,
    required this.textTheme,
  });

  final String title;
  final String message;
  final TextTheme textTheme;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            title,
            style: textTheme.displaySmall?.copyWith(
              fontWeight: FontWeight.w700,
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 12),
          Text(
            message,
            style: textTheme.bodyLarge,
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }
}
