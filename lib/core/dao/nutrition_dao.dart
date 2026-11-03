// lib/core/dao/nutrition_dao.dart
import 'package:drift/drift.dart';
import 'package:kiolog/features/nutrition/domain/models/option_frequency_stat.dart';
import 'package:kiolog/features/nutrition/domain/models/plan_option_draft.dart';
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
      // A new plan replaces the current one, usually after a consultation.
      await (update(mealPlans)..where((t) => t.isActive.equals(true)))
          .write(MealPlansCompanion(
        isActive: const Value(false),
        periodEnd: Value(now),
      ));
      return into(mealPlans).insert(plan.copyWith(
        createdAt: plan.createdAt.present ? plan.createdAt : Value(now),
        isActive: const Value(true),
        periodStart: plan.periodStart.present ? plan.periodStart : Value(now),
      ));
    });
  }

  /// Corrige un plan sin perder lo registrado: una opción quitada deja sus
  /// comidas como texto libre, y renombrar un tiempo también las actualiza.
  Future<void> updateMealPlan({
    required int planId,
    required String name,
    required int dailyMealGoal,
    required List<PlanOptionDraft> options,
  }) =>
      db.transaction(() async {
        await (update(mealPlans)..where((t) => t.id.equals(planId))).write(
          MealPlansCompanion(name: Value(name), dailyMealGoal: Value(dailyMealGoal)),
        );
        final kept = options.map((o) => o.id).nonNulls.toSet();
        final current = await getAllPlanOptions(planId);
        for (final option in current.where((o) => !kept.contains(o.id))) {
          await (update(dailyMealLogs)..where((t) => t.planOptionId.equals(option.id)))
              .write(DailyMealLogsCompanion(
            planOptionId: const Value(null),
            freeDescription: Value(option.description),
          ));
          await (delete(mealPlanOptions)..where((t) => t.id.equals(option.id))).go();
        }
        for (final draft in options) {
          final id = draft.id;
          final row = MealPlanOptionsCompanion(
            planId: Value(planId),
            mealType: Value(draft.mealType),
            optionNumber: Value(draft.optionNumber),
            description: Value(draft.description),
          );
          if (id == null) {
            await into(mealPlanOptions).insert(row);
          } else {
            await (update(mealPlanOptions)..where((t) => t.id.equals(id))).write(row);
            await (update(dailyMealLogs)..where((t) => t.planOptionId.equals(id)))
                .write(DailyMealLogsCompanion(mealType: Value(draft.mealType)));
          }
        }
      });

  /// Borra un plan y las comidas registradas con sus opciones. Si era el
  /// vigente, retoma el plan más reciente que quede.
  Future<void> deleteMealPlan(int planId) => db.transaction(() async {
        final plan = await (select(mealPlans)..where((t) => t.id.equals(planId)))
            .getSingleOrNull();
        if (plan == null) return;
        final options = await getAllPlanOptions(planId);
        await (delete(dailyMealLogs)
              ..where((t) => t.planOptionId.isIn(options.map((o) => o.id))))
            .go();
        await (delete(mealPlanOptions)..where((t) => t.planId.equals(planId))).go();
        await (delete(mealPlans)..where((t) => t.id.equals(planId))).go();
        if (!plan.isActive) return;
        final previous = await (select(mealPlans)
              ..orderBy([(t) => OrderingTerm.desc(t.id)])
              ..limit(1))
            .getSingleOrNull();
        if (previous == null) return;
        await (update(mealPlans)..where((t) => t.id.equals(previous.id))).write(
          const MealPlansCompanion(isActive: Value(true), periodEnd: Value(null)),
        );
      });

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

  /// Los tiempos de comida en el orden en que se escribieron en el plan
  /// (desayuno antes que almuerzo), no en orden alfabético.
  Future<List<MealPlanOption>> getAllPlanOptions(int planId) async {
    final options = await (select(mealPlanOptions)
          ..where((t) => t.planId.equals(planId)))
        .get();
    final firstId = <String, int>{};
    for (final o in options) {
      final seen = firstId[o.mealType];
      if (seen == null || o.id < seen) firstId[o.mealType] = o.id;
    }
    return options
      ..sort((a, b) {
        final byMeal = firstId[a.mealType]!.compareTo(firstId[b.mealType]!);
        return byMeal != 0 ? byMeal : a.optionNumber.compareTo(b.optionNumber);
      });
  }

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

  /// Returns logs where from <= date < to (to is exclusive).
  Future<List<DailyMealLog>> getLogsInRange(DateTime from, DateTime to) {
    final f = DateTime.utc(from.year, from.month, from.day);
    final tDay = DateTime.utc(to.year, to.month, to.day);
    return (select(dailyMealLogs)
          ..where((r) =>
              r.date.isBiggerOrEqualValue(f) &
              r.date.isSmallerThanValue(tDay)))
        .get();
  }

  Future<List<OptionFrequencyStat>> getOptionFrequenciesForPlan(
      int planId) async {
    final plan = await (select(mealPlans)
          ..where((t) => t.id.equals(planId)))
        .getSingleOrNull();
    if (plan == null) return [];

    final start = plan.periodStart;
    if (start == null) return [];

    // Usar .toUtc() para evitar desfase de zona horaria al reconstruir la fecha
    final startUtc = start.toUtc();
    final startDay = DateTime.utc(startUtc.year, startUtc.month, startUtc.day);

    final DateTime endDay;
    if (plan.periodEnd != null) {
      final endUtc = plan.periodEnd!.toUtc();
      // periodEnd es el último día incluido, por eso +1 día para el límite exclusivo
      endDay = DateTime.utc(endUtc.year, endUtc.month, endUtc.day)
          .add(const Duration(days: 1));
    } else {
      final now = DateTime.now().toUtc();
      endDay = DateTime.utc(now.year, now.month, now.day)
          .add(const Duration(days: 1));
    }

    final opts = await (select(mealPlanOptions)
          ..where((t) => t.planId.equals(planId))
          ..orderBy([
            (t) => OrderingTerm.asc(t.mealType),
            (t) => OrderingTerm.asc(t.optionNumber),
          ]))
        .get();
    if (opts.isEmpty) return [];

    final optionIds = opts.map((o) => o.id).toList();
    final logs = await (select(dailyMealLogs)
          ..where((t) =>
              t.planOptionId.isIn(optionIds) &
              t.date.isBiggerOrEqualValue(startDay) &
              t.date.isSmallerThanValue(endDay)))
        .get();

    final countMap = <int, int>{};
    for (final log in logs) {
      if (log.planOptionId != null) {
        countMap[log.planOptionId!] =
            (countMap[log.planOptionId!] ?? 0) + 1;
      }
    }

    return opts
        .map((o) => OptionFrequencyStat(
              planOptionId: o.id,
              mealType: o.mealType,
              optionNumber: o.optionNumber,
              description: o.description,
              count: countMap[o.id] ?? 0,
            ))
        .toList();
  }

  Future<List<MealPlanOption>> getMealPlanOptionsByIds(List<int> ids) {
    if (ids.isEmpty) return Future.value([]);
    return (select(mealPlanOptions)..where((t) => t.id.isIn(ids))).get();
  }
}
