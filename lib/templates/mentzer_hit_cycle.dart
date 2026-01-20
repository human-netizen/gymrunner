class MentzerExercise {
  const MentzerExercise({
    required this.name,
    required this.primaryMuscle,
    required this.repMin,
    required this.repMax,
    required this.notes,
    this.setsTarget = 1,
    this.preExhaustPairStart = false,
    this.noRestAfterThis = false,
  });

  final String name;
  final String primaryMuscle;
  final int setsTarget;
  final int repMin;
  final int repMax;
  final String notes;
  final bool preExhaustPairStart;
  final bool noRestAfterThis;
}

class MentzerWorkout {
  const MentzerWorkout({
    required this.title,
    required this.sideNotes,
    required this.exercises,
  });

  final String title;
  final String sideNotes;
  final List<MentzerExercise> exercises;
}

class MentzerCycleTemplate {
  const MentzerCycleTemplate({
    required this.name,
    required this.programNotes,
    required this.restMinDays,
    required this.restMaxDays,
    required this.workouts,
  });

  final String name;
  final String programNotes;
  final int restMinDays;
  final int restMaxDays;
  final List<MentzerWorkout> workouts;

  MentzerWorkout workoutForIndex(int index) {
    if (workouts.isEmpty) {
      throw StateError('No workouts configured.');
    }
    final safe = index % workouts.length;
    return workouts[safe];
  }
}

const mentzerHitCycleTemplate = MentzerCycleTemplate(
  name: 'Mentzer HIT — Main Cycle',
  programNotes:
      '1 all-out working set to failure. Strict tempo: 4 sec up, 2 sec hold, '
      '4 sec down. Pre-exhaust pairs: move immediately, essentially zero rest. '
      'Rep targets: most 6–10; legs/abs 12–20; incline press + dips 1–3 or 3–5. '
      'Progression: when you hit top of rep range, add ~10% next time. '
      'Warm-up is minimal but real (do it anyway). Safety: get medical clearance if needed.',
  restMinDays: 4,
  restMaxDays: 7,
  workouts: [
    MentzerWorkout(
      title: 'WORKOUT 1 — Chest & Back',
      sideNotes:
          'Pre-exhaust pairs: move immediately. Keep strict tempo. Rest 4–7 days after completion.',
      exercises: [
        MentzerExercise(
          name: 'Dumbbell Flyes',
          primaryMuscle: 'chest',
          repMin: 6,
          repMax: 10,
          notes:
              'Strict arc, don’t go crazy deep; tire pecs while saving triceps; move immediately to incline press.',
          preExhaustPairStart: true,
          noRestAfterThis: true,
        ),
        MentzerExercise(
          name: 'Incline Presses',
          primaryMuscle: 'chest',
          repMin: 1,
          repMax: 3,
          notes:
              'Low reps because pecs are smoked; controlled, don’t bounce; use safety arms/spotter.',
        ),
        MentzerExercise(
          name: 'Straight-arm Pulldowns',
          primaryMuscle: 'back',
          repMin: 6,
          repMax: 10,
          notes:
              'Arms almost straight to stop biceps; instantly switch to palms-up pulldowns.',
          preExhaustPairStart: true,
          noRestAfterThis: true,
        ),
        MentzerExercise(
          name: 'Palms-up Pulldowns',
          primaryMuscle: 'back',
          repMin: 6,
          repMax: 10,
          notes:
              'Underhand keeps you going after lats fail; pause + control; if you can’t do full reps, do negative-only chins.',
        ),
        MentzerExercise(
          name: 'Deadlifts',
          primaryMuscle: 'legs',
          repMin: 6,
          repMax: 10,
          notes:
              'Expensive stress-wise; flat back, reset, no jerking; hits hamstrings too—if you stop deadlifts, add leg curls somewhere.',
        ),
      ],
    ),
    MentzerWorkout(
      title: 'WORKOUT 2 — Legs & Abs',
      sideNotes:
          'Pre-exhaust legs: extensions immediately into leg press. Strict form. Rest 4–7 days after completion.',
      exercises: [
        MentzerExercise(
          name: 'Leg Extensions',
          primaryMuscle: 'legs',
          repMin: 12,
          repMax: 20,
          notes:
              'Strict + controlled; immediately move to leg press.',
          preExhaustPairStart: true,
          noRestAfterThis: true,
        ),
        MentzerExercise(
          name: 'Leg Presses',
          primaryMuscle: 'legs',
          repMin: 12,
          repMax: 20,
          notes:
              'Don’t go so deep your low back rounds; control; if no leg press, use squats with safety pins/rack.',
        ),
        MentzerExercise(
          name: 'Standing Calf Raises',
          primaryMuscle: 'legs',
          repMin: 12,
          repMax: 20,
          notes:
              'Knees locked, rise high, hold 2–3 sec, lower controlled.',
        ),
        MentzerExercise(
          name: 'Sit-ups',
          primaryMuscle: 'abs',
          repMin: 12,
          repMax: 20,
          notes:
              'Knees bent ~45°, arms across chest; when >20 reps, add weight slowly (e.g., +5 lb steps).',
        ),
      ],
    ),
    MentzerWorkout(
      title: 'WORKOUT 3 — Shoulders & Arms',
      sideNotes:
          'Strict laterals, no swinging. Pressdowns into dips immediately. Rest 4–7 days after completion.',
      exercises: [
        MentzerExercise(
          name: 'Dumbbell Lateral Raises',
          primaryMuscle: 'shoulders',
          repMin: 6,
          repMax: 10,
          notes: 'Strict, no swing; slow tempo.',
        ),
        MentzerExercise(
          name: 'Bent-over Dumbbell Laterals',
          primaryMuscle: 'shoulders',
          repMin: 6,
          repMax: 10,
          notes: 'Rear delts; torso locked, don’t heave.',
        ),
        MentzerExercise(
          name: 'Palms-up Pulldowns',
          primaryMuscle: 'biceps',
          repMin: 6,
          repMax: 10,
          notes:
              'Listed for biceps because underhand pulldown smashes biceps + lats.',
        ),
        MentzerExercise(
          name: 'Triceps Pressdowns',
          primaryMuscle: 'triceps',
          repMin: 6,
          repMax: 10,
          notes: 'Strict; move instantly to dips.',
          preExhaustPairStart: true,
          noRestAfterThis: true,
        ),
        MentzerExercise(
          name: 'Dips',
          primaryMuscle: 'triceps',
          repMin: 3,
          repMax: 5,
          notes:
              'Heavy finisher after pressdowns; add weight only after perfect form.',
        ),
      ],
    ),
    MentzerWorkout(
      title: 'WORKOUT 4 — Legs & Abs',
      sideNotes:
          'Pre-exhaust legs: extensions immediately into leg press. Strict form. Rest 4–7 days after completion.',
      exercises: [
        MentzerExercise(
          name: 'Leg Extensions',
          primaryMuscle: 'legs',
          repMin: 12,
          repMax: 20,
          notes:
              'Strict + controlled; immediately move to leg press.',
          preExhaustPairStart: true,
          noRestAfterThis: true,
        ),
        MentzerExercise(
          name: 'Leg Presses',
          primaryMuscle: 'legs',
          repMin: 12,
          repMax: 20,
          notes:
              'Don’t go so deep your low back rounds; control; if no leg press, use squats with safety pins/rack.',
        ),
        MentzerExercise(
          name: 'Standing Calf Raises',
          primaryMuscle: 'legs',
          repMin: 12,
          repMax: 20,
          notes:
              'Knees locked, rise high, hold 2–3 sec, lower controlled.',
        ),
        MentzerExercise(
          name: 'Sit-ups',
          primaryMuscle: 'abs',
          repMin: 12,
          repMax: 20,
          notes:
              'Knees bent ~45°, arms across chest; when >20 reps, add weight slowly (e.g., +5 lb steps).',
        ),
      ],
    ),
  ],
);

String mentzerSnippet(String text, {int maxLength = 80}) {
  if (text.length <= maxLength) {
    return text;
  }
  return '${text.substring(0, maxLength).trimRight()}…';
}
