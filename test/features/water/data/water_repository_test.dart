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

    test('saveConfig and getConfig roundtrip', () async {
      await repository.saveConfig(
        unitType: 'glass',
        containerMl: 250,
        dailyGoalMl: 2000,
      );

      final config = await repository.getConfig();
      expect(config?.unitType, 'glass');
      expect(config?.containerMl, 250);
      expect(config?.dailyGoalMl, 2000);
    });
  });
}
