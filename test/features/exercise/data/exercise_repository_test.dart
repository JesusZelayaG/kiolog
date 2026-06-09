import 'package:flutter_test/flutter_test.dart';
import 'package:kiolog/core/database/app_database.dart';
import 'package:kiolog/features/exercise/data/repositories/exercise_repository_impl.dart';
import 'package:drift/drift.dart' hide isNull, isNotNull;

import '../../../helpers/database_helper.dart';

void main() {
  late AppDatabase db;
  late ExerciseRepositoryImpl repository;

  setUp(() {
    db = createTestDatabase();
    repository = ExerciseRepositoryImpl(db.exerciseDao);
  });

  tearDown(() async => db.close());

  group('ExerciseRepositoryImpl', () {
    test('createPlan and getActivePlan', () async {
      final id = await repository.createPlan('Plan Gym');
      expect(id, isPositive);

      final active = await repository.getActivePlan();
      expect(active?.name, 'Plan Gym');
    });

    test('activatePlan switches active plan', () async {
      final id1 = await repository.createPlan('Plan A');
      final id2 = await repository.createPlan('Plan B');

      await repository.activatePlan(id2);

      final active = await repository.getActivePlan();
      expect(active?.id, id2);
    });

    test('addRoutine and getRoutinesForPlan', () async {
      final planId = await repository.createPlan('Plan');
      await repository.addRoutine(
        planId: planId,
        dayNumber: 1,
        routineName: 'Pecho',
      );

      final routines = await repository.getRoutinesForPlan(planId);
      expect(routines.length, 1);
      expect(routines.first.routineName, 'Pecho');
      expect(routines.first.dayNumber, 1);
    });

    test('addRoutineItem and getRoutineItems', () async {
      final planId = await repository.createPlan('Plan');
      final routineId = await repository.addRoutine(
        planId: planId,
        dayNumber: 1,
        routineName: 'Pecho',
      );

      await repository.addRoutineItem(
        routineId: routineId,
        exerciseName: 'Press Banca',
        sets: 4,
        reps: 10,
        weightKg: 60,
      );

      final items = await repository.getRoutineItems(routineId);
      expect(items.length, 1);
      expect(items.first.exerciseName, 'Press Banca');
    });

    test('startSession, logSet, endSession flow', () async {
      final date = DateTime(2026, 6, 8);
      final sessionId = await repository.startSession(date);
      expect(sessionId, isPositive);

      await repository.logSet(
        sessionId: sessionId,
        exerciseName: 'Sentadillas',
        setNumber: 1,
        reps: 12,
        weightKg: 80,
      );

      final sets = await repository.getSessionSets(sessionId);
      expect(sets.length, 1);
      expect(sets.first.reps, 12);

      await repository.endSession(sessionId);
      final session = await repository.getSession(sessionId);
      expect(session?.gymLeftAt, isNotNull);
    });

    test('getSessionsForDate returns today sessions', () async {
      final date = DateTime(2026, 6, 8);
      await repository.startSession(date);

      final sessions = await repository.getSessionsForDate(date);
      expect(sessions.length, 1);
    });
  });
}
