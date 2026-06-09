import 'package:flutter_test/flutter_test.dart';
import 'package:kiolog/core/database/app_database.dart';
import 'package:kiolog/features/exercise/data/repositories/exercise_repository_impl.dart';

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
      await repository.createPlan('Plan A');
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

      final itemId = await repository.addRoutineItem(
        routineId: routineId,
        exerciseName: 'Press Banca',
        sets: 4,
        reps: 10,
        weightKg: 60,
      );
      expect(itemId, isPositive);

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

    group('routine items', () {
      test('addRoutineItem and getRoutineItemsOrdered', () async {
        final planId = await repository.createPlan('Plan');
        final routineId = await repository.addRoutine(
          planId: planId,
          dayNumber: 1,
          routineName: 'Pecho',
        );
        final itemId = await repository.addRoutineItem(
          routineId: routineId,
          exerciseName: 'Press Banca',
          sets: 4,
          reps: 10,
          weightKg: 80.0,
          setType: 'pyramid',
          orderIndex: 0,
        );
        expect(itemId, isPositive);
        final items = await repository.getRoutineItemsOrdered(routineId);
        expect(items.length, 1);
        expect(items.first.setType, 'pyramid');
      });

      test('updateRoutineItem updates partial fields', () async {
        final planId = await repository.createPlan('Plan');
        final routineId = await repository.addRoutine(
          planId: planId,
          dayNumber: 1,
          routineName: 'Pecho',
        );
        final itemId = await repository.addRoutineItem(
          routineId: routineId,
          exerciseName: 'Press',
          sets: 3,
          reps: 10,
        );
        await repository.updateRoutineItem(
          itemId: itemId,
          exerciseName: 'Press Banca',
          setType: 'drop',
        );
        final items = await repository.getRoutineItemsOrdered(routineId);
        expect(items.first.exerciseName, 'Press Banca');
        expect(items.first.setType, 'drop');
        expect(items.first.sets, 3); // unchanged
      });

      test('deleteRoutineItem removes item', () async {
        final planId = await repository.createPlan('Plan');
        final routineId = await repository.addRoutine(
          planId: planId,
          dayNumber: 1,
          routineName: 'Pecho',
        );
        final itemId = await repository.addRoutineItem(
          routineId: routineId,
          exerciseName: 'Curl',
          sets: 3,
          reps: 12,
        );
        await repository.deleteRoutineItem(itemId);
        final items = await repository.getRoutineItemsOrdered(routineId);
        expect(items, isEmpty);
      });
    });

    group('set defs', () {
      test('replaceRoutineSetDefs and getRoutineSetDefs', () async {
        final planId = await repository.createPlan('Plan');
        final routineId = await repository.addRoutine(
          planId: planId,
          dayNumber: 1,
          routineName: 'Pecho',
        );
        final itemId = await repository.addRoutineItem(
          routineId: routineId,
          exerciseName: 'Press',
          sets: 3,
          reps: 10,
          setType: 'pyramid',
        );
        await repository.replaceRoutineSetDefs(
          routineItemId: itemId,
          defs: [
            (setNumber: 1, dropOfSetNumber: null, reps: 12, weightKg: 70.0),
            (setNumber: 2, dropOfSetNumber: null, reps: 10, weightKg: 80.0),
          ],
        );
        final defs = await repository.getRoutineSetDefs(itemId);
        expect(defs.length, 2);
        expect(defs[0].weightKg, 70.0);
        expect(defs[1].weightKg, 80.0);
      });
    });

    group('cardio', () {
      test('logCardio, getCardioLogsForWeek, updateCardio, deleteCardio', () async {
        final monday = DateTime.utc(2026, 6, 2);
        final id = await repository.logCardio(
          date: monday,
          cardioType: 'treadmill',
          durationMinutes: 30,
        );
        expect(id, isPositive);

        var logs = await repository.getCardioLogsForWeek(monday);
        expect(logs.length, 1);
        expect(logs.first.cardioType, 'treadmill');

        await repository.updateCardio(
          cardioId: id,
          durationMinutes: 45,
        );
        logs = await repository.getCardioLogsForWeek(monday);
        expect(logs.first.durationMinutes, 45);

        await repository.deleteCardio(id);
        logs = await repository.getCardioLogsForWeek(monday);
        expect(logs, isEmpty);
      });
    });

    group('exercise config', () {
      test('updateExerciseConfig and getExerciseConfig', () async {
        await repository.updateExerciseConfig(
          weeklyRoutineDaysGoal: 5,
          weeklyCardioDaysGoal: 4,
          cardioMinutesGoal: 45,
        );
        final config = await repository.getExerciseConfig();
        expect(config?.weeklyRoutineDaysGoal, 5);
        expect(config?.weeklyCardioDaysGoal, 4);
        expect(config?.cardioMinutesGoal, 45);
      });
    });

    group('weekly stats', () {
      test('getWeeklyStats returns list with correct length', () async {
        final stats = await repository.getWeeklyStats(weeksBack: 4);
        expect(stats.length, 4);
        expect(stats.every((s) => s.routineDaysDone >= 0), true);
        expect(stats.every((s) => s.cardioDaysDone >= 0), true);
      });

      test('routineDaysDone counts distinct days, not sessions', () async {
        final planId = await repository.createPlan('Plan');
        final routineId = await repository.addRoutine(
          planId: planId,
          dayNumber: 1,
          routineName: 'Pecho',
        );
        final now = DateTime.now().toUtc();
        final today = DateTime.utc(now.year, now.month, now.day);
        final yesterday = today.subtract(const Duration(days: 1));
        // Dos sesiones el mismo día — debe contar como 1 día
        final s1 = await repository.startSession(today, routineId: routineId);
        await repository.endSession(s1);
        final s2 = await repository.startSession(today, routineId: routineId);
        await repository.endSession(s2);
        // Una sesión un día distinto (dentro de la misma semana)
        final s3 =
            await repository.startSession(yesterday, routineId: routineId);
        await repository.endSession(s3);

        final stats = await repository.getWeeklyStats(weeksBack: 1);
        expect(stats.last.routineDaysDone, 2); // hoy + ayer = 2 días distintos
      });

      test('cardioDaysDone counts distinct days, not sessions', () async {
        final now = DateTime.now().toUtc();
        final today = DateTime.utc(now.year, now.month, now.day);
        // Dos sesiones de cardio el mismo día
        await repository.logCardio(
            date: today, cardioType: 'treadmill', durationMinutes: 20);
        await repository.logCardio(
            date: today, cardioType: 'elliptical', durationMinutes: 15);

        final stats = await repository.getWeeklyStats(weeksBack: 1);
        expect(stats.last.cardioDaysDone, 1); // mismo día = 1
      });
    });
  });
}
