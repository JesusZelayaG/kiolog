// lib/core/dao/exercise_dao.dart
import 'package:drift/drift.dart';
import '../database/app_database.dart';
import '../database/tables/exercise_tables.dart';

part 'exercise_dao.g.dart';

@DriftAccessor(tables: [
  ExercisePlans,
  ExerciseRoutines,
  ExerciseRoutineItems,
  DailyExerciseLogs,
  ExerciseSessionLogs,
  ExerciseSetLogs,
])
class ExerciseDao extends DatabaseAccessor<AppDatabase>
    with _$ExerciseDaoMixin {
  ExerciseDao(super.db);

  Future<int> insertExercisePlan(ExercisePlansCompanion plan) =>
      into(exercisePlans).insert(plan.copyWith(
        createdAt: plan.createdAt.present
            ? plan.createdAt
            : Value(DateTime.now().toUtc()),
        isActive: const Value(true),
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

      await (update(exercisePlans))
          .write(const ExercisePlansCompanion(isActive: Value(false)));
      await (update(exercisePlans)..where((t) => t.id.equals(planId)))
          .write(const ExercisePlansCompanion(isActive: Value(true)));
    });
  }

  Future<int> insertExerciseRoutine(ExerciseRoutinesCompanion routine) =>
      into(exerciseRoutines).insert(routine);

  Future<ExerciseRoutine?> getRoutineForDay(int planId, int dayOfWeek) =>
      (select(exerciseRoutines)
            ..where((t) =>
                t.planId.equals(planId) & t.dayOfWeek.equals(dayOfWeek)))
          .getSingleOrNull();

  Future<int> insertExerciseRoutineItem(
          ExerciseRoutineItemsCompanion item) =>
      into(exerciseRoutineItems).insert(item);

  Future<List<ExerciseRoutineItem>> getRoutineItems(int routineId) =>
      (select(exerciseRoutineItems)
            ..where((t) => t.routineId.equals(routineId)))
          .get();

  Future<int> insertExerciseSession(ExerciseSessionLogsCompanion session) =>
      into(exerciseSessionLogs).insert(session);

  Future<ExerciseSessionLog?> getSession(int sessionId) =>
      (select(exerciseSessionLogs)..where((t) => t.id.equals(sessionId)))
          .getSingleOrNull();

  Future<void> updateSessionEndTime(int sessionId, DateTime endTime) =>
      (update(exerciseSessionLogs)..where((t) => t.id.equals(sessionId)))
          .write(ExerciseSessionLogsCompanion(gymLeftAt: Value(endTime)));

  Future<int> insertExerciseSetLog(ExerciseSetLogsCompanion setLog) =>
      into(exerciseSetLogs).insert(setLog);

  Future<List<ExerciseSetLog>> getSessionSets(int sessionId) =>
      (select(exerciseSetLogs)
            ..where((t) => t.sessionId.equals(sessionId))
            ..orderBy([(t) => OrderingTerm.asc(t.setNumber)]))
          .get();

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
}
