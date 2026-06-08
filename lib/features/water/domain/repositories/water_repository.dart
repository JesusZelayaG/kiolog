import 'package:kiolog/core/database/app_database.dart';

abstract class WaterRepository {
  Future<int> getDailyTotalMl(DateTime date);
  Future<void> addWater(DateTime date, int amountMl);
  Future<WaterConfigData?> getConfig();
  Future<void> saveConfig({
    required String unitType,
    required int containerMl,
    required int dailyGoalMl,
  });
}
