import 'dart:math' as math;

import 'package:kiolog/features/reports/domain/repositories/report_repository.dart';
import 'package:kiolog/features/rewards/domain/xp.dart';

/// Un día del calendario con lo que se cumplió de las metas.
class DayScore {
  const DayScore({
    required this.date,
    required this.score,
    this.water = false,
    this.meals = false,
    this.sleep = false,
    this.exercise = false,
  });

  /// El día local, a medianoche.
  final DateTime date;

  /// De 0 a 1; null en los días que aún no llegan.
  final double? score;
  final bool water;

  /// Todas las comidas del plan.
  final bool meals;
  final bool sleep;
  final bool exercise;

  bool get future => score == null;
}

/// Cuánto se cumplió el mes, como en Recompensas, y día por día.
class MonthOverview {
  const MonthOverview({
    required this.month,
    required this.percent,
    required this.days,
    required this.water,
    required this.meals,
    required this.sleep,
    required this.exercise,
    required this.strongDays,
    required this.streak,
  });

  final DateTime month;

  /// El % del mes de Recompensas: sobre el mes completo.
  final int percent;

  /// Todos los días del mes, del 1 al último.
  final List<DayScore> days;

  /// Cumplimiento de cada área en los días que ya pasaron, de 0 a 1.
  final double water;
  final double meals;
  final double sleep;
  final double exercise;

  /// Días al menos al [strongDay].
  final int strongDays;

  /// Días seguidos hasta hoy al menos al [strongDay]. Hoy cuenta solo si ya
  /// llegó: un día a medias no rompe la racha.
  final int streak;

  static const strongDay = 0.7;
}

/// Puntos de un día sin rutina ni cardio, que son metas semanales: un día de
/// descanso completo llega a 100 %.
int _perDay(ReportGoals goals) =>
    goals.mealsPerDay * XpRules.perPlanMeal + XpRules.waterGoal + XpRules.sleepLogged + XpRules.weightLogged;

double dayScore(ReportDay day, ReportGoals goals) =>
    math.min(1, dayXpTotal(day, goals) / _perDay(goals));

/// [days] son los del mes hasta [today] (el reporte); [today] es local.
MonthOverview buildMonthOverview({
  required DateTime month,
  required List<ReportDay> days,
  required ReportGoals goals,
  required DateTime today,
}) {
  final first = DateTime(month.year, month.month);
  final length = DateTime(month.year, month.month + 1, 0).day;
  final byDay = {for (final d in days) DateTime(d.date.year, d.date.month, d.date.day): d};
  final todayDate = DateTime(today.year, today.month, today.day);

  final scores = <DayScore>[];
  for (var i = 0; i < length; i++) {
    final date = DateTime(first.year, first.month, i + 1);
    final record = byDay[date];
    if (date.isAfter(todayDate)) {
      scores.add(DayScore(date: date, score: null));
      continue;
    }
    final r = record ?? ReportDay(date: date);
    scores.add(DayScore(
      date: date,
      score: dayScore(r, goals),
      water: r.waterMl >= goals.waterMl,
      meals: r.mealsFromPlan >= goals.mealsPerDay,
      sleep: r.sleepHours != null,
      exercise: r.exercised,
    ));
  }

  final past = scores.where((s) => !s.future).toList();
  final elapsed = past.length;
  final recorded = [for (final s in past) byDay[s.date] ?? ReportDay(date: s.date)];
  final expectedRoutine = goals.routineDaysPerWeek * elapsed / 7;
  double share(int done, num of) => of <= 0 ? 0 : math.min(1, done / of);

  var streak = 0;
  for (final s in past.reversed) {
    if (s.score! >= MonthOverview.strongDay) {
      streak++;
    } else if (s.date != todayDate) {
      break;
    }
  }

  return MonthOverview(
    month: first,
    percent: monthProgress(recorded, goals, length).percent,
    days: scores,
    water: share(past.where((s) => s.water).length, elapsed),
    meals: share(
      recorded.fold(0, (sum, d) => sum + math.min(d.mealsFromPlan, goals.mealsPerDay)),
      goals.mealsPerDay * elapsed,
    ),
    sleep: share(past.where((s) => s.sleep).length, elapsed),
    exercise: share(past.where((s) => s.exercise).length, expectedRoutine),
    strongDays: past.where((s) => s.score! >= MonthOverview.strongDay).length,
    streak: streak,
  );
}
