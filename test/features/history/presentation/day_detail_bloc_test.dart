import 'package:bloc_test/bloc_test.dart';
import 'package:drift/drift.dart' hide isNull, isNotNull;
import 'package:flutter_test/flutter_test.dart';
import 'package:kiolog/core/database/app_database.dart';
import 'package:kiolog/features/history/presentation/bloc/day_detail_bloc.dart';
import 'package:kiolog/features/history/presentation/bloc/day_detail_event.dart';
import 'package:kiolog/features/history/presentation/bloc/day_detail_state.dart';

import '../../../helpers/database_helper.dart';

void main() {
  late AppDatabase db;

  setUp(() {
    db = createTestDatabase();
  });

  tearDown(() async => db.close());

  DayDetailBloc buildBloc() =>
      DayDetailBloc(db.waterSleepDao, db.nutritionDao, db.exerciseDao);

  final testDate = DateTime.utc(2026, 6, 11);

  group('DayDetailBloc', () {
    blocTest<DayDetailBloc, DayDetailState>(
      'emits [loading, success] with empty data for a day with no logs',
      build: buildBloc,
      act: (bloc) => bloc.add(DayDetailLoaded(date: testDate)),
      expect: () => [
        isA<DayDetailState>()
            .having((s) => s.status, 'status', DayDetailStatus.loading),
        isA<DayDetailState>()
            .having((s) => s.status, 'status', DayDetailStatus.success)
            .having((s) => s.waterLogs, 'waterLogs', isEmpty)
            .having((s) => s.mealLogs, 'mealLogs', isEmpty)
            .having((s) => s.exerciseSessions, 'exerciseSessions', isEmpty)
            .having((s) => s.hasWater, 'hasWater', false)
            .having((s) => s.hasMeals, 'hasMeals', false)
            .having((s) => s.hasExercise, 'hasExercise', false)
            .having((s) => s.completedSegments, 'completedSegments', 0),
      ],
    );

    blocTest<DayDetailBloc, DayDetailState>(
      'emits success with water logs and correct total',
      build: buildBloc,
      setUp: () async {
        await db.waterSleepDao.insertWaterLog(DailyWaterLogsCompanion(
          date: Value(testDate),
          timestamp: Value(testDate),
          amountMl: const Value(500),
        ));
        await db.waterSleepDao.insertWaterLog(DailyWaterLogsCompanion(
          date: Value(testDate),
          timestamp: Value(testDate),
          amountMl: const Value(300),
        ));
      },
      act: (bloc) => bloc.add(DayDetailLoaded(date: testDate)),
      expect: () => [
        isA<DayDetailState>()
            .having((s) => s.status, 'status', DayDetailStatus.loading),
        isA<DayDetailState>()
            .having((s) => s.status, 'status', DayDetailStatus.success)
            .having((s) => s.waterLogs.length, 'waterLogs.length', 2)
            .having((s) => s.totalWaterMl, 'totalWaterMl', 800)
            .having((s) => s.hasWater, 'hasWater', true)
            .having((s) => s.completedSegments, 'completedSegments', 1),
      ],
    );

    blocTest<DayDetailBloc, DayDetailState>(
      'emits success with exercise session',
      build: buildBloc,
      setUp: () async {
        await db.exerciseDao.insertExerciseSession(
          ExerciseSessionLogsCompanion(
            date: Value(testDate),
            gymArrivedAt: Value(testDate),
            gymLeftAt: Value(testDate.add(const Duration(hours: 1))),
          ),
        );
      },
      act: (bloc) => bloc.add(DayDetailLoaded(date: testDate)),
      expect: () => [
        isA<DayDetailState>()
            .having((s) => s.status, 'status', DayDetailStatus.loading),
        isA<DayDetailState>()
            .having((s) => s.status, 'status', DayDetailStatus.success)
            .having((s) => s.exerciseSessions.length, 'sessions', 1)
            .having((s) => s.hasExercise, 'hasExercise', true),
      ],
    );
  });
}
