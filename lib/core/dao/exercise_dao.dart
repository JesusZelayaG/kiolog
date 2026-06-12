import 'package:drift/drift.dart';
import '../database/app_database.dart';
import '../database/tables/exercise_tables.dart';

part 'exercise_dao.g.dart';

@DriftAccessor(tables: [
  ExercisePlans,
  ExerciseRoutines,
  ExerciseRoutineItems,
  ExerciseRoutineSetDefs,
  DailyExerciseLogs,
  ExerciseSessionLogs,
  ExerciseSetLogs,
  CardioLogs,
  ExerciseConfig,
])
class ExerciseDao extends DatabaseAccessor<AppDatabase>
    with _$ExerciseDaoMixin {
  ExerciseDao(super.db);

  // ── Plans ────────────────────────────────────────────────────────────────

  Future<int> insertExercisePlan(ExercisePlansCompanion plan) =>
      into(exercisePlans).insert(plan.copyWith(
        createdAt: plan.createdAt.present
            ? plan.createdAt
            : Value(DateTime.now().toUtc()),
        isActive: const Value(true),
        periodStart: plan.periodStart.present
            ? plan.periodStart
            : Value(DateTime.now().toUtc()),
      ));

  Future<List<ExercisePlan>> getExercisePlans() =>
      (select(exercisePlans)
            ..orderBy([(t) => OrderingTerm.desc(t.createdAt)]))
          .get();

  Future<ExercisePlan?> getActiveExercisePlan() =>
      (select(exercisePlans)..where((t) => t.isActive.equals(true)))
          .getSingleOrNull();

  Future<void> setActiveExercisePlan(int planId) async {
    await db.transaction(() async {
      final plan = await (select(exercisePlans)
            ..where((t) => t.id.equals(planId)))
          .getSingleOrNull();
      if (plan == null) throw ArgumentError('Exercise plan $planId not found');
      final now = DateTime.now().toUtc();
      // Close the currently active plan (set periodEnd)
      await (update(exercisePlans)
            ..where((t) => t.isActive.equals(true)))
          .write(ExercisePlansCompanion(
            isActive: const Value(false),
            periodEnd: Value(now),
          ));
      // Activate the selected plan with a new periodStart
      await (update(exercisePlans)..where((t) => t.id.equals(planId)))
          .write(ExercisePlansCompanion(
            isActive: const Value(true),
            periodStart: Value(now),
            periodEnd: const Value(null),
          ));
    });
  }

  // ── Routines ─────────────────────────────────────────────────────────────

  Future<int> insertExerciseRoutine(ExerciseRoutinesCompanion routine) =>
      into(exerciseRoutines).insert(routine);

  Future<List<ExerciseRoutine>> getRoutinesForPlan(int planId) =>
      (select(exerciseRoutines)
            ..where((t) => t.planId.equals(planId))
            ..orderBy([(t) => OrderingTerm.asc(t.dayNumber)]))
          .get();

  Future<ExerciseRoutine?> getRoutine(int routineId) =>
      (select(exerciseRoutines)..where((t) => t.id.equals(routineId)))
          .getSingleOrNull();

  // ── Routine Items ─────────────────────────────────────────────────────────

  Future<int> insertExerciseRoutineItem(ExerciseRoutineItemsCompanion item) =>
      into(exerciseRoutineItems).insert(item);

  Future<List<ExerciseRoutineItem>> getRoutineItems(int routineId) =>
      (select(exerciseRoutineItems)
            ..where((t) => t.routineId.equals(routineId)))
          .get();

  Future<List<ExerciseRoutineItem>> getRoutineItemsOrdered(int routineId) =>
      (select(exerciseRoutineItems)
            ..where((t) => t.routineId.equals(routineId))
            ..orderBy([(t) => OrderingTerm.asc(t.orderIndex)]))
          .get();

  Future<void> updateRoutineItem(
    int itemId,
    ExerciseRoutineItemsCompanion data,
  ) =>
      (update(exerciseRoutineItems)..where((t) => t.id.equals(itemId)))
          .write(data);

  Future<void> deleteRoutineItem(int itemId) =>
      (delete(exerciseRoutineItems)..where((t) => t.id.equals(itemId))).go();

  // ── Routine Set Defs ──────────────────────────────────────────────────────

  Future<List<ExerciseRoutineSetDef>> getRoutineSetDefs(int routineItemId) =>
      (select(exerciseRoutineSetDefs)
            ..where((t) => t.routineItemId.equals(routineItemId))
            ..orderBy([(t) => OrderingTerm.asc(t.setNumber)]))
          .get();

  Future<void> replaceRoutineSetDefs(
    int routineItemId,
    List<ExerciseRoutineSetDefsCompanion> defs,
  ) async {
    await db.transaction(() async {
      await (delete(exerciseRoutineSetDefs)
            ..where((t) => t.routineItemId.equals(routineItemId)))
          .go();
      for (final def in defs) {
        await into(exerciseRoutineSetDefs).insert(def);
      }
    });
  }

  // ── Sessions ──────────────────────────────────────────────────────────────

  Future<int> insertExerciseSession(ExerciseSessionLogsCompanion session) =>
      into(exerciseSessionLogs).insert(session);

  Future<ExerciseSessionLog?> getSession(int sessionId) =>
      (select(exerciseSessionLogs)..where((t) => t.id.equals(sessionId)))
          .getSingleOrNull();

  Future<void> updateSessionEndTime(int sessionId, DateTime endTime) =>
      (update(exerciseSessionLogs)..where((t) => t.id.equals(sessionId)))
          .write(ExerciseSessionLogsCompanion(gymLeftAt: Value(endTime)));

  Future<void> deleteSession(int sessionId) =>
      (delete(exerciseSessionLogs)..where((t) => t.id.equals(sessionId))).go();

  Future<List<ExerciseSessionLog>> getSessionsForDate(DateTime date) {
    final start = DateTime.utc(date.year, date.month, date.day);
    final end = start.add(const Duration(days: 1));
    return (select(exerciseSessionLogs)
          ..where((t) =>
              t.date.isBiggerOrEqualValue(start) &
              t.date.isSmallerThanValue(end))
          ..orderBy([(t) => OrderingTerm.desc(t.gymArrivedAt)]))
        .get();
  }

  Future<List<ExerciseSessionLog>> getCompletedRoutineSessionsForWeek(
    DateTime weekStart,
  ) {
    final start =
        DateTime.utc(weekStart.year, weekStart.month, weekStart.day);
    final end = start.add(const Duration(days: 7));
    return (select(exerciseSessionLogs)
          ..where((t) =>
              t.date.isBiggerOrEqualValue(start) &
              t.date.isSmallerThanValue(end) &
              t.routineId.isNotNull() &
              t.gymLeftAt.isNotNull()))
        .get();
  }

  Future<List<ExerciseSessionLog>> getIndependentSessionsForWeek(
    DateTime weekStart,
  ) {
    final start =
        DateTime.utc(weekStart.year, weekStart.month, weekStart.day);
    final end = start.add(const Duration(days: 7));
    return (select(exerciseSessionLogs)
          ..where((t) =>
              t.date.isBiggerOrEqualValue(start) &
              t.date.isSmallerThanValue(end) &
              t.routineId.isNull() &
              t.gymLeftAt.isNotNull())
          ..orderBy([(t) => OrderingTerm.desc(t.gymArrivedAt)]))
        .get();
  }

  /// Returns completed routine sessions (gymLeftAt != null) whose routineId
  /// is in [routineIds] and whose date falls in [start, end).
  Future<List<ExerciseSessionLog>> getCompletedSessionsInPeriod(
    List<int> routineIds,
    DateTime start,
    DateTime end,
  ) {
    if (routineIds.isEmpty) return Future.value([]);
    return (select(exerciseSessionLogs)
          ..where((t) =>
              t.routineId.isIn(routineIds) &
              t.gymLeftAt.isNotNull() &
              t.date.isBiggerOrEqualValue(start) &
              t.date.isSmallerThanValue(end)))
        .get();
  }

  // ── Set Logs ──────────────────────────────────────────────────────────────

  Future<int> insertExerciseSetLog(ExerciseSetLogsCompanion setLog) =>
      into(exerciseSetLogs).insert(setLog);

  Future<List<ExerciseSetLog>> getSessionSets(int sessionId) =>
      (select(exerciseSetLogs)
            ..where((t) => t.sessionId.equals(sessionId))
            ..orderBy([(t) => OrderingTerm.asc(t.setNumber)]))
          .get();

  Future<List<ExerciseSetLog>> getLastSessionSetsForExercise(
    String exerciseName,
  ) async {
    final allSets = await (select(exerciseSetLogs)
          ..where((t) => t.exerciseName.equals(exerciseName))
          ..orderBy([(t) => OrderingTerm.desc(t.id)]))
        .get();
    if (allSets.isEmpty) return [];
    final lastSessionId = allSets.first.sessionId;
    return allSets.where((s) => s.sessionId == lastSessionId).toList();
  }

  // ── Daily Logs ────────────────────────────────────────────────────────────

  Future<int> insertDailyExerciseLog(DailyExerciseLogsCompanion log) =>
      into(dailyExerciseLogs).insert(log);

  Future<DailyExerciseLog?> getDailyExerciseLog(DateTime date) {
    final start = DateTime.utc(date.year, date.month, date.day);
    final end = start.add(const Duration(days: 1));
    return (select(dailyExerciseLogs)
          ..where((t) =>
              t.date.isBiggerOrEqualValue(start) &
              t.date.isSmallerThanValue(end)))
        .getSingleOrNull();
  }

  // ── Cardio Logs ───────────────────────────────────────────────────────────

  Future<int> insertCardioLog(CardioLogsCompanion log) =>
      into(cardioLogs).insert(log.copyWith(
        date: Value(log.date.value.toUtc()),
      ));

  Future<void> updateCardioLog(int id, CardioLogsCompanion data) =>
      (update(cardioLogs)..where((t) => t.id.equals(id))).write(data);

  Future<void> deleteCardioLog(int id) =>
      (delete(cardioLogs)..where((t) => t.id.equals(id))).go();

  Future<List<CardioLog>> getCardioLogsForWeek(DateTime weekStart) {
    final start = DateTime.utc(weekStart.year, weekStart.month, weekStart.day);
    final end = start.add(const Duration(days: 7));
    return (select(cardioLogs)
          ..where((t) =>
              t.date.isBiggerOrEqualValue(start) &
              t.date.isSmallerThanValue(end))
          ..orderBy([(t) => OrderingTerm.desc(t.date)]))
        .get();
  }

  // ── Exercise Config ───────────────────────────────────────────────────────

  Future<ExerciseConfigData?> getExerciseConfig() =>
      (select(exerciseConfig)).getSingleOrNull();

  Future<void> upsertExerciseConfig(ExerciseConfigCompanion config) async {
    final existing = await getExerciseConfig();
    if (existing == null) {
      await into(exerciseConfig).insert(config.copyWith(id: const Value.absent()));
    } else {
      await (update(exerciseConfig)..where((t) => t.id.equals(existing.id)))
          .write(config);
    }
  }
}
