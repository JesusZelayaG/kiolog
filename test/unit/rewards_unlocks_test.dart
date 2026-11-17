import 'package:flutter_test/flutter_test.dart';
import 'package:kiolog/features/reports/domain/repositories/report_repository.dart';
import 'package:kiolog/features/rewards/domain/catalog.dart';
import 'package:kiolog/features/rewards/domain/unlocks.dart';

const goals = ReportGoals(
  waterMl: 3000,
  mealsPerDay: 4,
  routineDaysPerWeek: 4,
  cardioDaysPerWeek: 4,
  cardioMinutes: 30,
);

ReportDay day(DateTime date, {bool perfect = true, bool water = true}) => ReportDay(
      date: date,
      meals: perfect ? 4 : 0,
      mealsFromPlan: perfect ? 4 : 0,
      waterMl: water ? 3000 : 0,
      exercised: perfect && date.weekday <= 4,
      cardioMinutes: perfect && date.weekday <= 4 ? 30 : 0,
      sleepHours: perfect ? 7 : null,
      weightKg: perfect ? 74 : null,
    );

List<ReportDay> month(int year, int m, {bool perfect = true}) => [
      for (var d = 1; d <= DateTime.utc(year, m + 1, 0).day; d++)
        day(DateTime.utc(year, m, d), perfect: perfect),
    ];

RewardProgress progressOf(List<ReportDay> days, {int level = 1}) =>
    rewardProgress(days: days, goals: goals, level: level);

void main() {
  test('a month counts once it reaches 70 %', () {
    final days = [
      ...month(2026, 11),
      ...month(2026, 12, perfect: false),
      ...month(2027, 1),
    ];

    expect(monthsKept(days, goals), 2);
    expect(progressOf(days).isUnlocked(trophyByKey('trophy_month_1')), isTrue);
    expect(progressOf(days).isUnlocked(trophyByKey('trophy_month_3')), isFalse);
  });

  test('locked trophies say what is missing', () {
    final progress = progressOf(month(2026, 11));

    expect(progress.requirement(trophyByKey('trophy_month_3')), '3 meses a más del 70 % (1/3)');
  });

  test('no trophy without a kept month', () {
    final progress = progressOf(month(2026, 11, perfect: false));

    expect(progress.monthsKept, 0);
    expect(trophyCatalog.where(progress.isUnlocked), isEmpty);
  });
}
