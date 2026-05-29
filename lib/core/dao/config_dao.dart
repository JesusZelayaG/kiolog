import 'package:drift/drift.dart';
import '../database/app_database.dart';
import '../database/tables/config_tables.dart';

part 'config_dao.g.dart';

@DriftAccessor(tables: [WaterConfig, GymConfig, NotificationSettings, AiConfig])
class ConfigDao extends DatabaseAccessor<AppDatabase> with _$ConfigDaoMixin {
  ConfigDao(super.db);
}
