import 'dart:io';

import 'package:csv/csv.dart';
import 'package:drift/drift.dart' as drift;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';

import '../data/db/app_database.dart';

final exportServiceProvider = Provider<ExportService>((ref) {
  final db = ref.read(appDatabaseProvider);
  return ExportService(db);
});

class ExportService {
  ExportService(this._db);

  final AppDatabase _db;

  Future<File> exportSetsCsv({
    DateTime? start,
    DateTime? end,
  }) async {
    final rows = await _fetchRows(start: start, end: end);
    rows.sort(_compareRows);

    final data = <List<dynamic>>[
      _headerRow,
      ...rows.map(_rowToCsv),
    ];

    final csv = const ListToCsvConverter().convert(data);
    final directory = await getApplicationDocumentsDirectory();
    final fileName = 'gym_runner_sets_${_timestamp()}.csv';
    final file = File(p.join(directory.path, fileName));
    await file.writeAsString(csv);
    return file;
  }

  Future<void> shareFile(File file) async {
    await Share.shareXFiles([XFile(file.path)], subject: 'Gym Runner Export');
  }

  Future<List<_ExportRow>> _fetchRows({
    DateTime? start,
    DateTime? end,
  }) async {
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
      drift.leftOuterJoin(
        _db.programs,
        _db.programs.id.equalsExp(_db.sessions.programId),
      ),
      drift.leftOuterJoin(
        _db.workoutDays,
        _db.workoutDays.id.equalsExp(_db.sessions.workoutDayId),
      ),
    ]);

    query.where(_db.sessions.finishedAt.isNotNull());

    if (start != null && end != null) {
      final rangeCondition =
          _db.sessions.startedAt.isBetweenValues(start, end) |
              _db.sessions.finishedAt.isBetweenValues(start, end);
      query.where(rangeCondition);
    }

    final results = await query.get();
    return results
        .map(
          (row) => _ExportRow(
            setLog: row.readTable(_db.setLogs),
            sessionExercise: row.readTable(_db.sessionExercises),
            session: row.readTable(_db.sessions),
            exercise: row.readTable(_db.exercises),
            program: row.readTableOrNull(_db.programs),
            workoutDay: row.readTableOrNull(_db.workoutDays),
          ),
        )
        .toList();
  }

  int _compareRows(_ExportRow a, _ExportRow b) {
    final sessionCompare = a.session.startedAt.compareTo(b.session.startedAt);
    if (sessionCompare != 0) {
      return sessionCompare;
    }
    final orderCompare =
        a.sessionExercise.orderIndex.compareTo(b.sessionExercise.orderIndex);
    if (orderCompare != 0) {
      return orderCompare;
    }
    final typeCompare = _setTypeOrder(a.setLog)
        .compareTo(_setTypeOrder(b.setLog));
    if (typeCompare != 0) {
      return typeCompare;
    }
    return a.setLog.setIndex.compareTo(b.setLog.setIndex);
  }

  int _setTypeOrder(SetLog log) => log.isWarmup ? 0 : 1;

  List<dynamic> _rowToCsv(_ExportRow row) {
    final session = row.session;
    final finishedAt = session.finishedAt;
    final durationSeconds = finishedAt == null
        ? ''
        : finishedAt.difference(session.startedAt).inSeconds.toString();

    return [
      session.id,
      session.startedAt.toIso8601String(),
      finishedAt?.toIso8601String() ?? '',
      durationSeconds,
      session.isDeload ? 'true' : 'false',
      row.program?.name ?? '',
      row.workoutDay?.name ?? '',
      row.exercise.name,
      row.exercise.primaryMuscle,
      row.setLog.isWarmup ? 'warmup' : 'working',
      row.setLog.setIndex,
      _formatDouble(row.setLog.weightKg),
      row.setLog.reps,
      row.setLog.rpe == null ? '' : _formatDouble(row.setLog.rpe!),
    ];
  }

  String _timestamp() {
    final now = DateTime.now();
    return '${now.year}${_two(now.month)}${_two(now.day)}_'
        '${_two(now.hour)}${_two(now.minute)}${_two(now.second)}';
  }

  String _two(int value) => value.toString().padLeft(2, '0');

  String _formatDouble(double value) {
    if (value % 1 == 0) {
      return value.toStringAsFixed(0);
    }
    return value.toStringAsFixed(2);
  }
}

class _ExportRow {
  const _ExportRow({
    required this.setLog,
    required this.sessionExercise,
    required this.session,
    required this.exercise,
    required this.program,
    required this.workoutDay,
  });

  final SetLog setLog;
  final SessionExercise sessionExercise;
  final Session session;
  final Exercise exercise;
  final Program? program;
  final WorkoutDay? workoutDay;
}

const _headerRow = [
  'sessionId',
  'sessionStartedAt',
  'sessionFinishedAt',
  'durationSeconds',
  'isDeload',
  'programName',
  'workoutDayName',
  'exerciseName',
  'primaryMuscle',
  'setType',
  'setIndex',
  'weightKg',
  'reps',
  'rpe',
];
