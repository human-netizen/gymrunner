import 'dart:math';

import 'package:drift/drift.dart' as drift;

import '../db/app_database.dart';

class ExerciseSetEntry {
  const ExerciseSetEntry({
    required this.weightKg,
    required this.reps,
  });

  final double weightKg;
  final int reps;
}

class ExerciseSessionEntry {
  const ExerciseSessionEntry({
    required this.sessionId,
    required this.date,
    required this.sets,
    required this.maxE1rm,
    required this.volume,
    required this.workingSetCount,
  });

  final int sessionId;
  final DateTime date;
  final List<ExerciseSetEntry> sets;
  final double maxE1rm;
  final double volume;
  final int workingSetCount;
}

class ExercisePRMetric {
  const ExercisePRMetric({
    required this.value,
    required this.date,
  });

  final double value;
  final DateTime date;
}

class ExercisePRs {
  const ExercisePRs({
    required this.bestWeight,
    required this.bestReps,
    required this.bestSetVolume,
    required this.bestE1rm,
  });

  final ExercisePRMetric? bestWeight;
  final ExercisePRMetric? bestReps;
  final ExercisePRMetric? bestSetVolume;
  final ExercisePRMetric? bestE1rm;
}

class ExerciseSearchResult {
  const ExerciseSearchResult({
    required this.id,
    required this.name,
    required this.primaryMuscle,
  });

  final int id;
  final String name;
  final String primaryMuscle;
}

class ExerciseAnalyticsRepository {
  ExerciseAnalyticsRepository(this._db);

  final AppDatabase _db;

  Stream<List<ExerciseSessionEntry>> watchExerciseHistory(
    int exerciseId, {
    int limit = 50,
  }) {
    return _exerciseSetRows(exerciseId).map((rows) {
      final grouped = _groupBySession(rows);
      final entries = grouped.values.toList()
        ..sort((a, b) => b.date.compareTo(a.date));
      return entries.take(limit).toList();
    });
  }

  Stream<ExercisePRs> watchExercisePRs(int exerciseId) {
    return _exerciseSetRows(exerciseId).map((rows) {
      ExercisePRMetric? bestWeight;
      ExercisePRMetric? bestReps;
      ExercisePRMetric? bestSetVolume;
      ExercisePRMetric? bestE1rm;

      for (final row in rows) {
        final date = row.sessionDate;
        final weight = row.setLog.weightKg;
        final reps = row.setLog.reps;
        final volume = weight * reps;
        final e1rm = _estimate1rm(weight, reps);

        if (bestWeight == null || weight > bestWeight.value) {
          bestWeight = ExercisePRMetric(value: weight, date: date);
        }
        if (bestReps == null || reps > bestReps.value) {
          bestReps = ExercisePRMetric(value: reps.toDouble(), date: date);
        }
        if (bestSetVolume == null || volume > bestSetVolume.value) {
          bestSetVolume = ExercisePRMetric(value: volume, date: date);
        }
        if (bestE1rm == null || e1rm > bestE1rm.value) {
          bestE1rm = ExercisePRMetric(value: e1rm, date: date);
        }
      }

      return ExercisePRs(
        bestWeight: bestWeight,
        bestReps: bestReps,
        bestSetVolume: bestSetVolume,
        bestE1rm: bestE1rm,
      );
    });
  }

  Stream<List<ExerciseSearchResult>> watchExerciseSearchResults(String query) {
    final trimmed = query.trim();
    if (trimmed.isEmpty) {
      return Stream.value(const []);
    }

    final lowered = '%${trimmed.toLowerCase()}%';
    final selection = _db.select(_db.exercises)
      ..where((tbl) => tbl.name.lower().like(lowered))
      ..orderBy([(tbl) => drift.OrderingTerm(expression: tbl.name)]);
    return selection.watch().map(
          (rows) => rows
              .map(
                (exercise) => ExerciseSearchResult(
                  id: exercise.id,
                  name: exercise.name,
                  primaryMuscle: exercise.primaryMuscle,
                ),
              )
              .toList(),
        );
  }

  Stream<List<_ExerciseSetRow>> _exerciseSetRows(int exerciseId) {
    final query = _db.select(_db.setLogs).join([
      drift.innerJoin(
        _db.sessionExercises,
        _db.sessionExercises.id.equalsExp(_db.setLogs.sessionExerciseId),
      ),
      drift.innerJoin(
        _db.sessions,
        _db.sessions.id.equalsExp(_db.sessionExercises.sessionId),
      ),
    ]);

    query.where(
      _db.sessionExercises.exerciseId.equals(exerciseId) &
          _db.sessions.finishedAt.isNotNull() &
          _db.setLogs.isWarmup.equals(false),
    );

    query.orderBy([
      drift.OrderingTerm(
        expression: _db.sessions.startedAt,
        mode: drift.OrderingMode.desc,
      ),
      drift.OrderingTerm(expression: _db.setLogs.setIndex),
    ]);

    return query.watch().map((rows) {
      return rows
          .map(
            (row) => _ExerciseSetRow(
              setLog: row.readTable(_db.setLogs),
              session: row.readTable(_db.sessions),
            ),
          )
          .toList();
    });
  }

  Map<int, ExerciseSessionEntry> _groupBySession(
    List<_ExerciseSetRow> rows,
  ) {
    final grouped = <int, ExerciseSessionEntry>{};

    for (final row in rows) {
      final sessionId = row.session.id;
      final date = row.sessionDate;
      final entry = grouped[sessionId];

      final set = ExerciseSetEntry(
        weightKg: row.setLog.weightKg,
        reps: row.setLog.reps,
      );
      final e1rm = _estimate1rm(set.weightKg, set.reps);

      if (entry == null) {
        grouped[sessionId] = ExerciseSessionEntry(
          sessionId: sessionId,
          date: date,
          sets: [set],
          maxE1rm: e1rm,
          volume: set.weightKg * set.reps,
          workingSetCount: 1,
        );
      } else {
        final updatedSets = [...entry.sets, set];
        grouped[sessionId] = ExerciseSessionEntry(
          sessionId: entry.sessionId,
          date: entry.date,
          sets: updatedSets,
          maxE1rm: max(entry.maxE1rm, e1rm),
          volume: entry.volume + set.weightKg * set.reps,
          workingSetCount: entry.workingSetCount + 1,
        );
      }
    }

    return grouped;
  }

  double _estimate1rm(double weight, int reps) {
    if (reps <= 1) {
      return weight;
    }
    return weight * (1 + reps / 30.0);
  }
}

class _ExerciseSetRow {
  const _ExerciseSetRow({
    required this.setLog,
    required this.session,
  });

  final SetLog setLog;
  final Session session;

  DateTime get sessionDate => session.finishedAt ?? session.startedAt;
}
