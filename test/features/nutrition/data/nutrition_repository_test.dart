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
      final id = await repository.createPlan('Plan Test');
      expect(id, isPositive);

      final active = await repository.getActivePlan();
      expect(active?.name, 'Plan Test');
    });

    test('activatePlan switches active plan', () async {
      final id1 = await repository.createPlan('Plan A');
      final id2 = await repository.createPlan('Plan B');

      await repository.activatePlan(id2);

      final active = await repository.getActivePlan();
      expect(active?.id, id2);

      final all = await repository.getAllPlans();
      expect(all.firstWhere((p) => p.id == id1).isActive, false);
      expect(all.firstWhere((p) => p.id == id2).isActive, true);
    });

    test('addPlanOption and getPlanOptions', () async {
      final planId = await repository.createPlan('Plan');
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
      final planId = await repository.createPlan('Plan');
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
    });
  });
}
