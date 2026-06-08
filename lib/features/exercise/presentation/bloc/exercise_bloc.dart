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
    on<ExerciseRoutineMarkedDone>(_onRoutineMarkedDone);
    on<ExerciseSessionStarted>(_onSessionStarted);
    on<ExerciseSessionEnded>(_onSessionEnded);
    on<ExerciseSetLogged>(_onSetLogged);
  }

  Future<void> _onLoaded(ExerciseLoaded event, Emitter<ExerciseState> emit) async {
    emit(state.copyWith(status: ExerciseStatus.loading));
    try {
      final plan = await _repository.getActivePlan();
      final dailyLog = await _repository.getDailyLog(event.date);
      final dayOfWeek = event.date.weekday;

      ExerciseRoutine? routine;
      List<ExerciseRoutineItem> items = [];
      if (plan != null) {
        routine = await _repository.getRoutineForDay(plan.id, dayOfWeek);
        if (routine != null) {
          items = await _repository.getRoutineItems(routine.id);
        }
      }

      final sessions = await _repository.getSessionsForDate(event.date);
      final activeSession = sessions.isNotEmpty && sessions.first.gymLeftAt == null
          ? sessions.first
          : null;

      List<ExerciseSetLog> sets = [];
      if (activeSession != null) {
        sets = await _repository.getSessionSets(activeSession.id);
      }

      emit(state.copyWith(
        status: ExerciseStatus.success,
        activePlan: plan,
        dailyLog: dailyLog,
        todayRoutine: routine,
        routineItems: items,
        activeSession: activeSession,
        sessionSets: sets,
        recentSessions: sessions,
      ));
    } catch (e) {
      emit(state.copyWith(status: ExerciseStatus.failure, error: e.toString()));
    }
  }

  Future<void> _onPlanLoaded(
    ExercisePlanLoaded event,
    Emitter<ExerciseState> emit,
  ) async {
    try {
      final plans = await _repository.getAllPlans();
      final active = await _repository.getActivePlan();
      emit(state.copyWith(allPlans: plans, activePlan: active));
    } catch (e) {
      emit(state.copyWith(status: ExerciseStatus.failure, error: e.toString()));
    }
  }

  Future<void> _onPlanActivated(
    ExercisePlanActivated event,
    Emitter<ExerciseState> emit,
  ) async {
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
    ExercisePlanCreated event,
    Emitter<ExerciseState> emit,
  ) async {
    try {
      await _repository.createPlan(event.name);
      final plans = await _repository.getAllPlans();
      emit(state.copyWith(allPlans: plans));
    } catch (e) {
      emit(state.copyWith(status: ExerciseStatus.failure, error: e.toString()));
    }
  }

  Future<void> _onRoutineMarkedDone(
    ExerciseRoutineMarkedDone event,
    Emitter<ExerciseState> emit,
  ) async {
    if (state.status != ExerciseStatus.success) return;
    try {
      await _repository.logDailyExercise(event.date, event.routineId);
      final log = await _repository.getDailyLog(event.date);
      emit(state.copyWith(dailyLog: log));
    } catch (e) {
      emit(state.copyWith(status: ExerciseStatus.failure, error: e.toString()));
    }
  }

  Future<void> _onSessionStarted(
    ExerciseSessionStarted event,
    Emitter<ExerciseState> emit,
  ) async {
    if (state.status != ExerciseStatus.success) return;
    try {
      final sessionId = await _repository.startSession(event.date);
      final session = await _repository.getSession(sessionId);
      final sessions = await _repository.getSessionsForDate(event.date);
      emit(state.copyWith(
        activeSession: session,
        recentSessions: sessions,
        sessionSets: [],
      ));
    } catch (e) {
      emit(state.copyWith(status: ExerciseStatus.failure, error: e.toString()));
    }
  }

  Future<void> _onSessionEnded(
    ExerciseSessionEnded event,
    Emitter<ExerciseState> emit,
  ) async {
    if (state.status != ExerciseStatus.success) return;
    try {
      await _repository.endSession(event.sessionId);
      final session = await _repository.getSession(event.sessionId);
      emit(state.copyWith(activeSession: session));
    } catch (e) {
      emit(state.copyWith(status: ExerciseStatus.failure, error: e.toString()));
    }
  }

  Future<void> _onSetLogged(
    ExerciseSetLogged event,
    Emitter<ExerciseState> emit,
  ) async {
    if (state.status != ExerciseStatus.success) return;
    try {
      await _repository.logSet(
        sessionId: event.sessionId,
        exerciseName: event.exerciseName,
        setNumber: event.setNumber,
        reps: event.reps,
        weightKg: event.weightKg,
      );
      final sets = await _repository.getSessionSets(event.sessionId);
      emit(state.copyWith(sessionSets: sets));
    } catch (e) {
      emit(state.copyWith(status: ExerciseStatus.failure, error: e.toString()));
    }
  }
}
