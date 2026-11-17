import 'package:kiolog/core/database/app_database.dart';

abstract class WaterRepository {
  Future<int> getDailyTotalMl(DateTime date);
  Future<void> addWater(DateTime date, int amountMl);
  Future<WaterConfigData?> getConfig();

  /// La meta diaria es lo único que se configura del agua.
  Future<void> saveGoal(int dailyGoalMl);

  /// Las tomas del día, de la primera a la última.
  Future<List<DailyWaterLog>> getDailyLogs(DateTime date);

  Future<void> deleteWaterLog(int id);
}
