import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:kiolog/core/database/app_database.dart';
import '../../domain/repositories/exercise_repository.dart';
import 'exercise_event.dart';
import 'exercise_state.dart';

class ExerciseBloc extends Bloc<ExerciseEvent, ExerciseState> {
  final ExerciseRepository _repository;

  ExerciseBloc(this._repository) : super(const ExerciseState()) {
    on<ExerciseLoaded>(_onLoaded);
    on<ExercisePlanLoaded>(_onPlanLoaded);
    on<ExercisePlanActivated>(_onPlanActivated);
    on<ExercisePlanCreated>(_onPlanCreated);
    on<ExerciseRoutineAdded>(_onRoutineAdded);
    on<ExerciseRoutineMarkedDone>(_onRoutineMarkedDone);
    on<ExerciseRoutineItemAdded>(_onRoutineItemAdded);
    on<ExerciseRoutineItemUpdated>(_onRoutineItemUpdated);
    on<ExerciseRoutineItemDeleted>(_onRoutineItemDeleted);
    on<ExerciseSessionStarted>(_onSessionStarted);
    on<ExerciseSessionEnded>(_onSessionEnded);
    on<ExerciseItemCompleted>(_onItemCompleted);
    on<ExerciseSetLogged>(_onSetLogged);
    on<CardioLogged>(_onCardioLogged);
    on<CardioUpdated>(_onCardioUpdated);
    on<CardioDeleted>(_onCardioDeleted);
    on<IndependentExerciseLogged>(_onIndependentExerciseLogged);
    on<IndependentExerciseDeleted>(_onIndependentExerciseDeleted);
    on<ExerciseConfigUpdated>(_onConfigUpdated);
  }

  Future<void> _onLoaded(
      ExerciseLoaded event, Emitter<ExerciseState> emit) async {
    emit(state.copyWith(status: ExerciseStatus.loading));
    try {
      final plan = await _repository.getActivePlan();
      final dailyLog = await _repository.getDailyLog(event.date);
      final config = await _repository.getExerciseConfig();

      List<ExerciseRoutine> routines = [];
      final Map<int, List<ExerciseRoutineItem>> itemsByRoutine = {};
      if (plan != null) {
        routines = await _repository.getRoutinesForPlan(plan.id);
        for (final r in routines) {
          itemsByRoutine[r.id] = await _repository.getRoutineItemsOrdered(r.id);
        }
      }

      final sessions = await _repository.getSessionsForDate(event.date);
      final activeSession =
          sessions.isNotEmpty && sessions.first.gymLeftAt == null
              ? sessions.first
              : null;

      List<ExerciseSetLog> sets = [];
      if (activeSession != null) {
        sets = await _repository.getSessionSets(activeSession.id);
      }

      final monday = _mondayOf(DateTime.now().toUtc());
      final weeklyCardio = await _repository.getCardioLogsForWeek(monday);
      final weeklyStats = await _repository.getWeeklyStats(weeksBack: 8);

      emit(ExerciseState(
        status: ExerciseStatus.success,
        activePlan: plan,
        dailyLog: dailyLog,
        routines: routines,
        routineItemsByRoutine: itemsByRoutine,
        activeSession: activeSession,
        sessionSets: sets,
        recentSessions: sessions,
        weeklyCardioLogs: weeklyCardio,
        routineDaysGoal: config?.weeklyRoutineDaysGoal ?? 4,
        cardioDaysGoal: config?.weeklyCardioDaysGoal ?? 3,
        weeklyStats: weeklyStats,
      ));
    } catch (e) {
      emit(state.copyWith(status: ExerciseStatus.failure, error: e.toString()));
    }
  }

  Future<void> _onPlanLoaded(
      ExercisePlanLoaded event, Emitter<ExerciseState> emit) async {
    try {
      final plans = await _repository.getAllPlans();
      final active = await _repository.getActivePlan();
      emit(state.copyWith(allPlans: plans, activePlan: active));
    } catch (e) {
      emit(state.copyWith(status: ExerciseStatus.failure, error: e.toString()));
    }
  }

  Future<void> _onPlanActivated(
      ExercisePlanActivated event, Emitter<ExerciseState> emit) async {
    try {
      await _repository.activatePlan(event.planId);
      final plan = await _repository.getActivePlan();
      final plans = await _repository.getAllPlans();
      emit(state.copyWith(activePlan: plan, allPlans: plans));
    } catch (e) {
      emit(state.copyWith(status: ExerciseStatus.failure, error: e.toString()));
    }
  }

  Future<void> _onPlanCreated(
      ExercisePlanCreated event, Emitter<ExerciseState> emit) async {
    try {
      await _repository.createPlan(event.name);
      final plans = await _repository.getAllPlans();
      emit(state.copyWith(allPlans: plans));
    } catch (e) {
      emit(state.copyWith(status: ExerciseStatus.failure, error: e.toString()));
    }
  }

  Future<void> _onRoutineAdded(
      ExerciseRoutineAdded event, Emitter<ExerciseState> emit) async {
    try {
      await _repository.addRoutine(
        planId: event.planId,
        dayNumber: event.dayNumber,
        routineName: event.routineName,
      );
      add(ExerciseLoaded(date: DateTime.now()));
    } catch (e) {
      emit(state.copyWith(status: ExerciseStatus.failure, error: e.toString()));
    }
  }

  Future<void> _onRoutineMarkedDone(
      ExerciseRoutineMarkedDone event, Emitter<ExerciseState> emit) async {
    if (state.status != ExerciseStatus.success) return;
    try {
      await _repository.logDailyExercise(event.date, event.routineId);
      final log = await _repository.getDailyLog(event.date);
      emit(state.copyWith(dailyLog: log));
    } catch (e) {
      emit(state.copyWith(status: ExerciseStatus.failure, error: e.toString()));
    }
  }

  Future<void> _onRoutineItemAdded(
      ExerciseRoutineItemAdded event, Emitter<ExerciseState> emit) async {
    try {
      final itemId = await _repository.addRoutineItem(
        routineId: event.routineId,
        exerciseName: event.exerciseName,
        sets: event.sets,
        reps: event.reps,
        weightKg: event.weightKg,
        setType: event.setType,
        orderIndex: event.orderIndex,
      );
      if (event.setDefs.isNotEmpty) {
        await _repository.replaceRoutineSetDefs(
          routineItemId: itemId,
          defs: event.setDefs,
        );
      }
      final updatedItems =
          await _repository.getRoutineItemsOrdered(event.routineId);
      final updatedMap =
          Map<int, List<ExerciseRoutineItem>>.from(state.routineItemsByRoutine)
            ..[event.routineId] = updatedItems;
      emit(state.copyWith(routineItemsByRoutine: updatedMap));
    } catch (e) {
      emit(state.copyWith(status: ExerciseStatus.failure, error: e.toString()));
    }
  }

  Future<void> _onRoutineItemUpdated(
      ExerciseRoutineItemUpdated event, Emitter<ExerciseState> emit) async {
    try {
      await _repository.updateRoutineItem(
        itemId: event.itemId,
        exerciseName: event.exerciseName,
        sets: event.sets,
        reps: event.reps,
        weightKg: event.weightKg,
        setType: event.setType,
      );
      if (event.setDefs != null) {
        await _repository.replaceRoutineSetDefs(
          routineItemId: event.itemId,
          defs: event.setDefs!,
        );
      }
      final Map<int, List<ExerciseRoutineItem>> updatedMap = {};
      for (final routineId in state.routineItemsByRoutine.keys) {
        updatedMap[routineId] =
            await _repository.getRoutineItemsOrdered(routineId);
      }
      emit(state.copyWith(routineItemsByRoutine: updatedMap));
    } catch (e) {
      emit(state.copyWith(status: ExerciseStatus.failure, error: e.toString()));
    }
  }

  Future<void> _onRoutineItemDeleted(
      ExerciseRoutineItemDeleted event, Emitter<ExerciseState> emit) async {
    try {
      await _repository.deleteRoutineItem(event.itemId);
      final updatedItems =
          await _repository.getRoutineItemsOrdered(event.routineId);
      final updatedMap =
          Map<int, List<ExerciseRoutineItem>>.from(state.routineItemsByRoutine)
            ..[event.routineId] = updatedItems;
      emit(state.copyWith(routineItemsByRoutine: updatedMap));
    } catch (e) {
      emit(state.copyWith(status: ExerciseStatus.failure, error: e.toString()));
    }
  }

  Future<void> _onSessionStarted(
      ExerciseSessionStarted event, Emitter<ExerciseState> emit) async {
    if (state.status != ExerciseStatus.success) return;
    try {
      final sessionId = await _repository.startSession(event.date,
          routineId: event.routineId);
      final session = await _repository.getSession(sessionId);
      final sessions = await _repository.getSessionsForDate(event.date);
      emit(state.copyWith(
        activeSession: session,
        recentSessions: sessions,
        sessionSets: [],
        completedRoutineItemIds: {},
      ));
    } catch (e) {
      emit(state.copyWith(status: ExerciseStatus.failure, error: e.toString()));
    }
  }

  Future<void> _onSessionEnded(
      ExerciseSessionEnded event, Emitter<ExerciseState> emit) async {
    if (state.status != ExerciseStatus.success) return;
    try {
      await _repository.endSession(event.sessionId);
      final session = await _repository.getSession(event.sessionId);
      final weeklyStats = await _repository.getWeeklyStats(weeksBack: 8);
      emit(state.copyWith(
        activeSession: session,
        completedRoutineItemIds: {},
        weeklyStats: weeklyStats,
      ));
    } catch (e) {
      emit(state.copyWith(status: ExerciseStatus.failure, error: e.toString()));
    }
  }

  void _onItemCompleted(
      ExerciseItemCompleted event, Emitter<ExerciseState> emit) {
    final updated = Set<int>.from(state.completedRoutineItemIds)
      ..add(event.routineItemId);
    emit(state.copyWith(completedRoutineItemIds: updated));
  }

  Future<void> _onSetLogged(
      ExerciseSetLogged event, Emitter<ExerciseState> emit) async {
    if (state.status != ExerciseStatus.success) return;
    try {
      await _repository.logSet(
        sessionId: event.sessionId,
        exerciseName: event.exerciseName,
        setNumber: event.setNumber,
        reps: event.reps,
        weightKg: event.weightKg,
        setType: event.setType,
        dropOfSetId: event.dropOfSetId,
      );
      final sets = await _repository.getSessionSets(event.sessionId);
      emit(state.copyWith(sessionSets: sets));
    } catch (e) {
      emit(state.copyWith(status: ExerciseStatus.failure, error: e.toString()));
    }
  }

  Future<void> _onCardioLogged(
      CardioLogged event, Emitter<ExerciseState> emit) async {
    try {
      await _repository.logCardio(
        date: event.date,
        cardioType: event.cardioType,
        durationMinutes: event.durationMinutes,
        notes: event.notes,
      );
      final monday = _mondayOf(DateTime.now().toUtc());
      final cardioLogs = await _repository.getCardioLogsForWeek(monday);
      final weeklyStats = await _repository.getWeeklyStats(weeksBack: 8);
      emit(state.copyWith(
          weeklyCardioLogs: cardioLogs, weeklyStats: weeklyStats));
    } catch (e) {
      emit(state.copyWith(status: ExerciseStatus.failure, error: e.toString()));
    }
  }

  Future<void> _onCardioUpdated(
      CardioUpdated event, Emitter<ExerciseState> emit) async {
    try {
      await _repository.updateCardio(
        cardioId: event.cardioId,
        cardioType: event.cardioType,
        durationMinutes: event.durationMinutes,
        notes: event.notes,
      );
      final monday = _mondayOf(DateTime.now().toUtc());
      final cardioLogs = await _repository.getCardioLogsForWeek(monday);
      emit(state.copyWith(weeklyCardioLogs: cardioLogs));
    } catch (e) {
      emit(state.copyWith(status: ExerciseStatus.failure, error: e.toString()));
    }
  }

  Future<void> _onCardioDeleted(
      CardioDeleted event, Emitter<ExerciseState> emit) async {
    try {
      await _repository.deleteCardio(event.cardioId);
      final monday = _mondayOf(DateTime.now().toUtc());
      final cardioLogs = await _repository.getCardioLogsForWeek(monday);
      final weeklyStats = await _repository.getWeeklyStats(weeksBack: 8);
      emit(state.copyWith(
          weeklyCardioLogs: cardioLogs, weeklyStats: weeklyStats));
    } catch (e) {
      emit(state.copyWith(status: ExerciseStatus.failure, error: e.toString()));
    }
  }

  Future<void> _onIndependentExerciseLogged(
      IndependentExerciseLogged event, Emitter<ExerciseState> emit) async {
    try {
      final sessionId =
          await _repository.startSession(event.date, routineId: null);
      await _repository.logSet(
        sessionId: sessionId,
        exerciseName: event.exerciseName,
        setNumber: 1,
        reps: event.reps,
        weightKg: event.weightKg,
        setType: 'normal',
      );
      await _repository.endSession(sessionId);
      final sessions = await _repository.getSessionsForDate(event.date);
      emit(state.copyWith(recentSessions: sessions));
    } catch (e) {
      emit(state.copyWith(status: ExerciseStatus.failure, error: e.toString()));
    }
  }

  Future<void> _onIndependentExerciseDeleted(
      IndependentExerciseDeleted event, Emitter<ExerciseState> emit) async {
    try {
      await _repository.deleteSession(event.sessionId);
      final sessions = await _repository.getSessionsForDate(DateTime.now());
      emit(state.copyWith(recentSessions: sessions));
    } catch (e) {
      emit(state.copyWith(status: ExerciseStatus.failure, error: e.toString()));
    }
  }

  Future<void> _onConfigUpdated(
      ExerciseConfigUpdated event, Emitter<ExerciseState> emit) async {
    try {
      await _repository.updateExerciseConfig(
        weeklyRoutineDaysGoal: event.weeklyRoutineDaysGoal,
        weeklyCardioDaysGoal: event.weeklyCardioDaysGoal,
        cardioMinutesGoal: event.cardioMinutesGoal,
      );
      final config = await _repository.getExerciseConfig();
      emit(state.copyWith(
        routineDaysGoal:
            config?.weeklyRoutineDaysGoal ?? state.routineDaysGoal,
        cardioDaysGoal: config?.weeklyCardioDaysGoal ?? state.cardioDaysGoal,
      ));
    } catch (e) {
      emit(state.copyWith(status: ExerciseStatus.failure, error: e.toString()));
    }
  }

  DateTime _mondayOf(DateTime date) {
    final d = date.toUtc();
    return DateTime.utc(d.year, d.month, d.day)
        .subtract(Duration(days: d.weekday - 1));
  }
}
