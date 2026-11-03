import 'repositories/report_repository.dart';

/// Cumplimiento de un tramo de días (el periodo completo o una semana).
class ComplianceSummary {
  ComplianceSummary(this.days, this.goals);

  final List<ReportDay> days;
  final ReportGoals goals;

  int get dayCount => days.length;

  int get meals => days.fold(0, (sum, d) => sum + d.meals);
  int get mealsFromPlan => days.fold(0, (sum, d) => sum + d.mealsFromPlan);
  int get mealsExpected => goals.mealsPerDay * dayCount;

  int get exerciseDays => days.where((d) => d.exercised).length;

  /// La meta semanal repartida en los días del tramo.
  int get exerciseDaysExpected => _prorate(goals.routineDaysPerWeek);

  int get cardioDays => days.where((d) => d.cardioMinutes > 0).length;
  int get cardioDaysExpected => _prorate(goals.cardioDaysPerWeek);
  int get cardioMinutes => days.fold(0, (sum, d) => sum + d.cardioMinutes);

  int get waterGoalDays => days.where((d) => d.waterMl >= goals.waterMl).length;
  double? get waterAverageLiters => dayCount == 0
      ? null
      : days.fold(0, (sum, d) => sum + d.waterMl) / dayCount / 1000;

  List<double> get _sleep =>
      [for (final d in days) if (d.sleepHours != null) d.sleepHours!];
  int get nightsLogged => _sleep.length;
  double? get sleepAverage =>
      _sleep.isEmpty ? null : _sleep.reduce((a, b) => a + b) / _sleep.length;

  List<double> get weights =>
      [for (final d in days) if (d.weightKg != null) d.weightKg!];
  double? get weightAverage {
    final w = weights;
    return w.isEmpty ? null : w.reduce((a, b) => a + b) / w.length;
  }

  /// Último peso menos el primero del tramo.
  double? get weightChange {
    final w = weights;
    return w.length < 2 ? null : w.last - w.first;
  }

  int _prorate(int perWeek) => (perWeek * dayCount / 7).round();

  /// Partes por cien de [done] sobre [expected], tope 100.
  static int? percent(int done, int expected) =>
      expected == 0 ? null : (100 * done / expected).clamp(0, 100).round();
}

/// Corta [days] en semanas de lunes a domingo.
List<List<ReportDay>> splitByWeek(List<ReportDay> days) {
  final weeks = <List<ReportDay>>[];
  for (final day in days) {
    if (weeks.isEmpty || day.date.weekday == DateTime.monday) weeks.add([]);
    weeks.last.add(day);
  }
  return weeks;
}
