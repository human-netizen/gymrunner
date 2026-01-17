import 'package:drift/drift.dart' as drift;
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../data/db/app_database.dart';
import '../data/repositories/session_repository.dart';

final sessionShareServiceProvider = Provider<SessionShareService>((ref) {
  final db = ref.read(appDatabaseProvider);
  return SessionShareService(db);
});

class SessionShareService {
  SessionShareService(this._db);

  final AppDatabase _db;

  Future<String> buildSessionSummaryText(int sessionId) async {
    final summary = await _fetchSessionSummary(sessionId);
    if (summary == null) {
      throw StateError('Session not found.');
    }
    if (summary.session.finishedAt == null) {
      throw StateError('Session is not finished yet.');
    }

    final exercises = await _fetchSessionExercises(sessionId);
    final buffer = StringBuffer();
    final date = summary.session.startedAt;
    final dayName = summary.workoutDay?.name ?? 'Workout Session';
    final weekday = _weekdayShort(date.weekday);
    final dateLabel = '${date.year}-${_two(date.month)}-${_two(date.day)}';
    final duration = summary.duration;
    final durationLabel =
        duration == null ? '—' : _formatDuration(duration);

    buffer.writeln('Workout — $weekday, $dateLabel ($dayName)');
    buffer.writeln('Duration: $durationLabel');
    buffer.writeln('Deload: ${summary.session.isDeload ? 'Yes' : 'No'}');
    buffer.writeln('');

    for (final item in exercises) {
      buffer.writeln(item.exercise.name);
      final warmups = item.warmupSets;
      final workingSets = item.workingSets;
      if (warmups.isNotEmpty) {
        buffer.writeln('Warmup:');
        for (final set in warmups) {
          buffer.writeln(
            '- ${_formatWeight(set.weightKg)} x ${set.reps}',
          );
        }
      }
      if (workingSets.isNotEmpty) {
        buffer.writeln('Working sets:');
        for (final set in workingSets) {
          buffer.writeln(
            '- ${_formatWeight(set.weightKg)} x ${set.reps}',
          );
        }
      }
      if (warmups.isEmpty && workingSets.isEmpty) {
        buffer.writeln('No sets logged.');
      }
      buffer.writeln('');
    }

    return buffer.toString().trim();
  }

  Future<SessionSummary?> _fetchSessionSummary(int sessionId) async {
    final query = _db.select(_db.sessions).join([
      drift.leftOuterJoin(
        _db.workoutDays,
        _db.workoutDays.id.equalsExp(_db.sessions.workoutDayId),
      ),
      drift.leftOuterJoin(
        _db.programs,
        _db.programs.id.equalsExp(_db.sessions.programId),
      ),
    ]);
    query.where(_db.sessions.id.equals(sessionId));
    query.limit(1);

    final row = await query.getSingleOrNull();
    if (row == null) {
      return null;
    }

    return SessionSummary(
      session: row.readTable(_db.sessions),
      workoutDay: row.readTableOrNull(_db.workoutDays),
      program: row.readTableOrNull(_db.programs),
    );
  }

  Future<List<SessionExerciseWithExerciseAndSets>> _fetchSessionExercises(
    int sessionId,
  ) async {
    final query = _db.select(_db.sessionExercises).join([
      drift.innerJoin(
        _db.exercises,
        _db.exercises.id.equalsExp(_db.sessionExercises.exerciseId),
      ),
      drift.leftOuterJoin(
        _db.setLogs,
        _db.setLogs.sessionExerciseId.equalsExp(_db.sessionExercises.id),
      ),
    ]);
    query.where(_db.sessionExercises.sessionId.equals(sessionId));
    query.orderBy([
      drift.OrderingTerm(expression: _db.sessionExercises.orderIndex),
      drift.OrderingTerm(expression: _db.setLogs.setIndex),
    ]);

    final rows = await query.get();
    final grouped = <int, _SessionExerciseGroup>{};

    for (final row in rows) {
      final sessionExercise = row.readTable(_db.sessionExercises);
      final exercise = row.readTable(_db.exercises);
      final setLog = row.readTableOrNull(_db.setLogs);

      final entry = grouped.putIfAbsent(
        sessionExercise.id,
        () => _SessionExerciseGroup(sessionExercise, exercise),
      );
      if (setLog != null) {
        entry.sets.add(setLog);
      }
    }

    return grouped.values
        .map(
          (entry) => SessionExerciseWithExerciseAndSets(
            sessionExercise: entry.sessionExercise,
            exercise: entry.exercise,
            sets: entry.sets..sort((a, b) => a.setIndex.compareTo(b.setIndex)),
          ),
        )
        .toList();
  }

  String _weekdayShort(int weekday) {
    switch (weekday) {
      case DateTime.monday:
        return 'Mon';
      case DateTime.tuesday:
        return 'Tue';
      case DateTime.wednesday:
        return 'Wed';
      case DateTime.thursday:
        return 'Thu';
      case DateTime.friday:
        return 'Fri';
      case DateTime.saturday:
        return 'Sat';
      case DateTime.sunday:
        return 'Sun';
    }
    return '';
  }

  String _two(int value) => value.toString().padLeft(2, '0');

  String _formatDuration(Duration duration) {
    final hours = duration.inHours;
    final minutes = duration.inMinutes % 60;
    if (hours > 0) {
      return '${hours}h ${minutes}m';
    }
    return '${duration.inMinutes}m';
  }

  String _formatWeight(double value) {
    if (value % 1 == 0) {
      return value.toStringAsFixed(0);
    }
    return value.toStringAsFixed(1);
  }
}

class _SessionExerciseGroup {
  _SessionExerciseGroup(this.sessionExercise, this.exercise);

  final SessionExercise sessionExercise;
  final Exercise exercise;
  final List<SetLog> sets = [];
}
