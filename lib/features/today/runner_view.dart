import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../app/weekday_labels.dart';
import '../../data/db/app_database.dart';
import '../../data/providers.dart';
import '../../state/rest_timer.dart';
import 'rest_timer_bar.dart';
import 'session_exercise_card.dart';

class RunnerView extends ConsumerWidget {
  const RunnerView({super.key, required this.session});

  final Session session;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final textTheme = Theme.of(context).textTheme;
    final workoutDayId = session.workoutDayId;
    final workoutDayAsync = workoutDayId == null
        ? AsyncValue<WorkoutDay?>.data(null)
        : ref.watch(workoutDayProvider(workoutDayId));
    final exercisesAsync = ref.watch(sessionExercisesProvider(session.id));
    final timerState = ref.watch(restTimerProvider);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Active Workout',
          style: textTheme.displaySmall?.copyWith(
            fontWeight: FontWeight.w700,
          ),
        ),
        const SizedBox(height: 8),
        workoutDayAsync.when(
          data: (day) {
            if (day == null) {
              return Text('Workout session', style: textTheme.titleLarge);
            }
            return Text(
              '${weekdayLabel(day.weekday)} · ${day.name}',
              style: textTheme.titleLarge,
            );
          },
          loading: () => const Text('Loading day...'),
          error: (error, stack) => const Text('Workout session'),
        ),
        const SizedBox(height: 16),
        Expanded(
          child: exercisesAsync.when(
            loading: () => const Center(child: CircularProgressIndicator()),
            error: (error, stack) => const Center(
              child: Text('Failed to load session exercises.'),
            ),
            data: (exercises) {
              if (exercises.isEmpty) {
                return const Center(
                  child: Text('No exercises in this session yet.'),
                );
              }

              return ListView.separated(
                itemCount: exercises.length,
                separatorBuilder: (_, _) => const SizedBox(height: 12),
                itemBuilder: (context, index) {
                  final item = exercises[index];
                  return SessionExerciseCard(data: item);
                },
              );
            },
          ),
        ),
        if (timerState.initialSeconds > 0) ...[
          const SizedBox(height: 12),
          const RestTimerBar(),
        ],
        const SizedBox(height: 12),
        FilledButton(
          onPressed: () async {
            await ref
                .read(sessionRepositoryProvider)
                .finishSession(session.id);
            ref.read(restTimerProvider.notifier).reset();
          },
          child: const Text('Finish Workout'),
        ),
      ],
    );
  }
}
