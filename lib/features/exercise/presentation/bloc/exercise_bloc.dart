import 'package:kiolog/core/domain/day.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:kiolog/core/database/app_database.dart';
import 'package:kiolog/features/exercise/domain/models/independent_exercise_log.dart';
import 'package:kiolog/features/exercise/domain/models/plan_compliance_stat.dart';
import 'package:kiolog/features/exercise/domain/models/weekly_stat.dart';
import '../../domain/repositories/exercise_repository.dart';
import 'exercise_event.dart';
import 'exercise_state.dart';

class ExerciseBloc extends Bloc<ExerciseEvent, ExerciseState> {
  final ExerciseRepository _repository;

  ExerciseBloc(this._repository) : super(const ExerciseState()) {
    on<ExerciseLoaded>(_onLoaded);
    on<ExercisePlanLoaded>(_onPlanLoaded);
    on<ExercisePlanHistoryLoaded>(_onPlanHistoryLoaded);
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
    on<ExerciseSessionResumed>(_onSessionResumed);
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

      final monday = _mondayOf(todayUtcDay());
      final results = await Future.wait([
        _repository.getCardioLogsForWeek(monday),
        _repository.getCompletedRoutineSessionsForWeek(monday),
        _repository.getIndependentSessionsForWeek(monday),
        _repository.getWeeklyStats(weeksBack: 8),
      ]);
      final weeklyCardio = results[0] as List<CardioLog>;
      final completedSessions = results[1] as List<ExerciseSessionLog>;
      final independentLogs = results[2] as List<IndependentExerciseLog>;
      final weeklyStats = results[3] as List<WeeklyStat>;

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
        completedRoutineSessionsThisWeek: completedSessions,
        weeklyIndependentLogs: independentLogs,
        routineDaysGoal: config?.weeklyRoutineDaysGoal ?? 4,
        cardioDaysGoal: config?.weeklyCardioDaysGoal ?? 3,
        cardioMinutesGoal: config?.cardioMinutesGoal ?? 30,
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

  Future<void> _onPlanHistoryLoaded(
      ExercisePlanHistoryLoaded event, Emitter<ExerciseState> emit) async {
    emit(state.copyWith(status: ExerciseStatus.loading));
    try {
      final history = await _repository.getPlanHistory();
      emit(state.copyWith(status: ExerciseStatus.success, planHistory: history));
    } catch (e) {
      emit(state.copyWith(status: ExerciseStatus.failure, error: e.toString()));
    }
  }

  Future<void> _onPlanActivated(
      ExercisePlanActivated event, Emitter<ExerciseState> emit) async {
    try {
      await _repository.activatePlan(event.planId);
      final results = await Future.wait([
        _repository.getActivePlan(),
        _repository.getAllPlans(),
        _repository.getPlanHistory(),
      ]);
      emit(state.copyWith(
        activePlan: results[0] as ExercisePlan?,
        allPlans: results[1] as List<ExercisePlan>,
        planHistory: results[2] as List<PlanComplianceStat>,
      ));
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
        repsLabel: event.repsLabel,
        notes: event.notes,
        referenceUrl: event.referenceUrl,
        mediaId: event.mediaId,
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
        repsLabel: event.repsLabel,
        notes: event.notes,
        referenceUrl: event.referenceUrl,
        mediaId: event.mediaId,
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
        sessionSetDefs: const {},
        sessionHistorical: const {},
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
      final monday = _mondayOf(todayUtcDay());
      final completedSessions =
          await _repository.getCompletedRoutineSessionsForWeek(monday);
      final sessions = await _repository.getSessionsForDate(DateTime.now());
      final weeklyStats = await _repository.getWeeklyStats(weeksBack: 8);
      emit(state.copyWith(
        activeSession: session,
        recentSessions: sessions,
        completedRoutineSessionsThisWeek: completedSessions,
        completedRoutineItemIds: {},
        sessionSetDefs: const {},
        sessionHistorical: const {},
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
      final monday = _mondayOf(todayUtcDay());
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
      final monday = _mondayOf(todayUtcDay());
      final cardioLogs = await _repository.getCardioLogsForWeek(monday);
      final weeklyStats = await _repository.getWeeklyStats(weeksBack: 8);
      emit(state.copyWith(weeklyCardioLogs: cardioLogs, weeklyStats: weeklyStats));
    } catch (e) {
      emit(state.copyWith(status: ExerciseStatus.failure, error: e.toString()));
    }
  }

  Future<void> _onCardioDeleted(
      CardioDeleted event, Emitter<ExerciseState> emit) async {
    try {
      await _repository.deleteCardio(event.cardioId);
      final monday = _mondayOf(todayUtcDay());
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
      for (var i = 1; i <= event.sets; i++) {
        await _repository.logSet(
          sessionId: sessionId,
          exerciseName: event.exerciseName,
          setNumber: i,
          reps: event.reps,
          weightKg: event.weightKg,
          setType: 'normal',
        );
      }
      await _repository.endSession(sessionId);
      final monday = _mondayOf(todayUtcDay());
      final sessions = await _repository.getSessionsForDate(event.date);
      final logs = await _repository.getIndependentSessionsForWeek(monday);
      emit(state.copyWith(recentSessions: sessions, weeklyIndependentLogs: logs));
    } catch (e) {
      emit(state.copyWith(status: ExerciseStatus.failure, error: e.toString()));
    }
  }

  Future<void> _onIndependentExerciseDeleted(
      IndependentExerciseDeleted event, Emitter<ExerciseState> emit) async {
    try {
      await _repository.deleteSession(event.sessionId);
      final monday = _mondayOf(todayUtcDay());
      final sessions = await _repository.getSessionsForDate(DateTime.now());
      final logs = await _repository.getIndependentSessionsForWeek(monday);
      emit(state.copyWith(recentSessions: sessions, weeklyIndependentLogs: logs));
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
        cardioMinutesGoal:
            config?.cardioMinutesGoal ?? state.cardioMinutesGoal,
      ));
    } catch (e) {
      emit(state.copyWith(status: ExerciseStatus.failure, error: e.toString()));
    }
  }

  Future<void> _onSessionResumed(
      ExerciseSessionResumed event, Emitter<ExerciseState> emit) async {
    if (state.status != ExerciseStatus.success) return;
    if (state.activeSession?.id != event.sessionId) return;
    try {
      final routineId = state.activeSession?.routineId;
      final items = routineId != null
          ? (state.routineItemsByRoutine[routineId] ?? <ExerciseRoutineItem>[])
          : <ExerciseRoutineItem>[];

      final setDefs = <int, List<ExerciseRoutineSetDef>>{};
      final historical = <String, List<ExerciseSetLog>>{};

      final futures = await Future.wait(
        items.map((item) => Future.wait([
          _repository.getRoutineSetDefs(item.id),
          _repository.getLastSessionSetsForExercise(item.exerciseName),
        ])),
      );
      for (var i = 0; i < items.length; i++) {
        setDefs[items[i].id] = futures[i][0] as List<ExerciseRoutineSetDef>;
        historical[items[i].exerciseName] =
            futures[i][1] as List<ExerciseSetLog>;
      }

      final sets = await _repository.getSessionSets(event.sessionId);

      // Lo marcado en memoria se pierde si la pantalla de Ejercicio se
      // reconstruye; un ejercicio con todas sus series guardadas sigue
      // contando como hecho.
      final completed = Set<int>.from(state.completedRoutineItemIds);
      for (final item in items) {
        final planned = setDefs[item.id]!.isNotEmpty
            ? setDefs[item.id]!.where((d) => d.dropOfSetNumber == null).length
            : item.sets;
        final saved = sets
            .where((s) =>
                s.exerciseName == item.exerciseName && s.setType != 'drop')
            .length;
        if (planned > 0 && saved >= planned) completed.add(item.id);
      }

      emit(state.copyWith(
        sessionSetDefs: setDefs,
        sessionHistorical: historical,
        sessionSets: sets,
        completedRoutineItemIds: completed,
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
