import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

class RestTimerState {
  const RestTimerState({
    required this.initialSeconds,
    required this.remainingSeconds,
    required this.isRunning,
    required this.endsAt,
  });

  final int initialSeconds;
  final int remainingSeconds;
  final bool isRunning;
  final DateTime? endsAt;

  RestTimerState copyWith({
    int? initialSeconds,
    int? remainingSeconds,
    bool? isRunning,
    DateTime? endsAt,
    bool clearEndsAt = false,
  }) {
    return RestTimerState(
      initialSeconds: initialSeconds ?? this.initialSeconds,
      remainingSeconds: remainingSeconds ?? this.remainingSeconds,
      isRunning: isRunning ?? this.isRunning,
      endsAt: clearEndsAt ? null : (endsAt ?? this.endsAt),
    );
  }
}

class RestTimerNotifier extends Notifier<RestTimerState> {
  @override
  RestTimerState build() {
    ref.onDispose(() => _timer?.cancel());
    return const RestTimerState(
      initialSeconds: 0,
      remainingSeconds: 0,
      isRunning: false,
      endsAt: null,
    );
  }

  Timer? _timer;

  void start(int seconds) {
    if (seconds <= 0) {
      return;
    }
    _timer?.cancel();
    final endsAt = DateTime.now().add(Duration(seconds: seconds));
    state = RestTimerState(
      initialSeconds: seconds,
      remainingSeconds: seconds,
      isRunning: true,
      endsAt: endsAt,
    );
    _timer = Timer.periodic(const Duration(seconds: 1), (_) => _tick());
  }

  void _tick() {
    final nextRemaining = state.remainingSeconds - 1;
    if (nextRemaining <= 0) {
      _timer?.cancel();
      state = state.copyWith(
        remainingSeconds: 0,
        isRunning: false,
        clearEndsAt: true,
      );
      return;
    }
    state = state.copyWith(remainingSeconds: nextRemaining);
  }

  void togglePause() {
    if (state.isRunning) {
      _timer?.cancel();
      state = state.copyWith(isRunning: false, clearEndsAt: true);
      return;
    }

    if (state.remainingSeconds <= 0) {
      return;
    }
    _timer?.cancel();
    final endsAt =
        DateTime.now().add(Duration(seconds: state.remainingSeconds));
    state = state.copyWith(isRunning: true, endsAt: endsAt);
    _timer = Timer.periodic(const Duration(seconds: 1), (_) => _tick());
  }

  void reset() {
    _timer?.cancel();
    state = state.copyWith(
      remainingSeconds: state.initialSeconds,
      isRunning: false,
      clearEndsAt: true,
    );
  }

  void addSeconds(int seconds) {
    if (seconds <= 0) {
      return;
    }
    final nextRemaining = state.remainingSeconds + seconds;
    state = state.copyWith(
      initialSeconds: state.initialSeconds + seconds,
      remainingSeconds: nextRemaining,
    );
    if (state.isRunning) {
      final endsAt = DateTime.now().add(Duration(seconds: nextRemaining));
      state = state.copyWith(endsAt: endsAt);
    }
  }
}

final restTimerProvider = NotifierProvider<RestTimerNotifier, RestTimerState>(
  RestTimerNotifier.new,
);
