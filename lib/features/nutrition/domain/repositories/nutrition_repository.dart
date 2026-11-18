import 'package:kiolog/core/dao/nutrition_dao.dart';
import 'dart:typed_data';

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
    int? photoId,
    String? mealIcon,
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

  /// Guarda una foto de comida ya comprimida y devuelve su id.
  Future<int> savePhoto(Uint8List bytes);

  Future<Uint8List?> getPhoto(int photoId);

  /// La foto de referencia de un plato del plan; null la quita.
  Future<void> setOptionPhoto(int optionId, Uint8List? bytes);

  /// La foto de lo que se comió en un registro; null la quita.
  Future<void> setLogPhoto(int logId, Uint8List? bytes);

  /// El álbum de comidas: los registros con foto, del más reciente al más antiguo.
  Future<List<MealPhotoEntry>> getMealPhotoEntries();

  /// El ícono de un tiempo de comida del plan.
  Future<void> setMealIcon(int planId, String mealType, String icon);
}
