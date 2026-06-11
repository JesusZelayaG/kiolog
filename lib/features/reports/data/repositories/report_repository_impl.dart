import 'package:kiolog/core/dao/config_dao.dart';
import 'package:kiolog/core/dao/exercise_dao.dart';
import 'package:kiolog/core/dao/measurements_dao.dart';
import 'package:kiolog/core/dao/nutrition_dao.dart';
import 'package:kiolog/core/dao/water_sleep_dao.dart';
import '../../domain/repositories/report_repository.dart';

class ReportRepositoryImpl implements ReportRepository {
  final WaterSleepDao _waterSleepDao;
  final NutritionDao _nutritionDao;
  final ExerciseDao _exerciseDao;
  final MeasurementsDao _measurementsDao;
  final ConfigDao _configDao;

  ReportRepositoryImpl(
    this._waterSleepDao,
    this._nutritionDao,
    this._exerciseDao,
    this._measurementsDao,
    this._configDao,
  );

  DateTime _dateOnly(DateTime date) =>
      DateTime.utc(date.year, date.month, date.day);

  @override
  Future<ReportData> generateReport(DateTime start, DateTime end) async {
    final waterConfig = await _configDao.getWaterConfig();
    final dailyGoal = waterConfig?.dailyGoalMl ?? 3000;

    int waterGoalDays = 0;
    int waterTotalDays = 0;
    int mealsLogged = 0;
    int mealsTotal = 0;
    int exerciseDays = 0;
    int exerciseTotalDays = 0;
    double sleepTotal = 0;
    int sleepDays = 0;

    var current = _dateOnly(start);
    final last = _dateOnly(end);

    while (!current.isAfter(last)) {
      final water = await _waterSleepDao.getDailyWaterTotalMl(current);
      if (water > 0) waterTotalDays++;
      if (water >= dailyGoal) waterGoalDays++;

      final meals = await _nutritionDao.getDailyMealLogs(current);
      mealsLogged += meals.length;
      mealsTotal += 4;

      final exerciseLog = await _exerciseDao.getDailyExerciseLog(current);
      final sessions = await _exerciseDao.getSessionsForDate(current);
      if (exerciseLog?.completed == true || sessions.isNotEmpty) {
        exerciseDays++;
      }
      // Count only weekdays (Mon-Fri) as potential exercise days for simplicity
      if (current.weekday <= 5) exerciseTotalDays++;

      final sleepLogs = await _waterSleepDao.getSleepLogsForDate(current);
      if (sleepLogs.isNotEmpty) {
        sleepTotal += sleepLogs.fold(0.0, (s, l) => s + l.hoursCalculated);
        sleepDays++;
      }

      current = current.add(const Duration(days: 1));
    }

    final weightLogs = await _measurementsDao.getWeightLogs(start, end);
    final latestMeasurement = await _measurementsDao.getLatestMeasurement();

    return ReportData(
      start: start,
      end: end,
      waterGoalDays: waterGoalDays,
      waterTotalDays: waterTotalDays,
      mealsLogged: mealsLogged,
      mealsTotal: mealsTotal,
      exerciseDays: exerciseDays,
      exerciseTotalDays: exerciseTotalDays,
      sleepAverage: sleepDays > 0 ? sleepTotal / sleepDays : null,
      weightLogs: weightLogs,
      latestMeasurement: latestMeasurement,
    );
  }
}
