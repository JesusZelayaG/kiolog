import 'package:flutter_test/flutter_test.dart';
import 'package:kiolog/features/history/domain/month_overview.dart';
import 'package:kiolog/features/reports/domain/repositories/report_repository.dart';

const goals = ReportGoals(waterMl: 3000, mealsPerDay: 4, routineDaysPerWeek: 4);

ReportDay full(int day) => ReportDay(
      date: DateTime.utc(2026, 11, day),
      waterMl: 3000,
      meals: 4,
      mealsFromPlan: 4,
      sleepHours: 7,
      weightKg: 74,
    );

void main() {
  test('un día de descanso completo llega a 100 %', () {
    expect(dayScore(full(3), goals), 1.0);
  });

  test('solo agua cuenta una parte del día', () {
    final day = ReportDay(date: DateTime.utc(2026, 11, 3), waterMl: 3000);
    expect(dayScore(day, goals), closeTo(10 / 40, 0.001));
  });

  test('los días que no llegan quedan sin puntaje y no bajan las áreas', () {
    final o = buildMonthOverview(
      month: DateTime(2026, 11),
      days: [full(1), full(2)],
      goals: goals,
      today: DateTime(2026, 11, 2, 20),
    );

    expect(o.days, hasLength(30));
    expect(o.days[2].future, isTrue);
    expect(o.water, 1.0);
    expect(o.meals, 1.0);
  });

  test('la racha no se rompe por un hoy a medias', () {
    final o = buildMonthOverview(
      month: DateTime(2026, 11),
      days: [full(14), full(15), full(16), ReportDay(date: DateTime.utc(2026, 11, 17))],
      goals: goals,
      today: DateTime(2026, 11, 17, 9),
    );

    expect(o.streak, 3);
    expect(o.strongDays, 3);
  });

  test('un día flojo en medio corta la racha', () {
    final o = buildMonthOverview(
      month: DateTime(2026, 11),
      days: [full(14), ReportDay(date: DateTime.utc(2026, 11, 15)), full(16), full(17)],
      goals: goals,
      today: DateTime(2026, 11, 17, 21),
    );

    expect(o.streak, 2);
  });
}
