import 'package:drift/drift.dart';
import '../database/app_database.dart';
import '../database/tables/water_sleep_tables.dart';

part 'water_sleep_dao.g.dart';

@DriftAccessor(tables: [DailyWaterLogs, SleepLogs])
class WaterSleepDao extends DatabaseAccessor<AppDatabase>
    with _$WaterSleepDaoMixin {
  WaterSleepDao(super.db);

  Future<void> insertWaterLog(DailyWaterLogsCompanion log) =>
      into(dailyWaterLogs).insert(log);

  Future<List<DailyWaterLog>> getDailyWaterLogs(DateTime date) {
    final start = DateTime.utc(date.year, date.month, date.day);
    final end = start.add(const Duration(days: 1));
    return (select(dailyWaterLogs)
          ..where((t) =>
              t.date.isBiggerOrEqualValue(start) &
              t.date.isSmallerThanValue(end)))
        .get();
  }

  Future<void> deleteWaterLog(int id) =>
      (delete(dailyWaterLogs)..where((t) => t.id.equals(id))).go();

  Future<int> getDailyWaterTotalMl(DateTime date) async {
    final logs = await getDailyWaterLogs(date);
    return logs.fold<int>(0, (sum, log) => sum + log.amountMl);
  }

  Future<void> insertSleepLog(SleepLogsCompanion log) =>
      into(sleepLogs).insert(log);

  Future<List<SleepLog>> getSleepLogsForDate(DateTime date) {
    final start = DateTime.utc(date.year, date.month, date.day);
    final end = start.add(const Duration(days: 1));
    return (select(sleepLogs)
          ..where((t) =>
              t.date.isBiggerOrEqualValue(start) &
              t.date.isSmallerThanValue(end))
          ..orderBy([(t) => OrderingTerm.asc(t.sleepTime)]))
        .get();
  }

  Future<void> deleteSleepLog(int id) =>
      (delete(sleepLogs)..where((t) => t.id.equals(id))).go();

  Future<List<SleepLog>> getWeeklySleepLogs(
      DateTime startDate, DateTime endDate) {
    final start = DateTime.utc(startDate.year, startDate.month, startDate.day);
    final end = DateTime.utc(endDate.year, endDate.month, endDate.day)
        .add(const Duration(days: 1));
    return (select(sleepLogs)
          ..where((t) =>
              t.date.isBiggerOrEqualValue(start) &
              t.date.isSmallerThanValue(end))
          ..orderBy([(t) => OrderingTerm.asc(t.date)]))
        .get();
  }
}
