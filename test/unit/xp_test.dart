import 'package:flutter_test/flutter_test.dart';
import 'package:kiolog/features/reports/domain/repositories/report_repository.dart';
import 'package:kiolog/features/rewards/domain/xp.dart';

const goals = ReportGoals(
  waterMl: 3000,
  mealsPerDay: 4,
  routineDaysPerWeek: 4,
  cardioDaysPerWeek: 4,
  cardioMinutes: 30,
);

ReportDay perfect(int d, {bool train = true}) => ReportDay(
      date: DateTime.utc(2026, 11, d),
      meals: 4,
      mealsFromPlan: 4,
      waterMl: 3000,
      exercised: train,
      cardioMinutes: train ? 30 : 0,
      sleepHours: 7,
      weightKg: 74,
    );

void main() {
  test('a perfect day gives 65 XP', () {
    expect(dayXpTotal(perfect(3), goals), 65);
  });

  test('off-plan meals and short cardio give nothing', () {
    final day = ReportDay(
      date: DateTime.utc(2026, 11, 3),
      meals: 4,
      mealsFromPlan: 2,
      mealsOffPlan: 2,
      cardioMinutes: 20,
    );

    expect(dayXpTotal(day, goals), 10);
  });

  test('levels need 100, 300, 600 XP', () {
    expect(levelFor(0).number, 1);
    expect(levelFor(99).number, 1);
    expect(levelFor(100).number, 2);
    expect(levelFor(300).number, 3);
    expect(levelFor(450).progress, 0.5);
  });

  group('monthProgress', () {
    test('a perfect month reaches 100 %', () {
      // Cuatro días de entrenamiento por semana, como pide el plan.
      final days = [
        for (var d = 1; d <= 30; d++) perfect(d, train: d % 7 < 4),
      ];

      expect(monthProgress(days, goals, 30).percent, 100);
    });

    test('a perfect first week is about a quarter of the month', () {
      final days = [for (var d = 1; d <= 8; d++) perfect(d, train: d % 7 < 4)];

      final percent = monthProgress(days, goals, 30).percent;
      expect(percent, inInclusiveRange(25, 30));
    });

    test('training every day does not count beyond the weekly goal', () {
      final daily = [for (var d = 1; d <= 30; d++) perfect(d)];

      expect(monthProgress(daily, goals, 30).percent, 100);
      expect(monthProgress(daily, goals, 30).earned,
          monthProgress(daily, goals, 30).possible);
    });
  });
}
