import 'package:drift/drift.dart';
import 'package:kiolog/core/dao/exercise_dao.dart';
import 'package:kiolog/core/database/app_database.dart';
import '../../domain/repositories/exercise_repository.dart';

class ExerciseRepositoryImpl implements ExerciseRepository {
  final ExerciseDao _exerciseDao;

  ExerciseRepositoryImpl(this._exerciseDao);

  DateTime _dateOnly(DateTime date) =>
      DateTime.utc(date.year, date.month, date.day);

  @override
  Future<ExercisePlan?> getActivePlan() => _exerciseDao.getActiveExercisePlan();

  @override
  Future<List<ExercisePlan>> getAllPlans() => _exerciseDao.getExercisePlans();

  @override
  Future<void> activatePlan(int planId) =>
      _exerciseDao.setActiveExercisePlan(planId);

  @override
  Future<int> createPlan(String name) => _exerciseDao.insertExercisePlan(
        ExercisePlansCompanion(name: Value(name)),
      );

  @override
  Future<List<ExerciseRoutine>> getRoutinesForPlan(int planId) =>
      _exerciseDao.getRoutinesForPlan(planId);

  @override
  Future<ExerciseRoutine?> getRoutine(int routineId) =>
      _exerciseDao.getRoutine(routineId);

  @override
  Future<List<ExerciseRoutineItem>> getRoutineItems(int routineId) =>
      _exerciseDao.getRoutineItems(routineId);

  @override
  Future<int> addRoutine({
    required int planId,
    required int dayNumber,
    required String routineName,
    String? notes,
  }) =>
      _exerciseDao.insertExerciseRoutine(
        ExerciseRoutinesCompanion(
          planId: Value(planId),
          dayNumber: Value(dayNumber),
          routineName: Value(routineName),
          notes: Value(notes),
        ),
      );

  @override
  Future<void> addRoutineItem({
    required int routineId,
    required String exerciseName,
    required int sets,
    required int reps,
    double? weightKg,
  }) =>
      _exerciseDao.insertExerciseRoutineItem(
        ExerciseRoutineItemsCompanion(
          routineId: Value(routineId),
          exerciseName: Value(exerciseName),
          sets: Value(sets),
          reps: Value(reps),
          weightKg: Value(weightKg),
        ),
      );

  @override
  Future<DailyExerciseLog?> getDailyLog(DateTime date) =>
      _exerciseDao.getDailyExerciseLog(_dateOnly(date));

  @override
  Future<void> logDailyExercise(DateTime date, int routineId) =>
      _exerciseDao.insertDailyExerciseLog(
        DailyExerciseLogsCompanion(
          date: Value(_dateOnly(date)),
          routineId: Value(routineId),
          completed: const Value(true),
        ),
      );

  @override
  Future<int> startSession(DateTime date, {int? routineId}) =>
      _exerciseDao.insertExerciseSession(
        ExerciseSessionLogsCompanion(
          date: Value(_dateOnly(date)),
          routineId: Value(routineId),
          gymArrivedAt: Value(DateTime.now()),
        ),
      );

  @override
  Future<void> endSession(int sessionId) =>
      _exerciseDao.updateSessionEndTime(sessionId, DateTime.now());

  @override
  Future<ExerciseSessionLog?> getSession(int sessionId) =>
      _exerciseDao.getSession(sessionId);

  @override
  Future<List<ExerciseSessionLog>> getSessionsForDate(DateTime date) =>
      _exerciseDao.getSessionsForDate(_dateOnly(date));

  @override
  Future<void> logSet({
    required int sessionId,
    required String exerciseName,
    required int setNumber,
    required int reps,
    required double weightKg,
  }) =>
      _exerciseDao.insertExerciseSetLog(
        ExerciseSetLogsCompanion(
          sessionId: Value(sessionId),
          exerciseName: Value(exerciseName),
          setNumber: Value(setNumber),
          reps: Value(reps),
          weightKg: Value(weightKg),
        ),
      );

  @override
  Future<List<ExerciseSetLog>> getSessionSets(int sessionId) =>
      _exerciseDao.getSessionSets(sessionId);
}
