// lib/core/dao/nutrition_dao.dart
import 'package:drift/drift.dart';
import '../database/app_database.dart';
import '../database/tables/nutrition_tables.dart';

part 'nutrition_dao.g.dart';

@DriftAccessor(tables: [MealPlans, MealPlanOptions, DailyMealLogs])
class NutritionDao extends DatabaseAccessor<AppDatabase>
    with _$NutritionDaoMixin {
  NutritionDao(super.db);

  Future<int> insertMealPlan(MealPlansCompanion plan) =>
      into(mealPlans).insert(plan.copyWith(
        createdAt: plan.createdAt.present
            ? plan.createdAt
            : Value(DateTime.now()),
        isActive: const Value(true),
      ));

  Future<List<MealPlan>> getMealPlans() =>
      (select(mealPlans)..orderBy([(t) => OrderingTerm.desc(t.createdAt)]))
          .get();

  Future<MealPlan?> getActiveMealPlan() =>
      (select(mealPlans)..where((t) => t.isActive.equals(true)))
          .getSingleOrNull();

  Future<void> setActivePlan(int planId) async {
    await (update(mealPlans)).write(const MealPlansCompanion(
      isActive: Value(false),
    ));
    await (update(mealPlans)..where((t) => t.id.equals(planId)))
        .write(const MealPlansCompanion(isActive: Value(true)));
  }

  Future<int> insertMealPlanOption(MealPlanOptionsCompanion option) =>
      into(mealPlanOptions).insert(option);

  Future<List<MealPlanOption>> getMealPlanOptions(
          int planId, String mealType) =>
      (select(mealPlanOptions)
            ..where((t) =>
                t.planId.equals(planId) & t.mealType.equals(mealType))
            ..orderBy([(t) => OrderingTerm.asc(t.optionNumber)]))
          .get();

  Future<int> insertDailyMealLog(DailyMealLogsCompanion log) =>
      into(dailyMealLogs).insert(log);

  Future<List<DailyMealLog>> getDailyMealLogs(DateTime date) {
    final start = DateTime(date.year, date.month, date.day);
    final end = start.add(const Duration(days: 1));
    return (select(dailyMealLogs)
          ..where((t) =>
              t.date.isBiggerOrEqualValue(start) &
              t.date.isSmallerThanValue(end)))
        .get();
  }
}
