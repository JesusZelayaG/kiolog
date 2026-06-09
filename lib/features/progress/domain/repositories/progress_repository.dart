import 'package:kiolog/core/database/app_database.dart';

abstract class ProgressRepository {
  Future<List<WeightLog>> getWeightLogs(DateTime start, DateTime end);
  Future<void> addWeightLog(DateTime date, double weightKg);

  Future<List<Measurement>> getMeasurements();
  Future<Measurement?> getLatestMeasurement();
  Future<void> addMeasurement({
    required DateTime date,
    required double weightKg,
    required double heightCm,
    double? armFlexedCm,
    double? armRelaxedCm,
    double? waistCm,
    double? hipCm,
    double? calfCm,
    double? lowerAbdomenCm,
    double? thighCm,
    double? midGluteusCm,
    double? chestCm,
    double? bodyFatPct,
    double? leanMassKg,
    double? visceralMass,
  });
}
