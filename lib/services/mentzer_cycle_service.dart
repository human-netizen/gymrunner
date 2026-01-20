import 'package:drift/drift.dart' as drift;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../data/db/app_database.dart';
import '../data/providers.dart';
import '../data/repositories/settings_repository.dart';
import '../templates/mentzer_hit_cycle.dart';

final mentzerCycleServiceProvider = Provider<MentzerCycleService>((ref) {
  final db = ref.read(appDatabaseProvider);
  final settingsRepository = ref.read(settingsRepositoryProvider);
  return MentzerCycleService(db, settingsRepository);
});

class MentzerCycleState {
  const MentzerCycleState({
    required this.nextWorkoutIndex,
    required this.nextAvailableAt,
    required this.lastFinishedAt,
  });

  final int nextWorkoutIndex;
  final DateTime? nextAvailableAt;
  final DateTime? lastFinishedAt;
}

class MentzerCycleService {
  MentzerCycleService(this._db, this._settingsRepository);

  final AppDatabase _db;
  final SettingsRepository _settingsRepository;

  bool isMentzerProgramName(String name) =>
      name == mentzerHitCycleTemplate.name;

  Future<bool> isMentzerProgramId(int programId) async {
    final program = await (_db.select(_db.programs)
          ..where((tbl) => tbl.id.equals(programId))
          ..limit(1))
        .getSingleOrNull();
    if (program == null) {
      return false;
    }
    return isMentzerProgramName(program.name);
  }

  Future<int> ensureMentzerProgram({
    bool setActive = false,
    bool overwriteIfExists = false,
  }) async {
    final template = mentzerHitCycleTemplate;
    return _db.transaction(() async {
      final existingProgram = await (_db.select(_db.programs)
            ..where((tbl) => tbl.name.equals(template.name))
            ..limit(1))
          .getSingleOrNull();

      final programId = existingProgram?.id ??
          await _db.into(_db.programs).insert(
                ProgramsCompanion.insert(name: template.name),
              );

      final existingDays = await (_db.select(_db.workoutDays)
            ..where((tbl) => tbl.programId.equals(programId)))
          .get();

      if (existingProgram != null &&
          existingDays.isNotEmpty &&
          !overwriteIfExists) {
        if (setActive) {
          await _settingsRepository.setActiveProgram(programId);
        }
        return programId;
      }

      final exerciseIds = await _upsertExercises(template);

      if (existingDays.isNotEmpty) {
        await (_db.delete(_db.workoutDays)
              ..where((tbl) => tbl.programId.equals(programId)))
            .go();
      }

      for (var i = 0; i < template.workouts.length; i += 1) {
        final workout = template.workouts[i];
        final dayId = await _db.into(_db.workoutDays).insert(
              WorkoutDaysCompanion.insert(
                programId: programId,
                name: workout.title,
                weekday: 0,
                orderIndex: i,
              ),
            );

        for (var j = 0; j < workout.exercises.length; j += 1) {
          final exercise = workout.exercises[j];
          final exerciseId = exerciseIds[exercise.name];
          if (exerciseId == null) {
            continue;
          }
          await _db.into(_db.prescriptions).insert(
                PrescriptionsCompanion.insert(
                  workoutDayId: dayId,
                  exerciseId: exerciseId,
                  orderIndex: j,
                  setsTarget: drift.Value(exercise.setsTarget),
                  repMin: drift.Value(exercise.repMin),
                  repMax: drift.Value(exercise.repMax),
                  warmupEnabled: const drift.Value(false),
                  notes: drift.Value(exercise.notes),
                ),
              );
        }
      }

      if (setActive) {
        await _settingsRepository.setActiveProgram(programId);
      }

      return programId;
    });
  }

  MentzerWorkout workoutForIndex(int index) =>
      mentzerHitCycleTemplate.workoutForIndex(index);

  bool isNoRestAfterThis({
    required int workoutIndex,
    required String exerciseName,
  }) {
    final workout = workoutForIndex(workoutIndex);
    for (final exercise in workout.exercises) {
      if (exercise.name == exerciseName) {
        return exercise.noRestAfterThis;
      }
    }
    return false;
  }

  bool isPreExhaustStart({
    required int workoutIndex,
    required String exerciseName,
  }) {
    final workout = workoutForIndex(workoutIndex);
    for (final exercise in workout.exercises) {
      if (exercise.name == exerciseName) {
        return exercise.preExhaustPairStart;
      }
    }
    return false;
  }

  String? notesForExercise({
    required int workoutIndex,
    required String exerciseName,
  }) {
    final workout = workoutForIndex(workoutIndex);
    for (final exercise in workout.exercises) {
      if (exercise.name == exerciseName) {
        return exercise.notes;
      }
    }
    return null;
  }

  String? notesForWorkoutIndex(int workoutIndex) {
    if (workoutIndex < 0 ||
        workoutIndex >= mentzerHitCycleTemplate.workouts.length) {
      return null;
    }
    return mentzerHitCycleTemplate.workouts[workoutIndex].sideNotes;
  }

  Future<MentzerCycleState> loadCycleState(int programId) async {
    final prefs = await SharedPreferences.getInstance();
    final index = prefs.getInt(_indexKey(programId)) ?? 0;
    final millis = prefs.getInt(_nextAvailableAtKey(programId));
    final finishedMillis = prefs.getInt(_lastFinishedAtKey(programId));
    return MentzerCycleState(
      nextWorkoutIndex: index,
      nextAvailableAt:
          millis == null ? null : DateTime.fromMillisecondsSinceEpoch(millis),
      lastFinishedAt: finishedMillis == null
          ? null
          : DateTime.fromMillisecondsSinceEpoch(finishedMillis),
    );
  }

  Future<void> persistCycleState(
    int programId,
    MentzerCycleState state,
  ) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt(_indexKey(programId), state.nextWorkoutIndex);
    if (state.nextAvailableAt != null) {
      await prefs.setInt(
        _nextAvailableAtKey(programId),
        state.nextAvailableAt!.millisecondsSinceEpoch,
      );
    } else {
      await prefs.remove(_nextAvailableAtKey(programId));
    }
    if (state.lastFinishedAt != null) {
      await prefs.setInt(
        _lastFinishedAtKey(programId),
        state.lastFinishedAt!.millisecondsSinceEpoch,
      );
    } else {
      await prefs.remove(_lastFinishedAtKey(programId));
    }
  }

  Future<void> advanceAfterSession({
    required int programId,
    required int workoutIndex,
    required DateTime finishedAt,
  }) async {
    final nextIndex =
        (workoutIndex + 1) % mentzerHitCycleTemplate.workouts.length;
    final nextAvailable =
        finishedAt.add(Duration(days: mentzerHitCycleTemplate.restMinDays));
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt(_indexKey(programId), nextIndex);
    await prefs.setInt(
      _nextAvailableAtKey(programId),
      nextAvailable.millisecondsSinceEpoch,
    );
    await prefs.setInt(
      _lastFinishedAtKey(programId),
      finishedAt.millisecondsSinceEpoch,
    );
  }

  Future<void> resetCycle(int programId) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_indexKey(programId));
    await prefs.remove(_nextAvailableAtKey(programId));
    await prefs.remove(_lastFinishedAtKey(programId));
  }

  Future<int?> workoutIndexForDay(int workoutDayId) async {
    final day = await (_db.select(_db.workoutDays)
          ..where((tbl) => tbl.id.equals(workoutDayId))
          ..limit(1))
        .getSingleOrNull();
    return day?.orderIndex;
  }

  Future<Map<String, int>> _upsertExercises(
    MentzerCycleTemplate template,
  ) async {
    final existingExercises = await _db.select(_db.exercises).get();
    final existingByName = <String, int>{
      for (final exercise in existingExercises)
        exercise.name.toLowerCase(): exercise.id,
    };

    final idsByName = <String, int>{};

    for (final workout in template.workouts) {
      for (final item in workout.exercises) {
        final key = item.name.toLowerCase();
        final existingId = existingByName[key];
        if (existingId != null) {
          idsByName[item.name] = existingId;
          continue;
        }

        final id = await _db.into(_db.exercises).insert(
              ExercisesCompanion.insert(
                name: item.name,
                primaryMuscle: item.primaryMuscle,
                defaultRestSeconds: const drift.Value(120),
                defaultIncrementKg: const drift.Value(2.5),
              ),
            );

        existingByName[key] = id;
        idsByName[item.name] = id;
      }
    }

    return idsByName;
  }

  String _indexKey(int programId) =>
      'mentzer_cycle_next_index_$programId';
  String _nextAvailableAtKey(int programId) =>
      'mentzer_cycle_next_available_$programId';
  String _lastFinishedAtKey(int programId) =>
      'mentzer_cycle_last_finished_$programId';
}
