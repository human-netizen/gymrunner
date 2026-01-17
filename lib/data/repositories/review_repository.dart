import 'package:drift/drift.dart' as drift;

import '../db/app_database.dart';

class ReviewRange {
  const ReviewRange({required this.start, required this.end});

  final DateTime start;
  final DateTime end;

  @override
  bool operator ==(Object other) {
    return other is ReviewRange &&
        other.start == start &&
        other.end == end;
  }

  @override
  int get hashCode => Object.hash(start, end);
}

class ReviewSummary {
  const ReviewSummary({
    required this.sessionsCompleted,
    required this.totalWorkingSets,
    required this.totalVolume,
    required this.totalDuration,
    required this.muscleSummary,
    required this.exerciseHighlights,
  });

  final int sessionsCompleted;
  final int totalWorkingSets;
  final double totalVolume;
  final Duration totalDuration;
  final List<MuscleSummary> muscleSummary;
  final List<ExerciseHighlight> exerciseHighlights;
}

class MuscleSummary {
  const MuscleSummary({
    required this.muscle,
    required this.sets,
    required this.volume,
  });

  final String muscle;
  final int sets;
  final double volume;
}

class ExerciseHighlight {
  const ExerciseHighlight({
    required this.exerciseId,
    required this.exerciseName,
    required this.volume,
    required this.bestWeightKg,
    required this.bestReps,
  });

  final int exerciseId;
  final String exerciseName;
  final double volume;
  final double bestWeightKg;
  final int bestReps;
}

class ReviewRepository {
  ReviewRepository(this._db);

  final AppDatabase _db;

  Stream<ReviewSummary> watchReviewSummary(
    DateTime rangeStart,
    DateTime rangeEnd,
  ) {
    final query = _db.select(_db.setLogs).join([
      drift.innerJoin(
        _db.sessionExercises,
        _db.sessionExercises.id.equalsExp(_db.setLogs.sessionExerciseId),
      ),
      drift.innerJoin(
        _db.sessions,
        _db.sessions.id.equalsExp(_db.sessionExercises.sessionId),
      ),
      drift.innerJoin(
        _db.exercises,
        _db.exercises.id.equalsExp(_db.sessionExercises.exerciseId),
      ),
    ]);

    final rangeCondition = _db.sessions.startedAt.isBetweenValues(
          rangeStart,
          rangeEnd,
        ) |
        _db.sessions.finishedAt.isBetweenValues(rangeStart, rangeEnd);

    query.where(
      _db.setLogs.isWarmup.equals(false) &
          _db.sessions.finishedAt.isNotNull() &
          rangeCondition,
    );

    return query.watch().map((rows) {
      final workingSets = rows
          .map(
            (row) => _WorkingSetRow(
              setLog: row.readTable(_db.setLogs),
              exercise: row.readTable(_db.exercises),
              session: row.readTable(_db.sessions),
            ),
          )
          .toList();

      return _buildSummary(workingSets);
    });
  }
  ReviewSummary _buildSummary(
    List<_WorkingSetRow> sets,
  ) {
    final sessionsById = <int, Session>{};
    for (final row in sets) {
      sessionsById[row.session.id] = row.session;
    }

    final totalDuration = sessionsById.values.fold<Duration>(
      Duration.zero,
      (sum, session) =>
          sum + session.finishedAt!.difference(session.startedAt),
    );

    final totalWorkingSets = sets.length;
    var totalVolume = 0.0;
    final muscleCounts = <String, int>{};
    final muscleVolume = <String, double>{};
    final exerciseVolume = <int, double>{};
    final exerciseName = <int, String>{};
    final bestSetByExercise = <int, SetLog>{};

    for (final row in sets) {
      final volume = row.setLog.weightKg * row.setLog.reps;
      totalVolume += volume;

      final primary = row.exercise.primaryMuscle;
      muscleCounts[primary] = (muscleCounts[primary] ?? 0) + 1;
      muscleVolume[primary] = (muscleVolume[primary] ?? 0) + volume;

      final id = row.exercise.id;
      exerciseVolume[id] = (exerciseVolume[id] ?? 0) + volume;
      exerciseName[id] = row.exercise.name;

      final currentBest = bestSetByExercise[id];
      if (currentBest == null ||
          row.setLog.weightKg > currentBest.weightKg ||
          (row.setLog.weightKg == currentBest.weightKg &&
              row.setLog.reps > currentBest.reps)) {
        bestSetByExercise[id] = row.setLog;
      }
    }

    final muscleSummary = muscleCounts.entries
        .map(
          (entry) => MuscleSummary(
            muscle: entry.key,
            sets: entry.value,
            volume: muscleVolume[entry.key] ?? 0,
          ),
        )
        .toList()
      ..sort((a, b) => b.sets.compareTo(a.sets));

    final exerciseHighlights = exerciseVolume.entries
        .map(
          (entry) => ExerciseHighlight(
            exerciseId: entry.key,
            exerciseName: exerciseName[entry.key] ?? 'Exercise',
            volume: entry.value,
            bestWeightKg: bestSetByExercise[entry.key]?.weightKg ?? 0,
            bestReps: bestSetByExercise[entry.key]?.reps ?? 0,
          ),
        )
        .toList()
      ..sort((a, b) => b.volume.compareTo(a.volume));

    return ReviewSummary(
      sessionsCompleted: sessionsById.length,
      totalWorkingSets: totalWorkingSets,
      totalVolume: totalVolume,
      totalDuration: totalDuration,
      muscleSummary: muscleSummary.take(5).toList(),
      exerciseHighlights: exerciseHighlights.take(5).toList(),
    );
  }
}

class _WorkingSetRow {
  const _WorkingSetRow({
    required this.setLog,
    required this.exercise,
    required this.session,
  });

  final SetLog setLog;
  final Exercise exercise;
  final Session session;
}
