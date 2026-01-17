class TemplateProgram {
  const TemplateProgram({
    required this.name,
    required this.days,
  });

  final String name;
  final List<TemplateDay> days;
}

class TemplateDay {
  const TemplateDay({
    required this.name,
    required this.weekday,
    required this.items,
  });

  final String name;
  final int weekday;
  final List<TemplateItem> items;
}

class TemplateItem {
  const TemplateItem({
    required this.exerciseName,
    required this.primaryMuscle,
    required this.sets,
    required this.repMin,
    required this.repMax,
    required this.restSeconds,
    required this.warmupEnabled,
    this.notes,
  });

  final String exerciseName;
  final String primaryMuscle;
  final int sets;
  final int repMin;
  final int repMax;
  final int restSeconds;
  final bool warmupEnabled;
  final String? notes;
}

const scienceUpperLowerTemplate = TemplateProgram(
  name: 'Science-Based Upper/Lower (5-Day)',
  days: [
    TemplateDay(
      name: 'Upper Push (Chest/Shoulders/Triceps)',
      weekday: DateTime.saturday,
      items: [
        TemplateItem(
          exerciseName: 'Barbell Bench Press',
          primaryMuscle: 'chest',
          sets: 4,
          repMin: 6,
          repMax: 8,
          restSeconds: 150,
          warmupEnabled: true,
        ),
        TemplateItem(
          exerciseName: 'Incline Dumbbell Press',
          primaryMuscle: 'chest',
          sets: 3,
          repMin: 8,
          repMax: 12,
          restSeconds: 120,
          warmupEnabled: false,
        ),
        TemplateItem(
          exerciseName: 'Overhead Barbell Press',
          primaryMuscle: 'shoulders',
          sets: 3,
          repMin: 6,
          repMax: 10,
          restSeconds: 150,
          warmupEnabled: true,
        ),
        TemplateItem(
          exerciseName: 'Lateral Raise',
          primaryMuscle: 'shoulders',
          sets: 3,
          repMin: 10,
          repMax: 15,
          restSeconds: 75,
          warmupEnabled: false,
        ),
        TemplateItem(
          exerciseName: 'Triceps Pushdown',
          primaryMuscle: 'triceps',
          sets: 3,
          repMin: 10,
          repMax: 15,
          restSeconds: 75,
          warmupEnabled: false,
        ),
      ],
    ),
    TemplateDay(
      name: 'Lower (Quad-Dominant)',
      weekday: DateTime.sunday,
      items: [
        TemplateItem(
          exerciseName: 'Back Squat',
          primaryMuscle: 'legs',
          sets: 4,
          repMin: 6,
          repMax: 8,
          restSeconds: 150,
          warmupEnabled: true,
        ),
        TemplateItem(
          exerciseName: 'Leg Press',
          primaryMuscle: 'legs',
          sets: 3,
          repMin: 10,
          repMax: 12,
          restSeconds: 120,
          warmupEnabled: false,
        ),
        TemplateItem(
          exerciseName: 'Bulgarian Split Squat',
          primaryMuscle: 'legs',
          sets: 3,
          repMin: 8,
          repMax: 12,
          restSeconds: 120,
          warmupEnabled: false,
          notes: 'Per leg.',
        ),
        TemplateItem(
          exerciseName: 'Leg Extension',
          primaryMuscle: 'legs',
          sets: 3,
          repMin: 12,
          repMax: 15,
          restSeconds: 75,
          warmupEnabled: false,
        ),
        TemplateItem(
          exerciseName: 'Standing Calf Raise',
          primaryMuscle: 'legs',
          sets: 3,
          repMin: 12,
          repMax: 15,
          restSeconds: 75,
          warmupEnabled: false,
        ),
      ],
    ),
    TemplateDay(
      name: 'Upper Pull (Back/Biceps)',
      weekday: DateTime.monday,
      items: [
        TemplateItem(
          exerciseName: 'Lat Pulldown',
          primaryMuscle: 'back',
          sets: 4,
          repMin: 6,
          repMax: 10,
          restSeconds: 120,
          warmupEnabled: false,
          notes: 'Or Pull-ups.',
        ),
        TemplateItem(
          exerciseName: 'Bent-over Barbell Row',
          primaryMuscle: 'back',
          sets: 3,
          repMin: 6,
          repMax: 8,
          restSeconds: 150,
          warmupEnabled: false,
        ),
        TemplateItem(
          exerciseName: 'Seated Cable Row',
          primaryMuscle: 'back',
          sets: 3,
          repMin: 8,
          repMax: 12,
          restSeconds: 120,
          warmupEnabled: false,
        ),
        TemplateItem(
          exerciseName: 'Face Pull',
          primaryMuscle: 'shoulders',
          sets: 3,
          repMin: 12,
          repMax: 15,
          restSeconds: 75,
          warmupEnabled: false,
          notes: 'Or Reverse Flyes.',
        ),
        TemplateItem(
          exerciseName: 'Dumbbell Curl',
          primaryMuscle: 'biceps',
          sets: 3,
          repMin: 8,
          repMax: 12,
          restSeconds: 75,
          warmupEnabled: false,
          notes: 'Or Barbell Curl.',
        ),
      ],
    ),
    TemplateDay(
      name: 'Lower (Hip-Dominant + Core)',
      weekday: DateTime.wednesday,
      items: [
        TemplateItem(
          exerciseName: 'Romanian Deadlift',
          primaryMuscle: 'legs',
          sets: 4,
          repMin: 6,
          repMax: 8,
          restSeconds: 150,
          warmupEnabled: true,
        ),
        TemplateItem(
          exerciseName: 'Hip Thrust',
          primaryMuscle: 'legs',
          sets: 3,
          repMin: 8,
          repMax: 12,
          restSeconds: 120,
          warmupEnabled: false,
        ),
        TemplateItem(
          exerciseName: 'Leg Curl',
          primaryMuscle: 'legs',
          sets: 3,
          repMin: 10,
          repMax: 12,
          restSeconds: 120,
          warmupEnabled: false,
          notes: 'Or Glute-ham raise.',
        ),
        TemplateItem(
          exerciseName: 'Cable Pull-through',
          primaryMuscle: 'legs',
          sets: 3,
          repMin: 10,
          repMax: 12,
          restSeconds: 120,
          warmupEnabled: false,
          notes: 'Or Single-leg RDL; per leg if single-leg.',
        ),
        TemplateItem(
          exerciseName: 'Core Circuit',
          primaryMuscle: 'abs',
          sets: 3,
          repMin: 30,
          repMax: 60,
          restSeconds: 60,
          warmupEnabled: false,
          notes: 'Plank/Hanging leg raise/Pallof press; reps are seconds.',
        ),
      ],
    ),
    TemplateDay(
      name: 'Mixed / Arms & Shoulders',
      weekday: DateTime.thursday,
      items: [
        TemplateItem(
          exerciseName: 'Incline Dumbbell Press',
          primaryMuscle: 'chest',
          sets: 3,
          repMin: 8,
          repMax: 10,
          restSeconds: 120,
          warmupEnabled: false,
        ),
        TemplateItem(
          exerciseName: 'Dips',
          primaryMuscle: 'chest',
          sets: 3,
          repMin: 8,
          repMax: 12,
          restSeconds: 120,
          warmupEnabled: false,
          notes: 'Or Close-grip Bench Press.',
        ),
        TemplateItem(
          exerciseName: 'Chest-supported Row',
          primaryMuscle: 'back',
          sets: 3,
          repMin: 10,
          repMax: 12,
          restSeconds: 120,
          warmupEnabled: false,
          notes: 'Or Single-arm DB Row.',
        ),
        TemplateItem(
          exerciseName: 'Lateral Raise',
          primaryMuscle: 'shoulders',
          sets: 3,
          repMin: 12,
          repMax: 15,
          restSeconds: 75,
          warmupEnabled: false,
          notes: 'Or Y-raise.',
        ),
        TemplateItem(
          exerciseName: 'Biceps Curl',
          primaryMuscle: 'biceps',
          sets: 3,
          repMin: 10,
          repMax: 12,
          restSeconds: 75,
          warmupEnabled: false,
          notes: 'Superset with triceps extension; minimal rest between.',
        ),
        TemplateItem(
          exerciseName: 'Triceps Extension',
          primaryMuscle: 'triceps',
          sets: 3,
          repMin: 10,
          repMax: 12,
          restSeconds: 75,
          warmupEnabled: false,
          notes: 'Superset with biceps curl; 60-90s after superset.',
        ),
      ],
    ),
  ],
);
