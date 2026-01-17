import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/providers.dart';
import '../../data/repositories/review_repository.dart';

enum ReviewRangeOption { thisWeek, last4Weeks }

class ReviewScreen extends ConsumerStatefulWidget {
  const ReviewScreen({super.key});

  @override
  ConsumerState<ReviewScreen> createState() => _ReviewScreenState();
}

class _ReviewScreenState extends ConsumerState<ReviewScreen> {
  ReviewRangeOption _selected = ReviewRangeOption.thisWeek;
  late ReviewRange _range;

  @override
  void initState() {
    super.initState();
    _range = _buildRange(_selected);
  }

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    final summaryAsync = ref.watch(reviewSummaryProvider(_range));

    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Review',
              style:
                  textTheme.displaySmall?.copyWith(fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: 12),
            SegmentedButton<ReviewRangeOption>(
              segments: const [
                ButtonSegment(
                  value: ReviewRangeOption.thisWeek,
                  label: Text('This week'),
                ),
                ButtonSegment(
                  value: ReviewRangeOption.last4Weeks,
                  label: Text('Last 4 weeks'),
                ),
              ],
              selected: {_selected},
              onSelectionChanged: (selection) {
                final next = selection.first;
                setState(() {
                  _selected = next;
                  _range = _buildRange(next);
                });
              },
            ),
            const SizedBox(height: 16),
            Expanded(
              child: summaryAsync.when(
                loading: () =>
                    const Center(child: CircularProgressIndicator()),
                error: (error, stack) => SingleChildScrollView(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    children: [
                      const Text('Failed to load review.'),
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
                            ref.invalidate(reviewSummaryProvider(_range)),
                        child: const Text('Retry'),
                      ),
                    ],
                  ),
                ),
                data: (summary) {
                  return ListView(
                    children: [
                      _MetricCard(
                        label: 'Sessions completed',
                        value: summary.sessionsCompleted.toString(),
                      ),
                      _MetricCard(
                        label: 'Total working sets',
                        value: summary.totalWorkingSets.toString(),
                      ),
                      _MetricCard(
                        label: 'Total volume (kg)',
                        value: summary.totalVolume.toStringAsFixed(0),
                      ),
                      _MetricCard(
                        label: 'Total duration',
                        value: _formatDuration(summary.totalDuration),
                      ),
                      const SizedBox(height: 12),
                      Text(
                        'Top muscles',
                        style: textTheme.titleMedium,
                      ),
                      const SizedBox(height: 8),
                      if (summary.muscleSummary.isEmpty)
                        const Text('No muscle data yet.')
                      else
                        ...summary.muscleSummary.map(
                          (muscle) => ListTile(
                            contentPadding: EdgeInsets.zero,
                            title: Text(_formatMuscle(muscle.muscle)),
                            trailing: Text('${muscle.sets} sets'),
                          ),
                        ),
                      const SizedBox(height: 12),
                      Text(
                        'Top exercises',
                        style: textTheme.titleMedium,
                      ),
                      const SizedBox(height: 8),
                      if (summary.exerciseHighlights.isEmpty)
                        const Text('No exercise data yet.')
                      else
                        ...summary.exerciseHighlights.map(
                          (exercise) => ListTile(
                            contentPadding: EdgeInsets.zero,
                            title: Text(exercise.exerciseName),
                            subtitle: Text(
                              'Volume ${exercise.volume.toStringAsFixed(0)} kg',
                            ),
                            trailing: Text(
                              '${exercise.bestWeightKg.toStringAsFixed(1)} x ${exercise.bestReps}',
                            ),
                          ),
                        ),
                    ],
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }

  ReviewRange _buildRange(ReviewRangeOption option) {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final startOfWeek = today.subtract(Duration(days: today.weekday - 1));
    final start = option == ReviewRangeOption.thisWeek
        ? startOfWeek
        : startOfWeek.subtract(const Duration(days: 28));
    return ReviewRange(start: start, end: now);
  }

  String _formatDuration(Duration duration) {
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

class _MetricCard extends StatelessWidget {
  const _MetricCard({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Card(
      elevation: 0,
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Row(
          children: [
            Expanded(child: Text(label)),
            Text(
              value,
              style: Theme.of(context).textTheme.titleMedium,
            ),
          ],
        ),
      ),
    );
  }
}
