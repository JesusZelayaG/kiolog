import 'package:drift/drift.dart';
import '../database/app_database.dart';
import '../database/tables/config_tables.dart';

part 'config_dao.g.dart';

@DriftAccessor(tables: [WaterConfig, GymConfig, NotificationSettings, AiConfig])
class ConfigDao extends DatabaseAccessor<AppDatabase> with _$ConfigDaoMixin {
  ConfigDao(super.db);

  Future<WaterConfigData?> getWaterConfig() =>
      select(waterConfig).getSingleOrNull();

  Future<void> upsertWaterConfig(WaterConfigCompanion config) async {
    final existing = await getWaterConfig();
    if (existing == null) {
      await into(waterConfig).insert(config);
    } else {
      await (update(waterConfig)).write(config);
    }
  }

  Future<GymConfigData?> getGymConfig() =>
      select(gymConfig).getSingleOrNull();

  Future<void> upsertGymConfig(GymConfigCompanion config) async {
    final existing = await getGymConfig();
    if (existing == null) {
      await into(gymConfig).insert(config);
    } else {
      await (update(gymConfig)).write(config);
    }
  }

  Future<NotificationSetting?> getNotificationSettings(String module) =>
      (select(notificationSettings)
            ..where((t) => t.module.equals(module)))
          .getSingleOrNull();

  Future<void> upsertNotificationSettings(
      NotificationSettingsCompanion settings) async {
    final module = settings.module.present ? settings.module.value : null;
    if (module == null) return;
    final existing = await getNotificationSettings(module);
    if (existing == null) {
      await into(notificationSettings).insert(settings);
    } else {
      await (update(notificationSettings)
            ..where((t) => t.module.equals(module)))
          .write(settings);
    }
  }

  Future<AiConfigData?> getAiConfig() =>
      select(aiConfig).getSingleOrNull();

  Future<void> upsertAiConfig(AiConfigCompanion config) async {
    final existing = await getAiConfig();
    if (existing == null) {
      await into(aiConfig).insert(config);
    } else {
      await (update(aiConfig)).write(config);
    }
  }
}
