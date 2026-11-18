import 'package:drift/drift.dart';
import '../database/app_database.dart';
import '../database/tables/measurements_tables.dart';

part 'measurements_dao.g.dart';

@DriftAccessor(tables: [WeightLogs, Measurements, ProgressMedia])
class MeasurementsDao extends DatabaseAccessor<AppDatabase>
    with _$MeasurementsDaoMixin {
  MeasurementsDao(super.db);

  Future<void> insertWeightLog(WeightLogsCompanion log) =>
      into(weightLogs).insert(log);

  Future<List<WeightLog>> getWeightLogs(
      DateTime startDate, DateTime endDate) {
    final start = DateTime.utc(startDate.year, startDate.month, startDate.day);
    final end = DateTime.utc(endDate.year, endDate.month, endDate.day)
        .add(const Duration(days: 1));
    return (select(weightLogs)
          ..where((t) =>
              t.date.isBiggerOrEqualValue(start) &
              t.date.isSmallerThanValue(end))
          ..orderBy([(t) => OrderingTerm.asc(t.date)]))
        .get();
  }

  Future<void> insertMeasurement(MeasurementsCompanion measurement) =>
      into(measurements).insert(measurement);

  Future<List<Measurement>> getMeasurements() =>
      (select(measurements)
            ..orderBy([(t) => OrderingTerm.desc(t.date)]))
          .get();

  Future<bool> updateMeasurement(Measurement measurement) =>
      update(measurements).replace(measurement);

  Future<int> deleteMeasurement(int id) =>
      (delete(measurements)..where((t) => t.id.equals(id))).go();

  Future<Measurement?> getLatestMeasurement() =>
      (select(measurements)
            ..orderBy([(t) => OrderingTerm.desc(t.date)])
            ..limit(1))
          .getSingleOrNull();

  // ── Álbum de progreso ────────────────────────────────────────────────────

  /// Todo el álbum sin los archivos, del más reciente al más antiguo.
  Future<List<ProgressMediaInfo>> getProgressMediaInfo() async {
    final q = selectOnly(progressMedia)
      ..addColumns([progressMedia.id, progressMedia.day, progressMedia.kind, progressMedia.takenAt])
      ..orderBy([OrderingTerm.desc(progressMedia.day), OrderingTerm.asc(progressMedia.takenAt)]);
    return [
      for (final row in await q.get())
        (
          id: row.read(progressMedia.id)!,
          day: row.read(progressMedia.day)!,
          isVideo: row.read(progressMedia.kind) == 'video',
          takenAt: row.read(progressMedia.takenAt)!,
        ),
    ];
  }

  Future<ProgressMediaData?> getProgressMedia(int id) =>
      (select(progressMedia)..where((t) => t.id.equals(id))).getSingleOrNull();

  Future<int> countProgressMedia(DateTime day) async {
    final count = progressMedia.id.count();
    final q = selectOnly(progressMedia)
      ..addColumns([count])
      ..where(progressMedia.day.equals(day));
    return (await q.getSingle()).read(count) ?? 0;
  }

  Future<int> insertProgressMedia(ProgressMediaCompanion media) => into(progressMedia).insert(media);

  Future<void> deleteProgressMedia(int id) =>
      (delete(progressMedia)..where((t) => t.id.equals(id))).go();
}

typedef ProgressMediaInfo = ({int id, DateTime day, bool isVideo, DateTime takenAt});
