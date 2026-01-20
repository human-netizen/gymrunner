import 'package:drift/drift.dart' as drift;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../db/app_database.dart';
import '../providers.dart';
import '../repositories/settings_repository.dart';
import '../../services/mentzer_cycle_service.dart';

final seedServiceProvider = Provider<SeedService>((ref) {
  final db = ref.read(appDatabaseProvider);
  final settingsRepository = ref.read(settingsRepositoryProvider);
  final mentzerService = ref.read(mentzerCycleServiceProvider);
  return SeedService(db, settingsRepository, mentzerService);
});

class SeedService {
  SeedService(this._db, this._settingsRepository, this._mentzerService);

  final AppDatabase _db;
  final SettingsRepository _settingsRepository;
  final MentzerCycleService _mentzerService;

  Future<void> seedIfNeeded() async {
    final prefs = await SharedPreferences.getInstance();

    final mentzerId =
        await _mentzerService.ensureMentzerProgram(setActive: false);
    final didSetMentzerActive =
        prefs.getBool('mentzer_default_active_set') ?? false;
    if (!didSetMentzerActive) {
      await _settingsRepository.setActiveProgram(mentzerId);
      await prefs.setBool('mentzer_default_active_set', true);
    }

    final settings = await _settingsRepository.ensureSingleRow();
    final programs = await (_db.select(_db.programs)..limit(1)).get();

    if (programs.isEmpty) {
      await _seedDefaultProgram(setActive: false);
      return;
    }

    if (settings.activeProgramId == null) {
      final firstProgram = await (_db.select(_db.programs)
            ..orderBy([
              (tbl) => drift.OrderingTerm(expression: tbl.id),
            ])
            ..limit(1))
          .getSingleOrNull();
      if (firstProgram != null) {
        await _settingsRepository.setActiveProgram(firstProgram.id);
      }
    }
  }

  Future<void> _seedDefaultProgram({bool setActive = true}) async {
    final exerciseIds = <String, int>{};
    for (final exercise in _seedExercises) {
      final id = await _ensureExercise(exercise);
      exerciseIds[exercise.name] = id;
    }

    final programId = await _db
        .into(_db.programs)
        .insert(ProgramsCompanion.insert(name: 'My Routine'));

    for (var i = 0; i < _seedDays.length; i += 1) {
      final day = _seedDays[i];
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
              ),
            );
      }
    }

    if (setActive) {
      await _settingsRepository.setActiveProgram(programId);
    }
  }

  Future<int> _ensureExercise(_SeedExercise exercise) async {
    final existing = await (_db.select(_db.exercises)
          ..where((tbl) => tbl.name.equals(exercise.name))
          ..limit(1))
        .getSingleOrNull();

    if (existing != null) {
      return existing.id;
    }

    return _db.into(_db.exercises).insert(
          ExercisesCompanion.insert(
            name: exercise.name,
            primaryMuscle: exercise.primaryMuscle,
            secondaryMuscles: drift.Value(exercise.secondaryMuscles),
            defaultRestSeconds: drift.Value(exercise.defaultRestSeconds),
            defaultIncrementKg: drift.Value(exercise.defaultIncrementKg),
          ),
        );
  }
}

class _SeedExercise {
  const _SeedExercise(
    this.name,
    this.primaryMuscle, {
    this.secondaryMuscles = '',
    this.defaultRestSeconds = 90,
    this.defaultIncrementKg = 2.5,
  });

  final String name;
  final String primaryMuscle;
  final String secondaryMuscles;
  final int defaultRestSeconds;
  final double defaultIncrementKg;
}

class _SeedPrescription {
  const _SeedPrescription(
    this.exerciseName, {
    this.setsTarget = 3,
    this.repMin = 8,
    this.repMax = 12,
  });

  final String exerciseName;
  final int setsTarget;
  final int repMin;
  final int repMax;
}

class _SeedDay {
  const _SeedDay(this.weekday, this.name, this.prescriptions);

  final int weekday;
  final String name;
  final List<_SeedPrescription> prescriptions;
}

const _seedExercises = [
  _SeedExercise(
    'Bench Press',
    'chest',
    secondaryMuscles: 'triceps,shoulders',
    defaultRestSeconds: 150,
    defaultIncrementKg: 2.5,
  ),
  _SeedExercise('Incline Dumbbell Press', 'chest', secondaryMuscles: 'triceps,shoulders', defaultRestSeconds: 120),
  _SeedExercise('Cable Fly', 'chest', defaultRestSeconds: 90),
  _SeedExercise('Pec Deck', 'chest', defaultRestSeconds: 90),
  _SeedExercise('Overhead Press', 'shoulders', secondaryMuscles: 'triceps', defaultRestSeconds: 150),
  _SeedExercise('Lateral Raise', 'shoulders', defaultRestSeconds: 75),
  _SeedExercise('Face Pull', 'shoulders', secondaryMuscles: 'back', defaultRestSeconds: 75),
  _SeedExercise('Lat Pulldown', 'back', secondaryMuscles: 'biceps', defaultRestSeconds: 120),
  _SeedExercise('Seated Row', 'back', secondaryMuscles: 'biceps', defaultRestSeconds: 120),
  _SeedExercise('Barbell Row', 'back', secondaryMuscles: 'biceps', defaultRestSeconds: 150),
  _SeedExercise('Pull-up', 'back', secondaryMuscles: 'biceps', defaultRestSeconds: 150),
  _SeedExercise('Barbell Curl', 'biceps', defaultRestSeconds: 90),
  _SeedExercise('Incline Dumbbell Curl', 'biceps', defaultRestSeconds: 90),
  _SeedExercise('Hammer Curl', 'biceps', defaultRestSeconds: 90),
  _SeedExercise('Triceps Pushdown', 'triceps', defaultRestSeconds: 90),
  _SeedExercise('Overhead Triceps Extension', 'triceps', defaultRestSeconds: 90),
  _SeedExercise('Triceps Dips', 'triceps', secondaryMuscles: 'chest', defaultRestSeconds: 120),
  _SeedExercise('Squat', 'legs', secondaryMuscles: 'abs', defaultRestSeconds: 180),
  _SeedExercise('Leg Press', 'legs', defaultRestSeconds: 150),
  _SeedExercise('Romanian Deadlift', 'legs', secondaryMuscles: 'back', defaultRestSeconds: 150),
  _SeedExercise('Leg Curl', 'legs', defaultRestSeconds: 90),
  _SeedExercise('Leg Extension', 'legs', defaultRestSeconds: 90),
  _SeedExercise('Calf Raise', 'legs', defaultRestSeconds: 75),
];

const _seedDays = [
  _SeedDay(
    DateTime.saturday,
    'Biceps + Triceps',
    [
      _SeedPrescription('Barbell Curl'),
      _SeedPrescription('Incline Dumbbell Curl'),
      _SeedPrescription('Triceps Pushdown'),
      _SeedPrescription('Overhead Triceps Extension'),
    ],
  ),
  _SeedDay(
    DateTime.sunday,
    'Shoulder + Back',
    [
      _SeedPrescription('Overhead Press', setsTarget: 4, repMin: 6, repMax: 10),
      _SeedPrescription('Lateral Raise'),
      _SeedPrescription('Lat Pulldown', setsTarget: 4, repMin: 6, repMax: 10),
      _SeedPrescription('Seated Row', setsTarget: 4, repMin: 6, repMax: 10),
      _SeedPrescription('Face Pull'),
    ],
  ),
  _SeedDay(
    DateTime.monday,
    'Chest + Triceps',
    [
      _SeedPrescription('Bench Press', setsTarget: 4, repMin: 6, repMax: 10),
      _SeedPrescription('Incline Dumbbell Press', setsTarget: 4, repMin: 6, repMax: 10),
      _SeedPrescription('Cable Fly'),
      _SeedPrescription('Triceps Dips', setsTarget: 3, repMin: 8, repMax: 12),
    ],
  ),
  _SeedDay(
    DateTime.wednesday,
    'Shoulder + Chest',
    [
      _SeedPrescription('Incline Dumbbell Press', setsTarget: 4, repMin: 6, repMax: 10),
      _SeedPrescription('Overhead Press', setsTarget: 3, repMin: 8, repMax: 12),
      _SeedPrescription('Lateral Raise'),
      _SeedPrescription('Pec Deck'),
    ],
  ),
  _SeedDay(
    DateTime.thursday,
    'Legs',
    [
      _SeedPrescription('Squat', setsTarget: 4, repMin: 5, repMax: 8),
      _SeedPrescription('Romanian Deadlift', setsTarget: 4, repMin: 6, repMax: 10),
      _SeedPrescription('Leg Curl'),
      _SeedPrescription('Leg Extension'),
      _SeedPrescription('Calf Raise'),
    ],
  ),
];
