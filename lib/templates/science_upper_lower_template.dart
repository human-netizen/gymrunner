class TemplateProgram {
  const TemplateProgram({
    required this.name,
    required this.exercises,
    required this.days,
  });

  final String name;
  final List<TemplateExercise> exercises;
  final List<TemplateDay> days;
}

class TemplateExercise {
  const TemplateExercise({
    required this.name,
    required this.primaryMuscle,
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

class TemplateDay {
  const TemplateDay({
    required this.weekday,
    required this.name,
    required this.prescriptions,
  });

  final int weekday;
  final String name;
  final List<TemplatePrescription> prescriptions;
}

class TemplatePrescription {
  const TemplatePrescription({
    required this.exerciseName,
    required this.setsTarget,
    required this.repMin,
    required this.repMax,
    required this.restSeconds,
    this.warmupEnabled = false,
    this.notes,
  });

  final String exerciseName;
  final int setsTarget;
  final int repMin;
  final int repMax;
  final int restSeconds;
  final bool warmupEnabled;
  final String? notes;
}

const scienceUpperLowerTemplate = TemplateProgram(
  name: 'Science-Based Upper/Lower (5-Day)',
  exercises: [
    TemplateExercise(name: 'Barbell Bench Press', primaryMuscle: 'chest'),
    TemplateExercise(name: 'Incline Dumbbell Press', primaryMuscle: 'chest'),
    TemplateExercise(name: 'Overhead Barbell Press', primaryMuscle: 'shoulders'),
    TemplateExercise(name: 'Lateral Raises', primaryMuscle: 'shoulders'),
    TemplateExercise(name: 'Triceps Pushdowns', primaryMuscle: 'triceps'),
    TemplateExercise(name: 'Back Squat', primaryMuscle: 'legs'),
    TemplateExercise(name: 'Leg Press', primaryMuscle: 'legs'),
    TemplateExercise(name: 'Bulgarian Split Squat', primaryMuscle: 'legs'),
    TemplateExercise(name: 'Leg Extension', primaryMuscle: 'legs'),
    TemplateExercise(name: 'Standing Calf Raises', primaryMuscle: 'legs'),
    TemplateExercise(name: 'Pull-ups OR Lat Pulldown', primaryMuscle: 'back'),
    TemplateExercise(name: 'Bent-over Barbell Row', primaryMuscle: 'back'),
    TemplateExercise(name: 'Seated Cable Row', primaryMuscle: 'back'),
    TemplateExercise(
      name: 'Face Pulls OR Reverse Flyes',
      primaryMuscle: 'shoulders',
    ),
    TemplateExercise(
      name: 'Barbell or Dumbbell Curls',
      primaryMuscle: 'biceps',
    ),
    TemplateExercise(name: 'Romanian Deadlift', primaryMuscle: 'legs'),
    TemplateExercise(name: 'Hip Thrust', primaryMuscle: 'legs'),
    TemplateExercise(
      name: 'Leg Curl (or Glute-ham raise)',
      primaryMuscle: 'legs',
    ),
    TemplateExercise(
      name: 'Single-leg RDL OR Cable Pull-through',
      primaryMuscle: 'legs',
    ),
    TemplateExercise(name: 'Core Circuit', primaryMuscle: 'core'),
    TemplateExercise(
      name: 'Incline Barbell or Dumbbell Press',
      primaryMuscle: 'chest',
    ),
    TemplateExercise(
      name: 'Dips OR Close-grip Bench Press',
      primaryMuscle: 'chest',
    ),
    TemplateExercise(
      name: 'Chest-supported Row OR Single-arm DB Row',
      primaryMuscle: 'back',
    ),
    TemplateExercise(
      name: 'Lateral Raise OR Y-raise',
      primaryMuscle: 'shoulders',
    ),
    TemplateExercise(name: 'Biceps Curl', primaryMuscle: 'biceps'),
    TemplateExercise(name: 'Triceps Extension', primaryMuscle: 'triceps'),
  ],
  days: [
    TemplateDay(
      weekday: DateTime.saturday,
      name: 'Upper Push (Chest/Shoulders/Triceps)',
      prescriptions: [
        TemplatePrescription(
          exerciseName: 'Barbell Bench Press',
          setsTarget: 4,
          repMin: 6,
          repMax: 8,
          restSeconds: 150,
          warmupEnabled: true,
        ),
        TemplatePrescription(
          exerciseName: 'Incline Dumbbell Press',
          setsTarget: 3,
          repMin: 8,
          repMax: 12,
          restSeconds: 120,
        ),
        TemplatePrescription(
          exerciseName: 'Overhead Barbell Press',
          setsTarget: 3,
          repMin: 6,
          repMax: 10,
          restSeconds: 150,
          warmupEnabled: true,
        ),
        TemplatePrescription(
          exerciseName: 'Lateral Raises',
          setsTarget: 3,
          repMin: 10,
          repMax: 15,
          restSeconds: 75,
        ),
        TemplatePrescription(
          exerciseName: 'Triceps Pushdowns',
          setsTarget: 3,
          repMin: 10,
          repMax: 15,
          restSeconds: 75,
        ),
      ],
    ),
    TemplateDay(
      weekday: DateTime.sunday,
      name: 'Lower (Quad-Dominant)',
      prescriptions: [
        TemplatePrescription(
          exerciseName: 'Back Squat',
          setsTarget: 4,
          repMin: 6,
          repMax: 8,
          restSeconds: 150,
          warmupEnabled: true,
        ),
        TemplatePrescription(
          exerciseName: 'Leg Press',
          setsTarget: 3,
          repMin: 10,
          repMax: 12,
          restSeconds: 120,
        ),
        TemplatePrescription(
          exerciseName: 'Bulgarian Split Squat',
          setsTarget: 3,
          repMin: 8,
          repMax: 12,
          restSeconds: 120,
        ),
        TemplatePrescription(
          exerciseName: 'Leg Extension',
          setsTarget: 3,
          repMin: 12,
          repMax: 15,
          restSeconds: 75,
        ),
        TemplatePrescription(
          exerciseName: 'Standing Calf Raises',
          setsTarget: 3,
          repMin: 12,
          repMax: 15,
          restSeconds: 75,
        ),
      ],
    ),
    TemplateDay(
      weekday: DateTime.monday,
      name: 'Upper Pull (Back/Biceps)',
      prescriptions: [
        TemplatePrescription(
          exerciseName: 'Pull-ups OR Lat Pulldown',
          setsTarget: 4,
          repMin: 6,
          repMax: 10,
          restSeconds: 120,
        ),
        TemplatePrescription(
          exerciseName: 'Bent-over Barbell Row',
          setsTarget: 3,
          repMin: 6,
          repMax: 8,
          restSeconds: 150,
        ),
        TemplatePrescription(
          exerciseName: 'Seated Cable Row',
          setsTarget: 3,
          repMin: 8,
          repMax: 12,
          restSeconds: 120,
        ),
        TemplatePrescription(
          exerciseName: 'Face Pulls OR Reverse Flyes',
          setsTarget: 3,
          repMin: 12,
          repMax: 15,
          restSeconds: 75,
        ),
        TemplatePrescription(
          exerciseName: 'Barbell or Dumbbell Curls',
          setsTarget: 3,
          repMin: 8,
          repMax: 12,
          restSeconds: 75,
        ),
      ],
    ),
    TemplateDay(
      weekday: DateTime.wednesday,
      name: 'Lower (Hip-Dominant + Core)',
      prescriptions: [
        TemplatePrescription(
          exerciseName: 'Romanian Deadlift',
          setsTarget: 4,
          repMin: 6,
          repMax: 8,
          restSeconds: 150,
          warmupEnabled: true,
        ),
        TemplatePrescription(
          exerciseName: 'Hip Thrust',
          setsTarget: 3,
          repMin: 8,
          repMax: 12,
          restSeconds: 120,
        ),
        TemplatePrescription(
          exerciseName: 'Leg Curl (or Glute-ham raise)',
          setsTarget: 3,
          repMin: 10,
          repMax: 12,
          restSeconds: 120,
        ),
        TemplatePrescription(
          exerciseName: 'Single-leg RDL OR Cable Pull-through',
          setsTarget: 3,
          repMin: 10,
          repMax: 12,
          restSeconds: 120,
        ),
        TemplatePrescription(
          exerciseName: 'Core Circuit',
          setsTarget: 3,
          repMin: 30,
          repMax: 60,
          restSeconds: 60,
          notes: '3 sets x 30-60s',
        ),
      ],
    ),
    TemplateDay(
      weekday: DateTime.thursday,
      name: 'Mixed / Arms & Shoulders',
      prescriptions: [
        TemplatePrescription(
          exerciseName: 'Incline Barbell or Dumbbell Press',
          setsTarget: 3,
          repMin: 8,
          repMax: 10,
          restSeconds: 120,
        ),
        TemplatePrescription(
          exerciseName: 'Dips OR Close-grip Bench Press',
          setsTarget: 3,
          repMin: 8,
          repMax: 12,
          restSeconds: 120,
        ),
        TemplatePrescription(
          exerciseName: 'Chest-supported Row OR Single-arm DB Row',
          setsTarget: 3,
          repMin: 10,
          repMax: 12,
          restSeconds: 120,
        ),
        TemplatePrescription(
          exerciseName: 'Lateral Raise OR Y-raise',
          setsTarget: 3,
          repMin: 12,
          repMax: 15,
          restSeconds: 75,
        ),
        TemplatePrescription(
          exerciseName: 'Biceps Curl',
          setsTarget: 3,
          repMin: 10,
          repMax: 12,
          restSeconds: 75,
          notes: 'Superset with triceps extension.',
        ),
        TemplatePrescription(
          exerciseName: 'Triceps Extension',
          setsTarget: 3,
          repMin: 10,
          repMax: 12,
          restSeconds: 75,
          notes: 'Superset with biceps curl.',
        ),
      ],
    ),
  ],
);
