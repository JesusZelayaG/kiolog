import 'package:flutter_test/flutter_test.dart';
import 'package:kiolog/core/database/app_database.dart';
import 'package:kiolog/features/reports/data/repositories/report_repository_impl.dart';
import 'package:drift/drift.dart' hide isNull, isNotNull;

import '../../../helpers/database_helper.dart';

void main() {
  late AppDatabase db;
  late ReportRepositoryImpl repository;

  setUp(() {
    db = createTestDatabase();
    repository = ReportRepositoryImpl(
      db.waterSleepDao,
      db.nutritionDao,
      db.exerciseDao,
      db.measurementsDao,
      db.configDao,
    );
  });

  tearDown(() async => db.close());

  group('ReportRepositoryImpl', () {
    test('generateReport returns aggregated data', () async {
      final start = DateTime(2026, 6, 1);
      final end = DateTime(2026, 6, 7);

      // Water
      await db.waterSleepDao.insertWaterLog(DailyWaterLogsCompanion(
        date: Value(start),
        timestamp: Value(start),
        amountMl: const Value(3000),
      ));

      // Sleep
      await db.waterSleepDao.insertSleepLog(SleepLogsCompanion(
        date: Value(start),
        sleepTime: Value(start.subtract(const Duration(hours: 8))),
        wakeTime: Value(start),
        hoursCalculated: const Value(8.0),
      ));

      final report = await repository.generateReport(start, end);

      expect(report.waterGoalDays, 1);
      expect(report.waterTotalDays, 1);
      expect(report.sleepAverage, 8.0);
    });
  });
}
