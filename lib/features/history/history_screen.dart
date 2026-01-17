import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../data/providers.dart';

class HistoryScreen extends ConsumerWidget {
  const HistoryScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final sessionsAsync = ref.watch(recentSessionsProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('History')),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: sessionsAsync.when(
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (error, stack) => const Center(
            child: Text('Failed to load history.'),
          ),
          data: (sessions) {
            if (sessions.isEmpty) {
              return const Center(child: Text('No sessions yet.'));
            }

            return ListView.separated(
              itemCount: sessions.length,
              separatorBuilder: (_, _) => const Divider(height: 1),
              itemBuilder: (context, index) {
                final summary = sessions[index];
                final startedAt = summary.session.startedAt;
                final dayName = summary.workoutDay?.name ?? 'Workout Session';
                final dateLabel = _formatDateTime(context, startedAt);
                final durationLabel =
                    _formatDuration(summary.session.finishedAt, startedAt);

                return ListTile(
                  title: Text(dayName),
                  subtitle: Text(dateLabel),
                  trailing: Text(durationLabel),
                  onTap: () =>
                      context.push('/history/${summary.session.id}'),
                );
              },
            );
          },
        ),
      ),
    );
  }

  String _formatDateTime(BuildContext context, DateTime dateTime) {
    final localizations = MaterialLocalizations.of(context);
    final date = localizations.formatShortDate(dateTime);
    final time = localizations.formatTimeOfDay(
      TimeOfDay.fromDateTime(dateTime),
      alwaysUse24HourFormat: false,
    );
    return '$date · $time';
  }

  String _formatDuration(DateTime? finishedAt, DateTime startedAt) {
    if (finishedAt == null) {
      return 'Active';
    }
    final duration = finishedAt.difference(startedAt);
    final hours = duration.inHours;
    final minutes = duration.inMinutes % 60;
    if (hours > 0) {
      return '${hours}h ${minutes}m';
    }
    return '${duration.inMinutes}m';
  }
}
