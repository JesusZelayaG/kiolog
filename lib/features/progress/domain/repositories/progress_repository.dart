import 'dart:typed_data';

import 'package:kiolog/core/dao/measurements_dao.dart';
import 'package:kiolog/core/database/app_database.dart';

abstract class ProgressRepository {
  Future<List<WeightLog>> getWeightLogs(DateTime start, DateTime end);
  Future<void> addWeightLog(DateTime date, double weightKg);

  Future<List<Measurement>> getMeasurements();
  Future<Measurement?> getLatestMeasurement();
  Future<void> updateMeasurement(Measurement measurement);
  Future<void> deleteMeasurement(int id);
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

  /// El álbum de progreso sin los archivos, del más reciente al más antiguo.
  Future<List<ProgressMediaInfo>> getProgressMediaInfo();
  Future<ProgressMediaData?> getProgressMedia(int id);

  /// Agrega una foto o video al día [day] (medianoche UTC del día local).
  /// Lanza [ProgressAlbumFull] si ese día ya tiene [maxProgressMediaPerDay].
  Future<int> addProgressMedia({
    required DateTime day,
    required bool isVideo,
    required String extension,
    required Uint8List bytes,
  });
  Future<void> deleteProgressMedia(int id);
}

const maxProgressMediaPerDay = 3;

class ProgressAlbumFull implements Exception {
  const ProgressAlbumFull();
}
