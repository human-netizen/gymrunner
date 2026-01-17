import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../data/providers.dart';
import '../../data/repositories/exercise_analytics_repository.dart';

class ExerciseDetailScreen extends ConsumerWidget {
  const ExerciseDetailScreen({super.key, required this.exerciseId});

  final int exerciseId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final exerciseAsync = ref.watch(exerciseProvider(exerciseId));
    final historyAsync = ref.watch(exerciseHistoryProvider(exerciseId));
    final prsAsync = ref.watch(exercisePRsProvider(exerciseId));
    final textTheme = Theme.of(context).textTheme;

    final error = exerciseAsync.error ?? historyAsync.error ?? prsAsync.error;
    final stack = exerciseAsync.stackTrace ??
        historyAsync.stackTrace ??
        prsAsync.stackTrace;

    if (error != null) {
      return Scaffold(
        appBar: AppBar(title: const Text('Exercise Details')),
        body: SingleChildScrollView(
          padding: const EdgeInsets.all(16),
          child: Column(
            children: [
              const Text('Failed to load exercise details.'),
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
                onPressed: () {
                  ref.invalidate(exerciseProvider(exerciseId));
                  ref.invalidate(exerciseHistoryProvider(exerciseId));
                  ref.invalidate(exercisePRsProvider(exerciseId));
                },
                child: const Text('Retry'),
              ),
            ],
          ),
        ),
      );
    }

    if (exerciseAsync.isLoading ||
        historyAsync.isLoading ||
        prsAsync.isLoading) {
      return Scaffold(
        appBar: AppBar(title: const Text('Exercise Details')),
        body: const Center(child: CircularProgressIndicator()),
      );
    }

    final exercise = exerciseAsync.value;
    final history = historyAsync.value ?? const <ExerciseSessionEntry>[];
    final prs = prsAsync.value ?? const ExercisePRs(
          bestWeight: null,
          bestReps: null,
          bestSetVolume: null,
          bestE1rm: null,
        );

    if (exercise == null) {
      return Scaffold(
        appBar: AppBar(title: const Text('Exercise Details')),
        body: const Center(child: Text('Exercise not found.')),
      );
    }

    final chartEntries = [...history]
      ..sort((a, b) => a.date.compareTo(b.date));
    final recentEntries = [...history]
      ..sort((a, b) => b.date.compareTo(a.date));

    return Scaffold(
      appBar: AppBar(title: Text(exercise.name)),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Text(
            exercise.name,
            style: textTheme.headlineSmall?.copyWith(
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            _formatMuscle(exercise.primaryMuscle),
            style: textTheme.bodyMedium,
          ),
          const SizedBox(height: 16),
          if (history.isEmpty)
            const Text('No finished sessions for this exercise yet.')
          else ...[
            Text('PRs', style: textTheme.titleMedium),
            const SizedBox(height: 8),
            Wrap(
              spacing: 12,
              runSpacing: 12,
              children: [
                _PrCard(
                  label: 'Best e1RM',
                  value: _formatWeight(prs.bestE1rm?.value),
                  date: _formatDate(context, prs.bestE1rm?.date),
                ),
                _PrCard(
                  label: 'Best weight',
                  value: _formatWeight(prs.bestWeight?.value),
                  date: _formatDate(context, prs.bestWeight?.date),
                ),
                _PrCard(
                  label: 'Best reps',
                  value: prs.bestReps == null
                      ? '—'
                      : prs.bestReps!.value.toInt().toString(),
                  date: _formatDate(context, prs.bestReps?.date),
                ),
                _PrCard(
                  label: 'Best set volume',
                  value: _formatVolume(prs.bestSetVolume?.value),
                  date: _formatDate(context, prs.bestSetVolume?.date),
                ),
              ],
            ),
            const SizedBox(height: 16),
            Text('e1RM over time', style: textTheme.titleMedium),
            const SizedBox(height: 8),
            SizedBox(
              height: 200,
              child: _LineChart(entries: chartEntries),
            ),
            const SizedBox(height: 16),
            Text('Volume per session', style: textTheme.titleMedium),
            const SizedBox(height: 8),
            SizedBox(
              height: 200,
              child: _BarChart(entries: chartEntries),
            ),
            const SizedBox(height: 16),
            Text('Recent sessions', style: textTheme.titleMedium),
            const SizedBox(height: 8),
            ...recentEntries.take(10).map(
              (entry) => ListTile(
                contentPadding: EdgeInsets.zero,
                title: Text(_formatDate(context, entry.date)),
                subtitle: Text(_formatSets(entry.sets)),
                trailing: Text(
                  '${entry.workingSetCount} sets',
                ),
                onTap: () => context.push('/history/${entry.sessionId}'),
              ),
            ),
          ],
        ],
      ),
    );
  }

  String _formatDate(BuildContext context, DateTime? date) {
    if (date == null) {
      return '—';
    }
    return MaterialLocalizations.of(context).formatShortDate(date);
  }

  String _formatMuscle(String muscle) {
    if (muscle.isEmpty) {
      return muscle;
    }
    return muscle[0].toUpperCase() + muscle.substring(1);
  }

  String _formatWeight(double? value) {
    if (value == null) {
      return '—';
    }
    return '${value.toStringAsFixed(1)} kg';
  }

  String _formatVolume(double? value) {
    if (value == null) {
      return '—';
    }
    return value.toStringAsFixed(0);
  }

  String _formatSets(List<ExerciseSetEntry> sets) {
    if (sets.isEmpty) {
      return 'No sets logged';
    }
    return sets
        .map(
          (set) => '${set.weightKg.toStringAsFixed(1)}x${set.reps}',
        )
        .join(', ');
  }
}

class _PrCard extends StatelessWidget {
  const _PrCard({
    required this.label,
    required this.value,
    required this.date,
  });

  final String label;
  final String value;
  final String date;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 160,
      child: Card(
        elevation: 0,
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                label,
                style: Theme.of(context).textTheme.labelMedium,
              ),
              const SizedBox(height: 4),
              Text(
                value,
                style: Theme.of(context).textTheme.titleMedium,
              ),
              const SizedBox(height: 2),
              Text(
                date,
                style: Theme.of(context).textTheme.bodySmall,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _LineChart extends StatelessWidget {
  const _LineChart({required this.entries});

  final List<ExerciseSessionEntry> entries;

  @override
  Widget build(BuildContext context) {
    if (entries.isEmpty) {
      return const Center(child: Text('No data yet.'));
    }

    final spots = entries.asMap().entries.map((entry) {
      return FlSpot(
        entry.key.toDouble(),
        entry.value.maxE1rm,
      );
    }).toList();

    return LineChart(
      LineChartData(
        gridData: const FlGridData(show: false),
        titlesData: FlTitlesData(
          topTitles: const AxisTitles(
            sideTitles: SideTitles(showTitles: false),
          ),
          rightTitles: const AxisTitles(
            sideTitles: SideTitles(showTitles: false),
          ),
          leftTitles: AxisTitles(
            sideTitles: SideTitles(
              showTitles: true,
              reservedSize: 36,
              getTitlesWidget: (value, meta) => Text(
                value.toStringAsFixed(0),
                style: Theme.of(context).textTheme.labelSmall,
              ),
            ),
          ),
          bottomTitles: AxisTitles(
            sideTitles: SideTitles(
              showTitles: true,
              interval: 1,
              getTitlesWidget: (value, meta) {
                final index = value.toInt();
                if (index < 0 || index >= entries.length) {
                  return const SizedBox.shrink();
                }
                final date = entries[index].date;
                final label =
                    MaterialLocalizations.of(context).formatShortDate(date);
                return Padding(
                  padding: const EdgeInsets.only(top: 4),
                  child: Text(
                    label,
                    style: Theme.of(context).textTheme.labelSmall,
                  ),
                );
              },
            ),
          ),
        ),
        borderData: FlBorderData(show: false),
        lineBarsData: [
          LineChartBarData(
            spots: spots,
            isCurved: true,
            barWidth: 3,
            dotData: const FlDotData(show: true),
          ),
        ],
      ),
    );
  }
}

class _BarChart extends StatelessWidget {
  const _BarChart({required this.entries});

  final List<ExerciseSessionEntry> entries;

  @override
  Widget build(BuildContext context) {
    if (entries.isEmpty) {
      return const Center(child: Text('No data yet.'));
    }

    final groups = entries.asMap().entries.map((entry) {
      return BarChartGroupData(
        x: entry.key,
        barRods: [
          BarChartRodData(
            toY: entry.value.volume,
            width: 12,
            borderRadius: BorderRadius.circular(4),
          ),
        ],
      );
    }).toList();

    return BarChart(
      BarChartData(
        gridData: const FlGridData(show: false),
        titlesData: FlTitlesData(
          topTitles: const AxisTitles(
            sideTitles: SideTitles(showTitles: false),
          ),
          rightTitles: const AxisTitles(
            sideTitles: SideTitles(showTitles: false),
          ),
          leftTitles: AxisTitles(
            sideTitles: SideTitles(
              showTitles: true,
              reservedSize: 36,
              getTitlesWidget: (value, meta) => Text(
                value.toStringAsFixed(0),
                style: Theme.of(context).textTheme.labelSmall,
              ),
            ),
          ),
          bottomTitles: AxisTitles(
            sideTitles: SideTitles(
              showTitles: true,
              interval: 1,
              getTitlesWidget: (value, meta) {
                final index = value.toInt();
                if (index < 0 || index >= entries.length) {
                  return const SizedBox.shrink();
                }
                final date = entries[index].date;
                final label =
                    MaterialLocalizations.of(context).formatShortDate(date);
                return Padding(
                  padding: const EdgeInsets.only(top: 4),
                  child: Text(
                    label,
                    style: Theme.of(context).textTheme.labelSmall,
                  ),
                );
              },
            ),
          ),
        ),
        borderData: FlBorderData(show: false),
        barGroups: groups,
      ),
    );
  }
}
