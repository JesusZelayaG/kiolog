import 'package:flutter_test/flutter_test.dart';
import 'package:kiolog/core/database/app_database.dart';
import 'package:kiolog/features/nutrition/data/repositories/nutrition_repository_impl.dart';
import 'package:drift/drift.dart' hide isNull, isNotNull;

import '../../../helpers/database_helper.dart';

void main() {
  late AppDatabase db;
  late NutritionRepositoryImpl repository;

  setUp(() {
    db = createTestDatabase();
    repository = NutritionRepositoryImpl(db.nutritionDao);
  });

  tearDown(() async => db.close());

  group('NutritionRepositoryImpl', () {
    test('createPlan and getActivePlan', () async {
      final id = await repository.createPlan('Plan Test', dailyMealGoal: 4);
      expect(id, isPositive);

      final active = await repository.getActivePlan();
      expect(active?.name, 'Plan Test');
    });

    test('activatePlan switches active plan', () async {
      final id1 = await repository.createPlan('Plan A', dailyMealGoal: 4);
      final id2 = await repository.createPlan('Plan B', dailyMealGoal: 4);

      await repository.activatePlan(id2);

      final active = await repository.getActivePlan();
      expect(active?.id, id2);

      final all = await repository.getAllPlans();
      expect(all.firstWhere((p) => p.id == id1).isActive, false);
      expect(all.firstWhere((p) => p.id == id2).isActive, true);
    });

    test('addPlanOption and getPlanOptions', () async {
      final planId = await repository.createPlan('Plan', dailyMealGoal: 4);
      await repository.addPlanOption(
        planId: planId,
        mealType: 'breakfast',
        optionNumber: 1,
        description: 'Avena',
      );

      final options = await repository.getPlanOptions(planId, 'breakfast');
      expect(options.length, 1);
      expect(options.first.description, 'Avena');
    });

    test('logMeal and getDailyLogs', () async {
      final planId = await repository.createPlan('Plan', dailyMealGoal: 4);
      final optionId = await db.nutritionDao.insertMealPlanOption(
        MealPlanOptionsCompanion(
          planId: Value(planId),
          mealType: const Value('lunch'),
          optionNumber: const Value(1),
          description: const Value('Pollo'),
        ),
      );

      final date = DateTime(2026, 6, 8);
      await repository.logMeal(
        date: date,
        mealType: 'lunch',
        planOptionId: optionId,
      );

      final logs = await repository.getDailyLogs(date);
      expect(logs.length, 1);
      expect(logs.first.mealType, 'lunch');
      expect(logs.first.planOptionId, optionId);
    });

    test('logOffPlanMeal and getDailyLogs', () async {
      final date = DateTime(2026, 6, 8);
      await repository.logOffPlanMeal(
        date: date,
        mealType: 'dinner',
        description: 'Pizza',
      );

      final logs = await repository.getDailyLogs(date);
      expect(logs.length, 1);
      expect(logs.first.mealType, 'dinner');
      expect(logs.first.planOptionId, isNull);
      expect(logs.first.freeDescription, 'Pizza');
    });

    test('setActivePlan records periodStart/periodEnd on plan switch', () async {
      final id1 = await db.nutritionDao.insertMealPlan(
        const MealPlansCompanion(name: Value('Plan A'), dailyMealGoal: Value(4)),
      );
      final id2 = await db.nutritionDao.insertMealPlan(
        const MealPlansCompanion(name: Value('Plan B'), dailyMealGoal: Value(3)),
      );

      // Activate plan B (closes A's period, opens B's)
      await db.nutritionDao.setActivePlan(id2);

      final plans = await db.nutritionDao.getMealPlans();
      final planA = plans.firstWhere((p) => p.id == id1);
      final planB = plans.firstWhere((p) => p.id == id2);

      expect(planA.periodEnd, isNotNull);
      expect(planB.periodStart, isNotNull);
      expect(planB.periodEnd, isNull);
      expect(planB.isActive, isTrue);
      expect(planA.isActive, isFalse);
    });

    test('setActivePlan on already-active plan is a no-op', () async {
      final id = await db.nutritionDao.insertMealPlan(
        const MealPlansCompanion(name: Value('Plan A'), dailyMealGoal: Value(4)),
      );

      final before = await db.nutritionDao.getMealPlans();
      final startBefore = before.firstWhere((p) => p.id == id).periodStart;

      // Activating same plan again should not change periodStart
      await db.nutritionDao.setActivePlan(id);

      final after = await db.nutritionDao.getMealPlans();
      final startAfter = after.firstWhere((p) => p.id == id).periodStart;

      expect(startAfter, equals(startBefore));
    });

    test('insertMealPlan sets periodStart on new plan', () async {
      final id = await db.nutritionDao.insertMealPlan(
        const MealPlansCompanion(name: Value('Plan'), dailyMealGoal: Value(4)),
      );
      final plans = await db.nutritionDao.getMealPlans();
      final plan = plans.firstWhere((p) => p.id == id);
      expect(plan.periodStart, isNotNull);
      expect(plan.isActive, isTrue);
    });

    test('insertMealPlan inserts second plan as inactive with no periodStart', () async {
      // First plan auto-activates
      await db.nutritionDao.insertMealPlan(
        const MealPlansCompanion(name: Value('Plan A'), dailyMealGoal: Value(4)),
      );
      // Second plan should be inactive, no periodStart
      final id2 = await db.nutritionDao.insertMealPlan(
        const MealPlansCompanion(name: Value('Plan B'), dailyMealGoal: Value(3)),
      );
      final plans = await db.nutritionDao.getMealPlans();
      final planB = plans.firstWhere((p) => p.id == id2);
      expect(planB.isActive, isFalse);
      expect(planB.periodStart, isNull);
    });

    test('getLogsInRange returns only logs within range', () async {
      final planId = await db.nutritionDao.insertMealPlan(
        const MealPlansCompanion(name: Value('Plan'), dailyMealGoal: Value(4)),
      );
      final optId = await db.nutritionDao.insertMealPlanOption(
        MealPlanOptionsCompanion(
          planId: Value(planId),
          mealType: const Value('breakfast'),
          optionNumber: const Value(1),
          description: const Value('Avena'),
        ),
      );

      // Log on June 5 and June 10
      await db.nutritionDao.insertDailyMealLog(DailyMealLogsCompanion(
        date: Value(DateTime.utc(2026, 6, 5)),
        mealType: const Value('breakfast'),
        planOptionId: Value(optId),
      ));
      await db.nutritionDao.insertDailyMealLog(DailyMealLogsCompanion(
        date: Value(DateTime.utc(2026, 6, 10)),
        mealType: const Value('breakfast'),
        planOptionId: Value(optId),
      ));

      // Range [June 3, June 10) — should return only June 5
      final logs = await db.nutritionDao.getLogsInRange(
        DateTime.utc(2026, 6, 3),
        DateTime.utc(2026, 6, 10),
      );
      expect(logs.length, 1);
      expect(logs.first.date.toUtc(), DateTime.utc(2026, 6, 5));

      // Verify the June 3 log is included (inclusive lower bound)
      // Insert a log on June 3 first, re-run the range query
      await db.nutritionDao.insertDailyMealLog(DailyMealLogsCompanion(
        date: Value(DateTime.utc(2026, 6, 3)),
        mealType: const Value('lunch'),
        planOptionId: Value(optId),
      ));
      final logs2 = await db.nutritionDao.getLogsInRange(
        DateTime.utc(2026, 6, 3),
        DateTime.utc(2026, 6, 10),
      );
      expect(logs2.length, 2); // June 3 + June 5
      expect(logs2.any((l) => l.date.toUtc() == DateTime.utc(2026, 6, 3)), isTrue);
    });

    test('getWeeklyAdherence returns correct adherence for current week',
        () async {
      final planId =
          await repository.createPlan('Plan', dailyMealGoal: 2);
      await repository.activatePlan(planId);

      final optId = await db.nutritionDao.insertMealPlanOption(
        MealPlanOptionsCompanion(
          planId: Value(planId),
          mealType: const Value('breakfast'),
          optionNumber: const Value(1),
          description: const Value('Avena'),
        ),
      );

      // Usar DateTime.now() local (no .toUtc()) para que _dateOnly produzca
      // la misma fecha que getWeeklyAdherence usa internamente.
      final today = DateTime.now();
      await repository.logMeal(
        date: today,
        mealType: 'breakfast',
        planOptionId: optId,
      );
      await repository.logOffPlanMeal(
        date: today,
        mealType: 'snack',
        description: 'Pizza',
      );

      final stats = await repository.getWeeklyAdherence(weeksBack: 1);
      expect(stats.length, 1);
      expect(stats.first.mealsLogged, 1);
      expect(stats.first.offPlanMeals, 1);

      // Verificar mealsExpected: días desde inicio del plan activo hasta hoy
      final nowUtc = DateTime.now().toUtc();
      final todayMidnightUtc =
          DateTime.utc(nowUtc.year, nowUtc.month, nowUtc.day);
      final daysToMonday = todayMidnightUtc.weekday - 1;
      final weekStartUtc =
          todayMidnightUtc.subtract(Duration(days: daysToMonday));

      // Obtener el plan para leer su periodStart
      final activePlan = await repository.getActivePlan();
      final ps = activePlan!.periodStart!.toUtc();
      final planStartDay = DateTime.utc(ps.year, ps.month, ps.day);
      final effectiveStart = planStartDay.isAfter(weekStartUtc)
          ? planStartDay
          : weekStartUtc;
      final daysActive =
          todayMidnightUtc.difference(effectiveStart).inDays + 1;
      expect(stats.first.mealsExpected, daysActive * 2);
    });

    test('getWeeklyAdherence returns 0 expected when no plan active that week', () async {
      final stats = await repository.getWeeklyAdherence(weeksBack: 1);
      expect(stats.length, 1);
      expect(stats.first.mealsExpected, 0);
      expect(stats.first.mealsLogged, 0);
      expect(stats.first.adherencePct, 0.0);
    });

    test('getWeeklyAdherence returns stats ordered oldest-first across multiple weeks', () async {
      // Create and activate a plan
      final planId = await repository.createPlan('Plan', dailyMealGoal: 3);
      await repository.activatePlan(planId);

      final stats = await repository.getWeeklyAdherence(weeksBack: 3);
      expect(stats.length, 3);

      // Ordered oldest-first: stats[0].weekStart < stats[1].weekStart < stats[2].weekStart
      expect(stats[0].weekStart.isBefore(stats[1].weekStart), isTrue);
      expect(stats[1].weekStart.isBefore(stats[2].weekStart), isTrue);

      // stats[2] is current week (its weekStart is this week's Monday)
      final now = DateTime.now().toUtc();
      final today = DateTime.utc(now.year, now.month, now.day);
      final daysToMonday = today.weekday - 1;
      final currentMonday = today.subtract(Duration(days: daysToMonday));
      expect(stats[2].weekStart, currentMonday);
    });

    test('getWeeklyAdherence: week with active plan but no logs has mealsExpected > 0, mealsLogged == 0', () async {
      final planId = await repository.createPlan('Plan', dailyMealGoal: 2);
      await repository.activatePlan(planId);

      // No meals logged — plan is active but nothing was eaten
      final stats = await repository.getWeeklyAdherence(weeksBack: 1);
      expect(stats.length, 1);
      expect(stats.first.mealsExpected, greaterThan(0));
      expect(stats.first.mealsLogged, 0);
      expect(stats.first.offPlanMeals, 0);
      expect(stats.first.adherencePct, 0.0);
    });

    test('getWeeklyAdherence: week with no active plan has all zeros', () async {
      // No plans created at all
      final stats = await repository.getWeeklyAdherence(weeksBack: 1);
      expect(stats.length, 1);
      expect(stats.first.mealsExpected, 0);
      expect(stats.first.mealsLogged, 0);
      expect(stats.first.offPlanMeals, 0);
      expect(stats.first.adherencePct, 0.0);
    });

    test('getWeeklyAdherence with weeksBack: 8 returns 8 entries', () async {
      final stats = await repository.getWeeklyAdherence(weeksBack: 8);
      expect(stats.length, 8);
      // All zeros since no plans
      expect(stats.every((s) => s.mealsExpected == 0), isTrue);
    });

    test('getOptionFrequency returns frequency stats for plan', () async {
      final planId = await repository.createPlan('Plan', dailyMealGoal: 2);
      await repository.activatePlan(planId);

      await repository.addPlanOption(
        planId: planId,
        mealType: 'Desayuno',
        optionNumber: 1,
        description: 'Avena',
      );

      // Obtener el id de la opción recién creada
      final opts = await repository.getPlanOptions(planId, 'Desayuno');
      final optId = opts.first.id;

      final today = DateTime.now();
      await repository.logMeal(
        date: today,
        mealType: 'Desayuno',
        planOptionId: optId,
      );
      await repository.logMeal(
        date: today,
        mealType: 'Desayuno',
        planOptionId: optId,
      );

      final result = await repository.getOptionFrequency(planId);
      expect(result.length, 1);
      expect(result.first.description, 'Avena');
      expect(result.first.count, 2);
    });
  });
}
