// test/dao/exercise_dao_test.dart
import 'package:flutter_test/flutter_test.dart';
import 'package:drift/drift.dart' hide isNotNull;
import 'package:kiolog/core/database/app_database.dart';
import '../helpers/database_helper.dart';

void main() {
  late AppDatabase db;

  setUp(() => db = createTestDatabase());
  tearDown(() async => db.close());

  group('ExerciseDao - Plans', () {
    test('inserta plan y obtiene el activo', () async {
      await db.exerciseDao.insertExercisePlan(
        const ExercisePlansCompanion(name: Value('Plan Gym Enero')),
      );

      final active = await db.exerciseDao.getActiveExercisePlan();
      expect(active?.name, 'Plan Gym Enero');
      expect(active?.isActive, true);
    });

    test('setActiveExercisePlan desactiva planes anteriores', () async {
      final id1 = await db.exerciseDao.insertExercisePlan(
        const ExercisePlansCompanion(name: Value('Plan A')),
      );
      final id2 = await db.exerciseDao.insertExercisePlan(
        const ExercisePlansCompanion(name: Value('Plan B')),
      );

      await db.exerciseDao.setActiveExercisePlan(id2);

      final plans = await db.exerciseDao.getExercisePlans();
      expect(plans.firstWhere((p) => p.id == id1).isActive, false);
      expect(plans.firstWhere((p) => p.id == id2).isActive, true);
    });
  });

  group('ExerciseDao - Routines & Items', () {
    test('inserta rutina e items, recupera por día', () async {
      final planId = await db.exerciseDao.insertExercisePlan(
        const ExercisePlansCompanion(name: Value('Plan')),
      );
      final routineId = await db.exerciseDao.insertExerciseRoutine(
        ExerciseRoutinesCompanion(
          planId: Value(planId),
          dayNumber: const Value(1), // Día 1 de rutina
          routineName: const Value('Pecho y Tríceps'),
        ),
      );
      await db.exerciseDao.insertExerciseRoutineItem(
        ExerciseRoutineItemsCompanion(
          routineId: Value(routineId),
          exerciseName: const Value('Press de Banca'),
          sets: const Value(4),
          reps: const Value(10),
          weightKg: const Value(60.0),
        ),
      );

      final routines =
          await db.exerciseDao.getRoutinesForPlan(planId);
      expect(routines.length, 1);
      expect(routines.first.routineName, 'Pecho y Tríceps');
      expect(routines.first.dayNumber, 1);

      final items = await db.exerciseDao.getRoutineItems(routineId);
      expect(items.length, 1);
      expect(items.first.exerciseName, 'Press de Banca');
      expect(items.first.sets, 4);
    });
  });

  group('ExerciseDao - Sessions & Sets', () {
    test('crea sesión y registra series', () async {
      final sessionId = await db.exerciseDao.insertExerciseSession(
        ExerciseSessionLogsCompanion(
          date: Value(DateTime.utc(2026, 5, 28)),
          gymArrivedAt: Value(DateTime.utc(2026, 5, 28, 8, 0)),
        ),
      );

      await db.exerciseDao.insertExerciseSetLog(
        ExerciseSetLogsCompanion(
          sessionId: Value(sessionId),
          exerciseName: const Value('Sentadillas'),
          setNumber: const Value(1),
          reps: const Value(12),
          weightKg: const Value(80.0),
        ),
      );

      final sets = await db.exerciseDao.getSessionSets(sessionId);
      expect(sets.length, 1);
      expect(sets.first.weightKg, 80.0);
    });

    test('actualiza hora de salida de la sesión', () async {
      final sessionId = await db.exerciseDao.insertExerciseSession(
        ExerciseSessionLogsCompanion(
          date: Value(DateTime.utc(2026, 5, 28)),
          gymArrivedAt: Value(DateTime.utc(2026, 5, 28, 8, 0)),
        ),
      );

      await db.exerciseDao.updateSessionEndTime(
          sessionId, DateTime.utc(2026, 5, 28, 9, 30));

      final session =
          await db.exerciseDao.getSession(sessionId);
      expect(session?.gymLeftAt, isNotNull);
    });
  });

  group('ExerciseDao - RoutineItems CRUD', () {
    late int planId;
    late int routineId;

    setUp(() async {
      planId = await db.exerciseDao.insertExercisePlan(
        const ExercisePlansCompanion(name: Value('Plan')),
      );
      routineId = await db.exerciseDao.insertExerciseRoutine(
        ExerciseRoutinesCompanion(
          planId: Value(planId),
          dayNumber: const Value(1),
          routineName: const Value('Piernas'),
        ),
      );
    });

    test('insertExerciseRoutineItem con setType y orderIndex', () async {
      final itemId = await db.exerciseDao.insertExerciseRoutineItem(
        ExerciseRoutineItemsCompanion(
          routineId: Value(routineId),
          exerciseName: const Value('Sentadilla'),
          sets: const Value(4),
          reps: const Value(12),
          weightKg: const Value(80.0),
          setType: const Value('pyramid'),
          orderIndex: const Value(0),
        ),
      );
      final items = await db.exerciseDao.getRoutineItemsOrdered(routineId);
      expect(items.length, 1);
      expect(items.first.id, itemId);
      expect(items.first.setType, 'pyramid');
      expect(items.first.orderIndex, 0);
    });

    test('updateRoutineItem modifica nombre y setType', () async {
      final itemId = await db.exerciseDao.insertExerciseRoutineItem(
        ExerciseRoutineItemsCompanion(
          routineId: Value(routineId),
          exerciseName: const Value('Press'),
          sets: const Value(3),
          reps: const Value(10),
          setType: const Value('normal'),
          orderIndex: const Value(0),
        ),
      );
      await db.exerciseDao.updateRoutineItem(
        itemId,
        const ExerciseRoutineItemsCompanion(
          exerciseName: Value('Press Banca'),
          setType: Value('drop'),
        ),
      );
      final items = await db.exerciseDao.getRoutineItemsOrdered(routineId);
      expect(items.first.exerciseName, 'Press Banca');
      expect(items.first.setType, 'drop');
    });

    test('deleteRoutineItem elimina el item', () async {
      final itemId = await db.exerciseDao.insertExerciseRoutineItem(
        ExerciseRoutineItemsCompanion(
          routineId: Value(routineId),
          exerciseName: const Value('Curl'),
          sets: const Value(3),
          reps: const Value(12),
          setType: const Value('normal'),
          orderIndex: const Value(0),
        ),
      );
      await db.exerciseDao.deleteRoutineItem(itemId);
      final items = await db.exerciseDao.getRoutineItemsOrdered(routineId);
      expect(items, isEmpty);
    });

    test('getRoutineItemsOrdered retorna items por orderIndex', () async {
      await db.exerciseDao.insertExerciseRoutineItem(
        ExerciseRoutineItemsCompanion(
          routineId: Value(routineId),
          exerciseName: const Value('Ejercicio B'),
          sets: const Value(3),
          reps: const Value(10),
          setType: const Value('normal'),
          orderIndex: const Value(1),
        ),
      );
      await db.exerciseDao.insertExerciseRoutineItem(
        ExerciseRoutineItemsCompanion(
          routineId: Value(routineId),
          exerciseName: const Value('Ejercicio A'),
          sets: const Value(4),
          reps: const Value(12),
          setType: const Value('normal'),
          orderIndex: const Value(0),
        ),
      );
      final items = await db.exerciseDao.getRoutineItemsOrdered(routineId);
      expect(items[0].exerciseName, 'Ejercicio A');
      expect(items[1].exerciseName, 'Ejercicio B');
    });
  });

  group('ExerciseDao - RoutineSetDefs', () {
    late int routineItemId;

    setUp(() async {
      final planId = await db.exerciseDao.insertExercisePlan(
        const ExercisePlansCompanion(name: Value('Plan')),
      );
      final routineId = await db.exerciseDao.insertExerciseRoutine(
        ExerciseRoutinesCompanion(
          planId: Value(planId),
          dayNumber: const Value(1),
          routineName: const Value('Pecho'),
        ),
      );
      routineItemId = await db.exerciseDao.insertExerciseRoutineItem(
        ExerciseRoutineItemsCompanion(
          routineId: Value(routineId),
          exerciseName: const Value('Press Banca'),
          sets: const Value(3),
          reps: const Value(10),
          setType: const Value('pyramid'),
          orderIndex: const Value(0),
        ),
      );
    });

    test('replaceRoutineSetDefs guarda y reemplaza defs', () async {
      final defs = [
        ExerciseRoutineSetDefsCompanion(
          routineItemId: Value(routineItemId),
          setNumber: const Value(1),
          reps: const Value(12),
          weightKg: const Value(70.0),
        ),
        ExerciseRoutineSetDefsCompanion(
          routineItemId: Value(routineItemId),
          setNumber: const Value(2),
          reps: const Value(10),
          weightKg: const Value(80.0),
        ),
      ];
      await db.exerciseDao.replaceRoutineSetDefs(routineItemId, defs);
      final saved = await db.exerciseDao.getRoutineSetDefs(routineItemId);
      expect(saved.length, 2);
      expect(saved[0].weightKg, 70.0);
      expect(saved[1].weightKg, 80.0);

      await db.exerciseDao.replaceRoutineSetDefs(routineItemId, [
        ExerciseRoutineSetDefsCompanion(
          routineItemId: Value(routineItemId),
          setNumber: const Value(1),
          reps: const Value(8),
          weightKg: const Value(90.0),
        ),
      ]);
      final replaced = await db.exerciseDao.getRoutineSetDefs(routineItemId);
      expect(replaced.length, 1);
      expect(replaced[0].weightKg, 90.0);
    });

    test('getRoutineSetDefs retorna lista vacía si no hay defs', () async {
      final defs = await db.exerciseDao.getRoutineSetDefs(routineItemId);
      expect(defs, isEmpty);
    });
  });

  group('ExerciseDao - CardioLogs', () {
    test('insertCardioLog y getCardioLogsForWeek', () async {
      final monday = DateTime.utc(2026, 6, 2);
      await db.exerciseDao.insertCardioLog(CardioLogsCompanion(
        date: Value(monday),
        cardioType: const Value('treadmill'),
        durationMinutes: const Value(32),
      ));
      await db.exerciseDao.insertCardioLog(CardioLogsCompanion(
        date: Value(monday.add(const Duration(days: 2))),
        cardioType: const Value('elliptical'),
        durationMinutes: const Value(25),
      ));
      await db.exerciseDao.insertCardioLog(CardioLogsCompanion(
        date: Value(monday.add(const Duration(days: 8))),
        cardioType: const Value('bike'),
        durationMinutes: const Value(30),
      ));
      final logs = await db.exerciseDao.getCardioLogsForWeek(monday);
      expect(logs.length, 2);
    });

    test('updateCardioLog modifica duración', () async {
      final id = await db.exerciseDao.insertCardioLog(CardioLogsCompanion(
        date: Value(DateTime.utc(2026, 6, 3)),
        cardioType: const Value('treadmill'),
        durationMinutes: const Value(20),
      ));
      await db.exerciseDao.updateCardioLog(
        id,
        const CardioLogsCompanion(durationMinutes: Value(35)),
      );
      final logs = await db.exerciseDao
          .getCardioLogsForWeek(DateTime.utc(2026, 6, 2));
      expect(logs.first.durationMinutes, 35);
    });

    test('deleteCardioLog elimina el registro', () async {
      final id = await db.exerciseDao.insertCardioLog(CardioLogsCompanion(
        date: Value(DateTime.utc(2026, 6, 3)),
        cardioType: const Value('bike'),
        durationMinutes: const Value(30),
      ));
      await db.exerciseDao.deleteCardioLog(id);
      final logs = await db.exerciseDao
          .getCardioLogsForWeek(DateTime.utc(2026, 6, 2));
      expect(logs, isEmpty);
    });
  });

  group('ExerciseDao - ExerciseConfig', () {
    test('upsertExerciseConfig crea config si no existe', () async {
      await db.exerciseDao.upsertExerciseConfig(
        const ExerciseConfigCompanion(
          weeklyRoutineDaysGoal: Value(4),
          weeklyCardioDaysGoal: Value(3),
          cardioMinutesGoal: Value(30),
        ),
      );
      final config = await db.exerciseDao.getExerciseConfig();
      expect(config?.weeklyRoutineDaysGoal, 4);
      expect(config?.weeklyCardioDaysGoal, 3);
    });

    test('upsertExerciseConfig actualiza config existente', () async {
      await db.exerciseDao.upsertExerciseConfig(
        const ExerciseConfigCompanion(
          weeklyRoutineDaysGoal: Value(4),
          weeklyCardioDaysGoal: Value(3),
          cardioMinutesGoal: Value(30),
        ),
      );
      await db.exerciseDao.upsertExerciseConfig(
        const ExerciseConfigCompanion(
          weeklyCardioDaysGoal: Value(5),
        ),
      );
      final config = await db.exerciseDao.getExerciseConfig();
      expect(config?.weeklyCardioDaysGoal, 5);
      expect(config?.weeklyRoutineDaysGoal, 4);
    });
  });

  group('ExerciseDao - historical reference', () {
    test('getLastSessionSetsForExercise retorna sets de la última sesión', () async {
      final planId = await db.exerciseDao.insertExercisePlan(
        const ExercisePlansCompanion(name: Value('Plan')),
      );
      final session1 = await db.exerciseDao.insertExerciseSession(
        ExerciseSessionLogsCompanion(
          date: Value(DateTime.utc(2026, 6, 1)),
          gymArrivedAt: Value(DateTime.utc(2026, 6, 1, 7)),
          gymLeftAt: Value(DateTime.utc(2026, 6, 1, 8)),
          routineId: Value(null),
        ),
      );
      final session2 = await db.exerciseDao.insertExerciseSession(
        ExerciseSessionLogsCompanion(
          date: Value(DateTime.utc(2026, 6, 5)),
          gymArrivedAt: Value(DateTime.utc(2026, 6, 5, 7)),
          gymLeftAt: Value(DateTime.utc(2026, 6, 5, 8)),
          routineId: Value(null),
        ),
      );
      await db.exerciseDao.insertExerciseSetLog(ExerciseSetLogsCompanion(
        sessionId: Value(session1),
        exerciseName: const Value('Sentadilla'),
        setNumber: const Value(1),
        reps: const Value(12),
        weightKg: const Value(70.0),
        setType: const Value('normal'),
      ));
      await db.exerciseDao.insertExerciseSetLog(ExerciseSetLogsCompanion(
        sessionId: Value(session2),
        exerciseName: const Value('Sentadilla'),
        setNumber: const Value(1),
        reps: const Value(10),
        weightKg: const Value(85.0),
        setType: const Value('pyramid'),
      ));
      await db.exerciseDao.insertExerciseSetLog(ExerciseSetLogsCompanion(
        sessionId: Value(session2),
        exerciseName: const Value('Sentadilla'),
        setNumber: const Value(2),
        reps: const Value(8),
        weightKg: const Value(95.0),
        setType: const Value('pyramid'),
      ));

      final sets = await db.exerciseDao
          .getLastSessionSetsForExercise('Sentadilla');
      expect(sets.length, 2);
      expect(sets.every((s) => s.sessionId == session2), true);
    });

    test('getLastSessionSetsForExercise retorna vacío si no hay historial', () async {
      final sets = await db.exerciseDao
          .getLastSessionSetsForExercise('Ejercicio nuevo');
      expect(sets, isEmpty);
    });
  });

  group('ExerciseDao - weekly sessions', () {
    test('getCompletedRoutineSessionsForWeek retorna solo sesiones completadas con rutina', () async {
      final planId = await db.exerciseDao.insertExercisePlan(
        const ExercisePlansCompanion(name: Value('Plan')),
      );
      final routineId = await db.exerciseDao.insertExerciseRoutine(
        ExerciseRoutinesCompanion(
          planId: Value(planId),
          dayNumber: const Value(1),
          routineName: const Value('Pecho'),
        ),
      );
      final monday = DateTime.utc(2026, 6, 2);

      await db.exerciseDao.insertExerciseSession(ExerciseSessionLogsCompanion(
        date: Value(monday),
        routineId: Value(routineId),
        gymArrivedAt: Value(monday),
        gymLeftAt: Value(monday.add(const Duration(hours: 1))),
      ));
      await db.exerciseDao.insertExerciseSession(ExerciseSessionLogsCompanion(
        date: Value(monday.add(const Duration(days: 1))),
        routineId: Value(routineId),
        gymArrivedAt: Value(monday.add(const Duration(days: 1))),
      ));
      await db.exerciseDao.insertExerciseSession(ExerciseSessionLogsCompanion(
        date: Value(monday.add(const Duration(days: 8))),
        routineId: Value(routineId),
        gymArrivedAt: Value(monday.add(const Duration(days: 8))),
        gymLeftAt: Value(monday.add(const Duration(days: 8, hours: 1))),
      ));

      final sessions = await db.exerciseDao
          .getCompletedRoutineSessionsForWeek(monday);
      expect(sessions.length, 1);
    });
  });
}
