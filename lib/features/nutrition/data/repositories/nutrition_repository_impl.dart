import 'package:drift/drift.dart';
import 'package:kiolog/core/dao/nutrition_dao.dart';
import 'package:kiolog/core/database/app_database.dart';
import '../../domain/repositories/nutrition_repository.dart';

class NutritionRepositoryImpl implements NutritionRepository {
  final NutritionDao _nutritionDao;

  NutritionRepositoryImpl(this._nutritionDao);

  DateTime _dateOnly(DateTime date) =>
      DateTime.utc(date.year, date.month, date.day);

  @override
  Future<MealPlan?> getActivePlan() => _nutritionDao.getActiveMealPlan();

  @override
  Future<List<MealPlan>> getAllPlans() => _nutritionDao.getMealPlans();

  @override
  Future<void> activatePlan(int planId) => _nutritionDao.setActivePlan(planId);

  @override
  Future<int> createPlan(String name) => _nutritionDao.insertMealPlan(
        MealPlansCompanion(name: Value(name)),
      );

  @override
  Future<List<MealPlanOption>> getPlanOptions(
    int planId,
    String mealType,
  ) =>
      _nutritionDao.getMealPlanOptions(planId, mealType);

  @override
  Future<void> addPlanOption({
    required int planId,
    required String mealType,
    required int optionNumber,
    required String description,
  }) =>
      _nutritionDao.insertMealPlanOption(
        MealPlanOptionsCompanion(
          planId: Value(planId),
          mealType: Value(mealType),
          optionNumber: Value(optionNumber),
          description: Value(description),
        ),
      );

  @override
  Future<List<DailyMealLog>> getDailyLogs(DateTime date) =>
      _nutritionDao.getDailyMealLogs(_dateOnly(date));

  @override
  Future<void> logMeal({
    required DateTime date,
    required String mealType,
    required int planOptionId,
  }) =>
      _nutritionDao.insertDailyMealLog(
        DailyMealLogsCompanion(
          date: Value(_dateOnly(date)),
          mealType: Value(mealType),
          planOptionId: Value(planOptionId),
        ),
      );

  @override
  Future<void> logOffPlanMeal({
    required DateTime date,
    required String mealType,
    required String description,
    String? photoPath,
  }) =>
      _nutritionDao.insertDailyMealLog(
        DailyMealLogsCompanion(
          date: Value(_dateOnly(date)),
          mealType: Value(mealType),
          freeDescription: Value(description),
          photoPath: Value(photoPath),
        ),
      );
}
