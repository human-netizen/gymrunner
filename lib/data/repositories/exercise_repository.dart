import 'package:drift/drift.dart' as drift;

import '../db/app_database.dart';

class ExerciseRepository {
  ExerciseRepository(this._db);

  final AppDatabase _db;

  Stream<List<Exercise>> watchExercises() {
    final query = _db.select(_db.exercises)
      ..orderBy([
        (tbl) => drift.OrderingTerm(expression: tbl.name),
      ]);
    return query.watch();
  }

  Future<int?> createExercise({
    required String name,
    required String primaryMuscle,
    String secondaryMuscles = '',
    int? defaultRestSeconds,
    double? defaultIncrementKg,
  }) async {
    final trimmedName = name.trim();
    if (trimmedName.isEmpty) {
      return null;
    }

    final existing = await (_db.select(_db.exercises)
          ..where((tbl) => tbl.name.equals(trimmedName))
          ..limit(1))
        .getSingleOrNull();
    if (existing != null) {
      return null;
    }

    return _db.into(_db.exercises).insert(
          ExercisesCompanion.insert(
            name: trimmedName,
            primaryMuscle: primaryMuscle,
            secondaryMuscles: drift.Value(secondaryMuscles),
            defaultRestSeconds: defaultRestSeconds == null
                ? const drift.Value.absent()
                : drift.Value(defaultRestSeconds),
            defaultIncrementKg: defaultIncrementKg == null
                ? const drift.Value.absent()
                : drift.Value(defaultIncrementKg),
          ),
        );
  }

  Future<void> deleteExercise(int id) async {
    await (_db.delete(_db.exercises)..where((tbl) => tbl.id.equals(id))).go();
  }
}
