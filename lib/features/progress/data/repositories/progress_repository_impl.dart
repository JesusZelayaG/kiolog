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
  Future<List<WeightLog>> getWeightLogs(DateTime start, DateTime end) async {
    final logs = await _measurementsDao.getWeightLogs(start, end);
    final first = DateTime.utc(start.year, start.month, start.day);
    final last = DateTime.utc(end.year, end.month, end.day);
    DateTime day(DateTime date) {
      final utc = date.toUtc();
      return DateTime.utc(utc.year, utc.month, utc.day);
    }

    // A consultation also weighs you, so it counts unless that day has its own log.
    final logged = logs.map((log) => day(log.date)).toSet();
    final consultations = await _measurementsDao.getMeasurements();
    return [
      ...logs,
      for (final m in consultations)
        if (!day(m.date).isBefore(first) &&
            !day(m.date).isAfter(last) &&
            !logged.contains(day(m.date)))
          WeightLog(id: -m.id, date: m.date, weightKg: m.weightKg),
    ]..sort((a, b) => a.date.compareTo(b.date));
  }

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
  Future<void> updateMeasurement(Measurement measurement) => _measurementsDao
      .updateMeasurement(measurement.copyWith(date: _dateOnly(measurement.date.toUtc())));

  @override
  Future<void> deleteMeasurement(int id) => _measurementsDao.deleteMeasurement(id);

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

  @override
  Future<List<ProgressMediaInfo>> getProgressMediaInfo() => _measurementsDao.getProgressMediaInfo();

  @override
  Future<ProgressMediaData?> getProgressMedia(int id) => _measurementsDao.getProgressMedia(id);

  @override
  Future<int> addProgressMedia({
    required DateTime day,
    required bool isVideo,
    required String extension,
    required Uint8List bytes,
  }) =>
      _measurementsDao.transaction(() async {
        if (await _measurementsDao.countProgressMedia(day) >= maxProgressMediaPerDay) {
          throw const ProgressAlbumFull();
        }
        return _measurementsDao.insertProgressMedia(ProgressMediaCompanion.insert(
          day: day,
          kind: isVideo ? 'video' : 'image',
          extension: extension,
          bytes: bytes,
          takenAt: DateTime.now().toUtc(),
        ));
      });

  @override
  Future<void> deleteProgressMedia(int id) => _measurementsDao.deleteProgressMedia(id);
}
