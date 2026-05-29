// test/dao/config_dao_test.dart
import 'package:flutter_test/flutter_test.dart';
import 'package:drift/drift.dart' hide isNotNull;
import 'package:kiolog/core/database/app_database.dart';
import '../helpers/database_helper.dart';

void main() {
  late AppDatabase db;

  setUp(() => db = createTestDatabase());
  tearDown(() async => db.close());

  group('ConfigDao - WaterConfig', () {
    test('upsert crea config si no existe', () async {
      await db.configDao.upsertWaterConfig(
        const WaterConfigCompanion(
          unitType: Value('bottle'),
          containerMl: Value(1000),
          dailyGoalMl: Value(3000),
        ),
      );

      final config = await db.configDao.getWaterConfig();
      expect(config?.unitType, 'bottle');
      expect(config?.dailyGoalMl, 3000);
    });

    test('upsert actualiza config existente', () async {
      await db.configDao.upsertWaterConfig(
        const WaterConfigCompanion(
          unitType: Value('bottle'),
          containerMl: Value(1000),
          dailyGoalMl: Value(3000),
        ),
      );
      await db.configDao.upsertWaterConfig(
        const WaterConfigCompanion(
          unitType: Value('glass'),
          containerMl: Value(250),
          dailyGoalMl: Value(2500),
        ),
      );

      final config = await db.configDao.getWaterConfig();
      expect(config?.unitType, 'glass');
      expect(config?.containerMl, 250);
    });
  });

  group('ConfigDao - NotificationSettings', () {
    test('upsert y recupera configuración de notificación', () async {
      await db.configDao.upsertNotificationSettings(
        const NotificationSettingsCompanion(
          module: Value('water'),
          enabled: Value(true),
          hour: Value(0),
          minute: Value(0),
          reminderType: Value('interval'),
          intervalMinutes: Value(120),
        ),
      );

      final settings =
          await db.configDao.getNotificationSettings('water');
      expect(settings?.enabled, true);
      expect(settings?.intervalMinutes, 120);
    });
  });
}
