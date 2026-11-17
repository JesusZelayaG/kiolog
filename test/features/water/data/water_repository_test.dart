import 'package:flutter_test/flutter_test.dart';
import 'package:kiolog/core/dao/config_dao.dart';
import 'package:kiolog/core/dao/water_sleep_dao.dart';
import 'package:kiolog/core/database/app_database.dart';
import 'package:kiolog/features/water/data/repositories/water_repository_impl.dart';
import 'package:drift/drift.dart';

import '../../../helpers/database_helper.dart';

void main() {
  late AppDatabase db;
  late WaterRepositoryImpl repository;

  setUp(() {
    db = createTestDatabase();
    repository = WaterRepositoryImpl(db.waterSleepDao, db.configDao);
  });

  tearDown(() async => db.close());

  group('WaterRepositoryImpl', () {
    test('getDailyTotalMl returns 0 when empty', () async {
      final total = await repository.getDailyTotalMl(DateTime(2026, 6, 8));
      expect(total, 0);
    });

    test('addWater increases daily total', () async {
      final date = DateTime(2026, 6, 8);
      await repository.addWater(date, 500);
      await repository.addWater(date, 250);

      final total = await repository.getDailyTotalMl(date);
      expect(total, 750);
    });

    test('saveGoal guarda solo la meta diaria', () async {
      await repository.saveGoal(2500);

      expect((await repository.getConfig())?.dailyGoalMl, 2500);
    });

    test('las tomas del día se listan en orden y se pueden borrar', () async {
      final date = DateTime(2026, 6, 8);
      await repository.addWater(date, 500);
      await repository.addWater(date, 250);

      final logs = await repository.getDailyLogs(date);
      expect(logs.map((l) => l.amountMl), [500, 250]);

      await repository.deleteWaterLog(logs.first.id);
      expect(await repository.getDailyTotalMl(date), 250);
    });
  });
}
