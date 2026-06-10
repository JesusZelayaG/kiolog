import 'package:kiolog/core/database/app_database.dart';
import '../models/nutrition_weekly_stat.dart';

abstract class NutritionRepository {
  Future<MealPlan?> getActivePlan();
  Future<List<MealPlan>> getAllPlans();
  Future<void> activatePlan(int planId);
  Future<int> createPlan(String name, {required int dailyMealGoal});

  Future<List<MealPlanOption>> getPlanOptions(int planId, String mealType);
  Future<void> addPlanOption({
    required int planId,
    required String mealType,
    required int optionNumber,
    required String description,
  });

  Future<List<DailyMealLog>> getDailyLogs(DateTime date);
  Future<void> logMeal({
    required DateTime date,
    required String mealType,
    required int planOptionId,
  });
  Future<void> logOffPlanMeal({
    required DateTime date,
    required String mealType,
    required String description,
    String? photoPath,
  });
  Future<void> removeMealLog({
    required DateTime date,
    required String mealType,
  });

  Future<List<NutritionWeeklyStat>> getWeeklyAdherence({required int weeksBack});
}
