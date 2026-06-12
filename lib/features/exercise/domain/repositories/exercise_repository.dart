import 'package:kiolog/core/database/app_database.dart';
import '../models/independent_exercise_log.dart';
import '../models/plan_compliance_stat.dart';
import '../models/weekly_stat.dart';

abstract class ExerciseRepository {
  // ── Plans ──────────────────────────────────────────────────────────────
  Future<ExercisePlan?> getActivePlan();
  Future<List<ExercisePlan>> getAllPlans();
  Future<void> activatePlan(int planId);
  Future<int> createPlan(String name);

  // ── Routines ───────────────────────────────────────────────────────────
  Future<List<ExerciseRoutine>> getRoutinesForPlan(int planId);
  Future<ExerciseRoutine?> getRoutine(int routineId);
  Future<int> addRoutine({
    required int planId,
    required int dayNumber,
    required String routineName,
    String? notes,
  });

  // ── Routine Items ──────────────────────────────────────────────────────
  Future<List<ExerciseRoutineItem>> getRoutineItems(int routineId);
  Future<List<ExerciseRoutineItem>> getRoutineItemsOrdered(int routineId);
  Future<int> addRoutineItem({
    required int routineId,
    required String exerciseName,
    required int sets,
    required int reps,
    double? weightKg,
    String setType = 'normal',
    int orderIndex = 0,
  });
  Future<void> updateRoutineItem({
    required int itemId,
    String? exerciseName,
    int? sets,
    int? reps,
    double? weightKg,
    String? setType,
    int? orderIndex,
  });
  Future<void> deleteRoutineItem(int itemId);

  // ── Routine Set Defs ───────────────────────────────────────────────────
  Future<List<ExerciseRoutineSetDef>> getRoutineSetDefs(int routineItemId);
  Future<void> replaceRoutineSetDefs({
    required int routineItemId,
    required List<({int setNumber, int? dropOfSetNumber, int reps, double? weightKg})> defs,
  });

  // ── Daily Logs ─────────────────────────────────────────────────────────
  Future<DailyExerciseLog?> getDailyLog(DateTime date);
  Future<void> logDailyExercise(DateTime date, int routineId);

  // ── Sessions ───────────────────────────────────────────────────────────
  Future<int> startSession(DateTime date, {int? routineId});
  Future<void> endSession(int sessionId);
  Future<void> deleteSession(int sessionId);
  Future<ExerciseSessionLog?> getSession(int sessionId);
  Future<List<ExerciseSessionLog>> getSessionsForDate(DateTime date);
  Future<List<ExerciseSessionLog>> getCompletedRoutineSessionsForWeek(DateTime weekStart);
  Future<List<IndependentExerciseLog>> getIndependentSessionsForWeek(
    DateTime weekStart,
  );

  // ── Set Logs ───────────────────────────────────────────────────────────
  Future<void> logSet({
    required int sessionId,
    required String exerciseName,
    required int setNumber,
    required int reps,
    double? weightKg,
    String setType = 'normal',
    int? dropOfSetId,
  });
  Future<List<ExerciseSetLog>> getSessionSets(int sessionId);
  Future<List<ExerciseSetLog>> getLastSessionSetsForExercise(String exerciseName);

  // ── Cardio ─────────────────────────────────────────────────────────────
  Future<int> logCardio({
    required DateTime date,
    required String cardioType,
    required int durationMinutes,
    String? notes,
  });
  Future<void> updateCardio({
    required int cardioId,
    String? cardioType,
    int? durationMinutes,
    String? notes,
  });
  Future<void> deleteCardio(int cardioId);
  Future<List<CardioLog>> getCardioLogsForWeek(DateTime weekStart);

  // ── Config ─────────────────────────────────────────────────────────────
  Future<ExerciseConfigData?> getExerciseConfig();
  Future<void> updateExerciseConfig({
    int? weeklyRoutineDaysGoal,
    int? weeklyCardioDaysGoal,
    int? cardioMinutesGoal,
  });

  // ── Progress ───────────────────────────────────────────────────────────
  Future<List<WeeklyStat>> getWeeklyStats({int weeksBack = 8});
  Future<List<PlanComplianceStat>> getPlanHistory();
}
