import 'dart:math';

import 'package:drift/drift.dart' as drift;

import '../db/app_database.dart';
import 'settings_repository.dart';

class ProgramRepository {
  ProgramRepository(this._db, this._settingsRepository);

  final AppDatabase _db;
  final SettingsRepository _settingsRepository;

  Stream<List<Program>> watchPrograms() {
    final query = _db.select(_db.programs)
      ..orderBy([
        (tbl) => drift.OrderingTerm(expression: tbl.createdAt),
      ]);
    return query.watch();
  }

  Stream<Program?> watchProgram(int id) {
    final query = _db.select(_db.programs)
      ..where((tbl) => tbl.id.equals(id))
      ..limit(1);
    return query.watchSingleOrNull();
  }

  Future<int> createProgram(String name) {
    return _db.into(_db.programs).insert(ProgramsCompanion.insert(name: name));
  }

  Future<void> renameProgram(int id, String name) async {
    await (_db.update(_db.programs)..where((tbl) => tbl.id.equals(id)))
        .write(ProgramsCompanion(name: drift.Value(name)));
  }

  Future<void> deleteProgram(int id) async {
    final settings = await _settingsRepository.ensureSingleRow();
    await (_db.delete(_db.programs)..where((tbl) => tbl.id.equals(id))).go();
    if (settings.activeProgramId == id) {
      await _settingsRepository.setActiveProgram(null);
    }
  }

  Future<void> setActiveProgram(int id) {
    return _settingsRepository.setActiveProgram(id);
  }

  Stream<List<WorkoutDay>> watchWorkoutDays(int programId) {
    final query = _db.select(_db.workoutDays)
      ..where((tbl) => tbl.programId.equals(programId))
      ..orderBy([
        (tbl) => drift.OrderingTerm(expression: tbl.orderIndex),
        (tbl) => drift.OrderingTerm(expression: tbl.weekday),
      ]);
    return query.watch();
  }

  Stream<WorkoutDay?> watchWorkoutDayById(int dayId) {
    final query = _db.select(_db.workoutDays)
      ..where((tbl) => tbl.id.equals(dayId))
      ..limit(1);
    return query.watchSingleOrNull();
  }

  Stream<WorkoutDay?> watchWorkoutDayForWeekday(int programId, int weekday) {
    final query = _db.select(_db.workoutDays)
      ..where((tbl) =>
          tbl.programId.equals(programId) & tbl.weekday.equals(weekday))
      ..limit(1);
    return query.watchSingleOrNull();
  }

  Future<int> createOrUpdateWorkoutDay({
    required int programId,
    required int weekday,
    required String name,
  }) async {
    final existing = await (_db.select(_db.workoutDays)
          ..where((tbl) =>
              tbl.programId.equals(programId) & tbl.weekday.equals(weekday))
          ..limit(1))
        .getSingleOrNull();

    if (existing != null) {
      await updateWorkoutDay(
        dayId: existing.id,
        name: name,
        weekday: weekday,
      );
      return existing.id;
    }

    final orderIndex = await _nextWorkoutDayOrderIndex(programId);
    return _db.into(_db.workoutDays).insert(
          WorkoutDaysCompanion.insert(
            programId: programId,
            name: name,
            weekday: weekday,
            orderIndex: orderIndex,
          ),
        );
  }

  Future<void> updateWorkoutDay({
    required int dayId,
    String? name,
    int? weekday,
  }) async {
    final companion = WorkoutDaysCompanion(
      name: name == null ? const drift.Value.absent() : drift.Value(name),
      weekday:
          weekday == null ? const drift.Value.absent() : drift.Value(weekday),
    );
    await (_db.update(_db.workoutDays)..where((tbl) => tbl.id.equals(dayId)))
        .write(companion);
  }

  Future<int> _nextWorkoutDayOrderIndex(int programId) async {
    final rows = await (_db.select(_db.workoutDays)
          ..where((tbl) => tbl.programId.equals(programId)))
        .get();
    if (rows.isEmpty) {
      return 0;
    }
    final maxOrder = rows.map((row) => row.orderIndex).reduce(max);
    return maxOrder + 1;
  }
}
