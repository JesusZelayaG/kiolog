import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:kiolog/core/database/app_database.dart';
import 'package:kiolog/core/domain/day.dart';
import 'package:kiolog/features/exercise/domain/repositories/exercise_repository.dart';
import 'package:kiolog/features/nutrition/domain/repositories/nutrition_repository.dart';
import 'package:kiolog/features/sleep/domain/repositories/sleep_repository.dart';
import 'package:kiolog/features/water/domain/repositories/water_repository.dart';
import 'home_event.dart';
import 'home_state.dart';

class HomeBloc extends Bloc<HomeEvent, HomeState> {
  final WaterRepository _waterRepository;
  final SleepRepository _sleepRepository;
  final NutritionRepository _nutritionRepository;
  final ExerciseRepository _exerciseRepository;

  HomeBloc({
    required WaterRepository waterRepository,
    required SleepRepository sleepRepository,
    required NutritionRepository nutritionRepository,
    required ExerciseRepository exerciseRepository,
  })  : _waterRepository = waterRepository,
        _sleepRepository = sleepRepository,
        _nutritionRepository = nutritionRepository,
        _exerciseRepository = exerciseRepository,
        super(const HomeState()) {
    on<HomeLoaded>(_onLoaded);
    on<HomeWaterAdded>(_onWaterAdded);
  }

  Future<void> _onLoaded(HomeLoaded event, Emitter<HomeState> emit) async {
    // Al recargar se dejan los datos actuales en pantalla, sin parpadeo.
    if (state.status != HomeStatus.success) {
      emit(state.copyWith(status: HomeStatus.loading));
    }
    try {
      emit(await _load(event.date));
    } catch (e) {
      emit(state.copyWith(status: HomeStatus.failure, error: e.toString()));
    }
  }

  Future<void> _onWaterAdded(HomeWaterAdded event, Emitter<HomeState> emit) async {
    final now = DateTime.now();
    await _waterRepository.addWater(now, event.amountMl);
    final total = await _waterRepository.getDailyTotalMl(now);
    emit(state.copyWith(dailyWaterTotalMl: total));
  }

  Future<HomeState> _load(DateTime date) async {
    final waterTotal = await _waterRepository.getDailyTotalMl(date);
    final waterConfig = await _waterRepository.getConfig();

    final sleepLogs = await _sleepRepository.getSleepLogsForDate(date);
    final weekStart = DateTime(date.year, date.month, date.day).subtract(const Duration(days: 6));
    final weekLogs = await _sleepRepository.getSleepLogsInRange(weekStart, date);
    final sleepWeek = List<double>.filled(7, 0);
    for (final log in weekLogs) {
      final i = storedDay(log.date).difference(weekStart).inDays;
      if (i >= 0 && i < 7) sleepWeek[i] += log.hoursCalculated;
    }

    final meals = await _loadMeals(date);
    final exercise = await _loadExercise(date);

    return HomeState(
      status: HomeStatus.success,
      dailyWaterTotalMl: waterTotal,
      dailyWaterGoalMl: waterConfig?.dailyGoalMl ?? 3000,
      sleepHours: sleepLogs.firstOrNull?.hoursCalculated,
      sleepWeek: sleepWeek,
      mealsLogged: meals.logged,
      totalMeals: meals.total,
      nextMeal: meals.next,
      exerciseRoutineDone: exercise.done,
      hasGymSession: exercise.inSession,
      routineName: exercise.name,
      routineDay: exercise.day,
      routineExercises: exercise.items,
      weekRoutineDays: exercise.weekDays,
      weekRoutineGoal: exercise.goal,
    );
  }

  Future<({int logged, int total, String? next})> _loadMeals(DateTime date) async {
    final logs = await _nutritionRepository.getDailyLogs(date);
    final plan = await _nutritionRepository.getActivePlan();
    if (plan == null) return (logged: logs.length, total: 4, next: null);
    // Los tiempos de comida, en el orden en que se cargó el plan.
    final mealTypes = <String>[];
    for (final option in await _nutritionRepository.getAllPlanOptions(plan.id)) {
      if (!mealTypes.contains(option.mealType)) mealTypes.add(option.mealType);
    }
    final done = logs.map((l) => l.mealType).toSet();
    return (
      logged: logs.length,
      total: plan.dailyMealGoal,
      next: mealTypes.where((m) => !done.contains(m)).firstOrNull,
    );
  }

  Future<({bool done, bool inSession, String? name, int? day, int items, int weekDays, int goal})>
      _loadExercise(DateTime date) async {
    final daily = await _exerciseRepository.getDailyLog(date);
    final sessions = await _exerciseRepository.getSessionsForDate(date);
    final config = await _exerciseRepository.getExerciseConfig();
    final today = utcDayOf(date);
    final monday = today.subtract(Duration(days: today.weekday - 1));
    final week = await _exerciseRepository.getCompletedRoutineSessionsForWeek(monday);
    final doneIds = week.map((s) => s.routineId).whereType<int>().toSet();
    final weekDays = week.map((s) => storedDay(s.date)).toSet().length;
    final doneToday = (daily?.completed ?? false) ||
        sessions.any((s) => s.routineId != null && s.gymLeftAt != null);
    final open = sessions.where((s) => s.gymLeftAt == null).firstOrNull;

    final plan = await _exerciseRepository.getActivePlan();
    final routines = plan == null ? <ExerciseRoutine>[] : await _exerciseRepository.getRoutinesForPlan(plan.id);
    // En sesión o ya hecha hoy: esa rutina. Si no, la primera pendiente de la semana.
    final todayRoutineId = open?.routineId ??
        sessions.where((s) => s.routineId != null).firstOrNull?.routineId;
    final routine = routines.where((r) => r.id == todayRoutineId).firstOrNull ??
        routines.where((r) => !doneIds.contains(r.id)).firstOrNull ??
        routines.firstOrNull;
    final items = routine == null ? 0 : (await _exerciseRepository.getRoutineItems(routine.id)).length;

    return (
      done: doneToday,
      inSession: open != null,
      name: routine?.routineName,
      day: routine?.dayNumber,
      items: items,
      weekDays: weekDays,
      goal: config?.weeklyRoutineDaysGoal ?? 4,
    );
  }
}
