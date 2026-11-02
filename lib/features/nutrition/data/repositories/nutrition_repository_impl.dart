import 'package:kiolog/features/nutrition/domain/models/plan_option_draft.dart';
import 'package:drift/drift.dart';
import 'package:kiolog/core/dao/nutrition_dao.dart';
import 'package:kiolog/core/database/app_database.dart';
import '../../domain/models/nutrition_weekly_stat.dart';
import '../../domain/models/option_frequency_stat.dart';
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
  Future<int> createPlan(String name, {required int dailyMealGoal}) =>
      _nutritionDao.insertMealPlan(
        MealPlansCompanion(
          name: Value(name),
          dailyMealGoal: Value(dailyMealGoal),
        ),
      );

  @override
  Future<List<MealPlanOption>> getPlanOptions(
    int planId,
    String mealType,
  ) =>
      _nutritionDao.getMealPlanOptions(planId, mealType);

  @override
  Future<List<MealPlanOption>> getAllPlanOptions(int planId) =>
      _nutritionDao.getAllPlanOptions(planId);

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
    String? description,
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

  @override
  Future<void> removeMealLog({
    required DateTime date,
    required String mealType,
  }) =>
      _nutritionDao.deleteDailyMealLog(_dateOnly(date), mealType);

  @override
  Future<List<NutritionWeeklyStat>> getWeeklyAdherence(
      {required int weeksBack}) async {
    assert(weeksBack >= 1, 'weeksBack must be at least 1');
    final now = DateTime.now().toUtc();
    final todayMidnight = DateTime.utc(now.year, now.month, now.day);
    final daysToMonday = todayMidnight.weekday - 1; // Monday=1
    final currentWeekMonday =
        todayMidnight.subtract(Duration(days: daysToMonday));

    final rangeStart =
        currentWeekMonday.subtract(Duration(days: 7 * (weeksBack - 1)));
    // rangeEnd is exclusive upper bound — tomorrow midnight includes all of today's logs.
    final rangeEnd = todayMidnight.add(const Duration(days: 1));

    final allPlans = await _nutritionDao.getMealPlans();
    final allLogs = await _nutritionDao.getLogsInRange(rangeStart, rangeEnd);

    final result = <NutritionWeeklyStat>[];

    for (int w = weeksBack - 1; w >= 0; w--) {
      final weekStart =
          currentWeekMonday.subtract(Duration(days: 7 * w));
      int mealsLogged = 0;
      int mealsExpected = 0;
      int offPlanMeals = 0;

      for (int d = 0; d < 7; d++) {
        final day = weekStart.add(Duration(days: d));
        if (day.isAfter(todayMidnight)) break;

        // Find plan active on this day
        MealPlan? activePlan;
        for (final plan in allPlans) {
          final start = plan.periodStart;
          final end = plan.periodEnd;
          if (start == null) continue;
          final startUtc = start.toUtc();
          final startDay = DateTime.utc(startUtc.year, startUtc.month, startUtc.day);
          if (startDay.isAfter(day)) continue;
          if (end != null) {
            final endUtc = end.toUtc();
            final endDay = DateTime.utc(endUtc.year, endUtc.month, endUtc.day);
            // On the day of a plan switch, the new plan claims the full day's goal.
            if (!endDay.isAfter(day)) continue;
          }
          activePlan = plan;
          break;
        }

        if (activePlan == null) continue;

        mealsExpected += activePlan.dailyMealGoal;

        for (final log in allLogs) {
          final logUtc = log.date.toUtc();
          final logDay =
              DateTime.utc(logUtc.year, logUtc.month, logUtc.day);
          if (logDay != day) continue;
          if (log.planOptionId != null) {
            mealsLogged++;
          } else {
            offPlanMeals++;
          }
        }
      }

      result.add(NutritionWeeklyStat(
        weekStart: weekStart,
        mealsLogged: mealsLogged,
        mealsExpected: mealsExpected,
        offPlanMeals: offPlanMeals,
      ));
    }

    return result;
  }

  @override
  Future<void> updatePlan({
    required int planId,
    required String name,
    required int dailyMealGoal,
    required List<PlanOptionDraft> options,
  }) =>
      _nutritionDao.updateMealPlan(
        planId: planId,
        name: name,
        dailyMealGoal: dailyMealGoal,
        options: options,
      );

  @override
  Future<void> deletePlan(int planId) => _nutritionDao.deleteMealPlan(planId);

  @override
  Future<({int logged, int expected})> getPlanMealCounts(MealPlan plan) async {
    final start = plan.periodStart;
    if (start == null) return (logged: 0, expected: 0);
    DateTime day(DateTime date) {
      final utc = date.toUtc();
      return DateTime.utc(utc.year, utc.month, utc.day);
    }

    // As in the weekly stats, the plan that starts on a day owns that day.
    final tomorrow = day(DateTime.now()).add(const Duration(days: 1));
    final first = day(start);
    final end = plan.periodEnd == null ? tomorrow : day(plan.periodEnd!);
    final logs = await _nutritionDao.getLogsInRange(first, end);
    return (
      logged: logs.where((log) => log.planOptionId != null).length,
      expected: end.difference(first).inDays * plan.dailyMealGoal,
    );
  }

  @override
  Future<List<OptionFrequencyStat>> getOptionFrequency(int planId) =>
      _nutritionDao.getOptionFrequenciesForPlan(planId);
}
