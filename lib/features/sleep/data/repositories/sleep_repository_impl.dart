import 'package:drift/drift.dart';
import 'package:kiolog/core/dao/water_sleep_dao.dart';
import 'package:kiolog/core/database/app_database.dart';
import '../../domain/repositories/sleep_repository.dart';

class SleepRepositoryImpl implements SleepRepository {
  final WaterSleepDao _waterSleepDao;

  SleepRepositoryImpl(this._waterSleepDao);

  DateTime _dateOnly(DateTime date) =>
      DateTime.utc(date.year, date.month, date.day);

  @override
  Future<SleepLog?> getSleepLogForDate(DateTime date) =>
      _waterSleepDao.getSleepLog(_dateOnly(date));

  @override
  Future<List<SleepLog>> getSleepLogsInRange(DateTime start, DateTime end) =>
      _waterSleepDao.getWeeklySleepLogs(start, end);

  @override
  Future<void> addSleepLog({
    required DateTime date,
    required DateTime sleepTime,
    required DateTime wakeTime,
  }) {
    final diff = wakeTime.difference(sleepTime);
    final hours = diff.inMinutes / 60.0;
    return _waterSleepDao.insertSleepLog(
      SleepLogsCompanion(
        date: Value(_dateOnly(date)),
        sleepTime: Value(sleepTime),
        wakeTime: Value(wakeTime),
        hoursCalculated: Value(hours),
      ),
    );
  }
}
