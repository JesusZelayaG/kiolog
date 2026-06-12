// test/dao/nutrition_dao_test.dart
import 'package:flutter_test/flutter_test.dart';
import 'package:drift/drift.dart';
import 'package:kiolog/core/database/app_database.dart';
import '../helpers/database_helper.dart';

void main() {
  late AppDatabase db;

  setUp(() => db = createTestDatabase());
  tearDown(() async => db.close());

  group('NutritionDao - MealPlans', () {
    test('inserta y recupera un plan', () async {
      final id = await db.nutritionDao.insertMealPlan(
        MealPlansCompanion(
          name: const Value('Plan Enero'),
          createdAt: Value(DateTime(2026, 1, 1)),
        ),
      );

      final plans = await db.nutritionDao.getMealPlans();
      expect(plans.length, 1);
      expect(plans.first.id, id);
      expect(plans.first.name, 'Plan Enero');
      expect(plans.first.isActive, true);
    });

    test('setActivePlan desactiva los planes anteriores', () async {
      final id1 = await db.nutritionDao.insertMealPlan(
        MealPlansCompanion(
          name: const Value('Plan A'),
          createdAt: Value(DateTime(2026, 1, 1)),
        ),
      );
      final id2 = await db.nutritionDao.insertMealPlan(
        MealPlansCompanion(
          name: const Value('Plan B'),
          createdAt: Value(DateTime(2026, 2, 1)),
        ),
      );

      await db.nutritionDao.setActivePlan(id2);

      final plans = await db.nutritionDao.getMealPlans();
      final planA = plans.firstWhere((p) => p.id == id1);
      final planB = plans.firstWhere((p) => p.id == id2);
      expect(planA.isActive, false);
      expect(planB.isActive, true);
    });

    test('setActivePlan lanza ArgumentError si el plan no existe', () async {
      expect(
        () => db.nutritionDao.setActivePlan(999),
        throwsA(isA<ArgumentError>()),
      );
    });
  });

  group('NutritionDao - MealPlanOptions', () {
    test('inserta y recupera opciones del plan', () async {
      final planId = await db.nutritionDao.insertMealPlan(
        MealPlansCompanion(
          name: const Value('Plan Test'),
          createdAt: Value(DateTime(2026, 1, 1)),
        ),
      );

      await db.nutritionDao.insertMealPlanOption(
        MealPlanOptionsCompanion(
          planId: Value(planId),
          mealType: const Value('breakfast'),
          optionNumber: const Value(1),
          description: const Value('Avena con frutas'),
        ),
      );

      final options =
          await db.nutritionDao.getMealPlanOptions(planId, 'breakfast');
      expect(options.length, 1);
      expect(options.first.description, 'Avena con frutas');
    });
  });

  group('NutritionDao - DailyMealLogs', () {
    test('registra comida del plan', () async {
      final planId = await db.nutritionDao.insertMealPlan(
        MealPlansCompanion(
          name: const Value('Plan'),
          createdAt: Value(DateTime(2026, 1, 1)),
        ),
      );
      final optionId = await db.nutritionDao.insertMealPlanOption(
        MealPlanOptionsCompanion(
          planId: Value(planId),
          mealType: const Value('lunch'),
          optionNumber: const Value(2),
          description: const Value('Pollo con arroz'),
        ),
      );

      await db.nutritionDao.insertDailyMealLog(
        DailyMealLogsCompanion(
          date: Value(DateTime(2026, 5, 28)),
          mealType: const Value('lunch'),
          planOptionId: Value(optionId),
        ),
      );

      final logs =
          await db.nutritionDao.getDailyMealLogs(DateTime(2026, 5, 28));
      expect(logs.length, 1);
      expect(logs.first.planOptionId, optionId);
      expect(logs.first.freeDescription, null);
    });

    test('registra comida fuera del plan con descripción', () async {
      await db.nutritionDao.insertDailyMealLog(
        DailyMealLogsCompanion(
          date: Value(DateTime(2026, 5, 28)),
          mealType: const Value('dinner'),
          freeDescription: const Value('Pizza con amigos'),
        ),
      );

      final logs =
          await db.nutritionDao.getDailyMealLogs(DateTime(2026, 5, 28));
      expect(logs.first.planOptionId, null);
      expect(logs.first.freeDescription, 'Pizza con amigos');
    });
  });

  group('NutritionDao - getOptionFrequenciesForPlan', () {
    test('returns empty when plan has no options', () async {
      final planId = await db.nutritionDao.insertMealPlan(
        MealPlansCompanion(
          name: const Value('Plan'),
          createdAt: Value(DateTime.utc(2026, 6, 1)),
          periodStart: Value(DateTime.utc(2026, 6, 1)),
        ),
      );
      final result =
          await db.nutritionDao.getOptionFrequenciesForPlan(planId);
      expect(result, isEmpty);
    });

    test('returns count 0 for option with no logs', () async {
      final planId = await db.nutritionDao.insertMealPlan(
        MealPlansCompanion(
          name: const Value('Plan'),
          createdAt: Value(DateTime.utc(2026, 6, 1)),
          periodStart: Value(DateTime.utc(2026, 6, 1)),
        ),
      );
      await db.nutritionDao.insertMealPlanOption(
        MealPlanOptionsCompanion(
          planId: Value(planId),
          mealType: const Value('Desayuno'),
          optionNumber: const Value(1),
          description: const Value('Avena'),
        ),
      );
      final result =
          await db.nutritionDao.getOptionFrequenciesForPlan(planId);
      expect(result.length, 1);
      expect(result.first.count, 0);
      expect(result.first.description, 'Avena');
    });

    test('counts logs correctly within plan period', () async {
      final planId = await db.nutritionDao.insertMealPlan(
        MealPlansCompanion(
          name: const Value('Plan'),
          createdAt: Value(DateTime.utc(2026, 6, 1)),
          periodStart: Value(DateTime.utc(2026, 6, 1)),
        ),
      );
      final optId = await db.nutritionDao.insertMealPlanOption(
        MealPlanOptionsCompanion(
          planId: Value(planId),
          mealType: const Value('Desayuno'),
          optionNumber: const Value(1),
          description: const Value('Avena'),
        ),
      );
      // Log 3 veces la misma opción
      for (var i = 0; i < 3; i++) {
        await db.nutritionDao.insertDailyMealLog(
          DailyMealLogsCompanion(
            date: Value(DateTime.utc(2026, 6, i + 1)),
            mealType: const Value('Desayuno'),
            planOptionId: Value(optId),
          ),
        );
      }
      final result =
          await db.nutritionDao.getOptionFrequenciesForPlan(planId);
      expect(result.first.count, 3);
    });

    test('does not count logs outside plan period', () async {
      final planId = await db.nutritionDao.insertMealPlan(
        MealPlansCompanion(
          name: const Value('Plan'),
          createdAt: Value(DateTime.utc(2026, 6, 1)),
          periodStart: Value(DateTime.utc(2026, 6, 1)),
          periodEnd: Value(DateTime.utc(2026, 6, 10)), // terminó el 10
        ),
      );
      final optId = await db.nutritionDao.insertMealPlanOption(
        MealPlanOptionsCompanion(
          planId: Value(planId),
          mealType: const Value('Desayuno'),
          optionNumber: const Value(1),
          description: const Value('Avena'),
        ),
      );
      // Dentro del período
      await db.nutritionDao.insertDailyMealLog(
        DailyMealLogsCompanion(
          date: Value(DateTime.utc(2026, 6, 5)),
          mealType: const Value('Desayuno'),
          planOptionId: Value(optId),
        ),
      );
      // Fuera del período (después del 10)
      await db.nutritionDao.insertDailyMealLog(
        DailyMealLogsCompanion(
          date: Value(DateTime.utc(2026, 6, 15)),
          mealType: const Value('Desayuno'),
          planOptionId: Value(optId),
        ),
      );
      final result =
          await db.nutritionDao.getOptionFrequenciesForPlan(planId);
      expect(result.first.count, 1); // solo el log del día 5
    });
  });

  group('NutritionDao - getMealPlanOptionsByIds', () {
    test('returns empty list when ids is empty', () async {
      final result = await db.nutritionDao.getMealPlanOptionsByIds([]);
      expect(result, isEmpty);
    });

    test('returns only options matching the given ids', () async {
      final planId = await db.nutritionDao.insertMealPlan(
        MealPlansCompanion(
          name: const Value('Plan Test'),
          createdAt: Value(DateTime(2026, 1, 1)),
        ),
      );
      final opt1 = await db.nutritionDao.insertMealPlanOption(
        MealPlanOptionsCompanion(
          planId: Value(planId),
          mealType: const Value('breakfast'),
          optionNumber: const Value(1),
          description: const Value('Avena'),
        ),
      );
      final opt2 = await db.nutritionDao.insertMealPlanOption(
        MealPlanOptionsCompanion(
          planId: Value(planId),
          mealType: const Value('lunch'),
          optionNumber: const Value(1),
          description: const Value('Arroz con pollo'),
        ),
      );
      await db.nutritionDao.insertMealPlanOption(
        MealPlanOptionsCompanion(
          planId: Value(planId),
          mealType: const Value('dinner'),
          optionNumber: const Value(1),
          description: const Value('Ensalada'),
        ),
      );

      final result = await db.nutritionDao.getMealPlanOptionsByIds([opt1, opt2]);
      expect(result.length, 2);
      expect(result.map((o) => o.id), containsAll([opt1, opt2]));
    });
  });
}
