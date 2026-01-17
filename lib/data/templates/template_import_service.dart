import 'package:drift/drift.dart' as drift;
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../db/app_database.dart';
import '../../templates/science_upper_lower_template.dart';

final templateImportServiceProvider = Provider<TemplateImportService>((ref) {
  final db = ref.read(appDatabaseProvider);
  return TemplateImportService(db);
});

class TemplateImportResult {
  const TemplateImportResult({
    required this.programId,
    required this.wasCreated,
  });

  final int programId;
  final bool wasCreated;
}

class TemplateImportService {
  TemplateImportService(this._db);

  final AppDatabase _db;

  Future<TemplateImportResult> importScienceUpperLowerTemplate() async {
    final existingProgram = await (_db.select(_db.programs)
          ..where((tbl) => tbl.name.equals(scienceUpperLowerTemplate.name))
          ..limit(1))
        .getSingleOrNull();

    if (existingProgram != null) {
      return TemplateImportResult(
        programId: existingProgram.id,
        wasCreated: false,
      );
    }

    return _db.transaction(() async {
      final exerciseIds = await _upsertExercises(
        scienceUpperLowerTemplate.exercises,
      );

      final programId = await _db.into(_db.programs).insert(
            ProgramsCompanion.insert(
              name: scienceUpperLowerTemplate.name,
            ),
          );

      for (var i = 0; i < scienceUpperLowerTemplate.days.length; i += 1) {
        final day = scienceUpperLowerTemplate.days[i];
        final dayId = await _db.into(_db.workoutDays).insert(
              WorkoutDaysCompanion.insert(
                programId: programId,
                name: day.name,
                weekday: day.weekday,
                orderIndex: i,
              ),
            );

        for (var j = 0; j < day.prescriptions.length; j += 1) {
          final prescription = day.prescriptions[j];
          final exerciseId = exerciseIds[prescription.exerciseName];
          if (exerciseId == null) {
            continue;
          }

          await _db.into(_db.prescriptions).insert(
                PrescriptionsCompanion.insert(
                  workoutDayId: dayId,
                  exerciseId: exerciseId,
                  orderIndex: j,
                  setsTarget: drift.Value(prescription.setsTarget),
                  repMin: drift.Value(prescription.repMin),
                  repMax: drift.Value(prescription.repMax),
                  restSeconds: drift.Value(prescription.restSeconds),
                  warmupEnabled: drift.Value(prescription.warmupEnabled),
                  notes: drift.Value(prescription.notes),
                ),
              );
        }
      }

      return TemplateImportResult(
        programId: programId,
        wasCreated: true,
      );
    });
  }

  Future<Map<String, int>> _upsertExercises(
    List<TemplateExercise> templateExercises,
  ) async {
    final existing = await _db.select(_db.exercises).get();
    final existingByName = <String, Exercise>{};
    for (final exercise in existing) {
      existingByName[exercise.name.toLowerCase()] = exercise;
    }

    final idsByName = <String, int>{};

    for (final template in templateExercises) {
      final key = template.name.toLowerCase();
      final existingExercise = existingByName[key];
      if (existingExercise != null) {
        idsByName[template.name] = existingExercise.id;
        continue;
      }

      final id = await _db.into(_db.exercises).insert(
            ExercisesCompanion.insert(
              name: template.name,
              primaryMuscle: template.primaryMuscle,
              secondaryMuscles: drift.Value(template.secondaryMuscles),
              defaultRestSeconds: drift.Value(template.defaultRestSeconds),
              defaultIncrementKg: drift.Value(template.defaultIncrementKg),
            ),
          );

      idsByName[template.name] = id;
      existingByName[key] = Exercise(
        id: id,
        name: template.name,
        primaryMuscle: template.primaryMuscle,
        secondaryMuscles: template.secondaryMuscles,
        defaultRestSeconds: template.defaultRestSeconds,
        defaultIncrementKg: template.defaultIncrementKg,
        createdAt: DateTime.now(),
      );
    }

    return idsByName;
  }
}
