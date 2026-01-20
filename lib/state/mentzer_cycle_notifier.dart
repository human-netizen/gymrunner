import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../services/mentzer_cycle_service.dart';
import '../templates/mentzer_hit_cycle.dart';

class MentzerCycleNotifier extends AsyncNotifier<MentzerCycleState> {
  MentzerCycleNotifier(this._programId);

  final int _programId;
  int? _activeWorkoutIndex;

  int? get activeWorkoutIndex => _activeWorkoutIndex;

  @override
  Future<MentzerCycleState> build() async {
    return ref.read(mentzerCycleServiceProvider).loadCycleState(_programId);
  }

  void setActiveWorkoutIndex(int workoutIndex) {
    _activeWorkoutIndex = workoutIndex;
  }

  Future<MentzerCycleState> advanceAfterFinish({
    required int finishedWorkoutIndex,
    required DateTime finishedAt,
  }) async {
    final nextWorkoutIndex =
        (finishedWorkoutIndex + 1) % mentzerHitCycleTemplate.workouts.length;
    final nextAvailableAt = finishedAt.add(const Duration(hours: 96));
    final nextState = MentzerCycleState(
      nextWorkoutIndex: nextWorkoutIndex,
      nextAvailableAt: nextAvailableAt,
      lastFinishedAt: finishedAt,
    );
    state = AsyncData(nextState);
    await ref
        .read(mentzerCycleServiceProvider)
        .persistCycleState(_programId, nextState);
    _activeWorkoutIndex = null;
    return nextState;
  }
}
