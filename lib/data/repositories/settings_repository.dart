import 'package:drift/drift.dart' as drift;

import '../db/app_database.dart';

class SettingsRepository {
  SettingsRepository(this._db);

  final AppDatabase _db;

  Stream<Setting?> watchSettings() {
    final query = _db.select(_db.settings)
      ..orderBy([
        (tbl) => drift.OrderingTerm(expression: tbl.id),
      ])
      ..limit(1);
    return query.watchSingleOrNull();
  }

  Future<Setting> ensureSingleRow() async {
    final query = _db.select(_db.settings)
      ..orderBy([
        (tbl) => drift.OrderingTerm(expression: tbl.id),
      ]);
    final rows = await query.get();

    if (rows.isEmpty) {
      final id = await _db.into(_db.settings).insert(const SettingsCompanion());
      return (_db.select(_db.settings)..where((tbl) => tbl.id.equals(id)))
          .getSingle();
    }

    if (rows.length > 1) {
      final idsToDelete = rows.skip(1).map((row) => row.id).toList();
      await (_db.delete(_db.settings)..where((tbl) => tbl.id.isIn(idsToDelete)))
          .go();
    }

    return rows.first;
  }

  Future<void> updateBarWeightKg(double value) async {
    final settings = await ensureSingleRow();
    await (_db.update(_db.settings)..where((tbl) => tbl.id.equals(settings.id)))
        .write(SettingsCompanion(barWeightKg: drift.Value(value)));
  }

  Future<void> setActiveProgram(int? programId) async {
    final settings = await ensureSingleRow();
    await (_db.update(_db.settings)..where((tbl) => tbl.id.equals(settings.id)))
        .write(SettingsCompanion(activeProgramId: drift.Value(programId)));
  }

  Future<void> updatePlateInventoryCsv(String csv) async {
    final settings = await ensureSingleRow();
    await (_db.update(_db.settings)..where((tbl) => tbl.id.equals(settings.id)))
        .write(SettingsCompanion(plateInventoryCsv: drift.Value(csv)));
  }
}
