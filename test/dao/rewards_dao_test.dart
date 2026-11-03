import 'package:flutter_test/flutter_test.dart';
import 'package:kiolog/core/database/app_database.dart';

import '../helpers/database_helper.dart';

void main() {
  late AppDatabase db;

  setUp(() => db = createTestDatabase());
  tearDown(() async => db.close());

  test('one reward per threshold and month, replaced when edited', () async {
    await db.rewardsDao.setReward('2026-11', 25, 'Ir al cine');
    await db.rewardsDao.setReward('2026-11', 25, '  Cena  ');
    await db.rewardsDao.setReward('2026-11', 50, 'Zapatillas');
    await db.rewardsDao.setReward('2026-12', 25, 'Otro mes');

    final november = await db.rewardsDao.rewardsFor('2026-11');

    expect(november.map((r) => (r.threshold, r.title)), [(25, 'Cena'), (50, 'Zapatillas')]);
  });

  test('a blank title removes the reward', () async {
    await db.rewardsDao.setReward('2026-11', 75, 'Reloj');
    await db.rewardsDao.setReward('2026-11', 75, '   ');

    expect(await db.rewardsDao.rewardsFor('2026-11'), isEmpty);
  });

  test('redeeming can be undone', () async {
    await db.rewardsDao.setReward('2026-11', 25, 'Cine');
    final reward = (await db.rewardsDao.rewardsFor('2026-11')).single;

    await db.rewardsDao.setRedeemed(reward.id, redeemed: true);
    expect((await db.rewardsDao.rewardsFor('2026-11')).single.redeemedAt, isNotNull);

    await db.rewardsDao.setRedeemed(reward.id, redeemed: false);
    expect((await db.rewardsDao.rewardsFor('2026-11')).single.redeemedAt, isNull);
  });
}
