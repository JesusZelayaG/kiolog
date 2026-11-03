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
      // Los días sin registro también cuentan: no tomar agua es incumplir.
      expect(report.waterTotalDays, 7);
      expect(report.sleepAverage, 8.0);
    });

    test('builds one record per day with what was logged', () async {
      final day = DateTime.utc(2026, 6, 2);
      await db.waterSleepDao.insertWaterLog(DailyWaterLogsCompanion(
        date: Value(day),
        timestamp: Value(day),
        amountMl: const Value(1500),
      ));
      await db.measurementsDao.insertWeightLog(WeightLogsCompanion(
        date: Value(day),
        weightKg: const Value(81.5),
      ));
      for (final minutes in [20, 15]) {
        await db.exerciseDao.insertCardioLog(CardioLogsCompanion(
          date: Value(day),
          cardioType: const Value('Caminar'),
          durationMinutes: Value(minutes),
        ));
      }
      await db.nutritionDao.insertDailyMealLog(DailyMealLogsCompanion(
        date: Value(day),
        mealType: const Value('cena'),
        freeDescription: const Value('Pizza'),
      ));

      final report = await repository.generateReport(
        DateTime.utc(2026, 6, 1),
        DateTime.utc(2026, 6, 3),
      );

      expect(report.days, hasLength(3));
      final logged = report.days[1];
      expect(logged.date, day);
      expect(logged.waterMl, 1500);
      expect(logged.weightKg, 81.5);
      expect(logged.cardioMinutes, 35);
      expect(logged.meals, 1);
      expect(logged.mealsFromPlan, 0);
      expect(report.days.first.weightKg, isNull);
      expect(report.cardioLogs, hasLength(2));
    });

    test('does not count days that have not arrived yet', () async {
      final today = DateTime.now();
      final report = await repository.generateReport(
        today.subtract(const Duration(days: 2)),
        today.add(const Duration(days: 10)),
      );

      expect(report.days, hasLength(3));
    });

    test('meal goal comes from the active plan', () async {
      await db.nutritionDao.insertMealPlan(const MealPlansCompanion(
        name: Value('Plan'),
        dailyMealGoal: Value(5),
      ));

      final report = await repository.generateReport(
        DateTime.utc(2026, 6, 1),
        DateTime.utc(2026, 6, 2),
      );

      expect(report.goals.mealsPerDay, 5);
      expect(report.mealsTotal, 10);
    });
  });

  group('nutritionDetail', () {
    test('is null when no active meal plan exists', () async {
      final data = await repository.generateReport(
        DateTime.utc(2026, 6, 1),
        DateTime.utc(2026, 6, 7),
      );
      expect(data.nutritionDetail, isNull);
    });

    test('contains planName and meal frequencies for logs in range', () async {
      final planId = await db.nutritionDao.insertMealPlan(MealPlansCompanion(
        name: const Value('Plan Semana'),
        periodStart: Value(DateTime.utc(2026, 6, 1)),
      ));
      final optId = await db.nutritionDao.insertMealPlanOption(
        MealPlanOptionsCompanion(
          planId: Value(planId),
          mealType: const Value('desayuno'),
          optionNumber: const Value(1),
          description: const Value('Avena'),
        ),
      );
      // Log the option twice within the range
      await db.nutritionDao.insertDailyMealLog(DailyMealLogsCompanion(
        date: Value(DateTime.utc(2026, 6, 2)),
        mealType: const Value('desayuno'),
        planOptionId: Value(optId),
      ));
      await db.nutritionDao.insertDailyMealLog(DailyMealLogsCompanion(
        date: Value(DateTime.utc(2026, 6, 3)),
        mealType: const Value('desayuno'),
        planOptionId: Value(optId),
      ));
      // Log outside range — must not count
      await db.nutritionDao.insertDailyMealLog(DailyMealLogsCompanion(
        date: Value(DateTime.utc(2026, 6, 20)),
        mealType: const Value('desayuno'),
        planOptionId: Value(optId),
      ));

      final data = await repository.generateReport(
        DateTime.utc(2026, 6, 1),
        DateTime.utc(2026, 6, 7),
      );

      expect(data.nutritionDetail, isNotNull);
      expect(data.nutritionDetail!.planName, 'Plan Semana');
      expect(data.nutritionDetail!.mealFrequencies.length, 1);
      expect(data.nutritionDetail!.mealFrequencies.first.count, 2);
      expect(data.nutritionDetail!.mealFrequencies.first.description, 'Avena');
    });

    test('drops options with count 0 from mealFrequencies', () async {
      final planId = await db.nutritionDao.insertMealPlan(MealPlansCompanion(
        name: const Value('Plan'),
        periodStart: Value(DateTime.utc(2026, 6, 1)),
      ));
      // Option that is never logged
      await db.nutritionDao.insertMealPlanOption(
        MealPlanOptionsCompanion(
          planId: Value(planId),
          mealType: const Value('almuerzo'),
          optionNumber: const Value(1),
          description: const Value('Ensalada'),
        ),
      );

      final data = await repository.generateReport(
        DateTime.utc(2026, 6, 1),
        DateTime.utc(2026, 6, 7),
      );

      expect(data.nutritionDetail!.mealFrequencies, isEmpty);
    });
  });

  group('exerciseDetail', () {
    test('is null when no active exercise plan exists', () async {
      final data = await repository.generateReport(
        DateTime.utc(2026, 6, 1),
        DateTime.utc(2026, 6, 7),
      );
      expect(data.exerciseDetail, isNull);
    });

    test('contains planName, weeklyCompliance, and session counts', () async {
      final planId = await db.exerciseDao.insertExercisePlan(
        const ExercisePlansCompanion(name: Value('Mi Rutina')),
      );
      final routineId = await db.exerciseDao.insertExerciseRoutine(
        ExerciseRoutinesCompanion(
          planId: Value(planId),
          dayNumber: const Value(1),
          routineName: const Value('Pecho'),
        ),
      );
      // 2 completed routine sessions on different days in week 1
      for (final day in [2, 3]) {
        await db.exerciseDao.insertExerciseSession(ExerciseSessionLogsCompanion(
          date: Value(DateTime.utc(2026, 6, day)),
          routineId: Value(routineId),
          gymArrivedAt: Value(DateTime.utc(2026, 6, day, 9)),
          gymLeftAt: Value(DateTime.utc(2026, 6, day, 10)),
        ));
      }
      // 1 cardio log in range
      await db.exerciseDao.insertCardioLog(CardioLogsCompanion(
        date: Value(DateTime.utc(2026, 6, 4)),
        cardioType: const Value('Correr'),
        durationMinutes: const Value(30),
      ));
      // 1 free exercise session in range
      await db.exerciseDao.insertExerciseSession(ExerciseSessionLogsCompanion(
        date: Value(DateTime.utc(2026, 6, 5)),
        gymArrivedAt: Value(DateTime.utc(2026, 6, 5, 8)),
        gymLeftAt: Value(DateTime.utc(2026, 6, 5, 9)),
      ));

      final data = await repository.generateReport(
        DateTime.utc(2026, 6, 1),
        DateTime.utc(2026, 6, 7),
      );

      expect(data.exerciseDetail, isNotNull);
      expect(data.exerciseDetail!.planName, 'Mi Rutina');
      expect(data.exerciseDetail!.totalRoutineSessions, 2);
      expect(data.exerciseDetail!.cardioSessionsCount, 1);
      expect(data.exerciseDetail!.freeExerciseCount, 1);
      expect(data.exerciseDetail!.weeklyCompliance.length, 1);
      expect(data.exerciseDetail!.weeklyCompliance.first.daysDone, 2);
      expect(data.exerciseDetail!.weeklyCompliance.first.weekLabel, 'Sem 1');
    });

    test('weeklyCompliance has 2 entries for a range spanning 2 weeks', () async {
      final planId = await db.exerciseDao.insertExercisePlan(
        const ExercisePlansCompanion(name: Value('Plan')),
      );
      final routineId = await db.exerciseDao.insertExerciseRoutine(
        ExerciseRoutinesCompanion(
          planId: Value(planId),
          dayNumber: const Value(1),
          routineName: const Value('Espalda'),
        ),
      );
      // Week 1 (Sem 1): Thu Jun 4 and Fri Jun 5
      for (final day in [4, 5]) {
        await db.exerciseDao.insertExerciseSession(ExerciseSessionLogsCompanion(
          date: Value(DateTime.utc(2026, 6, day)),
          routineId: Value(routineId),
          gymArrivedAt: Value(DateTime.utc(2026, 6, day, 9)),
          gymLeftAt: Value(DateTime.utc(2026, 6, day, 10)),
        ));
      }
      // Week 2 (Sem 2): Mon Jun 8
      await db.exerciseDao.insertExerciseSession(ExerciseSessionLogsCompanion(
        date: Value(DateTime.utc(2026, 6, 8)),
        routineId: Value(routineId),
        gymArrivedAt: Value(DateTime.utc(2026, 6, 8, 9)),
        gymLeftAt: Value(DateTime.utc(2026, 6, 8, 10)),
      ));

      // Range starts on Wednesday Jun 3 (mid-week), ends Jun 10
      final data = await repository.generateReport(
        DateTime.utc(2026, 6, 3),
        DateTime.utc(2026, 6, 10),
      );

      expect(data.exerciseDetail, isNotNull);
      expect(data.exerciseDetail!.weeklyCompliance.length, 2);
      expect(data.exerciseDetail!.weeklyCompliance[0].weekLabel, 'Sem 1');
      expect(data.exerciseDetail!.weeklyCompliance[0].daysDone, 2);
      expect(data.exerciseDetail!.weeklyCompliance[1].weekLabel, 'Sem 2');
      expect(data.exerciseDetail!.weeklyCompliance[1].daysDone, 1);
    });
  });
}
