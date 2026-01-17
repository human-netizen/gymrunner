import 'dart:async';
import 'dart:math';
import 'package:drift/drift.dart' as drift;

import '../db/app_database.dart';
import '../strength_utils.dart';
import 'settings_repository.dart';

class SessionSummary {
  const SessionSummary({
    required this.session,
    this.workoutDay,
    this.program,
  });

  final Session session;
  final WorkoutDay? workoutDay;
  final Program? program;

  Duration? get duration {
    final finished = session.finishedAt;
    if (finished == null) {
      return null;
    }
    return finished.difference(session.startedAt);
  }
}

class SessionExerciseWithExerciseAndSets {
  const SessionExerciseWithExerciseAndSets({
    required this.sessionExercise,
    required this.exercise,
    required this.sets,
  });

  final SessionExercise sessionExercise;
  final Exercise exercise;
  final List<SetLog> sets;

  List<SetLog> get workingSets => _sortedSets(warmup: false);
  List<SetLog> get warmupSets => _sortedSets(warmup: true);

  List<SetLog> _sortedSets({required bool warmup}) {
    final filtered = sets.where((set) => set.isWarmup == warmup).toList();
    filtered.sort((a, b) => a.setIndex.compareTo(b.setIndex));
    return filtered;
  }
}

class SessionExerciseDetail {
  const SessionExerciseDetail({
    required this.sessionExercise,
    required this.exercise,
    required this.sets,
  });

  final SessionExercise sessionExercise;
  final Exercise exercise;
  final List<SetLog> sets;

  List<SetLog> get workingSets => _sortedSets(warmup: false);
  List<SetLog> get warmupSets => _sortedSets(warmup: true);
  int get loggedWorkingSetsCount => workingSets.length;
  int get targetSets => sessionExercise.setsTarget;
  bool get isTargetReached => loggedWorkingSetsCount >= targetSets;

  List<SetLog> _sortedSets({required bool warmup}) {
    final filtered = sets.where((set) => set.isWarmup == warmup).toList();
    filtered.sort((a, b) => a.setIndex.compareTo(b.setIndex));
    return filtered;
  }
}

class SessionExerciseSummary {
  const SessionExerciseSummary({
    required this.sessionExerciseId,
    required this.exerciseName,
    required this.orderIndex,
    required this.setsTarget,
    required this.repMin,
    required this.repMax,
    required this.restSeconds,
    required this.loggedSetsCount,
    required this.isCompleted,
    required this.isTargetReached,
  });

  final int sessionExerciseId;
  final String exerciseName;
  final int orderIndex;
  final int setsTarget;
  final int repMin;
  final int repMax;
  final int restSeconds;
  final int loggedSetsCount;
  final bool isCompleted;
  final bool isTargetReached;
}

class ActiveSessionBundle {
  const ActiveSessionBundle({
    required this.session,
    required this.exercises,
  });

  final Session session;
  final List<SessionExerciseSummary> exercises;
}

class LastPerformance {
  const LastPerformance({required this.sets});

  final List<SetLog> sets;

  double? get firstWeight => sets.isEmpty ? null : sets.first.weightKg;

  String toSummaryLine() {
    if (sets.isEmpty) {
      return 'No history yet';
    }
    final uniqueWeights = sets.map((set) => set.weightKg).toSet();
    if (uniqueWeights.length == 1) {
      final weight = sets.first.weightKg.toStringAsFixed(1);
      final reps = sets.map((set) => set.reps).join(', ');
      return 'Last: $weight x $reps';
    }
    final parts = sets
        .map((set) => '${set.weightKg.toStringAsFixed(1)}x${set.reps}')
        .join(', ');
    return 'Last: $parts';
  }
}

class SessionDetails {
  const SessionDetails({
    required this.summary,
    required this.exercises,
  });

  final SessionSummary summary;
  final List<SessionExerciseWithExerciseAndSets> exercises;
}

class SessionRepository {
  SessionRepository(this._db, this._settingsRepository);

  final AppDatabase _db;
  final SettingsRepository _settingsRepository;

  Stream<Session?> watchActiveSession() {
    final query = _db.select(_db.sessions)
      ..where((tbl) => tbl.finishedAt.isNull())
      ..orderBy([
        (tbl) => drift.OrderingTerm(
              expression: tbl.startedAt,
              mode: drift.OrderingMode.desc,
            ),
      ])
      ..limit(1);
    return query.watchSingleOrNull();
  }

  Stream<Session?> watchSession(int sessionId) {
    final query = _db.select(_db.sessions)
      ..where((tbl) => tbl.id.equals(sessionId))
      ..limit(1);
    return query.watchSingleOrNull();
  }

  Future<void> setCurrentExercise(int sessionId, int? sessionExerciseId) async {
    await (_db.update(_db.sessions)..where((tbl) => tbl.id.equals(sessionId)))
        .write(
      SessionsCompanion(
        currentSessionExerciseId: drift.Value(sessionExerciseId),
      ),
    );
  }

  Future<int?> startSessionForWorkoutDayAndSelectExercise({
    required int workoutDayId,
    required int exerciseId,
    bool isDeload = false,
  }) async {
    final sessionId = await startSessionForWorkoutDay(
      workoutDayId,
      isDeload: isDeload,
    );
    final sessionExercise = await (_db.select(_db.sessionExercises)
          ..where((tbl) =>
              tbl.sessionId.equals(sessionId) &
              tbl.exerciseId.equals(exerciseId))
          ..orderBy([
            (tbl) => drift.OrderingTerm(expression: tbl.orderIndex),
          ])
          ..limit(1))
        .getSingleOrNull();
    if (sessionExercise == null) {
      return null;
    }
    await setCurrentExercise(sessionId, sessionExercise.id);
    return sessionExercise.id;
  }

  Future<void> toggleExerciseCompleted(
    int sessionExerciseId,
    bool done,
  ) async {
    await (_db.update(_db.sessionExercises)
          ..where((tbl) => tbl.id.equals(sessionExerciseId)))
        .write(
      SessionExercisesCompanion(
        isCompleted: drift.Value(done),
        completedAt: drift.Value(done ? DateTime.now() : null),
      ),
    );
  }

  Stream<SessionExerciseDetail?> watchSessionExerciseDetail(
    int sessionExerciseId,
  ) {
    final query = _db.select(_db.sessionExercises).join([
      drift.innerJoin(
        _db.exercises,
        _db.exercises.id.equalsExp(_db.sessionExercises.exerciseId),
      ),
      drift.leftOuterJoin(
        _db.setLogs,
        _db.setLogs.sessionExerciseId.equalsExp(_db.sessionExercises.id),
      ),
    ]);
    query.where(_db.sessionExercises.id.equals(sessionExerciseId));
    query.orderBy([
      drift.OrderingTerm(expression: _db.setLogs.setIndex),
    ]);

    return query.watch().map((rows) {
      if (rows.isEmpty) {
        return null;
      }

      final sessionExercise = rows.first.readTable(_db.sessionExercises);
      final exercise = rows.first.readTable(_db.exercises);
      final sets = <SetLog>[];

      for (final row in rows) {
        final setLog = row.readTableOrNull(_db.setLogs);
        if (setLog != null) {
          sets.add(setLog);
        }
      }

      sets.sort((a, b) => a.setIndex.compareTo(b.setIndex));

      return SessionExerciseDetail(
        sessionExercise: sessionExercise,
        exercise: exercise,
        sets: sets,
      );
    });
  }

  Stream<ActiveSessionBundle?> watchTodayActiveSessionBundle() {
    return _switchMap<Session?, ActiveSessionBundle?>(
      watchActiveSession(),
      (session) {
        if (session == null) {
          return Stream<ActiveSessionBundle?>.value(null);
        }
        return watchSessionExercises(session.id).map((items) {
          final summaries = items
              .map(
                (item) => SessionExerciseSummary(
                  sessionExerciseId: item.sessionExercise.id,
                  exerciseName: item.exercise.name,
                  orderIndex: item.sessionExercise.orderIndex,
                  setsTarget: item.sessionExercise.setsTarget,
                  repMin: item.sessionExercise.repMin,
                  repMax: item.sessionExercise.repMax,
                  restSeconds: item.sessionExercise.restSeconds,
                  loggedSetsCount: item.workingSets.length,
                  isCompleted: item.sessionExercise.isCompleted,
                  isTargetReached:
                      item.workingSets.length >= item.sessionExercise.setsTarget,
                ),
              )
              .toList();
          summaries.sort((a, b) => a.orderIndex.compareTo(b.orderIndex));

          return ActiveSessionBundle(
            session: session,
            exercises: summaries,
          );
        });
      },
    );
  }

  Stream<SessionSummary?> watchSessionSummary(int sessionId) {
    final query = _db.select(_db.sessions).join([
      drift.leftOuterJoin(
        _db.workoutDays,
        _db.workoutDays.id.equalsExp(_db.sessions.workoutDayId),
      ),
      drift.leftOuterJoin(
        _db.programs,
        _db.programs.id.equalsExp(_db.sessions.programId),
      ),
    ]);
    query.where(_db.sessions.id.equals(sessionId));
    query.limit(1);

    return query.watchSingleOrNull().map((row) {
      if (row == null) {
        return null;
      }
      return SessionSummary(
        session: row.readTable(_db.sessions),
        workoutDay: row.readTableOrNull(_db.workoutDays),
        program: row.readTableOrNull(_db.programs),
      );
    });
  }

  Stream<List<SessionSummary>> watchRecentSessions({int limit = 50}) {
    final query = _db.select(_db.sessions).join([
      drift.leftOuterJoin(
        _db.workoutDays,
        _db.workoutDays.id.equalsExp(_db.sessions.workoutDayId),
      ),
      drift.leftOuterJoin(
        _db.programs,
        _db.programs.id.equalsExp(_db.sessions.programId),
      ),
    ]);
    query.where(_db.sessions.finishedAt.isNotNull());
    query.orderBy([
      drift.OrderingTerm(
        expression: _db.sessions.startedAt,
        mode: drift.OrderingMode.desc,
      ),
    ]);
    query.limit(limit);

    return query.watch().map((rows) {
      return rows
          .map(
            (row) => SessionSummary(
              session: row.readTable(_db.sessions),
              workoutDay: row.readTableOrNull(_db.workoutDays),
              program: row.readTableOrNull(_db.programs),
            ),
          )
          .toList();
    });
  }

  Stream<SessionDetails?> watchSessionDetails(int sessionId) {
    final summaryStream = watchSessionSummary(sessionId);
    final exercisesStream = watchSessionExercises(sessionId);

    return _combineLatest2<SessionSummary?,
        List<SessionExerciseWithExerciseAndSets>, SessionDetails?>(
      summaryStream,
      exercisesStream,
      (summary, exercises) {
        if (summary == null) {
          return null;
        }
        return SessionDetails(summary: summary, exercises: exercises);
      },
    );
  }

  Future<int> startSessionForWorkoutDay(
    int workoutDayId, {
    bool isDeload = false,
  }) async {
    final settings = await _settingsRepository.ensureSingleRow();
    final programId = settings.activeProgramId;

    return _db.transaction(() async {
      final sessionId = await _db.into(_db.sessions).insert(
            SessionsCompanion.insert(
              programId: drift.Value(programId),
              workoutDayId: drift.Value(workoutDayId),
              isDeload: drift.Value(isDeload),
            ),
          );

      final query = _db.select(_db.prescriptions).join([
        drift.innerJoin(
          _db.exercises,
          _db.exercises.id.equalsExp(_db.prescriptions.exerciseId),
        ),
      ]);
      query.where(_db.prescriptions.workoutDayId.equals(workoutDayId));
      query.orderBy([
        drift.OrderingTerm(expression: _db.prescriptions.orderIndex),
      ]);

      final rows = await query.get();
      final inserts = <SessionExercisesCompanion>[];

      for (final row in rows) {
        final prescription = row.readTable(_db.prescriptions);
        final exercise = row.readTable(_db.exercises);
        final restSeconds =
            prescription.restSeconds ?? exercise.defaultRestSeconds;
        final incrementKg =
            prescription.incrementKg ?? exercise.defaultIncrementKg;

        double? suggestedWorkingWeightKg;
        final lastWorkingSets =
            await _getLastFinishedWorkingSets(prescription.exerciseId);
        if (lastWorkingSets.isNotEmpty) {
          final lastWeight = lastWorkingSets.first.weightKg;
          final lastReps = lastWorkingSets.map((set) => set.reps).toList();
          suggestedWorkingWeightKg = suggestNextWorkingWeightKg(
            lastWorkingWeightKg: lastWeight,
            lastWorkingReps: lastReps,
            repMin: prescription.repMin,
            repMax: prescription.repMax,
            setsTarget: prescription.setsTarget,
            incrementKg: incrementKg,
          );
        }

        if (isDeload && suggestedWorkingWeightKg != null) {
          suggestedWorkingWeightKg = roundToNearestStep(
            suggestedWorkingWeightKg * 0.9,
          );
        }

        final setsTarget = isDeload
            ? max(1, prescription.setsTarget - 1)
            : prescription.setsTarget;

        inserts.add(
          SessionExercisesCompanion.insert(
            sessionId: sessionId,
            exerciseId: prescription.exerciseId,
            orderIndex: prescription.orderIndex,
            setsTarget: setsTarget,
            repMin: prescription.repMin,
            repMax: prescription.repMax,
            restSeconds: restSeconds,
            warmupEnabled: drift.Value(prescription.warmupEnabled),
            suggestedWorkingWeightKg: drift.Value(suggestedWorkingWeightKg),
            incrementKg: incrementKg,
            progressionRule: prescription.progressionRule,
            prescriptionNotes: drift.Value(prescription.notes),
          ),
        );
      }

      await _db.batch((batch) {
        batch.insertAll(_db.sessionExercises, inserts);
      });

      return sessionId;
    });
  }

  Future<void> finishSession(int sessionId) async {
    await (_db.update(_db.sessions)..where((tbl) => tbl.id.equals(sessionId)))
        .write(
      SessionsCompanion(
        finishedAt: drift.Value(DateTime.now()),
        currentSessionExerciseId: const drift.Value(null),
      ),
    );
  }

  Future<void> discardSession(int sessionId) async {
    await (_db.delete(_db.sessions)..where((tbl) => tbl.id.equals(sessionId)))
        .go();
  }

  Stream<List<SessionExerciseWithExerciseAndSets>> watchSessionExercises(
    int sessionId,
  ) {
    final query = _db.select(_db.sessionExercises).join([
      drift.innerJoin(
        _db.exercises,
        _db.exercises.id.equalsExp(_db.sessionExercises.exerciseId),
      ),
      drift.leftOuterJoin(
        _db.setLogs,
        _db.setLogs.sessionExerciseId.equalsExp(_db.sessionExercises.id),
      ),
    ]);
    query.where(_db.sessionExercises.sessionId.equals(sessionId));
    query.orderBy([
      drift.OrderingTerm(expression: _db.sessionExercises.orderIndex),
      drift.OrderingTerm(expression: _db.setLogs.setIndex),
    ]);

    return query.watch().map((rows) {
      final grouped = <int, _SessionExerciseGroup>{};

      for (final row in rows) {
        final sessionExercise = row.readTable(_db.sessionExercises);
        final exercise = row.readTable(_db.exercises);
        final setLog = row.readTableOrNull(_db.setLogs);

        final entry = grouped.putIfAbsent(
          sessionExercise.id,
          () => _SessionExerciseGroup(sessionExercise, exercise),
        );
        if (setLog != null) {
          entry.sets.add(setLog);
        }
      }

      return grouped.values
          .map(
            (entry) => SessionExerciseWithExerciseAndSets(
              sessionExercise: entry.sessionExercise,
              exercise: entry.exercise,
              sets: entry.sets
                ..sort((a, b) => a.setIndex.compareTo(b.setIndex)),
            ),
          )
          .toList();
    });
  }

  Future<void> addSet(
    int sessionExerciseId,
    double weightKg,
    int reps,
    {bool isWarmup = false}
  ) async {
    await addSetReturningLog(
      sessionExerciseId,
      weightKg,
      reps,
      isWarmup: isWarmup,
    );
  }

  Future<SetLog> addSetReturningLog(
    int sessionExerciseId,
    double weightKg,
    int reps, {
    bool isWarmup = false,
  }) async {
    final now = DateTime.now();
    late int insertedId;
    late int nextIndex;

    await _db.transaction(() async {
      final countExp = _db.setLogs.id.count();
      final countQuery = _db.selectOnly(_db.setLogs)
        ..addColumns([countExp])
        ..where(
          _db.setLogs.sessionExerciseId.equals(sessionExerciseId) &
              _db.setLogs.isWarmup.equals(isWarmup),
        );
      final count =
          await countQuery.map((row) => row.read(countExp)).getSingle();
      nextIndex = (count ?? 0) + 1;

      insertedId = await _db.into(_db.setLogs).insert(
            SetLogsCompanion.insert(
              sessionExerciseId: sessionExerciseId,
              setIndex: nextIndex,
              weightKg: weightKg,
              reps: reps,
              isWarmup: drift.Value(isWarmup),
              createdAt: drift.Value(now),
            ),
          );

      if (!isWarmup) {
        final sessionExercise = await (_db.select(_db.sessionExercises)
              ..where((tbl) => tbl.id.equals(sessionExerciseId))
              ..limit(1))
            .getSingle();

        if (nextIndex >= sessionExercise.setsTarget &&
            !sessionExercise.isCompleted) {
          await (_db.update(_db.sessionExercises)
                ..where((tbl) => tbl.id.equals(sessionExerciseId)))
              .write(
            SessionExercisesCompanion(
              isCompleted: const drift.Value(true),
              completedAt: drift.Value(DateTime.now()),
            ),
          );
        }
      }
    });

    return SetLog(
      id: insertedId,
      sessionExerciseId: sessionExerciseId,
      setIndex: nextIndex,
      weightKg: weightKg,
      reps: reps,
      isWarmup: isWarmup,
      rpe: null,
      createdAt: now,
    );
  }

  Future<void> deleteLastSet(int sessionExerciseId) async {
    final lastSet = await (_db.select(_db.setLogs)
          ..where((tbl) => tbl.sessionExerciseId.equals(sessionExerciseId))
          ..orderBy([
            (tbl) => drift.OrderingTerm(
                  expression: tbl.createdAt,
                  mode: drift.OrderingMode.desc,
                ),
          ])
          ..limit(1))
        .getSingleOrNull();

    if (lastSet == null) {
      return;
    }

    await (_db.delete(_db.setLogs)..where((tbl) => tbl.id.equals(lastSet.id)))
        .go();

    if (!lastSet.isWarmup) {
      await _updateCompletionForSessionExercise(sessionExerciseId);
    }
  }

  Future<void> updateSetLog({
    required int id,
    required double weightKg,
    required int reps,
  }) async {
    await (_db.update(_db.setLogs)..where((tbl) => tbl.id.equals(id))).write(
      SetLogsCompanion(
        weightKg: drift.Value(weightKg),
        reps: drift.Value(reps),
      ),
    );
  }

  Future<void> deleteSetLog(int setLogId) async {
    final setLog = await (_db.select(_db.setLogs)
          ..where((tbl) => tbl.id.equals(setLogId))
          ..limit(1))
        .getSingleOrNull();
    if (setLog == null) {
      return;
    }

    await (_db.delete(_db.setLogs)..where((tbl) => tbl.id.equals(setLogId)))
        .go();

    if (!setLog.isWarmup) {
      await _updateCompletionForSessionExercise(setLog.sessionExerciseId);
    }
  }

  Future<LastPerformance?> getLastPerformance(int exerciseId) async {
    final sets = await _getLastFinishedWorkingSets(exerciseId);
    if (sets.isEmpty) {
      return null;
    }

    return LastPerformance(sets: sets);
  }

  Future<List<SetLog>> _getLastFinishedWorkingSets(int exerciseId) async {
    final query = _db.select(_db.setLogs).join([
      drift.innerJoin(
        _db.sessionExercises,
        _db.sessionExercises.id.equalsExp(_db.setLogs.sessionExerciseId),
      ),
      drift.innerJoin(
        _db.sessions,
        _db.sessions.id.equalsExp(_db.sessionExercises.sessionId),
      ),
    ]);
    query.where(
      _db.sessionExercises.exerciseId.equals(exerciseId) &
          _db.sessions.finishedAt.isNotNull() &
          _db.setLogs.isWarmup.equals(false),
    );
    query.orderBy([
      drift.OrderingTerm(
        expression: _db.sessions.finishedAt,
        mode: drift.OrderingMode.desc,
      ),
      drift.OrderingTerm(expression: _db.setLogs.setIndex),
    ]);

    final rows = await query.get();
    if (rows.isEmpty) {
      return [];
    }

    final firstSessionId = rows.first.readTable(_db.sessions).id;
    final firstSessionExerciseId =
        rows.first.readTable(_db.sessionExercises).id;
    final sets = <SetLog>[];

    for (final row in rows) {
      final session = row.readTable(_db.sessions);
      final sessionExercise = row.readTable(_db.sessionExercises);
      if (session.id != firstSessionId ||
          sessionExercise.id != firstSessionExerciseId) {
        break;
      }
      sets.add(row.readTable(_db.setLogs));
    }

    sets.sort((a, b) => a.setIndex.compareTo(b.setIndex));
    return sets;
  }

  Future<void> _updateCompletionForSessionExercise(
    int sessionExerciseId,
  ) async {
    final countExp = _db.setLogs.id.count();
    final countQuery = _db.selectOnly(_db.setLogs)
      ..addColumns([countExp])
      ..where(
        _db.setLogs.sessionExerciseId.equals(sessionExerciseId) &
            _db.setLogs.isWarmup.equals(false),
      );
    final count = await countQuery.map((row) => row.read(countExp)).getSingle();
    final remaining = count ?? 0;

    final sessionExercise = await (_db.select(_db.sessionExercises)
          ..where((tbl) => tbl.id.equals(sessionExerciseId))
          ..limit(1))
        .getSingle();

    final shouldComplete = remaining >= sessionExercise.setsTarget;
    if (shouldComplete == sessionExercise.isCompleted) {
      return;
    }

    await (_db.update(_db.sessionExercises)
          ..where((tbl) => tbl.id.equals(sessionExerciseId)))
        .write(
      SessionExercisesCompanion(
        isCompleted: drift.Value(shouldComplete),
        completedAt:
            drift.Value(shouldComplete ? DateTime.now() : null),
      ),
    );
  }

  Future<int?> getNextSessionExerciseId(
    int sessionId,
    int currentSessionExerciseId,
  ) async {
    final rows = await (_db.select(_db.sessionExercises)
          ..where((tbl) => tbl.sessionId.equals(sessionId))
          ..orderBy([
            (tbl) => drift.OrderingTerm(expression: tbl.orderIndex),
          ]))
        .get();

    if (rows.isEmpty) {
      return null;
    }

    final index =
        rows.indexWhere((row) => row.id == currentSessionExerciseId);
    if (index == -1) {
      return null;
    }
    if (index + 1 >= rows.length) {
      return null;
    }
    return rows[index + 1].id;
  }

  Future<int?> getPreviousSessionExerciseId(
    int sessionId,
    int currentSessionExerciseId,
  ) async {
    final rows = await (_db.select(_db.sessionExercises)
          ..where((tbl) => tbl.sessionId.equals(sessionId))
          ..orderBy([
            (tbl) => drift.OrderingTerm(expression: tbl.orderIndex),
          ]))
        .get();

    if (rows.isEmpty) {
      return null;
    }

    final index =
        rows.indexWhere((row) => row.id == currentSessionExerciseId);
    if (index == -1) {
      return null;
    }
    if (index - 1 < 0) {
      return null;
    }
    return rows[index - 1].id;
  }
}

class _SessionExerciseGroup {
  _SessionExerciseGroup(this.sessionExercise, this.exercise);

  final SessionExercise sessionExercise;
  final Exercise exercise;
  final List<SetLog> sets = [];
}

Stream<T> _combineLatest2<A, B, T>(
  Stream<A> streamA,
  Stream<B> streamB,
  T Function(A a, B b) combiner,
) {
  late StreamController<T> controller;
  StreamSubscription<A>? subscriptionA;
  StreamSubscription<B>? subscriptionB;
  A? latestA;
  B? latestB;
  var hasA = false;
  var hasB = false;

  controller = StreamController<T>(
    onListen: () {
      subscriptionA = streamA.listen(
        (value) {
          latestA = value;
          hasA = true;
          if (hasB) {
            controller.add(combiner(latestA as A, latestB as B));
          }
        },
        onError: controller.addError,
      );
      subscriptionB = streamB.listen(
        (value) {
          latestB = value;
          hasB = true;
          if (hasA) {
            controller.add(combiner(latestA as A, latestB as B));
          }
        },
        onError: controller.addError,
      );
    },
    onCancel: () async {
      await subscriptionA?.cancel();
      await subscriptionB?.cancel();
    },
  );

  return controller.stream;
}

Stream<T> _switchMap<S, T>(
  Stream<S> source,
  Stream<T> Function(S value) mapper,
) {
  late StreamController<T> controller;
  StreamSubscription<S>? sourceSubscription;
  StreamSubscription<T>? innerSubscription;

  controller = StreamController<T>(
    onListen: () {
      sourceSubscription = source.listen(
        (value) {
          innerSubscription?.cancel();
          innerSubscription = mapper(value).listen(
            controller.add,
            onError: controller.addError,
          );
        },
        onError: controller.addError,
      );
    },
    onCancel: () async {
      await sourceSubscription?.cancel();
      await innerSubscription?.cancel();
    },
  );

  return controller.stream;
}
