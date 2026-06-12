import 'package:kiolog/core/dao/config_dao.dart';
import 'package:kiolog/core/dao/exercise_dao.dart';
import 'package:kiolog/core/dao/measurements_dao.dart';
import 'package:kiolog/core/dao/nutrition_dao.dart';
import 'package:kiolog/core/dao/water_sleep_dao.dart';
import 'package:kiolog/core/database/app_database.dart';
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
      if (current.weekday <= 5) exerciseTotalDays++;

      final sleepLogs = await _waterSleepDao.getSleepLogsForDate(current);
      if (sleepLogs.isNotEmpty) {
        sleepTotal += sleepLogs.fold(0.0, (s, l) => s + l.hoursCalculated);
        sleepDays++;
      }

      current = current.add(const Duration(days: 1));
    }

    final results = await Future.wait([
      _measurementsDao.getWeightLogs(start, end),
      _measurementsDao.getLatestMeasurement(),
      _buildNutritionDetail(start, end),
      _buildExerciseDetail(start, end),
    ]);

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
      weightLogs: results[0] as List<WeightLog>,
      latestMeasurement: results[1] as Measurement?,
      nutritionDetail: results[2] as NutritionReportData?,
      exerciseDetail: results[3] as ExerciseReportData?,
    );
  }

  Future<NutritionReportData?> _buildNutritionDetail(
      DateTime start, DateTime end) async {
    final plan = await _nutritionDao.getActiveMealPlan();
    if (plan == null) return null;

    final endExclusive =
        _dateOnly(end).add(const Duration(days: 1));
    final logs =
        await _nutritionDao.getLogsInRange(_dateOnly(start), endExclusive);
    final options = await _nutritionDao.getAllPlanOptions(plan.id);

    if (options.isEmpty) {
      return NutritionReportData(planName: plan.name, mealFrequencies: const []);
    }

    final countMap = <int, int>{};
    for (final log in logs) {
      if (log.planOptionId != null) {
        countMap[log.planOptionId!] = (countMap[log.planOptionId!] ?? 0) + 1;
      }
    }

    const mealTypeOrder = ['desayuno', 'almuerzo', 'cena', 'snack'];
    final entries = options
        .where((o) => (countMap[o.id] ?? 0) > 0)
        .map((o) => MealFrequencyEntry(
              mealType: o.mealType,
              description: o.description,
              count: countMap[o.id]!,
            ))
        .toList()
      ..sort((a, b) {
        final ai = mealTypeOrder.indexOf(a.mealType);
        final bi = mealTypeOrder.indexOf(b.mealType);
        final typeComp = (ai < 0 ? 99 : ai).compareTo(bi < 0 ? 99 : bi);
        if (typeComp != 0) return typeComp;
        return b.count.compareTo(a.count);
      });

    return NutritionReportData(planName: plan.name, mealFrequencies: entries);
  }

  Future<ExerciseReportData?> _buildExerciseDetail(
      DateTime start, DateTime end) async {
    final plan = await _exerciseDao.getActiveExercisePlan();
    if (plan == null) return null;

    final config = await _exerciseDao.getExerciseConfig();
    final daysGoal = config?.weeklyRoutineDaysGoal ?? 4;

    final routines = await _exerciseDao.getRoutinesForPlan(plan.id);
    final routineIds = routines.map((r) => r.id).toList();

    final startDay = _dateOnly(start);
    final endDay = _dateOnly(end);
    final endExclusive = endDay.add(const Duration(days: 1));

    final routineSessions = await _exerciseDao.getCompletedSessionsInPeriod(
      routineIds,
      startDay,
      endExclusive,
    );

    final weeklyCompliance = _buildWeeklyCompliance(
      sessions: routineSessions,
      rangeStart: startDay,
      rangeEnd: endDay,
      daysGoal: daysGoal,
    );

    final uniqueRoutineDays = routineSessions
        .map((s) => DateTime.utc(s.date.year, s.date.month, s.date.day))
        .toSet();

    final allSessions =
        await _exerciseDao.getSessionsInRange(startDay, endDay);
    final freeExerciseCount =
        allSessions.where((s) => s.routineId == null).length;

    final cardioLogs =
        await _exerciseDao.getCardioLogsInRange(startDay, endDay);

    return ExerciseReportData(
      planName: plan.name,
      weeklyCompliance: weeklyCompliance,
      totalRoutineSessions: uniqueRoutineDays.length,
      cardioSessionsCount: cardioLogs.length,
      freeExerciseCount: freeExerciseCount,
    );
  }

  List<WeeklyComplianceEntry> _buildWeeklyCompliance({
    required List<ExerciseSessionLog> sessions,
    required DateTime rangeStart,
    required DateTime rangeEnd,
    required int daysGoal,
  }) {
    // Monday on or before rangeStart
    final firstMonday =
        rangeStart.subtract(Duration(days: rangeStart.weekday - 1));

    final weeks = <WeeklyComplianceEntry>[];
    var weekStart = firstMonday;
    var weekIndex = 1;

    while (!weekStart.isAfter(rangeEnd)) {
      final weekEnd = weekStart.add(const Duration(days: 7));
      final uniqueDays = sessions
          .where((s) {
            final d = DateTime.utc(s.date.year, s.date.month, s.date.day);
            return !d.isBefore(weekStart) && d.isBefore(weekEnd);
          })
          .map((s) => DateTime.utc(s.date.year, s.date.month, s.date.day))
          .toSet();

      weeks.add(WeeklyComplianceEntry(
        weekLabel: 'Sem $weekIndex',
        daysDone: uniqueDays.length,
        daysGoal: daysGoal,
      ));

      weekStart = weekEnd;
      weekIndex++;
    }

    return weeks;
  }
}
