import 'package:kiolog/core/dao/config_dao.dart';
import 'package:kiolog/core/dao/exercise_dao.dart';
import 'package:kiolog/core/dao/measurements_dao.dart';
import 'package:kiolog/core/dao/nutrition_dao.dart';
import 'package:kiolog/core/dao/user_profile_dao.dart';
import 'package:kiolog/core/dao/water_sleep_dao.dart';
import 'package:kiolog/core/database/app_database.dart';
import '../../domain/repositories/report_repository.dart';

class ReportRepositoryImpl implements ReportRepository {
  final WaterSleepDao _waterSleepDao;
  final NutritionDao _nutritionDao;
  final ExerciseDao _exerciseDao;
  final MeasurementsDao _measurementsDao;
  final ConfigDao _configDao;
  final UserProfileDao? _profileDao;

  ReportRepositoryImpl(
    this._waterSleepDao,
    this._nutritionDao,
    this._exerciseDao,
    this._measurementsDao,
    this._configDao, {
    UserProfileDao? profileDao,
  }) : _profileDao = profileDao;

  DateTime _dateOnly(DateTime date) =>
      DateTime.utc(date.year, date.month, date.day);

  @override
  Future<ReportData> generateReport(DateTime start, DateTime end) async {
    final waterConfig = await _configDao.getWaterConfig();
    final exerciseConfig = await _exerciseDao.getExerciseConfig();
    final mealPlan = await _nutritionDao.getActiveMealPlan();
    final goals = ReportGoals(
      waterMl: waterConfig?.dailyGoalMl ?? 3000,
      mealsPerDay: mealPlan?.dailyMealGoal ?? 4,
      routineDaysPerWeek: exerciseConfig?.weeklyRoutineDaysGoal ?? 4,
      cardioDaysPerWeek: exerciseConfig?.weeklyCardioDaysGoal ?? 3,
      cardioMinutes: exerciseConfig?.cardioMinutesGoal ?? 30,
    );

    final first = _dateOnly(start);
    // Los días que aún no llegan no cuentan como incumplidos.
    final today = _dateOnly(DateTime.now());
    final requestedLast = _dateOnly(end);
    final last = requestedLast.isAfter(today) ? today : requestedLast;

    final (weightLogs, consultations, cardioLogs, nutritionDetail, exerciseDetail) =
        await (
          _measurementsDao.getWeightLogs(start, end),
          _measurementsDao.getMeasurements(),
          _exerciseDao.getCardioLogsInRange(start, end),
          _buildNutritionDetail(start, end),
          _buildExerciseDetail(start, end),
        ).wait;

    final weightByDay = {for (final log in weightLogs) _day(log.date): log.weightKg};
    final cardioByDay = <DateTime, int>{};
    for (final log in cardioLogs) {
      final day = _day(log.date);
      cardioByDay[day] = (cardioByDay[day] ?? 0) + log.durationMinutes;
    }

    final days = <ReportDay>[];
    for (var current = first; !current.isAfter(last); current = current.add(const Duration(days: 1))) {
      final water = await _waterSleepDao.getDailyWaterTotalMl(current);
      final meals = await _nutritionDao.getDailyMealLogs(current);
      final exerciseLog = await _exerciseDao.getDailyExerciseLog(current);
      final sessions = await _exerciseDao.getSessionsForDate(current);
      final sleepLogs = await _waterSleepDao.getSleepLogsForDate(current);
      days.add(ReportDay(
        date: current,
        waterMl: water,
        meals: meals.length,
        mealsFromPlan: meals.where((m) => m.planOptionId != null).length,
        exercised: exerciseLog?.completed == true || sessions.isNotEmpty,
        cardioMinutes: cardioByDay[current] ?? 0,
        sleepHours: sleepLogs.isEmpty
            ? null
            : sleepLogs.fold<double>(0, (sum, l) => sum + l.hoursCalculated),
        weightKg: weightByDay[current],
      ));
    }

    final slept = days.where((d) => d.sleepHours != null).toList();
    final exerciseDays = days.where((d) => d.exercised).length;
    return ReportData(
      start: start,
      end: end,
      waterGoalDays: days.where((d) => d.waterMl >= goals.waterMl).length,
      waterTotalDays: days.length,
      mealsLogged: days.fold(0, (sum, d) => sum + d.meals),
      mealsTotal: goals.mealsPerDay * days.length,
      exerciseDays: exerciseDays,
      exerciseTotalDays: (goals.routineDaysPerWeek * days.length / 7).round(),
      sleepAverage: slept.isEmpty
          ? null
          : slept.fold<double>(0, (sum, d) => sum + d.sleepHours!) / slept.length,
      weightLogs: weightLogs,
      latestMeasurement: consultations.firstOrNull,
      consultations: consultations.reversed.toList(),
      nutritionDetail: nutritionDetail,
      exerciseDetail: exerciseDetail,
      days: days,
      goals: goals,
      cardioLogs: cardioLogs,
      personName: (await _profileDao?.getProfile())?.name,
    );
  }

  DateTime _day(DateTime stored) {
    final utc = stored.toUtc();
    return DateTime.utc(utc.year, utc.month, utc.day);
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
        .map((s) {
          final u = s.date.toUtc();
          return DateTime.utc(u.year, u.month, u.day);
        })
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
            final u = s.date.toUtc();
            final d = DateTime.utc(u.year, u.month, u.day);
            return !d.isBefore(weekStart) && d.isBefore(weekEnd);
          })
          .map((s) {
            final u = s.date.toUtc();
            return DateTime.utc(u.year, u.month, u.day);
          })
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
