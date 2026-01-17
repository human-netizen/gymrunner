import 'package:drift/drift.dart' as drift;
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../data/db/app_database.dart';
import '../templates/science_upper_lower_template.dart';

final templateImportServiceProvider = Provider<TemplateImportService>((ref) {
  final db = ref.read(appDatabaseProvider);
  return TemplateImportService(db);
});

class TemplateImportService {
  TemplateImportService(this._db);

  final AppDatabase _db;

  Future<Program?> getProgramByName(String name) {
    final query = _db.select(_db.programs)
      ..where((tbl) => tbl.name.equals(name))
      ..limit(1);
    return query.getSingleOrNull();
  }

  Future<int> importScienceUpperLower({
    required bool overwriteIfExists,
  }) async {
    final template = scienceUpperLowerTemplate;
    return _db.transaction(() async {
      final existingProgram = await getProgramByName(template.name);
      final shouldOverwrite = overwriteIfExists && existingProgram != null;

      final programId = existingProgram?.id ??
          await _db.into(_db.programs).insert(
                ProgramsCompanion.insert(name: template.name),
              );

      final exerciseIds = await _upsertExercises(template);

      if (shouldOverwrite) {
        await (_db.delete(_db.workoutDays)
              ..where((tbl) => tbl.programId.equals(programId)))
            .go();
      }

      final existingDays = shouldOverwrite
          ? <WorkoutDay>[]
          : await (_db.select(_db.workoutDays)
                ..where((tbl) => tbl.programId.equals(programId)))
              .get();
      final daysByWeekday = <int, WorkoutDay>{
        for (final day in existingDays) day.weekday: day,
      };

      for (var i = 0; i < template.days.length; i += 1) {
        final day = template.days[i];
        final existingDay = daysByWeekday[day.weekday];

        final int dayId;
        if (existingDay == null) {
          dayId = await _db.into(_db.workoutDays).insert(
                WorkoutDaysCompanion.insert(
                  programId: programId,
                  name: day.name,
                  weekday: day.weekday,
                  orderIndex: i,
                ),
              );
        } else {
          dayId = existingDay.id;
          if (existingDay.name != day.name ||
              existingDay.weekday != day.weekday) {
            await (_db.update(_db.workoutDays)
                  ..where((tbl) => tbl.id.equals(dayId)))
                .write(
              WorkoutDaysCompanion(
                name: drift.Value(day.name),
                weekday: drift.Value(day.weekday),
              ),
            );
          }
        }

        final hasPrescriptions =
            shouldOverwrite ? false : await _hasPrescriptions(dayId);
        if (!shouldOverwrite && hasPrescriptions) {
          continue;
        }

        for (var j = 0; j < day.items.length; j += 1) {
          final item = day.items[j];
          final exerciseId = exerciseIds[item.exerciseName];
          if (exerciseId == null) {
            continue;
          }

          await _db.into(_db.prescriptions).insert(
                PrescriptionsCompanion.insert(
                  workoutDayId: dayId,
                  exerciseId: exerciseId,
                  orderIndex: j,
                  setsTarget: drift.Value(item.sets),
                  repMin: drift.Value(item.repMin),
                  repMax: drift.Value(item.repMax),
                  restSeconds: drift.Value(item.restSeconds),
                  warmupEnabled: drift.Value(item.warmupEnabled),
                  notes: drift.Value(item.notes),
                ),
              );
        }
      }

      return programId;
    });
  }

  Future<Map<String, int>> _upsertExercises(TemplateProgram template) async {
    final existingExercises = await _db.select(_db.exercises).get();
    final existingByName = <String, int>{
      for (final exercise in existingExercises)
        exercise.name.toLowerCase(): exercise.id,
    };

    final idsByName = <String, int>{};

    for (final day in template.days) {
      for (final item in day.items) {
        final key = item.exerciseName.toLowerCase();
        final existingId = existingByName[key];
        if (existingId != null) {
          idsByName[item.exerciseName] = existingId;
          continue;
        }

        final id = await _db.into(_db.exercises).insert(
              ExercisesCompanion.insert(
                name: item.exerciseName,
                primaryMuscle: item.primaryMuscle,
                defaultRestSeconds: drift.Value(item.restSeconds),
                defaultIncrementKg: const drift.Value(2.5),
              ),
            );

        existingByName[key] = id;
        idsByName[item.exerciseName] = id;
      }
    }

    return idsByName;
  }

  Future<bool> _hasPrescriptions(int dayId) async {
    final existing = await (_db.select(_db.prescriptions)
          ..where((tbl) => tbl.workoutDayId.equals(dayId))
          ..limit(1))
        .getSingleOrNull();
    return existing != null;
  }
}
