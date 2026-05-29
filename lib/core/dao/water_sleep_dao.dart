import 'package:drift/drift.dart';
import '../database/app_database.dart';
import '../database/tables/water_sleep_tables.dart';

part 'water_sleep_dao.g.dart';

@DriftAccessor(tables: [DailyWaterLogs, SleepLogs])
class WaterSleepDao extends DatabaseAccessor<AppDatabase>
    with _$WaterSleepDaoMixin {
  WaterSleepDao(super.db);
}
