import '../models/plan_option_draft.dart';
import 'package:kiolog/core/database/app_database.dart';
import '../models/nutrition_weekly_stat.dart';
import '../models/option_frequency_stat.dart';

abstract class NutritionRepository {
  Future<MealPlan?> getActivePlan();
  Future<List<MealPlan>> getAllPlans();
  Future<void> activatePlan(int planId);
  Future<int> createPlan(String name, {required int dailyMealGoal});
  Future<void> updatePlan({
    required int planId,
    required String name,
    required int dailyMealGoal,
    required List<PlanOptionDraft> options,
  });
  Future<void> deletePlan(int planId);

  /// Comidas del plan registradas y esperadas durante su periodo.
  Future<({int logged, int expected})> getPlanMealCounts(MealPlan plan);

  Future<List<MealPlanOption>> getPlanOptions(int planId, String mealType);
  Future<List<MealPlanOption>> getAllPlanOptions(int planId);
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
    String? description,
    String? photoPath,
  });
  Future<void> removeMealLog({
    required DateTime date,
    required String mealType,
  });

  Future<List<NutritionWeeklyStat>> getWeeklyAdherence({required int weeksBack});

  Future<List<OptionFrequencyStat>> getOptionFrequency(int planId);
}
