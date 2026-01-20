import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'db/app_database.dart';
import 'repositories/exercise_repository.dart';
import 'repositories/exercise_analytics_repository.dart';
import 'repositories/prescription_repository.dart';
import 'repositories/program_repository.dart';
import 'repositories/review_repository.dart';
import 'repositories/session_repository.dart';
import 'repositories/settings_repository.dart';
import '../services/mentzer_cycle_service.dart';

final settingsRepositoryProvider = Provider<SettingsRepository>((ref) {
  final db = ref.read(appDatabaseProvider);
  return SettingsRepository(db);
});

final programRepositoryProvider = Provider<ProgramRepository>((ref) {
  final db = ref.read(appDatabaseProvider);
  final settingsRepository = ref.read(settingsRepositoryProvider);
  return ProgramRepository(db, settingsRepository);
});

final exerciseRepositoryProvider = Provider<ExerciseRepository>((ref) {
  final db = ref.read(appDatabaseProvider);
  return ExerciseRepository(db);
});

final exerciseAnalyticsRepositoryProvider =
    Provider<ExerciseAnalyticsRepository>((ref) {
  final db = ref.read(appDatabaseProvider);
  return ExerciseAnalyticsRepository(db);
});

final prescriptionRepositoryProvider = Provider<PrescriptionRepository>((ref) {
  final db = ref.read(appDatabaseProvider);
  return PrescriptionRepository(db);
});

final sessionRepositoryProvider = Provider<SessionRepository>((ref) {
  final db = ref.read(appDatabaseProvider);
  final settingsRepository = ref.read(settingsRepositoryProvider);
  return SessionRepository(db, settingsRepository);
});

final reviewRepositoryProvider = Provider<ReviewRepository>((ref) {
  final db = ref.read(appDatabaseProvider);
  return ReviewRepository(db);
});

final settingsStreamProvider = StreamProvider<Setting?>((ref) {
  final repository = ref.watch(settingsRepositoryProvider);
  return repository.watchSettings();
});

final programsStreamProvider = StreamProvider<List<Program>>((ref) {
  final repository = ref.watch(programRepositoryProvider);
  return repository.watchPrograms();
});

final programProvider = StreamProvider.family<Program?, int>((ref, id) {
  final repository = ref.watch(programRepositoryProvider);
  return repository.watchProgram(id);
});

final workoutDaysProvider = StreamProvider.family<List<WorkoutDay>, int>(
  (ref, programId) {
    final repository = ref.watch(programRepositoryProvider);
    return repository.watchWorkoutDays(programId);
  },
);

final workoutDayProvider = StreamProvider.family<WorkoutDay?, int>((ref, id) {
  final repository = ref.watch(programRepositoryProvider);
  return repository.watchWorkoutDayById(id);
});

class WorkoutDayKey {
  const WorkoutDayKey(this.programId, this.weekday);

  final int programId;
  final int weekday;

  @override
  bool operator ==(Object other) {
    return other is WorkoutDayKey &&
        other.programId == programId &&
        other.weekday == weekday;
  }

  @override
  int get hashCode => Object.hash(programId, weekday);
}

final workoutDayForWeekdayProvider =
    StreamProvider.family<WorkoutDay?, WorkoutDayKey>((ref, key) {
  final repository = ref.watch(programRepositoryProvider);
  return repository.watchWorkoutDayForWeekday(key.programId, key.weekday);
});

final exercisesStreamProvider = StreamProvider<List<Exercise>>((ref) {
  final repository = ref.watch(exerciseRepositoryProvider);
  return repository.watchExercises();
});

final exerciseProvider = StreamProvider.family<Exercise?, int>((ref, id) {
  final repository = ref.watch(exerciseRepositoryProvider);
  return repository.watchExerciseById(id);
});

final exerciseHistoryProvider =
    StreamProvider.family<List<ExerciseSessionEntry>, int>(
  (ref, exerciseId) {
    final repository = ref.watch(exerciseAnalyticsRepositoryProvider);
    return repository.watchExerciseHistory(exerciseId);
  },
);

final exercisePRsProvider = StreamProvider.family<ExercisePRs, int>(
  (ref, exerciseId) {
    final repository = ref.watch(exerciseAnalyticsRepositoryProvider);
    return repository.watchExercisePRs(exerciseId);
  },
);

final exerciseSearchProvider =
    StreamProvider.family<List<ExerciseSearchResult>, String>(
  (ref, query) {
    final repository = ref.watch(exerciseAnalyticsRepositoryProvider);
    return repository.watchExerciseSearchResults(query);
  },
);

final prescriptionsProvider =
    StreamProvider.family<List<PrescriptionWithExercise>, int>((ref, dayId) {
  final repository = ref.watch(prescriptionRepositoryProvider);
  return repository.watchPrescriptions(dayId);
});

final prescriptionProvider =
    StreamProvider.family<PrescriptionWithExercise?, int>((ref, id) {
  final repository = ref.watch(prescriptionRepositoryProvider);
  return repository.watchPrescription(id);
});

final activeSessionProvider = StreamProvider<Session?>((ref) {
  final repository = ref.watch(sessionRepositoryProvider);
  return repository.watchActiveSession();
});

final activeSessionBundleProvider = StreamProvider<ActiveSessionBundle?>((ref) {
  final repository = ref.watch(sessionRepositoryProvider);
  return repository.watchTodayActiveSessionBundle();
});

final sessionExercisesProvider =
    StreamProvider.family<List<SessionExerciseWithExerciseAndSets>, int>(
  (ref, sessionId) {
    final repository = ref.watch(sessionRepositoryProvider);
    return repository.watchSessionExercises(sessionId);
  },
);

final sessionExerciseDetailProvider =
    StreamProvider.family<SessionExerciseDetail?, int>((ref, sessionExerciseId) {
  final repository = ref.watch(sessionRepositoryProvider);
  return repository.watchSessionExerciseDetail(sessionExerciseId);
});

final lastPerformanceProvider =
    FutureProvider.family<LastPerformance?, int>((ref, exerciseId) {
  final repository = ref.watch(sessionRepositoryProvider);
  return repository.getLastPerformance(exerciseId);
});

final recentSessionsProvider = StreamProvider<List<SessionSummary>>((ref) {
  final repository = ref.watch(sessionRepositoryProvider);
  return repository.watchRecentSessions();
});

final sessionDetailsProvider =
    StreamProvider.family<SessionDetails?, int>((ref, sessionId) {
  final repository = ref.watch(sessionRepositoryProvider);
  return repository.watchSessionDetails(sessionId);
});

final reviewSummaryProvider =
    StreamProvider.family<ReviewSummary, ReviewRange>((ref, range) {
  final repository = ref.watch(reviewRepositoryProvider);
  return repository.watchReviewSummary(range.start, range.end);
});

final mentzerCycleStateProvider =
    FutureProvider.family<MentzerCycleState, int>((ref, programId) {
  final service = ref.read(mentzerCycleServiceProvider);
  return service.loadCycleState(programId);
});
