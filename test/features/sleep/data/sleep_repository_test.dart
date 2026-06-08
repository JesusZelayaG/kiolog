import 'package:flutter_test/flutter_test.dart';
import 'package:kiolog/core/dao/water_sleep_dao.dart';
import 'package:kiolog/core/database/app_database.dart';
import 'package:kiolog/features/sleep/data/repositories/sleep_repository_impl.dart';
import 'package:drift/drift.dart' hide isNull, isNotNull;

import '../../../helpers/database_helper.dart';

void main() {
  late AppDatabase db;
  late SleepRepositoryImpl repository;

  setUp(() {
    db = createTestDatabase();
    repository = SleepRepositoryImpl(db.waterSleepDao);
  });

  tearDown(() async => db.close());

  group('SleepRepositoryImpl', () {
    test('getSleepLogForDate returns null when empty', () async {
      final log = await repository.getSleepLogForDate(DateTime(2026, 6, 8));
      expect(log, isNull);
    });

    test('addSleepLog and retrieve it', () async {
      final date = DateTime(2026, 6, 8);
      final sleepTime = DateTime(2026, 6, 7, 22, 30);
      final wakeTime = DateTime(2026, 6, 8, 6, 30);

      await repository.addSleepLog(
        date: date,
        sleepTime: sleepTime,
        wakeTime: wakeTime,
      );

      final log = await repository.getSleepLogForDate(date);
      expect(log, isNotNull);
      expect(log!.hoursCalculated, 8.0);
    });

    test('getSleepLogsInRange returns logs in range', () async {
      for (int i = 0; i < 3; i++) {
        final date = DateTime(2026, 6, 6 + i);
        await db.waterSleepDao.insertSleepLog(SleepLogsCompanion(
          date: Value(date),
          sleepTime: Value(date.subtract(const Duration(hours: 8))),
          wakeTime: Value(date),
          hoursCalculated: const Value(8.0),
        ));
      }

      final logs = await repository.getSleepLogsInRange(
        DateTime(2026, 6, 6),
        DateTime(2026, 6, 8),
      );
      expect(logs.length, 3);
    });
  });
}
