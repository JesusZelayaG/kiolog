import 'package:flutter_test/flutter_test.dart';
import 'package:kiolog/core/database/app_database.dart';
import 'package:kiolog/features/progress/data/repositories/progress_repository_impl.dart';
import 'package:drift/drift.dart' hide isNull, isNotNull;

import '../../../helpers/database_helper.dart';

void main() {
  late AppDatabase db;
  late ProgressRepositoryImpl repository;

  setUp(() {
    db = createTestDatabase();
    repository = ProgressRepositoryImpl(db.measurementsDao);
  });

  tearDown(() async => db.close());

  group('ProgressRepositoryImpl', () {
    test('addWeightLog and getWeightLogs', () async {
      final date = DateTime(2026, 6, 1);
      await repository.addWeightLog(date, 80.5);
      await repository.addWeightLog(date.add(const Duration(days: 7)), 79.8);

      final logs = await repository.getWeightLogs(
        DateTime(2026, 6, 1),
        DateTime(2026, 6, 30),
      );
      expect(logs.length, 2);
      expect(logs.first.weightKg, 80.5);
    });

    test('addMeasurement and getLatestMeasurement', () async {
      await repository.addMeasurement(
        date: DateTime(2026, 5, 1),
        weightKg: 82.0,
        heightCm: 175.0,
        waistCm: 88.0,
      );
      await repository.addMeasurement(
        date: DateTime(2026, 6, 1),
        weightKg: 80.0,
        heightCm: 175.0,
        waistCm: 85.0,
      );

      final latest = await repository.getLatestMeasurement();
      expect(latest?.weightKg, 80.0);
      expect(latest?.waistCm, 85.0);
    });

    test('getMeasurements returns all ordered by date desc', () async {
      for (int i = 1; i <= 3; i++) {
        await repository.addMeasurement(
          date: DateTime(2026, i, 1),
          weightKg: 80.0 + i,
          heightCm: 175.0,
        );
      }

      final all = await repository.getMeasurements();
      expect(all.length, 3);
      expect(all.first.date.toUtc().month, 3);
    });
  });
}
