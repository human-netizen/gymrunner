import 'dart:math';

import 'package:drift/drift.dart' as drift;

import '../db/app_database.dart';

class PrescriptionWithExercise {
  const PrescriptionWithExercise({
    required this.prescription,
    required this.exercise,
  });

  final Prescription prescription;
  final Exercise exercise;
}

class PrescriptionRepository {
  PrescriptionRepository(this._db);

  final AppDatabase _db;

  Stream<List<PrescriptionWithExercise>> watchPrescriptions(int workoutDayId) {
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

    return query.watch().map((rows) {
      return rows
          .map((row) => PrescriptionWithExercise(
                prescription: row.readTable(_db.prescriptions),
                exercise: row.readTable(_db.exercises),
              ))
          .toList();
    });
  }

  Stream<PrescriptionWithExercise?> watchPrescription(int id) {
    final query = _db.select(_db.prescriptions).join([
      drift.innerJoin(
        _db.exercises,
        _db.exercises.id.equalsExp(_db.prescriptions.exerciseId),
      ),
    ]);
    query.where(_db.prescriptions.id.equals(id));
    query.limit(1);

    return query.watchSingleOrNull().map((row) {
      if (row == null) {
        return null;
      }
      return PrescriptionWithExercise(
        prescription: row.readTable(_db.prescriptions),
        exercise: row.readTable(_db.exercises),
      );
    });
  }

  Future<void> addPrescription(int workoutDayId, int exerciseId) async {
    final orderIndex = await _nextOrderIndex(workoutDayId);
    await _db.into(_db.prescriptions).insert(
          PrescriptionsCompanion.insert(
            workoutDayId: workoutDayId,
            exerciseId: exerciseId,
            orderIndex: orderIndex,
          ),
        );
  }

  Future<void> updatePrescription({
    required int id,
    required int setsTarget,
    required int repMin,
    required int repMax,
    int? restSeconds,
    bool? warmupEnabled,
    double? incrementKg,
    String? notes,
    String? progressionRule,
  }) async {
    final companion = PrescriptionsCompanion(
      setsTarget: drift.Value(setsTarget),
      repMin: drift.Value(repMin),
      repMax: drift.Value(repMax),
      restSeconds: drift.Value(restSeconds),
      warmupEnabled: warmupEnabled == null
          ? const drift.Value.absent()
          : drift.Value(warmupEnabled),
      incrementKg: drift.Value(incrementKg),
      notes: drift.Value(notes),
      progressionRule: progressionRule == null
          ? const drift.Value.absent()
          : drift.Value(progressionRule),
    );
    await (_db.update(_db.prescriptions)..where((tbl) => tbl.id.equals(id)))
        .write(companion);
  }

  Future<void> reorderPrescriptions(
    int workoutDayId,
    List<int> orderedIds,
  ) async {
    await _db.batch((batch) {
      for (var i = 0; i < orderedIds.length; i += 1) {
        batch.update(
          _db.prescriptions,
          PrescriptionsCompanion(orderIndex: drift.Value(-i - 1)),
          where: (tbl) =>
              tbl.id.equals(orderedIds[i]) &
              tbl.workoutDayId.equals(workoutDayId),
        );
      }
    });

    await _db.batch((batch) {
      for (var i = 0; i < orderedIds.length; i += 1) {
        batch.update(
          _db.prescriptions,
          PrescriptionsCompanion(orderIndex: drift.Value(i)),
          where: (tbl) =>
              tbl.id.equals(orderedIds[i]) &
              tbl.workoutDayId.equals(workoutDayId),
        );
      }
    });
  }

  Future<void> deletePrescription(int id) async {
    await (_db.delete(_db.prescriptions)..where((tbl) => tbl.id.equals(id)))
        .go();
  }

  Future<int> _nextOrderIndex(int workoutDayId) async {
    final rows = await (_db.select(_db.prescriptions)
          ..where((tbl) => tbl.workoutDayId.equals(workoutDayId)))
        .get();
    if (rows.isEmpty) {
      return 0;
    }
    final maxOrder = rows.map((row) => row.orderIndex).reduce(max);
    return maxOrder + 1;
  }
}
