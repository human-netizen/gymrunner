import 'dart:convert';
import 'dart:io';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

import '../data/db/app_database.dart';

final backupServiceProvider = Provider<BackupService>((ref) {
  final db = ref.read(appDatabaseProvider);
  return BackupService(db);
});

class BackupService {
  BackupService(this._db);

  final AppDatabase _db;

  Future<File> exportBackup() async {
    final payload = await buildBackupMap();
    final directory = await getApplicationDocumentsDirectory();
    final fileName = 'gym_runner_backup_${_timestamp()}.json';
    final file = File(p.join(directory.path, fileName));
    await file.writeAsString(jsonEncode(payload));
    return file;
  }

  Future<Map<String, dynamic>> buildBackupMap() async {
    final exercises = await _db.select(_db.exercises).get();
    final programs = await _db.select(_db.programs).get();
    final workoutDays = await _db.select(_db.workoutDays).get();
    final prescriptions = await _db.select(_db.prescriptions).get();
    final sessions = await _db.select(_db.sessions).get();
    final sessionExercises = await _db.select(_db.sessionExercises).get();
    final setLogs = await _db.select(_db.setLogs).get();
    final settings = await _db.select(_db.settings).get();

    return <String, dynamic>{
      'version': 1,
      'exportedAt': DateTime.now().toIso8601String(),
      'data': {
        'exercises': exercises.map((row) => row.toJson()).toList(),
        'programs': programs.map((row) => row.toJson()).toList(),
        'workoutDays': workoutDays.map((row) => row.toJson()).toList(),
        'prescriptions': prescriptions.map((row) => row.toJson()).toList(),
        'sessions': sessions.map((row) => row.toJson()).toList(),
        'sessionExercises':
            sessionExercises.map((row) => row.toJson()).toList(),
        'setLogs': setLogs.map((row) => row.toJson()).toList(),
        'settings': settings.map((row) => row.toJson()).toList(),
      },
    };
  }

  Future<void> importBackupJson(String jsonString) async {
    final payload = jsonDecode(jsonString);
    if (payload is! Map<String, dynamic>) {
      throw const FormatException('Invalid backup file.');
    }

    await importBackupMap(payload);
  }

  Future<void> importBackupMap(Map<String, dynamic> payload) async {
    final version = payload['version'];
    if (version != 1) {
      throw FormatException('Unsupported backup version: $version');
    }

    final data = payload['data'];
    if (data is! Map<String, dynamic>) {
      throw const FormatException('Invalid backup data.');
    }

    final exercises = _decodeList(data, 'exercises', Exercise.fromJson);
    final programs = _decodeList(data, 'programs', Program.fromJson);
    final workoutDays = _decodeList(data, 'workoutDays', WorkoutDay.fromJson);
    final prescriptions =
        _decodeList(data, 'prescriptions', Prescription.fromJson);
    final sessions = _decodeList(data, 'sessions', Session.fromJson);
    final sessionExercises =
        _decodeList(data, 'sessionExercises', SessionExercise.fromJson);
    final setLogs = _decodeList(data, 'setLogs', SetLog.fromJson);
    final settings = _decodeList(data, 'settings', Setting.fromJson);

    await _db.transaction(() async {
      await (_db.delete(_db.setLogs)).go();
      await (_db.delete(_db.sessionExercises)).go();
      await (_db.delete(_db.sessions)).go();
      await (_db.delete(_db.prescriptions)).go();
      await (_db.delete(_db.workoutDays)).go();
      await (_db.delete(_db.programs)).go();
      await (_db.delete(_db.exercises)).go();
      await (_db.delete(_db.settings)).go();

      await _db.batch((batch) {
        batch.insertAll(_db.exercises, exercises);
        batch.insertAll(_db.programs, programs);
        batch.insertAll(_db.workoutDays, workoutDays);
        batch.insertAll(_db.prescriptions, prescriptions);
        batch.insertAll(_db.sessions, sessions);
        batch.insertAll(_db.sessionExercises, sessionExercises);
        batch.insertAll(_db.setLogs, setLogs);
        batch.insertAll(_db.settings, settings);
      });
    });
  }

  List<T> _decodeList<T>(
    Map<String, dynamic> data,
    String key,
    T Function(Map<String, dynamic>) fromJson,
  ) {
    final raw = data[key];
    if (raw is! List) {
      throw FormatException('Missing or invalid "$key" list.');
    }

    return raw
        .map((item) => Map<String, dynamic>.from(item as Map))
        .map(fromJson)
        .toList();
  }

  String _timestamp() {
    final now = DateTime.now();
    return '${now.year}${_two(now.month)}${_two(now.day)}_'
        '${_two(now.hour)}${_two(now.minute)}';
  }

  String _two(int value) => value.toString().padLeft(2, '0');
}
