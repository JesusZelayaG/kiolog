import 'dart:math' as math;

import 'package:kiolog/features/reports/domain/repositories/report_repository.dart';

/// Puntos de experiencia por cada cosa cumplida en un día.
abstract final class XpRules {
  static const perPlanMeal = 5;
  static const waterGoal = 10;
  static const exercise = 15;
  static const cardioGoal = 10;
  static const sleepLogged = 5;
  static const weightLogged = 5;
}

/// Una línea del desglose de experiencia de un día.
class XpItem {
  const XpItem(this.label, this.points, {required this.done});

  final String label;
  final int points;
  final bool done;
}

/// La experiencia ganada en [day], con lo que faltó.
List<XpItem> dayXp(ReportDay day, ReportGoals goals) {
  final planMeals = math.min(day.mealsFromPlan, goals.mealsPerDay);
  return [
    XpItem('$planMeals/${goals.mealsPerDay} comidas del plan',
        planMeals * XpRules.perPlanMeal,
        done: planMeals >= goals.mealsPerDay),
    XpItem('Meta de agua', day.waterMl >= goals.waterMl ? XpRules.waterGoal : 0,
        done: day.waterMl >= goals.waterMl),
    XpItem('Rutina o ejercicio', day.exercised ? XpRules.exercise : 0,
        done: day.exercised),
    XpItem('Cardio de ${goals.cardioMinutes} min',
        day.cardioMinutes >= goals.cardioMinutes ? XpRules.cardioGoal : 0,
        done: day.cardioMinutes >= goals.cardioMinutes),
    XpItem('Sueño registrado', day.sleepHours != null ? XpRules.sleepLogged : 0,
        done: day.sleepHours != null),
    XpItem('Peso registrado', day.weightKg != null ? XpRules.weightLogged : 0,
        done: day.weightKg != null),
  ];
}

int dayXpTotal(ReportDay day, ReportGoals goals) =>
    dayXp(day, goals).fold(0, (sum, item) => sum + item.points);

/// Experiencia necesaria para llegar a [level]: 100, 300, 600, 1000…
int xpForLevel(int level) => 50 * (level - 1) * level;

class Level {
  const Level(this.number, this.xp);

  final int number;

  /// Experiencia total acumulada.
  final int xp;

  int get floor => xpForLevel(number);
  int get next => xpForLevel(number + 1);
  double get progress => (xp - floor) / (next - floor);
}

Level levelFor(int xp) {
  var level = 1;
  while (xp >= xpForLevel(level + 1)) {
    level++;
  }
  return Level(level, xp);
}

/// Avance del mes sobre el mes completo: un mes perfecto llega a 100 %.
class MonthProgress {
  const MonthProgress({required this.earned, required this.possible});

  final int earned;
  final int possible;

  double get fraction => possible == 0 ? 0 : math.min(1, earned / possible);
  int get percent => (fraction * 100).floor();
}

/// [days] son los días transcurridos del mes; [daysInMonth] todos los del mes.
/// Rutina y cardio cuentan hasta su meta semanal, repartida en el mes.
MonthProgress monthProgress(List<ReportDay> days, ReportGoals goals, int daysInMonth) {
  int weekly(int perWeek) => (perWeek * daysInMonth / 7).round();
  final routineCap = weekly(goals.routineDaysPerWeek);
  final cardioCap = weekly(goals.cardioDaysPerWeek);

  var earned = 0;
  var routineDays = 0;
  var cardioDays = 0;
  for (final day in days) {
    earned += math.min(day.mealsFromPlan, goals.mealsPerDay) * XpRules.perPlanMeal;
    if (day.waterMl >= goals.waterMl) earned += XpRules.waterGoal;
    if (day.sleepHours != null) earned += XpRules.sleepLogged;
    if (day.weightKg != null) earned += XpRules.weightLogged;
    if (day.exercised) routineDays++;
    if (day.cardioMinutes >= goals.cardioMinutes) cardioDays++;
  }
  earned += math.min(routineDays, routineCap) * XpRules.exercise;
  earned += math.min(cardioDays, cardioCap) * XpRules.cardioGoal;

  final perDay = goals.mealsPerDay * XpRules.perPlanMeal +
      XpRules.waterGoal +
      XpRules.sleepLogged +
      XpRules.weightLogged;
  final possible = perDay * daysInMonth +
      routineCap * XpRules.exercise +
      cardioCap * XpRules.cardioGoal;
  return MonthProgress(earned: earned, possible: possible);
}

/// Los umbrales del mes que desbloquean una recompensa.
const rewardThresholds = [25, 50, 75, 100];
