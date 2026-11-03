import 'package:equatable/equatable.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:intl/intl.dart';
import 'package:kiolog/core/domain/day.dart';
import 'package:kiolog/core/database/app_database.dart';
import 'package:kiolog/features/exercise/domain/repositories/exercise_repository.dart';
import 'package:kiolog/features/nutrition/domain/repositories/nutrition_repository.dart';
import 'package:kiolog/features/sleep/domain/repositories/sleep_repository.dart';
import 'package:kiolog/features/water/domain/repositories/water_repository.dart';

import '../../domain/plan_progress.dart';
import '../../domain/repositories/progress_repository.dart';

const _weeksBack = 8;
const _daysBack = 7;
const _weekdays = ['L', 'M', 'X', 'J', 'V', 'S', 'D'];

/// Una barra de gráfica; [values] trae un número por serie, apilados.
class ChartBar extends Equatable {
  const ChartBar(this.label, this.values);

  final String label;
  final List<double> values;

  double get total => values.fold(0, (sum, v) => sum + v);

  @override
  List<Object?> get props => [label, values];
}

enum OverviewStatus { loading, ready, failure }

class ProgressOverviewState extends Equatable {
  const ProgressOverviewState({
    this.status = OverviewStatus.loading,
    this.exercise = const [],
    this.nutrition = const [],
    this.water = const [],
    this.waterGoalLiters,
    this.sleep = const [],
    this.waist = const [],
    this.plans = const [],
  });

  final OverviewStatus status;
  final List<ChartBar> exercise;
  final List<ChartBar> nutrition;
  final List<ChartBar> water;
  final double? waterGoalLiters;
  final List<ChartBar> sleep;
  final List<ChartBar> waist;

  /// Planes de nutrición con periodo, del más reciente al más antiguo.
  final List<PlanProgress> plans;

  @override
  List<Object?> get props =>
      [status, exercise, nutrition, water, waterGoalLiters, sleep, waist, plans];
}

/// Junta los datos semanales de cada módulo para las gráficas de Progreso.
class ProgressOverviewCubit extends Cubit<ProgressOverviewState> {
  ProgressOverviewCubit({
    required ExerciseRepository exercise,
    required NutritionRepository nutrition,
    required WaterRepository water,
    required SleepRepository sleep,
    required ProgressRepository progress,
    DateTime Function() now = DateTime.now,
  })  : _exercise = exercise,
        _nutrition = nutrition,
        _water = water,
        _sleep = sleep,
        _progress = progress,
        _now = now,
        super(const ProgressOverviewState());

  final ExerciseRepository _exercise;
  final NutritionRepository _nutrition;
  final WaterRepository _water;
  final SleepRepository _sleep;
  final ProgressRepository _progress;
  final DateTime Function() _now;

  static final _shortDate = DateFormat('dd/MM');

  DateTime _mondayOf(DateTime date) {
    final utc = date.toUtc();
    return DateTime.utc(utc.year, utc.month, utc.day - (utc.weekday - 1));
  }

  Future<PlanProgress> _progressOf(MealPlan plan, List<Measurement> measurements) async {
    final meals = await _nutrition.getPlanMealCounts(plan);
    return planProgressFor(
      plan,
      measurements,
      mealsLogged: meals.logged,
      mealsExpected: meals.expected,
    );
  }

  Future<void> load() async {
    try {
      final now = _now();
      final today = DateTime(now.year, now.month, now.day);
      final days = [
        for (var i = _daysBack - 1; i >= 0; i--) today.subtract(Duration(days: i)),
      ];
      final exercise = await _exercise.getWeeklyStats(weeksBack: _weeksBack);
      final nutrition = await _nutrition.getWeeklyAdherence(weeksBack: _weeksBack);
      final waterConfig = await _water.getConfig();
      final waterMl = [for (final day in days) await _water.getDailyTotalMl(day)];
      final sleepLogs = await _sleep.getSleepLogsInRange(
        days.first.subtract(const Duration(days: 1)),
        days.last.add(const Duration(days: 1)),
      );
      final measurements = await _progress.getMeasurements();
      final allPlans = await _nutrition.getAllPlans();
      final plans = <PlanProgress>[
        for (final plan in allPlans.where((p) => p.periodStart != null))
          await _progressOf(plan, measurements),
      ]..sort((a, b) => b.plan.periodStart!.compareTo(a.plan.periodStart!));
      final current = plans.where((p) => p.plan.isActive).firstOrNull?.plan;
      final currentWeek = current == null ? null : _mondayOf(utcDayOf(current.periodStart!.toLocal()));

      final sleepHours = <String, double>{};
      for (final log in sleepLogs) {
        final key = _shortDate.format(log.date.toUtc());
        sleepHours[key] = (sleepHours[key] ?? 0) + log.hoursCalculated;
      }
      final waist = measurements.where((m) => m.waistCm != null).toList()
        ..sort((a, b) => a.date.compareTo(b.date));
      final goalMl = waterConfig?.dailyGoalMl;

      emit(ProgressOverviewState(
        status: OverviewStatus.ready,
        exercise: [
          for (final week in exercise)
            ChartBar(_shortDate.format(week.weekStart), [
              week.routineDaysDone.toDouble(),
              week.cardioDaysDone.toDouble(),
            ]),
        ],
        nutrition: [
          for (final week in nutrition)
            if (currentWeek == null || !week.weekStart.isBefore(currentWeek))
              ChartBar(_shortDate.format(week.weekStart), [
              week.mealsExpected == 0 ? 0 : 100 * week.mealsLogged / week.mealsExpected,
            ]),
        ],
        water: [
          for (var i = 0; i < days.length; i++)
            ChartBar(_weekdays[days[i].weekday - 1], [waterMl[i] / 1000]),
        ],
        waterGoalLiters: goalMl == null ? null : goalMl / 1000,
        sleep: [
          for (final day in days)
            ChartBar(_weekdays[day.weekday - 1], [sleepHours[_shortDate.format(day)] ?? 0]),
        ],
        waist: [
          for (final m in waist) ChartBar(_shortDate.format(m.date.toUtc()), [m.waistCm!]),
        ],
        plans: plans,
      ));
    } catch (_) {
      emit(const ProgressOverviewState(status: OverviewStatus.failure));
    }
  }
}
