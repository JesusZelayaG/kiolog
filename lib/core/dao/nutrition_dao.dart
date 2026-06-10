// lib/core/dao/nutrition_dao.dart
import 'package:drift/drift.dart';
import '../database/app_database.dart';
import '../database/tables/nutrition_tables.dart';

part 'nutrition_dao.g.dart';

@DriftAccessor(tables: [MealPlans, MealPlanOptions, DailyMealLogs])
class NutritionDao extends DatabaseAccessor<AppDatabase>
    with _$NutritionDaoMixin {
  NutritionDao(super.db);

  Future<int> insertMealPlan(MealPlansCompanion plan) async {
    return db.transaction(() async {
      final now = DateTime.now().toUtc();
      final hasActive = await (select(mealPlans)
                ..where((t) => t.isActive.equals(true)))
              .getSingleOrNull() !=
          null;
      return into(mealPlans).insert(plan.copyWith(
        createdAt: plan.createdAt.present ? plan.createdAt : Value(now),
        isActive: Value(!hasActive),
        periodStart: hasActive ? const Value(null) : Value(now),
      ));
    });
  }

  Future<List<MealPlan>> getMealPlans() =>
      (select(mealPlans)..orderBy([(t) => OrderingTerm.desc(t.createdAt)]))
          .get();

  Future<MealPlan?> getActiveMealPlan() =>
      (select(mealPlans)..where((t) => t.isActive.equals(true)))
          .getSingleOrNull();

  Future<void> setActivePlan(int planId) async {
    await db.transaction(() async {
      final now = DateTime.now().toUtc();
      final plan = await (select(mealPlans)..where((t) => t.id.equals(planId)))
          .getSingleOrNull();
      if (plan == null) throw ArgumentError('Plan $planId not found');
      if (plan.isActive) return; // already active, nothing to do

      // Close period on currently active plan
      await (update(mealPlans)..where((t) => t.isActive.equals(true)))
          .write(MealPlansCompanion(
            isActive: const Value(false),
            periodEnd: Value(now),
          ));

      // Open period on new plan
      await (update(mealPlans)..where((t) => t.id.equals(planId)))
          .write(MealPlansCompanion(
            isActive: const Value(true),
            periodStart: Value(now),
            periodEnd: const Value(null),
          ));
    });
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

  Future<void> deleteDailyMealLog(DateTime date, String mealType) {
    final start = DateTime.utc(date.year, date.month, date.day);
    final end = start.add(const Duration(days: 1));
    return (delete(dailyMealLogs)
          ..where((t) =>
              t.date.isBiggerOrEqualValue(start) &
              t.date.isSmallerThanValue(end) &
              t.mealType.equals(mealType)))
        .go();
  }

  Future<List<DailyMealLog>> getDailyMealLogs(DateTime date) {
    // Normalize to UTC midnight to ensure consistent day boundaries.
    // Drift stores DateTimes as milliseconds since epoch (UTC).
    final start = DateTime.utc(date.year, date.month, date.day);
    final end = start.add(const Duration(days: 1));
    return (select(dailyMealLogs)
          ..where((t) =>
              t.date.isBiggerOrEqualValue(start) &
              t.date.isSmallerThanValue(end)))
        .get();
  }

  Future<List<DailyMealLog>> getLogsInRange(DateTime from, DateTime to) {
    final f = DateTime.utc(from.year, from.month, from.day);
    final t = DateTime.utc(to.year, to.month, to.day);
    return (select(dailyMealLogs)
          ..where((r) =>
              r.date.isBiggerOrEqualValue(f) &
              r.date.isSmallerThanValue(t)))
        .get();
  }
}
