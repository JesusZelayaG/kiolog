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
  });
}
