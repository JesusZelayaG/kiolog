import 'package:kiolog/core/database/app_database.dart';

abstract class SleepRepository {
  Future<SleepLog?> getSleepLogForDate(DateTime date);
  Future<List<SleepLog>> getSleepLogsInRange(DateTime start, DateTime end);
  Future<void> addSleepLog({
    required DateTime date,
    required DateTime sleepTime,
    required DateTime wakeTime,
  });
}
