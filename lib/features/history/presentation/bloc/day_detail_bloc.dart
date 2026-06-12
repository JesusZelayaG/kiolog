import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:kiolog/core/dao/exercise_dao.dart';
import 'package:kiolog/core/dao/nutrition_dao.dart';
import 'package:kiolog/core/dao/water_sleep_dao.dart';
import 'day_detail_event.dart';
import 'day_detail_state.dart';

class DayDetailBloc extends Bloc<DayDetailEvent, DayDetailState> {
  final WaterSleepDao _waterSleepDao;
  final NutritionDao _nutritionDao;
  final ExerciseDao _exerciseDao;

  DayDetailBloc(this._waterSleepDao, this._nutritionDao, this._exerciseDao)
      : super(DayDetailState(date: DateTime.utc(0))) {
    on<DayDetailLoaded>(_onLoaded);
  }

  Future<void> _onLoaded(
    DayDetailLoaded event,
    Emitter<DayDetailState> emit,
  ) async {
    emit(state.copyWith(status: DayDetailStatus.loading, date: event.date));
    try {
      final waterLogs = await _waterSleepDao.getDailyWaterLogs(event.date);
      final mealLogs = await _nutritionDao.getDailyMealLogs(event.date);
      final sessions = await _exerciseDao.getSessionsForDate(event.date);
      final exerciseLog = await _exerciseDao.getDailyExerciseLog(event.date);

      final optionIds = mealLogs
          .map((l) => l.planOptionId)
          .whereType<int>()
          .toList();
      final options = await _nutritionDao.getMealPlanOptionsByIds(optionIds);
      final mealOptions = {for (final o in options) o.id: o};

      emit(state.copyWith(
        status: DayDetailStatus.success,
        date: event.date,
        waterLogs: waterLogs,
        mealLogs: mealLogs,
        mealOptions: mealOptions,
        exerciseSessions: sessions,
        exerciseLog: exerciseLog,
        clearExerciseLog: exerciseLog == null,
        error: null,
      ));
    } catch (e) {
      emit(state.copyWith(
          status: DayDetailStatus.failure, error: e.toString()));
    }
  }
}
