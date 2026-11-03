import 'package:kiolog/core/domain/day.dart';
import 'package:drift/drift.dart';
import 'package:kiolog/core/dao/exercise_dao.dart';
import 'package:kiolog/core/database/app_database.dart';
import '../../domain/models/independent_exercise_log.dart';
import '../../domain/models/plan_compliance_stat.dart';
import '../../domain/models/weekly_stat.dart';
import '../../domain/repositories/exercise_repository.dart';

class ExerciseRepositoryImpl implements ExerciseRepository {
  final ExerciseDao _dao;

  ExerciseRepositoryImpl(this._dao);

  DateTime _utcDate(DateTime date) =>
      DateTime.utc(date.year, date.month, date.day);

  DateTime _mondayOf(DateTime date) {
    final d = date.toUtc();
    return DateTime.utc(d.year, d.month, d.day)
        .subtract(Duration(days: d.weekday - 1));
  }

  @override
  Future<ExercisePlan?> getActivePlan() => _dao.getActiveExercisePlan();

  @override
  Future<List<ExercisePlan>> getAllPlans() => _dao.getExercisePlans();

  @override
  Future<void> activatePlan(int planId) => _dao.setActiveExercisePlan(planId);

  @override
  Future<int> createPlan(String name, {String weightUnit = 'kg'}) =>
      _dao.insertExercisePlan(
        ExercisePlansCompanion(
          name: Value(name),
          weightUnit: Value(weightUnit),
        ),
      );

  @override
  Future<List<ExerciseRoutine>> getRoutinesForPlan(int planId) =>
      _dao.getRoutinesForPlan(planId);

  @override
  Future<ExerciseRoutine?> getRoutine(int routineId) =>
      _dao.getRoutine(routineId);

  @override
  Future<int> addRoutine({
    required int planId,
    required int dayNumber,
    required String routineName,
    String? notes,
  }) =>
      _dao.insertExerciseRoutine(ExerciseRoutinesCompanion(
        planId: Value(planId),
        dayNumber: Value(dayNumber),
        routineName: Value(routineName),
        notes: Value(notes),
      ));

  @override
  Future<List<ExerciseRoutineItem>> getRoutineItems(int routineId) =>
      _dao.getRoutineItems(routineId);

  @override
  Future<List<ExerciseRoutineItem>> getRoutineItemsOrdered(int routineId) =>
      _dao.getRoutineItemsOrdered(routineId);

  @override
  Future<int> addRoutineItem({
    required int routineId,
    required String exerciseName,
    required int sets,
    required int reps,
    double? weightKg,
    String setType = 'normal',
    int orderIndex = 0,
    String? repsLabel,
    String? notes,
  }) =>
      _dao.insertExerciseRoutineItem(ExerciseRoutineItemsCompanion(
        routineId: Value(routineId),
        exerciseName: Value(exerciseName),
        sets: Value(sets),
        reps: Value(reps),
        weightKg: Value(weightKg),
        setType: Value(setType),
        orderIndex: Value(orderIndex),
        repsLabel: Value(repsLabel),
        notes: Value(notes),
      ));

  @override
  Future<void> updateRoutineItem({
    required int itemId,
    String? exerciseName,
    int? sets,
    int? reps,
    double? weightKg,
    String? setType,
    int? orderIndex,
    ({String? value})? repsLabel,
    ({String? value})? notes,
  }) =>
      _dao.updateRoutineItem(
        itemId,
        ExerciseRoutineItemsCompanion(
          exerciseName: exerciseName != null
              ? Value(exerciseName)
              : const Value.absent(),
          sets: sets != null ? Value(sets) : const Value.absent(),
          reps: reps != null ? Value(reps) : const Value.absent(),
          weightKg: weightKg != null ? Value(weightKg) : const Value.absent(),
          setType: setType != null ? Value(setType) : const Value.absent(),
          orderIndex:
              orderIndex != null ? Value(orderIndex) : const Value.absent(),
          repsLabel:
              repsLabel != null ? Value(repsLabel.value) : const Value.absent(),
          notes: notes != null ? Value(notes.value) : const Value.absent(),
        ),
      );

  @override
  Future<void> deleteRoutineItem(int itemId) => _dao.deleteRoutineItem(itemId);

  @override
  Future<List<ExerciseRoutineSetDef>> getRoutineSetDefs(int routineItemId) =>
      _dao.getRoutineSetDefs(routineItemId);

  @override
  Future<void> replaceRoutineSetDefs({
    required int routineItemId,
    required List<({int setNumber, int? dropOfSetNumber, int reps, double? weightKg})> defs,
  }) =>
      _dao.replaceRoutineSetDefs(
        routineItemId,
        defs
            .map((d) => ExerciseRoutineSetDefsCompanion(
                  routineItemId: Value(routineItemId),
                  setNumber: Value(d.setNumber),
                  dropOfSetNumber: Value(d.dropOfSetNumber),
                  reps: Value(d.reps),
                  weightKg: Value(d.weightKg),
                ))
            .toList(),
      );

  @override
  Future<DailyExerciseLog?> getDailyLog(DateTime date) =>
      _dao.getDailyExerciseLog(_utcDate(date));

  @override
  Future<void> logDailyExercise(DateTime date, int routineId) =>
      _dao.insertDailyExerciseLog(DailyExerciseLogsCompanion(
        date: Value(_utcDate(date)),
        routineId: Value(routineId),
        completed: const Value(true),
      ));

  @override
  Future<int> startSession(DateTime date, {int? routineId}) =>
      _dao.insertExerciseSession(ExerciseSessionLogsCompanion(
        date: Value(_utcDate(date)),
        routineId: Value(routineId),
        gymArrivedAt: Value(DateTime.now().toUtc()),
      ));

  @override
  Future<void> endSession(int sessionId) =>
      _dao.updateSessionEndTime(sessionId, DateTime.now().toUtc());

  @override
  Future<void> deleteSession(int sessionId) => _dao.deleteSession(sessionId);

  @override
  Future<ExerciseSessionLog?> getSession(int sessionId) =>
      _dao.getSession(sessionId);

  @override
  Future<List<ExerciseSessionLog>> getSessionsForDate(DateTime date) =>
      _dao.getSessionsForDate(_utcDate(date));

  @override
  Future<List<ExerciseSessionLog>> getCompletedRoutineSessionsForWeek(
          DateTime weekStart) =>
      _dao.getCompletedRoutineSessionsForWeek(_utcDate(weekStart));

  @override
  Future<List<IndependentExerciseLog>> getIndependentSessionsForWeek(
    DateTime weekStart,
  ) async {
    final sessions =
        await _dao.getIndependentSessionsForWeek(_utcDate(weekStart));
    final result = <IndependentExerciseLog>[];
    for (final s in sessions) {
      final sets = await _dao.getSessionSets(s.id);
      if (sets.isEmpty) continue;
      result.add(IndependentExerciseLog(
        sessionId: s.id,
        date: s.date,
        exerciseName: sets.first.exerciseName,
        sets: sets.length,
        reps: sets.first.reps,
        weightKg: sets.first.weightKg,
      ));
    }
    return result;
  }

  @override
  Future<void> logSet({
    required int sessionId,
    required String exerciseName,
    required int setNumber,
    required int reps,
    double? weightKg,
    String setType = 'normal',
    int? dropOfSetId,
  }) =>
      _dao.insertExerciseSetLog(ExerciseSetLogsCompanion(
        sessionId: Value(sessionId),
        exerciseName: Value(exerciseName),
        setNumber: Value(setNumber),
        reps: Value(reps),
        weightKg: Value(weightKg),
        setType: Value(setType),
        dropOfSetId: Value(dropOfSetId),
      ));

  @override
  Future<List<ExerciseSetLog>> getSessionSets(int sessionId) =>
      _dao.getSessionSets(sessionId);

  @override
  Future<List<ExerciseSetLog>> getLastSessionSetsForExercise(
          String exerciseName) =>
      _dao.getLastSessionSetsForExercise(exerciseName);

  @override
  Future<int> logCardio({
    required DateTime date,
    required String cardioType,
    required int durationMinutes,
    String? notes,
  }) =>
      _dao.insertCardioLog(CardioLogsCompanion(
        date: Value(_utcDate(date)),
        cardioType: Value(cardioType),
        durationMinutes: Value(durationMinutes),
        notes: Value(notes),
      ));

  @override
  Future<void> updateCardio({
    required int cardioId,
    String? cardioType,
    int? durationMinutes,
    String? notes,
  }) =>
      _dao.updateCardioLog(
        cardioId,
        CardioLogsCompanion(
          cardioType:
              cardioType != null ? Value(cardioType) : const Value.absent(),
          durationMinutes: durationMinutes != null
              ? Value(durationMinutes)
              : const Value.absent(),
          notes: notes != null ? Value(notes) : const Value.absent(),
        ),
      );

  @override
  Future<void> deleteCardio(int cardioId) => _dao.deleteCardioLog(cardioId);

  @override
  Future<List<CardioLog>> getCardioLogsForWeek(DateTime weekStart) =>
      _dao.getCardioLogsForWeek(_utcDate(weekStart));

  @override
  Future<ExerciseConfigData?> getExerciseConfig() => _dao.getExerciseConfig();

  @override
  Future<void> updateExerciseConfig({
    int? weeklyRoutineDaysGoal,
    int? weeklyCardioDaysGoal,
    int? cardioMinutesGoal,
  }) =>
      _dao.upsertExerciseConfig(ExerciseConfigCompanion(
        weeklyRoutineDaysGoal: weeklyRoutineDaysGoal != null
            ? Value(weeklyRoutineDaysGoal)
            : const Value.absent(),
        weeklyCardioDaysGoal: weeklyCardioDaysGoal != null
            ? Value(weeklyCardioDaysGoal)
            : const Value.absent(),
        cardioMinutesGoal: cardioMinutesGoal != null
            ? Value(cardioMinutesGoal)
            : const Value.absent(),
      ));

  @override
  Future<List<WeeklyStat>> getWeeklyStats({int weeksBack = 8}) async {
    final thisMonday = _mondayOf(todayUtcDay());
    final stats = <WeeklyStat>[];
    for (var i = weeksBack - 1; i >= 0; i--) {
      final weekStart = thisMonday.subtract(Duration(days: 7 * i));
      final routineSessions =
          await _dao.getCompletedRoutineSessionsForWeek(weekStart);
      final cardioLogs = await _dao.getCardioLogsForWeek(weekStart);
      stats.add(WeeklyStat(
        weekStart: weekStart,
        routineDaysDone: routineSessions
            .map((s) => DateTime.utc(s.date.year, s.date.month, s.date.day))
            .toSet()
            .length,
        cardioDaysDone: cardioLogs
            .map((l) => DateTime.utc(l.date.year, l.date.month, l.date.day))
            .toSet()
            .length,
      ));
    }
    return stats;
  }

  @override
  Future<List<PlanComplianceStat>> getPlanHistory() async {
    final plans = await _dao.getExercisePlans();
    final config = await _dao.getExerciseConfig();
    final goal = config?.weeklyRoutineDaysGoal ?? 4;
    final stats = <PlanComplianceStat>[];

    for (final plan in plans) {
      final periodStart = plan.periodStart ?? plan.createdAt;
      final periodEnd = plan.periodEnd ?? DateTime.now().toUtc();

      final routines = await _dao.getRoutinesForPlan(plan.id);
      final routineIds = routines.map((r) => r.id).toList();

      final sessions = await _dao.getCompletedSessionsInPeriod(
        routineIds,
        periodStart,
        periodEnd,
      );

      // Count unique days (avoid duplicate sessions on the same day)
      final uniqueDays = sessions
          .map((s) {
            final d = s.date.toUtc();
            return DateTime.utc(d.year, d.month, d.day);
          })
          .toSet()
          .length;

      final durationDays = periodEnd.difference(periodStart).inDays;
      final weeksActive = ((durationDays / 7).ceil()).clamp(1, 9999);
      final weeklyAvg = uniqueDays / weeksActive;
      final compliancePercent =
          ((uniqueDays / (goal * weeksActive)) * 100).round().clamp(0, 100);

      stats.add(PlanComplianceStat(
        planId: plan.id,
        planName: plan.name,
        periodStart: periodStart,
        periodEnd: plan.periodEnd,
        totalSessions: uniqueDays,
        weeksActive: weeksActive,
        weeklyAvg: weeklyAvg,
        compliancePercent: compliancePercent,
      ));
    }

    return stats;
  }
}
