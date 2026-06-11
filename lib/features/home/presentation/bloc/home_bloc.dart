import 'package:flutter_bloc/flutter_bloc.dart';
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
  }

  Future<void> _onLoaded(HomeLoaded event, Emitter<HomeState> emit) async {
    emit(state.copyWith(status: HomeStatus.loading));
    try {
      final waterTotal = await _waterRepository.getDailyTotalMl(event.date);
      final waterConfig = await _waterRepository.getConfig();

      final sleepLogs = await _sleepRepository.getSleepLogsForDate(event.date);
      final sleepLog = sleepLogs.firstOrNull;

      final mealLogs = await _nutritionRepository.getDailyLogs(event.date);

      final dailyExercise = await _exerciseRepository.getDailyLog(event.date);
      final sessions = await _exerciseRepository.getSessionsForDate(event.date);

      emit(state.copyWith(
        status: HomeStatus.success,
        dailyWaterTotalMl: waterTotal,
        dailyWaterGoalMl: waterConfig?.dailyGoalMl ?? 3000,
        sleepHours: sleepLog?.hoursCalculated,
        mealsLogged: mealLogs.length,
        exerciseRoutineDone: dailyExercise?.completed ?? false,
        hasGymSession: sessions.isNotEmpty,
      ));
    } catch (e) {
      emit(state.copyWith(status: HomeStatus.failure, error: e.toString()));
    }
  }
}
