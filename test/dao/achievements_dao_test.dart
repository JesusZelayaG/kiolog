// test/dao/achievements_dao_test.dart
import 'package:flutter_test/flutter_test.dart';
import 'package:kiolog/core/database/app_database.dart';
import '../helpers/database_helper.dart';

void main() {
  late AppDatabase db;

  setUp(() => db = createTestDatabase());
  tearDown(() async => db.close());

  test('seed inserta logros por defecto', () async {
    await db.achievementsDao.seedDefaultAchievements();

    final all = await db.achievementsDao.getAchievements();
    expect(all.isNotEmpty, true);
    expect(all.every((a) => !a.isUnlocked), true);
  });

  test('unlockAchievement marca el logro como desbloqueado', () async {
    await db.achievementsDao.seedDefaultAchievements();

    await db.achievementsDao.unlockAchievement('first_plan_imported');

    final unlocked = await db.achievementsDao.getUnlockedAchievements();
    expect(unlocked.length, 1);
    expect(unlocked.first.key, 'first_plan_imported');
    expect(unlocked.first.isUnlocked, true);
    expect(unlocked.first.unlockedAt, isNotNull);
  });

  test('isUnlocked retorna false si no desbloqueado', () async {
    await db.achievementsDao.seedDefaultAchievements();

    final result =
        await db.achievementsDao.isUnlocked('water_30_days_total');
    expect(result, false);
  });
}
