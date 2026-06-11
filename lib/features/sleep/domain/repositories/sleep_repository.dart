import 'package:kiolog/core/database/app_database.dart';

abstract class SleepRepository {
  Future<List<SleepLog>> getSleepLogsForDate(DateTime date);
  Future<List<SleepLog>> getSleepLogsInRange(DateTime start, DateTime end);
  Future<void> addSleepLog({
    required DateTime date,
    required DateTime sleepTime,
    required DateTime wakeTime,
    required String type,
  });
  Future<void> deleteSleepLog(int id);
}
