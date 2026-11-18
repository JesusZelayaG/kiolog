import 'package:drift/drift.dart';

class WeightLogs extends Table {
  IntColumn get id => integer().autoIncrement()();
  DateTimeColumn get date => dateTime()();
  RealColumn get weightKg => real()();
}

// Append-only: cada consulta agrega un registro nuevo
class Measurements extends Table {
  IntColumn get id => integer().autoIncrement()();
  DateTimeColumn get date => dateTime()();
  RealColumn get weightKg => real()();
  RealColumn get heightCm => real()();
  RealColumn get armFlexedCm => real().nullable()();
  RealColumn get armRelaxedCm => real().nullable()();
  RealColumn get waistCm => real().nullable()();
  RealColumn get hipCm => real().nullable()();
  RealColumn get calfCm => real().nullable()();
  RealColumn get lowerAbdomenCm => real().nullable()();
  RealColumn get thighCm => real().nullable()();
  RealColumn get midGluteusCm => real().nullable()();
  RealColumn get chestCm => real().nullable()();
  RealColumn get bodyFatPct => real().nullable()();
  RealColumn get leanMassKg => real().nullable()();
  RealColumn get visceralMass => real().nullable()();
}

/// El álbum de progreso: hasta 3 fotos o videos cortos por día.
/// Como las fotos de comida, van en la base para que el respaldo siga
/// siendo un solo archivo, y nunca salen en el reporte.
class ProgressMedia extends Table {
  IntColumn get id => integer().autoIncrement()();

  /// El día, como medianoche UTC del día local (ver core/domain/day.dart).
  DateTimeColumn get day => dateTime()();

  /// image | video
  TextColumn get kind => text()();

  /// La extensión original (jpg, mp4…), para reproducir el video.
  TextColumn get extension => text()();
  BlobColumn get bytes => blob()();
  DateTimeColumn get takenAt => dateTime()();
}
