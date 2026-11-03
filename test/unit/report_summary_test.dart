import 'package:flutter_test/flutter_test.dart';
import 'package:kiolog/features/reports/domain/report_summary.dart';
import 'package:kiolog/features/reports/domain/repositories/report_repository.dart';

ReportDay _day(int d, {int meals = 0, bool exercised = false, int cardio = 0,
        int water = 0, double? sleep, double? weight}) =>
    ReportDay(
      date: DateTime.utc(2026, 11, d),
      meals: meals,
      mealsFromPlan: meals,
      exercised: exercised,
      cardioMinutes: cardio,
      waterMl: water,
      sleepHours: sleep,
      weightKg: weight,
    );

void main() {
  const goals = ReportGoals(
    waterMl: 3000,
    mealsPerDay: 5,
    routineDaysPerWeek: 7,
    cardioDaysPerWeek: 3,
  );

  test('measures every day of the period, logged or not', () {
    final s = ComplianceSummary([
      _day(3, meals: 5, water: 3000, exercised: true),
      _day(4, meals: 4, water: 1000),
      _day(5),
    ], goals);

    expect(s.mealsExpected, 15);
    expect(s.meals, 9);
    expect(s.waterGoalDays, 1);
    expect(s.exerciseDays, 1);
    expect(s.exerciseDaysExpected, 3);
  });

  test('weight change runs from the first to the last weigh-in', () {
    final s = ComplianceSummary([
      _day(3, weight: 80),
      _day(4),
      _day(5, weight: 79.2),
    ], goals);

    expect(s.weightChange, closeTo(-0.8, 1e-9));
    expect(s.weights, [80, 79.2]);
  });

  test('sleep average ignores nights without a record', () {
    final s = ComplianceSummary([_day(3, sleep: 6), _day(4), _day(5, sleep: 8)], goals);

    expect(s.sleepAverage, 7);
    expect(s.nightsLogged, 2);
  });

  test('percent is capped at 100 and empty when nothing is expected', () {
    expect(ComplianceSummary.percent(9, 6), 100);
    expect(ComplianceSummary.percent(1, 0), isNull);
  });

  test('splitByWeek starts a new week every Monday', () {
    // 2026-11-01 is a Sunday.
    final weeks = splitByWeek([for (var d = 1; d <= 10; d++) _day(d)]);

    expect([for (final w in weeks) w.length], [1, 7, 2]);
    expect(weeks[1].first.date.weekday, DateTime.monday);
  });
}
