// test/dao/measurements_dao_test.dart
import 'package:flutter_test/flutter_test.dart';
import 'package:drift/drift.dart' hide isNotNull;
import 'package:kiolog/core/database/app_database.dart';
import '../helpers/database_helper.dart';

void main() {
  late AppDatabase db;

  setUp(() => db = createTestDatabase());
  tearDown(() async => db.close());

  group('MeasurementsDao - Weight', () {
    test('registra pesos y los recupera en orden', () async {
      await db.measurementsDao.insertWeightLog(WeightLogsCompanion(
        date: Value(DateTime.utc(2026, 5, 1)),
        weightKg: const Value(80.0),
      ));
      await db.measurementsDao.insertWeightLog(WeightLogsCompanion(
        date: Value(DateTime.utc(2026, 5, 8)),
        weightKg: const Value(79.2),
      ));

      final logs = await db.measurementsDao.getWeightLogs(
        DateTime.utc(2026, 5, 1),
        DateTime.utc(2026, 5, 31),
      );
      expect(logs.length, 2);
      expect(logs.first.weightKg, 80.0);
    });
  });

  group('MeasurementsDao - Anthropometric', () {
    test('inserta medidas y getLatest retorna la más reciente', () async {
      await db.measurementsDao.insertMeasurement(MeasurementsCompanion(
        date: Value(DateTime.utc(2026, 4, 1)),
        weightKg: const Value(82.0),
        heightCm: const Value(175.0),
        waistCm: const Value(88.0),
      ));
      await db.measurementsDao.insertMeasurement(MeasurementsCompanion(
        date: Value(DateTime.utc(2026, 5, 1)),
        weightKg: const Value(80.0),
        heightCm: const Value(175.0),
        waistCm: const Value(85.0),
      ));

      final latest = await db.measurementsDao.getLatestMeasurement();
      expect(latest?.weightKg, 80.0);
      expect(latest?.waistCm, 85.0);
    });

    test('getMeasurements retorna todos ordenados por fecha desc', () async {
      for (int i = 1; i <= 3; i++) {
        await db.measurementsDao.insertMeasurement(MeasurementsCompanion(
          date: Value(DateTime.utc(2026, i, 1)),
          weightKg: Value(80.0 + i),
          heightCm: const Value(175.0),
        ));
      }

      final all = await db.measurementsDao.getMeasurements();
      expect(all.length, 3);
      expect(all.first.date.toUtc().month, 3); // más reciente primero
    });
  });
}
