import 'package:flutter_test/flutter_test.dart';
import 'package:kiolog/core/database/app_database.dart';
import 'package:kiolog/features/history/data/repositories/history_repository_impl.dart';
import 'package:drift/drift.dart' hide isNull, isNotNull;

import '../../../helpers/database_helper.dart';

void main() {
  late AppDatabase db;
  late HistoryRepositoryImpl repository;

  setUp(() {
    db = createTestDatabase();
    repository = HistoryRepositoryImpl(
      db.waterSleepDao,
      db.nutritionDao,
      db.exerciseDao,
    );
  });

  tearDown(() async => db.close());

  group('HistoryRepositoryImpl', () {
    test('getMonthSummary returns correct day summaries', () async {
      final date = DateTime(2026, 6, 8);

      // Add water
      await db.waterSleepDao.insertWaterLog(DailyWaterLogsCompanion(
        date: Value(date),
        timestamp: Value(date),
        amountMl: const Value(1000),
      ));

      // Add sleep
      await db.waterSleepDao.insertSleepLog(SleepLogsCompanion(
        date: Value(date),
        sleepTime: Value(date.subtract(const Duration(hours: 8))),
        wakeTime: Value(date),
        hoursCalculated: const Value(8.0),
      ));

      final summary = await repository.getMonthSummary(date);
      final day8 = summary.firstWhere((d) => d.date.day == 8);

      expect(day8.hasWater, true);
      expect(day8.hasSleep, true);
      expect(day8.hasMeals, false);
      expect(day8.hasExercise, false);
      expect(day8.completedCount, 2);
    });
  });
}
