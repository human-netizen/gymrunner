import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../data/providers.dart';
import '../../data/repositories/exercise_analytics_repository.dart';
import '../../data/repositories/session_repository.dart';

class HistoryScreen extends ConsumerStatefulWidget {
  const HistoryScreen({super.key});

  @override
  ConsumerState<HistoryScreen> createState() => _HistoryScreenState();
}

class _HistoryScreenState extends ConsumerState<HistoryScreen> {
  final TextEditingController _searchController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _searchController.addListener(_handleSearch);
  }

  @override
  void dispose() {
    _searchController
      ..removeListener(_handleSearch)
      ..dispose();
    super.dispose();
  }

  void _handleSearch() {
    setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    final query = _searchController.text.trim();
    final sessionsAsync = ref.watch(recentSessionsProvider);
    final exercisesAsync =
        query.isEmpty ? null : ref.watch(exerciseSearchProvider(query));

    return Scaffold(
      appBar: AppBar(title: const Text('History')),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            TextField(
              controller: _searchController,
              decoration: const InputDecoration(
                hintText: 'Search exercise…',
                prefixIcon: Icon(Icons.search),
              ),
            ),
            const SizedBox(height: 12),
            Expanded(
              child: query.isEmpty
                  ? _buildSessionList(context, sessionsAsync)
                  : _buildExerciseResults(context, exercisesAsync!),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildExerciseResults(
    BuildContext context,
    AsyncValue<List<ExerciseSearchResult>> resultsAsync,
  ) {
    return resultsAsync.when(
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (error, stack) => SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            const Text('Failed to load exercises.'),
            const SizedBox(height: 8),
            Text(error.toString(), textAlign: TextAlign.center),
            if (kDebugMode) ...[
              const SizedBox(height: 8),
              Text(
                stack.toString(),
                textAlign: TextAlign.center,
              ),
            ],
            const SizedBox(height: 12),
            FilledButton(
              onPressed: () =>
                  ref.invalidate(exerciseSearchProvider(_searchController.text.trim())),
              child: const Text('Retry'),
            ),
          ],
        ),
      ),
      data: (results) {
        if (results.isEmpty) {
          return const Center(child: Text('No exercises match.'));
        }
        return ListView.separated(
          itemCount: results.length,
          separatorBuilder: (_, _) => const Divider(height: 1),
          itemBuilder: (context, index) {
            final result = results[index];
            return ListTile(
              title: Text(result.name),
              subtitle: Text(_formatMuscle(result.primaryMuscle)),
              onTap: () =>
                  context.push('/history/exercise/${result.id}'),
            );
          },
        );
      },
    );
  }

  Widget _buildSessionList(
    BuildContext context,
    AsyncValue<List<SessionSummary>> sessionsAsync,
  ) {
    return sessionsAsync.when(
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (error, stack) => SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            const Text('Failed to load history.'),
            const SizedBox(height: 8),
            Text(error.toString(), textAlign: TextAlign.center),
            if (kDebugMode) ...[
              const SizedBox(height: 8),
              Text(
                stack.toString(),
                textAlign: TextAlign.center,
              ),
            ],
            const SizedBox(height: 12),
            FilledButton(
              onPressed: () => ref.invalidate(recentSessionsProvider),
              child: const Text('Retry'),
            ),
          ],
        ),
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
              onTap: () => context.push('/history/${summary.session.id}'),
            );
          },
        );
      },
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

  String _formatMuscle(String muscle) {
    if (muscle.isEmpty) {
      return muscle;
    }
    return muscle[0].toUpperCase() + muscle.substring(1);
  }
}
