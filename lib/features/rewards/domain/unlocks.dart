import 'package:kiolog/features/reports/domain/repositories/report_repository.dart';

import 'catalog.dart';
import 'xp.dart';

/// Lo que el usuario ha logrado, calculado desde sus registros.
class RewardProgress {
  const RewardProgress({required this.level, required this.monthsKept});

  final int level;

  /// Meses con más de [trophyThreshold] % cumplido.
  final int monthsKept;

  bool isUnlocked(Trophy trophy) => monthsKept >= trophy.months;

  /// Qué falta para ganar [trophy], para mostrarlo junto al candado.
  String requirement(Trophy trophy) =>
      '${trophy.months} ${trophy.months == 1 ? 'mes' : 'meses'} a más del $trophyThreshold % '
      '(${monthsKept.clamp(0, trophy.months)}/${trophy.months})';
}

/// [days] en orden, desde el registro hasta hoy, sin huecos.
RewardProgress rewardProgress({
  required List<ReportDay> days,
  required ReportGoals goals,
  required int level,
}) =>
    RewardProgress(level: level, monthsKept: monthsKept(days, goals));

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
