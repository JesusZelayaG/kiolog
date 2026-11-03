import 'package:kiolog/features/reports/domain/repositories/report_repository.dart';

import 'catalog.dart';
import 'xp.dart';

/// Lo que el usuario ha logrado, calculado desde sus registros.
class RewardProgress {
  const RewardProgress({
    required this.level,
    required this.goals,
    required this.monthsKept,
  });

  final int level;

  /// Avance de cada logro contable.
  final Map<Goal, int> goals;

  /// Meses con más de [trophyThreshold] % cumplido.
  final int monthsKept;

  bool isUnlocked(RewardItem item) => switch (item.unlock) {
        FromStart() => true,
        AtLevel(:final level) => this.level >= level,
        ByGoal(:final goal) => (goals[goal] ?? 0) >= goal.target,
        ByMonths(:final months) => monthsKept >= months,
      };

  /// Qué falta para desbloquear [item], para mostrarlo junto al candado.
  String requirement(RewardItem item) => switch (item.unlock) {
        FromStart() => 'Desde el inicio',
        AtLevel(:final level) => 'Nivel $level',
        ByGoal(:final goal) =>
          '${goal.label} (${(goals[goal] ?? 0).clamp(0, goal.target)}/${goal.target})',
        ByMonths(:final months) =>
          '$months ${months == 1 ? 'mes' : 'meses'} a más del $trophyThreshold % '
              '(${monthsKept.clamp(0, months)}/$months)',
      };
}

int _longestStreak(Iterable<ReportDay> days, bool Function(ReportDay) kept) {
  var best = 0;
  var current = 0;
  for (final day in days) {
    current = kept(day) ? current + 1 : 0;
    if (current > best) best = current;
  }
  return best;
}

/// [days] en orden, desde el registro hasta hoy, sin huecos.
RewardProgress rewardProgress({
  required List<ReportDay> days,
  required ReportGoals goals,
  required int cardioSessions,
  required int level,
}) {
  bool fullMeals(ReportDay d) => d.mealsFromPlan >= goals.mealsPerDay;
  bool water(ReportDay d) => d.waterMl >= goals.waterMl;
  return RewardProgress(
    level: level,
    monthsKept: monthsKept(days, goals),
    goals: {
      Goal.waterStreak7: _longestStreak(days, water),
      Goal.cardio10: cardioSessions,
      Goal.cardio20: cardioSessions,
      Goal.routines10: days.where((d) => d.exercised).length,
      Goal.planMeals30: days.fold(0, (sum, d) => sum + d.mealsFromPlan),
      Goal.planMeals50: days.fold(0, (sum, d) => sum + d.mealsFromPlan),
      Goal.weights30: days.where((d) => d.weightKg != null).length,
      Goal.sleepStreak14: _longestStreak(days, (d) => d.sleepHours != null),
      Goal.fullMealsStreak15: _longestStreak(days, fullMeals),
      Goal.perfectDays30: days
          .where((d) => fullMeals(d) && water(d) && d.sleepHours != null && d.weightKg != null)
          .length,
    },
  );
}

/// Cuenta los meses que llegaron a [trophyThreshold] %. El mes en curso cuenta
/// en cuanto llega: su porcentaje solo puede subir.
int monthsKept(List<ReportDay> days, ReportGoals goals) {
  final byMonth = <(int, int), List<ReportDay>>{};
  for (final day in days) {
    byMonth.putIfAbsent((day.date.year, day.date.month), () => []).add(day);
  }
  var kept = 0;
  for (final MapEntry(key: (year, month), value: monthDays) in byMonth.entries) {
    final length = DateTime.utc(year, month + 1, 0).day;
    if (monthProgress(monthDays, goals, length).percent >= trophyThreshold) kept++;
  }
  return kept;
}
