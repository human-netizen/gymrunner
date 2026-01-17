import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:share_plus/share_plus.dart';

import '../../data/providers.dart';
import '../../data/repositories/session_repository.dart';
import '../../services/session_share_service.dart';

class SessionDetailScreen extends ConsumerWidget {
  const SessionDetailScreen({super.key, required this.sessionId});

  final int sessionId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final detailsAsync = ref.watch(sessionDetailsProvider(sessionId));

    return Scaffold(
      appBar: AppBar(
        title: const Text('Session Details'),
        actions: [
          IconButton(
            onPressed: () => _shareSession(context, ref),
            icon: const Icon(Icons.share),
            tooltip: 'Share summary',
          ),
        ],
      ),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: detailsAsync.when(
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (error, stack) => const Center(
            child: Text('Failed to load session details.'),
          ),
          data: (details) {
            if (details == null) {
              return const Center(child: Text('Session not found.'));
            }

            return Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _SessionHeader(summary: details.summary),
                const SizedBox(height: 16),
                Expanded(
                  child: ListView.separated(
                    itemCount: details.exercises.length,
                    separatorBuilder: (_, _) => const SizedBox(height: 12),
                    itemBuilder: (context, index) {
                      final item = details.exercises[index];
                      return _ExerciseSummaryCard(item: item);
                    },
                  ),
                ),
              ],
            );
          },
        ),
      ),
    );
  }

  Future<void> _shareSession(BuildContext context, WidgetRef ref) async {
    try {
      final text = await ref
          .read(sessionShareServiceProvider)
          .buildSessionSummaryText(sessionId);
      await Share.share(text, subject: 'Workout Summary');
    } catch (error) {
      if (!context.mounted) {
        return;
      }
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Share failed: $error')),
      );
    }
  }
}

class _SessionHeader extends StatelessWidget {
  const _SessionHeader({required this.summary});

  final SessionSummary summary;

  @override
  Widget build(BuildContext context) {
    final localizations = MaterialLocalizations.of(context);
    final startedAt = summary.session.startedAt;
    final finishedAt = summary.session.finishedAt;
    final date = localizations.formatShortDate(startedAt);
    final time = localizations.formatTimeOfDay(
      TimeOfDay.fromDateTime(startedAt),
      alwaysUse24HourFormat: false,
    );
    final duration = finishedAt == null
        ? 'Active'
        : _formatDuration(finishedAt.difference(startedAt));
    final dayName = summary.workoutDay?.name ?? 'Workout Session';
    final programName = summary.program?.name;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(dayName, style: Theme.of(context).textTheme.titleLarge),
        const SizedBox(height: 4),
        Text('$date · $time'),
        if (programName != null) Text('Program: $programName'),
        const SizedBox(height: 4),
        Text('Duration: $duration'),
      ],
    );
  }

  String _formatDuration(Duration duration) {
    final hours = duration.inHours;
    final minutes = duration.inMinutes % 60;
    if (hours > 0) {
      return '${hours}h ${minutes}m';
    }
    return '${duration.inMinutes}m';
  }
}

class _ExerciseSummaryCard extends StatelessWidget {
  const _ExerciseSummaryCard({required this.item});

  final SessionExerciseWithExerciseAndSets item;

  @override
  Widget build(BuildContext context) {
    final warmupSets = item.warmupSets;
    final workingSets = item.workingSets;

    return Card(
      elevation: 0,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              item.exercise.name,
              style: Theme.of(context).textTheme.titleMedium,
            ),
            const SizedBox(height: 8),
            if (warmupSets.isEmpty && workingSets.isEmpty)
              const Text('No sets logged.')
            else ...[
              if (warmupSets.isNotEmpty) ...[
                Text(
                  'Warm-up',
                  style: Theme.of(context).textTheme.labelLarge,
                ),
                const SizedBox(height: 4),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: warmupSets
                      .map(
                        (set) => Padding(
                          padding: const EdgeInsets.symmetric(vertical: 2),
                          child: Text(
                            'Warm-up ${set.setIndex}: ${set.weightKg.toStringAsFixed(1)} x ${set.reps}',
                          ),
                        ),
                      )
                      .toList(),
                ),
                const SizedBox(height: 8),
              ],
              if (workingSets.isNotEmpty) ...[
                Text(
                  'Working sets',
                  style: Theme.of(context).textTheme.labelLarge,
                ),
                const SizedBox(height: 4),
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
              ],
            ],
          ],
        ),
      ),
    );
  }
}
