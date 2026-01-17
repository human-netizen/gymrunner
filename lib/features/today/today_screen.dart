import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../app/weekday_labels.dart';
import '../../data/providers.dart';
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

        final dayAsync = ref.watch(
          workoutDayForWeekdayProvider(
            WorkoutDayKey(activeProgramId, weekday),
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
                    loading: () =>
                        const Center(child: CircularProgressIndicator()),
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
