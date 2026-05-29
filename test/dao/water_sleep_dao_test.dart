// test/dao/water_sleep_dao_test.dart
import 'package:flutter_test/flutter_test.dart';
import 'package:drift/drift.dart' hide isNotNull;
import 'package:kiolog/core/database/app_database.dart';
import '../helpers/database_helper.dart';

void main() {
  late AppDatabase db;

  setUp(() => db = createTestDatabase());
  tearDown(() async => db.close());

  group('WaterSleepDao - Water', () {
    test('registra ingesta y calcula total diario', () async {
      final date = DateTime.utc(2026, 5, 28);
      await db.waterSleepDao.insertWaterLog(DailyWaterLogsCompanion(
        date: Value(date),
        timestamp: Value(DateTime.utc(2026, 5, 28, 9, 0)),
        amountMl: const Value(1000),
      ));
      await db.waterSleepDao.insertWaterLog(DailyWaterLogsCompanion(
        date: Value(date),
        timestamp: Value(DateTime.utc(2026, 5, 28, 13, 0)),
        amountMl: const Value(1000),
      ));

      final total = await db.waterSleepDao.getDailyWaterTotalMl(date);
      expect(total, 2000);
    });

    test('total es 0 si no hay logs', () async {
      final total =
          await db.waterSleepDao.getDailyWaterTotalMl(DateTime.utc(2026, 5, 28));
      expect(total, 0);
    });
  });

  group('WaterSleepDao - Sleep', () {
    test('registra sueño y recupera por fecha', () async {
      final sleepTime = DateTime.utc(2026, 5, 27, 22, 30);
      final wakeTime = DateTime.utc(2026, 5, 28, 6, 30);
      final hours = wakeTime.difference(sleepTime).inMinutes / 60;

      await db.waterSleepDao.insertSleepLog(SleepLogsCompanion(
        date: Value(DateTime.utc(2026, 5, 28)),
        sleepTime: Value(sleepTime),
        wakeTime: Value(wakeTime),
        hoursCalculated: Value(hours),
      ));

      final log =
          await db.waterSleepDao.getSleepLog(DateTime.utc(2026, 5, 28));
      expect(log?.hoursCalculated, 8.0);
    });

    test('getWeeklySleepLogs retorna logs del rango', () async {
      for (int i = 0; i < 7; i++) {
        final date = DateTime.utc(2026, 5, 22 + i);
        await db.waterSleepDao.insertSleepLog(SleepLogsCompanion(
          date: Value(date),
          sleepTime: Value(date.subtract(const Duration(hours: 8))),
          wakeTime: Value(date),
          hoursCalculated: const Value(8.0),
        ));
      }

      final logs = await db.waterSleepDao.getWeeklySleepLogs(
        DateTime.utc(2026, 5, 22),
        DateTime.utc(2026, 5, 28),
      );
      expect(logs.length, 7);
    });
  });
}
