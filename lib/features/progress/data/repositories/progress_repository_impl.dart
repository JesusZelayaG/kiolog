import 'package:drift/drift.dart';
import 'package:kiolog/core/dao/measurements_dao.dart';
import 'package:kiolog/core/database/app_database.dart';
import '../../domain/repositories/progress_repository.dart';

class ProgressRepositoryImpl implements ProgressRepository {
  final MeasurementsDao _measurementsDao;

  ProgressRepositoryImpl(this._measurementsDao);

  DateTime _dateOnly(DateTime date) =>
      DateTime.utc(date.year, date.month, date.day);

  @override
  Future<List<WeightLog>> getWeightLogs(DateTime start, DateTime end) =>
      _measurementsDao.getWeightLogs(start, end);

  @override
  Future<void> addWeightLog(DateTime date, double weightKg) =>
      _measurementsDao.insertWeightLog(
        WeightLogsCompanion(
          date: Value(_dateOnly(date)),
          weightKg: Value(weightKg),
        ),
      );

  @override
  Future<List<Measurement>> getMeasurements() =>
      _measurementsDao.getMeasurements();

  @override
  Future<Measurement?> getLatestMeasurement() =>
      _measurementsDao.getLatestMeasurement();

  @override
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
  }) =>
      _measurementsDao.insertMeasurement(
        MeasurementsCompanion(
          date: Value(_dateOnly(date)),
          weightKg: Value(weightKg),
          heightCm: Value(heightCm),
          armFlexedCm: Value(armFlexedCm),
          armRelaxedCm: Value(armRelaxedCm),
          waistCm: Value(waistCm),
          hipCm: Value(hipCm),
          calfCm: Value(calfCm),
          lowerAbdomenCm: Value(lowerAbdomenCm),
          thighCm: Value(thighCm),
          midGluteusCm: Value(midGluteusCm),
          chestCm: Value(chestCm),
          bodyFatPct: Value(bodyFatPct),
          leanMassKg: Value(leanMassKg),
          visceralMass: Value(visceralMass),
        ),
      );
}
