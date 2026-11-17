import 'package:drift/drift.dart';
import 'package:kiolog/core/dao/config_dao.dart';
import 'package:kiolog/core/dao/water_sleep_dao.dart';
import 'package:kiolog/core/database/app_database.dart';
import '../../domain/repositories/water_repository.dart';

class WaterRepositoryImpl implements WaterRepository {
  final WaterSleepDao _waterSleepDao;
  final ConfigDao _configDao;

  WaterRepositoryImpl(this._waterSleepDao, this._configDao);

  DateTime _dateOnly(DateTime date) =>
      DateTime.utc(date.year, date.month, date.day);

  @override
  Future<int> getDailyTotalMl(DateTime date) =>
      _waterSleepDao.getDailyWaterTotalMl(_dateOnly(date));

  @override
  Future<void> addWater(DateTime date, int amountMl) =>
      _waterSleepDao.insertWaterLog(
        DailyWaterLogsCompanion(
          date: Value(_dateOnly(date)),
          timestamp: Value(DateTime.now()),
          amountMl: Value(amountMl),
        ),
      );

  @override
  Future<WaterConfigData?> getConfig() => _configDao.getWaterConfig();

  @override
  Future<void> saveGoal(int dailyGoalMl) =>
      _configDao.upsertWaterConfig(WaterConfigCompanion(dailyGoalMl: Value(dailyGoalMl)));

  @override
  Future<List<DailyWaterLog>> getDailyLogs(DateTime date) async =>
      (await _waterSleepDao.getDailyWaterLogs(_dateOnly(date)))..sort((a, b) => a.timestamp.compareTo(b.timestamp));

  @override
  Future<void> deleteWaterLog(int id) => _waterSleepDao.deleteWaterLog(id);
}
