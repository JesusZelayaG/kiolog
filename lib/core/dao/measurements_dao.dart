import 'package:drift/drift.dart';
import '../database/app_database.dart';
import '../database/tables/measurements_tables.dart';

part 'measurements_dao.g.dart';

@DriftAccessor(tables: [WeightLogs, Measurements])
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

  Future<Measurement?> getLatestMeasurement() =>
      (select(measurements)
            ..orderBy([(t) => OrderingTerm.desc(t.date)])
            ..limit(1))
          .getSingleOrNull();
}
