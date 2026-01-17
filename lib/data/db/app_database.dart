import 'package:drift/drift.dart';
import 'package:drift_flutter/drift_flutter.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

part 'app_database.g.dart';

class Programs extends Table {
  IntColumn get id => integer().autoIncrement()();
  TextColumn get name => text()();
  DateTimeColumn get createdAt =>
      dateTime().withDefault(currentDateAndTime)();
}

class Settings extends Table {
  IntColumn get id => integer().autoIncrement()();
  RealColumn get barWeightKg => real().withDefault(const Constant(20.0))();
  IntColumn get activeProgramId =>
      integer().nullable().references(Programs, #id, onDelete: KeyAction.setNull)();
  TextColumn get plateInventoryCsv =>
      text().withDefault(const Constant('20,15,10,5,2.5,1.25'))();
  BoolColumn get backupAutoEnabled =>
      boolean().withDefault(const Constant(false))();
  BoolColumn get backupEncryptionEnabled =>
      boolean().withDefault(const Constant(false))();
  DateTimeColumn get lastAutoBackupAt => dateTime().nullable()();
  DateTimeColumn get createdAt =>
      dateTime().withDefault(currentDateAndTime)();
}

class Exercises extends Table {
  IntColumn get id => integer().autoIncrement()();
  TextColumn get name => text().unique()();
  TextColumn get primaryMuscle => text()();
  TextColumn get secondaryMuscles =>
      text().withDefault(const Constant(''))();
  IntColumn get defaultRestSeconds => integer().withDefault(const Constant(90))();
  RealColumn get defaultIncrementKg =>
      real().withDefault(const Constant(2.5))();
  DateTimeColumn get createdAt =>
      dateTime().withDefault(currentDateAndTime)();
}

class WorkoutDays extends Table {
  IntColumn get id => integer().autoIncrement()();
  IntColumn get programId =>
      integer().references(Programs, #id, onDelete: KeyAction.cascade)();
  TextColumn get name => text()();
  IntColumn get weekday => integer()();
  IntColumn get orderIndex => integer()();
  DateTimeColumn get createdAt =>
      dateTime().withDefault(currentDateAndTime)();
}

@TableIndex(
  name: 'prescriptions_day_order',
  columns: {#workoutDayId, #orderIndex},
  unique: true,
)
@TableIndex(
  name: 'prescriptions_day_exercise',
  columns: {#workoutDayId, #exerciseId},
)
class Prescriptions extends Table {
  IntColumn get id => integer().autoIncrement()();
  IntColumn get workoutDayId =>
      integer().references(WorkoutDays, #id, onDelete: KeyAction.cascade)();
  IntColumn get exerciseId => integer().references(Exercises, #id)();
  IntColumn get orderIndex => integer()();
  IntColumn get setsTarget => integer().withDefault(const Constant(3))();
  IntColumn get repMin => integer().withDefault(const Constant(8))();
  IntColumn get repMax => integer().withDefault(const Constant(12))();
  IntColumn get restSeconds => integer().nullable()();
  BoolColumn get warmupEnabled =>
      boolean().withDefault(const Constant(false))();
  RealColumn get incrementKg => real().nullable()();
  TextColumn get progressionRule =>
      text().withDefault(const Constant('double_progression'))();
  TextColumn get notes => text().nullable()();
}

@TableIndex(name: 'sessions_finished_at', columns: {#finishedAt})
class Sessions extends Table {
  IntColumn get id => integer().autoIncrement()();
  IntColumn get programId =>
      integer().nullable().references(Programs, #id, onDelete: KeyAction.setNull)();
  IntColumn get workoutDayId => integer()
      .nullable()
      .references(WorkoutDays, #id, onDelete: KeyAction.setNull)();
  IntColumn get currentSessionExerciseId => integer().nullable()();
  BoolColumn get isDeload =>
      boolean().withDefault(const Constant(false))();
  DateTimeColumn get startedAt =>
      dateTime().withDefault(currentDateAndTime)();
  DateTimeColumn get finishedAt => dateTime().nullable()();
  TextColumn get note => text().nullable()();
}

@TableIndex(name: 'session_exercises_session_id', columns: {#sessionId})
class SessionExercises extends Table {
  IntColumn get id => integer().autoIncrement()();
  IntColumn get sessionId =>
      integer().references(Sessions, #id, onDelete: KeyAction.cascade)();
  IntColumn get exerciseId => integer().references(Exercises, #id)();
  IntColumn get orderIndex => integer()();
  IntColumn get setsTarget => integer()();
  IntColumn get repMin => integer()();
  IntColumn get repMax => integer()();
  IntColumn get restSeconds => integer()();
  BoolColumn get warmupEnabled =>
      boolean().withDefault(const Constant(false))();
  BoolColumn get isCompleted =>
      boolean().withDefault(const Constant(false))();
  DateTimeColumn get completedAt => dateTime().nullable()();
  RealColumn get suggestedWorkingWeightKg => real().nullable()();
  RealColumn get incrementKg => real()();
  TextColumn get progressionRule => text()();
  TextColumn get prescriptionNotes => text().nullable()();
}

@TableIndex(
  name: 'set_logs_session_exercise_id',
  columns: {#sessionExerciseId},
)
class SetLogs extends Table {
  IntColumn get id => integer().autoIncrement()();
  IntColumn get sessionExerciseId =>
      integer().references(SessionExercises, #id, onDelete: KeyAction.cascade)();
  IntColumn get setIndex => integer()();
  RealColumn get weightKg => real()();
  IntColumn get reps => integer()();
  BoolColumn get isWarmup =>
      boolean().withDefault(const Constant(false))();
  RealColumn get rpe => real().nullable()();
  DateTimeColumn get createdAt =>
      dateTime().withDefault(currentDateAndTime)();
}

@DriftDatabase(
  tables: [
    Programs,
    Settings,
    Exercises,
    WorkoutDays,
    Prescriptions,
    Sessions,
    SessionExercises,
    SetLogs,
  ],
)
class AppDatabase extends _$AppDatabase {
  AppDatabase() : super(_openConnection());
  AppDatabase.forTesting(super.executor);

  @override
  int get schemaVersion => 8;

  @override
  MigrationStrategy get migration => MigrationStrategy(
        onCreate: (m) async {
          await m.createAll();
        },
        onUpgrade: (m, from, to) async {
          if (from < 2) {
            await m.createTable(programs);
            await m.createTable(exercises);
            await m.createTable(workoutDays);
            await m.createTable(prescriptions);
            await m.addColumn(settings, settings.activeProgramId);
            await m.createIndex(prescriptionsDayOrder);
            await m.createIndex(prescriptionsDayExercise);
          }
          if (from < 3) {
            await m.createTable(sessions);
            await m.createTable(sessionExercises);
            await m.createTable(setLogs);
            await m.createIndex(sessionsFinishedAt);
            await m.createIndex(sessionExercisesSessionId);
            await m.createIndex(setLogsSessionExerciseId);
          }
          if (from < 4 && from >= 3) {
            await m.addColumn(
              sessions,
              sessions.currentSessionExerciseId,
            );
            await m.addColumn(
              sessionExercises,
              sessionExercises.isCompleted,
            );
            await m.addColumn(
              sessionExercises,
              sessionExercises.completedAt,
            );
          }
          if (from < 5) {
            await m.addColumn(settings, settings.plateInventoryCsv);
            await m.addColumn(
              sessionExercises,
              sessionExercises.suggestedWorkingWeightKg,
            );
          }
          if (from < 6) {
            await m.addColumn(sessions, sessions.isDeload);
          }
          if (from < 7) {
            await _ensureColumnExists(
              table: 'sessions',
              column: 'is_deload',
              onMissing: () => m.addColumn(sessions, sessions.isDeload),
            );
          }
          if (from < 8) {
            await m.addColumn(settings, settings.backupAutoEnabled);
            await m.addColumn(settings, settings.backupEncryptionEnabled);
            await m.addColumn(settings, settings.lastAutoBackupAt);
          }
        },
      );

  Future<void> _ensureColumnExists({
    required String table,
    required String column,
    required Future<void> Function() onMissing,
  }) async {
    final rows = await customSelect('PRAGMA table_info($table)').get();
    final hasColumn = rows.any((row) => row.data['name'] == column);
    if (!hasColumn) {
      await onMissing();
    }
  }
}

LazyDatabase _openConnection() {
  return LazyDatabase(() async {
    final dbFolder = await getApplicationDocumentsDirectory();
    final dbPath = p.join(dbFolder.path, 'gym_runner.sqlite');
    return driftDatabase(
      name: 'gym_runner',
      native: DriftNativeOptions(
        databasePath: () async => dbPath,
      ),
    );
  });
}

final appDatabaseProvider = Provider<AppDatabase>((ref) {
  final db = AppDatabase();
  ref.onDispose(db.close);
  return db;
});
