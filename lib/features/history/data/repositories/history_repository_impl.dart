import 'package:kiolog/core/dao/exercise_dao.dart';
import 'package:kiolog/core/dao/nutrition_dao.dart';
import 'package:kiolog/core/dao/water_sleep_dao.dart';
import '../../domain/repositories/history_repository.dart';

class HistoryRepositoryImpl implements HistoryRepository {
  final WaterSleepDao _waterSleepDao;
  final NutritionDao _nutritionDao;
  final ExerciseDao _exerciseDao;

  HistoryRepositoryImpl(
    this._waterSleepDao,
    this._nutritionDao,
    this._exerciseDao,
  );

  DateTime _dateOnly(DateTime date) =>
      DateTime.utc(date.year, date.month, date.day);

  @override
  Future<List<DaySummary>> getMonthSummary(DateTime month) async {
    final start = DateTime.utc(month.year, month.month, 1);
    final end = DateTime.utc(month.year, month.month + 1, 1);
    final days = <DaySummary>[];

    for (var d = start;
        d.isBefore(end);
        d = d.add(const Duration(days: 1))) {
      final waterLogs = await _waterSleepDao.getDailyWaterLogs(d);
      final sleepLogs = await _waterSleepDao.getSleepLogsForDate(d);
      final mealLogs = await _nutritionDao.getDailyMealLogs(d);
      final exerciseLog = await _exerciseDao.getDailyExerciseLog(d);
      final sessions = await _exerciseDao.getSessionsForDate(d);

      days.add(DaySummary(
        date: d,
        hasWater: waterLogs.isNotEmpty,
        hasSleep: sleepLogs.isNotEmpty,
        hasMeals: mealLogs.isNotEmpty,
        hasExercise: (exerciseLog?.completed ?? false) || sessions.isNotEmpty,
      ));
    }

    return days;
  }
}
