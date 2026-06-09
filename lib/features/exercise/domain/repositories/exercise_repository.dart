import 'package:kiolog/core/database/app_database.dart';

abstract class ExerciseRepository {
  Future<ExercisePlan?> getActivePlan();
  Future<List<ExercisePlan>> getAllPlans();
  Future<void> activatePlan(int planId);
  Future<int> createPlan(String name);

  Future<List<ExerciseRoutine>> getRoutinesForPlan(int planId);
  Future<ExerciseRoutine?> getRoutine(int routineId);
  Future<List<ExerciseRoutineItem>> getRoutineItems(int routineId);
  Future<int> addRoutine({
    required int planId,
    required int dayNumber,
    required String routineName,
    String? notes,
  });
  Future<void> addRoutineItem({
    required int routineId,
    required String exerciseName,
    required int sets,
    required int reps,
    double? weightKg,
  });

  Future<DailyExerciseLog?> getDailyLog(DateTime date);
  Future<void> logDailyExercise(DateTime date, int routineId);

  Future<int> startSession(DateTime date, {int? routineId});
  Future<void> endSession(int sessionId);
  Future<ExerciseSessionLog?> getSession(int sessionId);
  Future<List<ExerciseSessionLog>> getSessionsForDate(DateTime date);
  Future<void> logSet({
    required int sessionId,
    required String exerciseName,
    required int setNumber,
    required int reps,
    required double weightKg,
  });
  Future<List<ExerciseSetLog>> getSessionSets(int sessionId);
}
