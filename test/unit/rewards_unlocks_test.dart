import 'package:flutter_test/flutter_test.dart';
import 'package:kiolog/features/reports/domain/repositories/report_repository.dart';
import 'package:kiolog/features/rewards/domain/catalog.dart';
import 'package:kiolog/features/rewards/domain/outfit.dart';
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

RewardProgress progressOf(List<ReportDay> days, {int level = 1, int cardio = 0}) =>
    rewardProgress(days: days, goals: goals, cardioSessions: cardio, level: level);

void main() {
  test('streaks count the longest run, not the latest', () {
    final days = [
      for (var d = 1; d <= 8; d++) day(DateTime.utc(2026, 11, d)),
      day(DateTime.utc(2026, 11, 9), water: false),
      for (var d = 10; d <= 12; d++) day(DateTime.utc(2026, 11, d)),
    ];

    final progress = progressOf(days);

    expect(progress.goals[Goal.waterStreak7], 8);
    expect(progress.isUnlocked(itemByKey('house_water_bottle')), isTrue);
  });

  test('locked items say what is missing', () {
    final progress = progressOf([day(DateTime.utc(2026, 11, 3))], cardio: 4);

    expect(progress.requirement(itemByKey('shoes_running')), '10 sesiones de cardio (4/10)');
    expect(progress.requirement(itemByKey('top_hoodie')), 'Nivel 9');
    expect(progress.isUnlocked(itemByKey('top_tshirt')), isTrue);
  });

  test('a month counts once it reaches 70 %', () {
    final days = [
      ...month(2026, 11),
      ...month(2026, 12, perfect: false),
      ...month(2027, 1),
    ];

    expect(monthsKept(days, goals), 2);
    expect(progressOf(days).isUnlocked(itemByKey('trophy_month_1')), isTrue);
    expect(progressOf(days).isUnlocked(itemByKey('trophy_month_3')), isFalse);
  });

  group('Outfit', () {
    test('starts with the starter clothes and room', () {
      final parts = const Outfit().visibleParts(progressOf(const []));

      expect(parts, containsAll(['top_tshirt', 'bottom_shorts', 'shoes_basic', 'house_bed_basic', 'house_yoga_mat']));
      expect(parts, isNot(contains('house_trophy_shelf')));
      expect(parts, isNot(contains('acc_cap')));
    });

    test('falls back to the starter piece when the choice is locked', () {
      const outfit = Outfit(chosen: {RewardSlot.top: 'top_hoodie'});

      expect(outfit.wearing(RewardSlot.top, progressOf(const [], level: 3)), 'top_tshirt');
      expect(outfit.wearing(RewardSlot.top, progressOf(const [], level: 9)), 'top_hoodie');
    });

    test('optional slots can be left empty and extras hidden', () {
      const outfit = Outfit(
        chosen: {RewardSlot.head: null, RewardSlot.rug: 'house_rug'},
        hiddenExtras: {'house_dumbbells'},
      );

      final parts = outfit.visibleParts(progressOf(const [], level: 5));

      expect(parts, contains('house_rug'));
      expect(parts, contains('house_plant'));
      expect(parts, isNot(contains('house_dumbbells')));
    });

    test('the first rug and poster earned appear until another is chosen', () {
      final level3 = progressOf(const [], level: 3);

      expect(const Outfit().visibleParts(level3), containsAll(['house_rug', 'house_poster_simple']));
      expect(
        const Outfit(chosen: {RewardSlot.poster: null}).visibleParts(level3),
        isNot(contains('house_poster_simple')),
      );
    });

    test('the trophy shelf appears with the first trophy', () {
      final parts = const Outfit().visibleParts(progressOf(month(2026, 11)));

      expect(parts, containsAll(['house_trophy_shelf', 'trophy_month_1']));
    });
  });
}
