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
          dayOfWeek: const Value(1), // Lunes
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

      final routine =
          await db.exerciseDao.getRoutineForDay(planId, 1);
      expect(routine?.routineName, 'Pecho y Tríceps');

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
}
