# Exercise Module — Phase A: Foundation Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Add DB schema, DAO methods, repository interface/impl, and BLoC layer to support routine items with set types (normal/pyramid/drop), cardio logs, exercise config, and weekly progress — no UI changes.

**Architecture:** Schema-first TDD: each layer (DAO → Repository → BLoC) is tested before the next builds on it. New tables (`ExerciseRoutineSetDefs`, `CardioLogs`, `ExerciseConfig`) and columns (`setType`, `orderIndex` on routine items; `setType`, `dropOfSetId` on set logs) extend the existing exercise schema without breaking existing data. Schema bumps to version 4.

**Tech Stack:** Drift 2.18 (SQLite), flutter_bloc 8, bloc_test, mocktail, build_runner for code generation.

---

## File Map

| Action | File |
|--------|------|
| Modify | `lib/core/database/tables/exercise_tables.dart` |
| Modify | `lib/core/database/app_database.dart` |
| Modify | `lib/core/dao/exercise_dao.dart` |
| Create | `lib/features/exercise/domain/models/weekly_stat.dart` |
| Modify | `lib/features/exercise/domain/repositories/exercise_repository.dart` |
| Modify | `lib/features/exercise/data/repositories/exercise_repository_impl.dart` |
| Modify | `lib/features/exercise/presentation/bloc/exercise_event.dart` |
| Modify | `lib/features/exercise/presentation/bloc/exercise_state.dart` |
| Modify | `lib/features/exercise/presentation/bloc/exercise_bloc.dart` |
| Modify | `test/dao/exercise_dao_test.dart` |
| Modify | `test/features/exercise/data/exercise_repository_test.dart` |
| Modify | `test/features/exercise/presentation/exercise_bloc_test.dart` |

---

## Task 1: Schema — nuevas tablas y columnas

**Files:**
- Modify: `lib/core/database/tables/exercise_tables.dart`
- Modify: `lib/core/database/app_database.dart`

- [ ] **Step 1.1: Agregar columnas a tablas existentes y nuevas tablas**

Reemplaza el contenido de `lib/core/database/tables/exercise_tables.dart`:

```dart
import 'package:drift/drift.dart';

class ExercisePlans extends Table {
  IntColumn get id => integer().autoIncrement()();
  TextColumn get name => text()();
  DateTimeColumn get createdAt => dateTime()();
  BoolColumn get isActive => boolean().withDefault(const Constant(true))();
}

class ExerciseRoutines extends Table {
  IntColumn get id => integer().autoIncrement()();
  IntColumn get planId => integer().references(ExercisePlans, #id)();
  IntColumn get dayNumber => integer()();
  TextColumn get routineName => text()();
  TextColumn get notes => text().nullable()();
}

class ExerciseRoutineItems extends Table {
  IntColumn get id => integer().autoIncrement()();
  IntColumn get routineId => integer().references(ExerciseRoutines, #id)();
  TextColumn get exerciseName => text()();
  IntColumn get sets => integer()();
  IntColumn get reps => integer()();
  RealColumn get weightKg => real().nullable()();
  // NEW: tipo de serie — normal | pyramid | drop | pyramid_drop
  TextColumn get setType =>
      text().withDefault(const Constant('normal'))();
  // NEW: orden dentro del día de rutina
  IntColumn get orderIndex =>
      integer().withDefault(const Constant(0))();
}

/// Definiciones opcionales por serie de un ítem de rutina.
/// Si existen, la sesión las usa como plantilla pre-llenada.
/// Si no existen, se generan filas vacías según el conteo del ítem.
class ExerciseRoutineSetDefs extends Table {
  IntColumn get id => integer().autoIncrement()();
  IntColumn get routineItemId =>
      integer().references(ExerciseRoutineItems, #id)();
  IntColumn get setNumber => integer()();
  // null = serie normal; valor = número de serie padre (para drops)
  IntColumn get dropOfSet => integer().nullable()();
  IntColumn get reps => integer()();
  RealColumn get weightKg => real().nullable()();
}

class DailyExerciseLogs extends Table {
  IntColumn get id => integer().autoIncrement()();
  DateTimeColumn get date => dateTime()();
  IntColumn get routineId => integer().references(ExerciseRoutines, #id)();
  BoolColumn get completed =>
      boolean().withDefault(const Constant(false))();
}

class ExerciseSessionLogs extends Table {
  IntColumn get id => integer().autoIncrement()();
  DateTimeColumn get date => dateTime()();
  IntColumn get routineId =>
      integer().nullable().references(ExerciseRoutines, #id)();
  DateTimeColumn get gymArrivedAt => dateTime()();
  DateTimeColumn get gymLeftAt => dateTime().nullable()();
  RealColumn get lat => real().nullable()();
  RealColumn get lng => real().nullable()();
}

class ExerciseSetLogs extends Table {
  IntColumn get id => integer().autoIncrement()();
  IntColumn get sessionId =>
      integer().references(ExerciseSessionLogs, #id)();
  TextColumn get exerciseName => text()();
  IntColumn get setNumber => integer()();
  IntColumn get reps => integer()();
  RealColumn get weightKg => real().nullable()();
  // NEW: tipo de esta serie — normal | pyramid | drop
  TextColumn get setType =>
      text().withDefault(const Constant('normal'))();
  // NEW: id del ExerciseSetLog padre si es drop set
  IntColumn get dropOfSetId => integer().nullable()();
}

/// Registro de sesiones de cardio independientes (no parte de rutina).
class CardioLogs extends Table {
  IntColumn get id => integer().autoIncrement()();
  DateTimeColumn get date => dateTime()();
  // treadmill | elliptical | bike | other
  TextColumn get cardioType => text()();
  IntColumn get durationMinutes => integer()();
  TextColumn get notes => text().nullable()();
}

/// Configuración de metas semanales de ejercicio.
class ExerciseConfig extends Table {
  IntColumn get id => integer().autoIncrement()();
  IntColumn get weeklyRoutineDaysGoal =>
      integer().withDefault(const Constant(4))();
  IntColumn get weeklyCardioDaysGoal =>
      integer().withDefault(const Constant(3))();
  IntColumn get cardioMinutesGoal =>
      integer().withDefault(const Constant(30))();
}
```

- [ ] **Step 1.2: Registrar nuevas tablas en AppDatabase y bump a schema v4**

En `lib/core/database/app_database.dart`, actualiza las importaciones, el registro de tablas y la migración:

```dart
import 'dart:io';

import 'package:drift/drift.dart';
import 'package:drift/native.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

import 'tables/nutrition_tables.dart';
import 'tables/exercise_tables.dart';
import 'tables/water_sleep_tables.dart';
import 'tables/measurements_tables.dart';
import 'tables/achievements_tables.dart';
import 'tables/config_tables.dart';

import '../dao/nutrition_dao.dart';
import '../dao/exercise_dao.dart';
import '../dao/water_sleep_dao.dart';
import '../dao/measurements_dao.dart';
import '../dao/config_dao.dart';
import '../dao/achievements_dao.dart';
import '../dao/user_profile_dao.dart';

part 'app_database.g.dart';

@DriftDatabase(
  tables: [
    // Nutrition
    MealPlans,
    MealPlanOptions,
    DailyMealLogs,
    // Exercise
    ExercisePlans,
    ExerciseRoutines,
    ExerciseRoutineItems,
    ExerciseRoutineSetDefs,
    DailyExerciseLogs,
    ExerciseSessionLogs,
    ExerciseSetLogs,
    CardioLogs,
    ExerciseConfig,
    // Water & Sleep
    DailyWaterLogs,
    SleepLogs,
    // Measurements
    WeightLogs,
    Measurements,
    Achievements,
    // Config
    WaterConfig,
    GymConfig,
    NotificationSettings,
    AiConfig,
    UserProfiles,
  ],
  daos: [
    NutritionDao,
    ExerciseDao,
    WaterSleepDao,
    MeasurementsDao,
    ConfigDao,
    AchievementsDao,
    UserProfileDao,
  ],
)
class AppDatabase extends _$AppDatabase {
  AppDatabase() : super(_openConnection());

  AppDatabase.forTesting(super.executor);

  @override
  int get schemaVersion => 4;

  @override
  MigrationStrategy get migration {
    return MigrationStrategy(
      onCreate: (m) async {
        await m.createAll();
      },
      onUpgrade: (m, from, to) async {
        if (from < 2) {
          await m.createTable(userProfiles);
        }
        if (from < 3) {
          await m.deleteTable('exercise_set_logs');
          await m.deleteTable('exercise_session_logs');
          await m.deleteTable('daily_exercise_logs');
          await m.deleteTable('exercise_routine_items');
          await m.deleteTable('exercise_routines');
          await m.createTable(exerciseRoutines);
          await m.createTable(exerciseRoutineItems);
          await m.createTable(dailyExerciseLogs);
          await m.createTable(exerciseSessionLogs);
          await m.createTable(exerciseSetLogs);
        }
        if (from < 4) {
          await m.addColumn(
              exerciseRoutineItems, exerciseRoutineItems.setType);
          await m.addColumn(
              exerciseRoutineItems, exerciseRoutineItems.orderIndex);
          await m.addColumn(exerciseSetLogs, exerciseSetLogs.setType);
          await m.addColumn(
              exerciseSetLogs, exerciseSetLogs.dropOfSetId);
          await m.createTable(exerciseRoutineSetDefs);
          await m.createTable(cardioLogs);
          await m.createTable(exerciseConfig);
        }
      },
    );
  }
}

LazyDatabase _openConnection() {
  return LazyDatabase(() async {
    final dir = await getApplicationDocumentsDirectory();
    final file = File(p.join(dir.path, 'kiolog.sqlite'));
    return NativeDatabase.createInBackground(file);
  });
}
```

- [ ] **Step 1.3: Regenerar código de Drift**

```bash
cd /home/jesuszelaya/Documents/kiolog
flutter pub run build_runner build --delete-conflicting-outputs
```

Salida esperada: sin errores, archivos `.g.dart` regenerados.

- [ ] **Step 1.4: Verificar que compila**

```bash
flutter analyze lib/core/database/ lib/core/dao/
```

Salida esperada: `No issues found!`

- [ ] **Step 1.5: Commit**

```bash
git add lib/core/database/tables/exercise_tables.dart lib/core/database/app_database.dart lib/core/database/app_database.g.dart
git commit -m "feat(db): schema v4 — set types, set defs, cardio logs, exercise config"
```

---

## Task 2: DAO — nuevos métodos

**Files:**
- Modify: `lib/core/dao/exercise_dao.dart`
- Modify: `test/dao/exercise_dao_test.dart`

- [ ] **Step 2.1: Escribir tests primero**

Agrega al final de `test/dao/exercise_dao_test.dart`:

```dart
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

      // Reemplazar con nuevas defs
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
      // Fuera de la semana
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
      expect(config?.weeklyRoutineDaysGoal, 4); // no cambió
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
      expect(sets.length, 2); // solo de session2
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

      // Sesión completada con rutina — debe aparecer
      await db.exerciseDao.insertExerciseSession(ExerciseSessionLogsCompanion(
        date: Value(monday),
        routineId: Value(routineId),
        gymArrivedAt: Value(monday),
        gymLeftAt: Value(monday.add(const Duration(hours: 1))),
      ));
      // Sesión sin finalizar — no debe aparecer
      await db.exerciseDao.insertExerciseSession(ExerciseSessionLogsCompanion(
        date: Value(monday.add(const Duration(days: 1))),
        routineId: Value(routineId),
        gymArrivedAt: Value(monday.add(const Duration(days: 1))),
      ));
      // Sesión fuera de la semana — no debe aparecer
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
```

- [ ] **Step 2.2: Ejecutar tests — deben fallar**

```bash
flutter test test/dao/exercise_dao_test.dart
```

Salida esperada: errores de compilación (métodos no existen aún).

- [ ] **Step 2.3: Implementar nuevos métodos en el DAO**

Reemplaza el contenido de `lib/core/dao/exercise_dao.dart`:

```dart
import 'package:drift/drift.dart';
import '../database/app_database.dart';
import '../database/tables/exercise_tables.dart';

part 'exercise_dao.g.dart';

@DriftAccessor(tables: [
  ExercisePlans,
  ExerciseRoutines,
  ExerciseRoutineItems,
  ExerciseRoutineSetDefs,
  DailyExerciseLogs,
  ExerciseSessionLogs,
  ExerciseSetLogs,
  CardioLogs,
  ExerciseConfig,
])
class ExerciseDao extends DatabaseAccessor<AppDatabase>
    with _$ExerciseDaoMixin {
  ExerciseDao(super.db);

  // ── Plans ────────────────────────────────────────────────────────────────

  Future<int> insertExercisePlan(ExercisePlansCompanion plan) =>
      into(exercisePlans).insert(plan.copyWith(
        createdAt: plan.createdAt.present
            ? plan.createdAt
            : Value(DateTime.now().toUtc()),
        isActive: const Value(true),
      ));

  Future<List<ExercisePlan>> getExercisePlans() =>
      (select(exercisePlans)
            ..orderBy([(t) => OrderingTerm.desc(t.createdAt)]))
          .get();

  Future<ExercisePlan?> getActiveExercisePlan() =>
      (select(exercisePlans)..where((t) => t.isActive.equals(true)))
          .getSingleOrNull();

  Future<void> setActiveExercisePlan(int planId) async {
    await db.transaction(() async {
      final plan = await (select(exercisePlans)
            ..where((t) => t.id.equals(planId)))
          .getSingleOrNull();
      if (plan == null) throw ArgumentError('Exercise plan $planId not found');
      await (update(exercisePlans))
          .write(const ExercisePlansCompanion(isActive: Value(false)));
      await (update(exercisePlans)..where((t) => t.id.equals(planId)))
          .write(const ExercisePlansCompanion(isActive: Value(true)));
    });
  }

  // ── Routines ─────────────────────────────────────────────────────────────

  Future<int> insertExerciseRoutine(ExerciseRoutinesCompanion routine) =>
      into(exerciseRoutines).insert(routine);

  Future<List<ExerciseRoutine>> getRoutinesForPlan(int planId) =>
      (select(exerciseRoutines)
            ..where((t) => t.planId.equals(planId))
            ..orderBy([(t) => OrderingTerm.asc(t.dayNumber)]))
          .get();

  Future<ExerciseRoutine?> getRoutine(int routineId) =>
      (select(exerciseRoutines)..where((t) => t.id.equals(routineId)))
          .getSingleOrNull();

  // ── Routine Items ─────────────────────────────────────────────────────────

  Future<int> insertExerciseRoutineItem(ExerciseRoutineItemsCompanion item) =>
      into(exerciseRoutineItems).insert(item);

  Future<List<ExerciseRoutineItem>> getRoutineItems(int routineId) =>
      (select(exerciseRoutineItems)
            ..where((t) => t.routineId.equals(routineId)))
          .get();

  Future<List<ExerciseRoutineItem>> getRoutineItemsOrdered(int routineId) =>
      (select(exerciseRoutineItems)
            ..where((t) => t.routineId.equals(routineId))
            ..orderBy([(t) => OrderingTerm.asc(t.orderIndex)]))
          .get();

  Future<void> updateRoutineItem(
    int itemId,
    ExerciseRoutineItemsCompanion data,
  ) =>
      (update(exerciseRoutineItems)..where((t) => t.id.equals(itemId)))
          .write(data);

  Future<void> deleteRoutineItem(int itemId) =>
      (delete(exerciseRoutineItems)..where((t) => t.id.equals(itemId))).go();

  // ── Routine Set Defs ──────────────────────────────────────────────────────

  Future<List<ExerciseRoutineSetDef>> getRoutineSetDefs(int routineItemId) =>
      (select(exerciseRoutineSetDefs)
            ..where((t) => t.routineItemId.equals(routineItemId))
            ..orderBy([(t) => OrderingTerm.asc(t.setNumber)]))
          .get();

  Future<void> replaceRoutineSetDefs(
    int routineItemId,
    List<ExerciseRoutineSetDefsCompanion> defs,
  ) async {
    await db.transaction(() async {
      await (delete(exerciseRoutineSetDefs)
            ..where((t) => t.routineItemId.equals(routineItemId)))
          .go();
      for (final def in defs) {
        await into(exerciseRoutineSetDefs).insert(def);
      }
    });
  }

  // ── Sessions ──────────────────────────────────────────────────────────────

  Future<int> insertExerciseSession(ExerciseSessionLogsCompanion session) =>
      into(exerciseSessionLogs).insert(session);

  Future<ExerciseSessionLog?> getSession(int sessionId) =>
      (select(exerciseSessionLogs)..where((t) => t.id.equals(sessionId)))
          .getSingleOrNull();

  Future<void> updateSessionEndTime(int sessionId, DateTime endTime) =>
      (update(exerciseSessionLogs)..where((t) => t.id.equals(sessionId)))
          .write(ExerciseSessionLogsCompanion(gymLeftAt: Value(endTime)));

  Future<List<ExerciseSessionLog>> getSessionsForDate(DateTime date) {
    final start = DateTime.utc(date.year, date.month, date.day);
    final end = start.add(const Duration(days: 1));
    return (select(exerciseSessionLogs)
          ..where((t) =>
              t.date.isBiggerOrEqualValue(start) &
              t.date.isSmallerThanValue(end))
          ..orderBy([(t) => OrderingTerm.desc(t.gymArrivedAt)]))
        .get();
  }

  Future<List<ExerciseSessionLog>> getCompletedRoutineSessionsForWeek(
    DateTime weekStart,
  ) {
    final end = weekStart.add(const Duration(days: 7));
    return (select(exerciseSessionLogs)
          ..where((t) =>
              t.date.isBiggerOrEqualValue(weekStart) &
              t.date.isSmallerThanValue(end) &
              t.routineId.isNotNull() &
              t.gymLeftAt.isNotNull()))
        .get();
  }

  // ── Set Logs ──────────────────────────────────────────────────────────────

  Future<int> insertExerciseSetLog(ExerciseSetLogsCompanion setLog) =>
      into(exerciseSetLogs).insert(setLog);

  Future<List<ExerciseSetLog>> getSessionSets(int sessionId) =>
      (select(exerciseSetLogs)
            ..where((t) => t.sessionId.equals(sessionId))
            ..orderBy([(t) => OrderingTerm.asc(t.setNumber)]))
          .get();

  Future<List<ExerciseSetLog>> getLastSessionSetsForExercise(
    String exerciseName,
  ) async {
    final allSets = await (select(exerciseSetLogs)
          ..where((t) => t.exerciseName.equals(exerciseName))
          ..orderBy([(t) => OrderingTerm.desc(t.id)]))
        .get();
    if (allSets.isEmpty) return [];
    final lastSessionId = allSets.first.sessionId;
    return allSets.where((s) => s.sessionId == lastSessionId).toList();
  }

  // ── Daily Logs ────────────────────────────────────────────────────────────

  Future<int> insertDailyExerciseLog(DailyExerciseLogsCompanion log) =>
      into(dailyExerciseLogs).insert(log);

  Future<DailyExerciseLog?> getDailyExerciseLog(DateTime date) {
    final start = DateTime.utc(date.year, date.month, date.day);
    final end = start.add(const Duration(days: 1));
    return (select(dailyExerciseLogs)
          ..where((t) =>
              t.date.isBiggerOrEqualValue(start) &
              t.date.isSmallerThanValue(end)))
        .getSingleOrNull();
  }

  // ── Cardio Logs ───────────────────────────────────────────────────────────

  Future<int> insertCardioLog(CardioLogsCompanion log) =>
      into(cardioLogs).insert(log.copyWith(
        date: Value(log.date.value.toUtc()),
      ));

  Future<void> updateCardioLog(int id, CardioLogsCompanion data) =>
      (update(cardioLogs)..where((t) => t.id.equals(id))).write(data);

  Future<void> deleteCardioLog(int id) =>
      (delete(cardioLogs)..where((t) => t.id.equals(id))).go();

  Future<List<CardioLog>> getCardioLogsForWeek(DateTime weekStart) {
    final start = DateTime.utc(
        weekStart.year, weekStart.month, weekStart.day);
    final end = start.add(const Duration(days: 7));
    return (select(cardioLogs)
          ..where((t) =>
              t.date.isBiggerOrEqualValue(start) &
              t.date.isSmallerThanValue(end))
          ..orderBy([(t) => OrderingTerm.desc(t.date)]))
        .get();
  }

  // ── Exercise Config ───────────────────────────────────────────────────────

  Future<ExerciseConfigData?> getExerciseConfig() =>
      (select(exerciseConfig)).getSingleOrNull();

  Future<void> upsertExerciseConfig(ExerciseConfigCompanion config) async {
    final existing = await getExerciseConfig();
    if (existing == null) {
      await into(exerciseConfig).insert(config.copyWith(id: const Value.absent()));
    } else {
      await (update(exerciseConfig)..where((t) => t.id.equals(existing.id)))
          .write(config);
    }
  }
}
```

> **Nota:** Drift genera el tipo de dato de `ExerciseConfig` como `ExerciseConfigData` (no `ExerciseConfig`) para evitar colisión con el nombre de la tabla. Usar `ExerciseConfigData` en todo el código.

- [ ] **Step 2.4: Regenerar código del DAO**

```bash
flutter pub run build_runner build --delete-conflicting-outputs
```

- [ ] **Step 2.5: Ejecutar tests del DAO — deben pasar**

```bash
flutter test test/dao/exercise_dao_test.dart
```

Salida esperada: todos los tests en verde.

- [ ] **Step 2.6: Commit**

```bash
git add lib/core/dao/exercise_dao.dart lib/core/dao/exercise_dao.g.dart test/dao/exercise_dao_test.dart
git commit -m "feat(dao): routine items CRUD, set defs, cardio logs, exercise config, historical reference"
```

---

## Task 3: Domain model + Repository interface/impl

**Files:**
- Create: `lib/features/exercise/domain/models/weekly_stat.dart`
- Modify: `lib/features/exercise/domain/repositories/exercise_repository.dart`
- Modify: `lib/features/exercise/data/repositories/exercise_repository_impl.dart`
- Modify: `test/features/exercise/data/exercise_repository_test.dart`

- [ ] **Step 3.1: Crear modelo WeeklyStat**

Crea `lib/features/exercise/domain/models/weekly_stat.dart`:

```dart
import 'package:equatable/equatable.dart';

class WeeklyStat extends Equatable {
  final DateTime weekStart;
  final int routineDaysDone;
  final int cardioDaysDone;

  const WeeklyStat({
    required this.weekStart,
    required this.routineDaysDone,
    required this.cardioDaysDone,
  });

  @override
  List<Object?> get props => [weekStart, routineDaysDone, cardioDaysDone];
}
```

- [ ] **Step 3.2: Actualizar interfaz del repositorio**

Reemplaza `lib/features/exercise/domain/repositories/exercise_repository.dart`:

```dart
import 'package:kiolog/core/database/app_database.dart';
import '../models/weekly_stat.dart';

abstract class ExerciseRepository {
  // ── Plans ──────────────────────────────────────────────────────────────
  Future<ExercisePlan?> getActivePlan();
  Future<List<ExercisePlan>> getAllPlans();
  Future<void> activatePlan(int planId);
  Future<int> createPlan(String name);

  // ── Routines ───────────────────────────────────────────────────────────
  Future<List<ExerciseRoutine>> getRoutinesForPlan(int planId);
  Future<ExerciseRoutine?> getRoutine(int routineId);
  Future<int> addRoutine({
    required int planId,
    required int dayNumber,
    required String routineName,
    String? notes,
  });

  // ── Routine Items ──────────────────────────────────────────────────────
  Future<List<ExerciseRoutineItem>> getRoutineItems(int routineId);
  Future<List<ExerciseRoutineItem>> getRoutineItemsOrdered(int routineId);
  Future<int> addRoutineItem({
    required int routineId,
    required String exerciseName,
    required int sets,
    required int reps,
    double? weightKg,
    String setType = 'normal',
    int orderIndex = 0,
  });
  Future<void> updateRoutineItem({
    required int itemId,
    String? exerciseName,
    int? sets,
    int? reps,
    double? weightKg,
    String? setType,
    int? orderIndex,
  });
  Future<void> deleteRoutineItem(int itemId);

  // ── Routine Set Defs ───────────────────────────────────────────────────
  Future<List<ExerciseRoutineSetDef>> getRoutineSetDefs(int routineItemId);
  Future<void> replaceRoutineSetDefs({
    required int routineItemId,
    required List<({int setNumber, int? dropOfSet, int reps, double? weightKg})> defs,
  });

  // ── Daily Logs ─────────────────────────────────────────────────────────
  Future<DailyExerciseLog?> getDailyLog(DateTime date);
  Future<void> logDailyExercise(DateTime date, int routineId);

  // ── Sessions ───────────────────────────────────────────────────────────
  Future<int> startSession(DateTime date, {int? routineId});
  Future<void> endSession(int sessionId);
  Future<ExerciseSessionLog?> getSession(int sessionId);
  Future<List<ExerciseSessionLog>> getSessionsForDate(DateTime date);
  Future<List<ExerciseSessionLog>> getCompletedRoutineSessionsForWeek(
      DateTime weekStart);

  // ── Set Logs ───────────────────────────────────────────────────────────
  Future<void> logSet({
    required int sessionId,
    required String exerciseName,
    required int setNumber,
    required int reps,
    double? weightKg,
    String setType = 'normal',
    int? dropOfSetId,
  });
  Future<List<ExerciseSetLog>> getSessionSets(int sessionId);
  Future<List<ExerciseSetLog>> getLastSessionSetsForExercise(
      String exerciseName);

  // ── Cardio ─────────────────────────────────────────────────────────────
  Future<int> logCardio({
    required DateTime date,
    required String cardioType,
    required int durationMinutes,
    String? notes,
  });
  Future<void> updateCardio({
    required int cardioId,
    String? cardioType,
    int? durationMinutes,
    String? notes,
  });
  Future<void> deleteCardio(int cardioId);
  Future<List<CardioLog>> getCardioLogsForWeek(DateTime weekStart);

  // ── Config ─────────────────────────────────────────────────────────────
  Future<ExerciseConfigData?> getExerciseConfig();
  Future<void> updateExerciseConfig({
    int? weeklyRoutineDaysGoal,
    int? weeklyCardioDaysGoal,
    int? cardioMinutesGoal,
  });

  // ── Sessions (extended) ────────────────────────────────────────────────
  Future<void> deleteSession(int sessionId);

  // ── Progress ───────────────────────────────────────────────────────────
  Future<List<WeeklyStat>> getWeeklyStats({int weeksBack = 8});
}
```

- [ ] **Step 3.3: Implementar los nuevos métodos en el repositorio**

Reemplaza `lib/features/exercise/data/repositories/exercise_repository_impl.dart`:

```dart
import 'package:drift/drift.dart';
import 'package:kiolog/core/dao/exercise_dao.dart';
import 'package:kiolog/core/database/app_database.dart';
import '../../domain/models/weekly_stat.dart';
import '../../domain/repositories/exercise_repository.dart';

class ExerciseRepositoryImpl implements ExerciseRepository {
  final ExerciseDao _dao;

  ExerciseRepositoryImpl(this._dao);

  DateTime _utcDate(DateTime date) =>
      DateTime.utc(date.year, date.month, date.day);

  DateTime _mondayOf(DateTime date) {
    final d = date.toUtc();
    return DateTime.utc(d.year, d.month, d.day)
        .subtract(Duration(days: d.weekday - 1));
  }

  @override
  Future<ExercisePlan?> getActivePlan() => _dao.getActiveExercisePlan();

  @override
  Future<List<ExercisePlan>> getAllPlans() => _dao.getExercisePlans();

  @override
  Future<void> activatePlan(int planId) => _dao.setActiveExercisePlan(planId);

  @override
  Future<int> createPlan(String name) => _dao.insertExercisePlan(
        ExercisePlansCompanion(name: Value(name)),
      );

  @override
  Future<List<ExerciseRoutine>> getRoutinesForPlan(int planId) =>
      _dao.getRoutinesForPlan(planId);

  @override
  Future<ExerciseRoutine?> getRoutine(int routineId) =>
      _dao.getRoutine(routineId);

  @override
  Future<int> addRoutine({
    required int planId,
    required int dayNumber,
    required String routineName,
    String? notes,
  }) =>
      _dao.insertExerciseRoutine(ExerciseRoutinesCompanion(
        planId: Value(planId),
        dayNumber: Value(dayNumber),
        routineName: Value(routineName),
        notes: Value(notes),
      ));

  @override
  Future<List<ExerciseRoutineItem>> getRoutineItems(int routineId) =>
      _dao.getRoutineItems(routineId);

  @override
  Future<List<ExerciseRoutineItem>> getRoutineItemsOrdered(int routineId) =>
      _dao.getRoutineItemsOrdered(routineId);

  @override
  Future<int> addRoutineItem({
    required int routineId,
    required String exerciseName,
    required int sets,
    required int reps,
    double? weightKg,
    String setType = 'normal',
    int orderIndex = 0,
  }) =>
      _dao.insertExerciseRoutineItem(ExerciseRoutineItemsCompanion(
        routineId: Value(routineId),
        exerciseName: Value(exerciseName),
        sets: Value(sets),
        reps: Value(reps),
        weightKg: Value(weightKg),
        setType: Value(setType),
        orderIndex: Value(orderIndex),
      ));

  @override
  Future<void> updateRoutineItem({
    required int itemId,
    String? exerciseName,
    int? sets,
    int? reps,
    double? weightKg,
    String? setType,
    int? orderIndex,
  }) =>
      _dao.updateRoutineItem(
        itemId,
        ExerciseRoutineItemsCompanion(
          exerciseName:
              exerciseName != null ? Value(exerciseName) : const Value.absent(),
          sets: sets != null ? Value(sets) : const Value.absent(),
          reps: reps != null ? Value(reps) : const Value.absent(),
          weightKg: weightKg != null ? Value(weightKg) : const Value.absent(),
          setType: setType != null ? Value(setType) : const Value.absent(),
          orderIndex:
              orderIndex != null ? Value(orderIndex) : const Value.absent(),
        ),
      );

  @override
  Future<void> deleteRoutineItem(int itemId) => _dao.deleteRoutineItem(itemId);

  @override
  Future<List<ExerciseRoutineSetDef>> getRoutineSetDefs(int routineItemId) =>
      _dao.getRoutineSetDefs(routineItemId);

  @override
  Future<void> replaceRoutineSetDefs({
    required int routineItemId,
    required List<({int setNumber, int? dropOfSet, int reps, double? weightKg})>
        defs,
  }) =>
      _dao.replaceRoutineSetDefs(
        routineItemId,
        defs
            .map((d) => ExerciseRoutineSetDefsCompanion(
                  routineItemId: Value(routineItemId),
                  setNumber: Value(d.setNumber),
                  dropOfSet: Value(d.dropOfSet),
                  reps: Value(d.reps),
                  weightKg: Value(d.weightKg),
                ))
            .toList(),
      );

  @override
  Future<DailyExerciseLog?> getDailyLog(DateTime date) =>
      _dao.getDailyExerciseLog(_utcDate(date));

  @override
  Future<void> logDailyExercise(DateTime date, int routineId) =>
      _dao.insertDailyExerciseLog(DailyExerciseLogsCompanion(
        date: Value(_utcDate(date)),
        routineId: Value(routineId),
        completed: const Value(true),
      ));

  @override
  Future<int> startSession(DateTime date, {int? routineId}) =>
      _dao.insertExerciseSession(ExerciseSessionLogsCompanion(
        date: Value(_utcDate(date)),
        routineId: Value(routineId),
        gymArrivedAt: Value(DateTime.now().toUtc()),
      ));

  @override
  Future<void> endSession(int sessionId) =>
      _dao.updateSessionEndTime(sessionId, DateTime.now().toUtc());

  @override
  Future<ExerciseSessionLog?> getSession(int sessionId) =>
      _dao.getSession(sessionId);

  @override
  Future<List<ExerciseSessionLog>> getSessionsForDate(DateTime date) =>
      _dao.getSessionsForDate(_utcDate(date));

  @override
  Future<List<ExerciseSessionLog>> getCompletedRoutineSessionsForWeek(
          DateTime weekStart) =>
      _dao.getCompletedRoutineSessionsForWeek(_utcDate(weekStart));

  @override
  Future<void> deleteSession(int sessionId) =>
      (_dao.db.delete(_dao.exerciseSessionLogs)
            ..where((t) => t.id.equals(sessionId)))
          .go();

  @override
  Future<void> logSet({
    required int sessionId,
    required String exerciseName,
    required int setNumber,
    required int reps,
    double? weightKg,
    String setType = 'normal',
    int? dropOfSetId,
  }) =>
      _dao.insertExerciseSetLog(ExerciseSetLogsCompanion(
        sessionId: Value(sessionId),
        exerciseName: Value(exerciseName),
        setNumber: Value(setNumber),
        reps: Value(reps),
        weightKg: Value(weightKg),
        setType: Value(setType),
        dropOfSetId: Value(dropOfSetId),
      ));

  @override
  Future<List<ExerciseSetLog>> getSessionSets(int sessionId) =>
      _dao.getSessionSets(sessionId);

  @override
  Future<List<ExerciseSetLog>> getLastSessionSetsForExercise(
          String exerciseName) =>
      _dao.getLastSessionSetsForExercise(exerciseName);

  @override
  Future<int> logCardio({
    required DateTime date,
    required String cardioType,
    required int durationMinutes,
    String? notes,
  }) =>
      _dao.insertCardioLog(CardioLogsCompanion(
        date: Value(date.toUtc()),
        cardioType: Value(cardioType),
        durationMinutes: Value(durationMinutes),
        notes: Value(notes),
      ));

  @override
  Future<void> updateCardio({
    required int cardioId,
    String? cardioType,
    int? durationMinutes,
    String? notes,
  }) =>
      _dao.updateCardioLog(
        cardioId,
        CardioLogsCompanion(
          cardioType: cardioType != null
              ? Value(cardioType)
              : const Value.absent(),
          durationMinutes: durationMinutes != null
              ? Value(durationMinutes)
              : const Value.absent(),
          notes: notes != null ? Value(notes) : const Value.absent(),
        ),
      );

  @override
  Future<void> deleteCardio(int cardioId) => _dao.deleteCardioLog(cardioId);

  @override
  Future<List<CardioLog>> getCardioLogsForWeek(DateTime weekStart) =>
      _dao.getCardioLogsForWeek(_utcDate(weekStart));

  @override
  Future<ExerciseConfigData?> getExerciseConfig() =>
      _dao.getExerciseConfig();

  @override
  Future<void> updateExerciseConfig({
    int? weeklyRoutineDaysGoal,
    int? weeklyCardioDaysGoal,
    int? cardioMinutesGoal,
  }) =>
      _dao.upsertExerciseConfig(ExerciseConfigCompanion(
        weeklyRoutineDaysGoal: weeklyRoutineDaysGoal != null
            ? Value(weeklyRoutineDaysGoal)
            : const Value.absent(),
        weeklyCardioDaysGoal: weeklyCardioDaysGoal != null
            ? Value(weeklyCardioDaysGoal)
            : const Value.absent(),
        cardioMinutesGoal: cardioMinutesGoal != null
            ? Value(cardioMinutesGoal)
            : const Value.absent(),
      ));

  @override
  Future<List<WeeklyStat>> getWeeklyStats({int weeksBack = 8}) async {
    final now = DateTime.now().toUtc();
    final thisMonday = _mondayOf(now);
    final stats = <WeeklyStat>[];
    for (var i = weeksBack - 1; i >= 0; i--) {
      final weekStart =
          thisMonday.subtract(Duration(days: 7 * i));
      final routineSessions =
          await _dao.getCompletedRoutineSessionsForWeek(weekStart);
      final cardioLogs =
          await _dao.getCardioLogsForWeek(weekStart);
      stats.add(WeeklyStat(
        weekStart: weekStart,
        routineDaysDone: routineSessions.length,
        cardioDaysDone: cardioLogs.length,
      ));
    }
    return stats;
  }
}
```

- [ ] **Step 3.4: Agregar tests al repositorio**

Agrega los siguientes grupos al final de `test/features/exercise/data/exercise_repository_test.dart` (antes del `}` que cierra `main()`):

```dart
    group('cardio', () {
      test('logCardio y getCardioLogsForWeek', () async {
        final monday = DateTime.utc(2026, 6, 2);
        when(() => repository.logCardio(
              date: any(named: 'date'),
              cardioType: any(named: 'cardioType'),
              durationMinutes: any(named: 'durationMinutes'),
              notes: any(named: 'notes'),
            )).thenAnswer((_) async => 1);
        when(() => repository.getCardioLogsForWeek(any()))
            .thenAnswer((_) async => []);

        await repository.logCardio(
          date: monday,
          cardioType: 'treadmill',
          durationMinutes: 30,
        );
        verify(() => repository.logCardio(
              date: monday,
              cardioType: 'treadmill',
              durationMinutes: 30,
              notes: null,
            )).called(1);
      });
    });

    group('getWeeklyStats', () {
      test('retorna WeeklyStats con datos de rutina y cardio', () async {
        when(() => repository.getWeeklyStats(weeksBack: any(named: 'weeksBack')))
            .thenAnswer((_) async => [
                  WeeklyStat(
                    weekStart: DateTime.utc(2026, 5, 26),
                    routineDaysDone: 3,
                    cardioDaysDone: 2,
                  ),
                  WeeklyStat(
                    weekStart: DateTime.utc(2026, 6, 2),
                    routineDaysDone: 2,
                    cardioDaysDone: 1,
                  ),
                ]);

        final stats = await repository.getWeeklyStats(weeksBack: 2);
        expect(stats.length, 2);
        expect(stats[0].routineDaysDone, 3);
        expect(stats[1].cardioDaysDone, 1);
      });
    });
```

También agrega el import al inicio del archivo:
```dart
import 'package:kiolog/features/exercise/domain/models/weekly_stat.dart';
```

- [ ] **Step 3.5: Ejecutar tests del repositorio**

```bash
flutter test test/features/exercise/data/exercise_repository_test.dart
```

Salida esperada: todos en verde.

- [ ] **Step 3.6: Commit**

```bash
git add lib/features/exercise/domain/models/ \
        lib/features/exercise/domain/repositories/exercise_repository.dart \
        lib/features/exercise/data/repositories/exercise_repository_impl.dart \
        test/features/exercise/data/exercise_repository_test.dart
git commit -m "feat(exercise): domain model WeeklyStat, repository interface + impl con cardio, config y weekly stats"
```

---

## Task 4: BLoC — eventos, estado y handlers

**Files:**
- Modify: `lib/features/exercise/presentation/bloc/exercise_event.dart`
- Modify: `lib/features/exercise/presentation/bloc/exercise_state.dart`
- Modify: `lib/features/exercise/presentation/bloc/exercise_bloc.dart`
- Modify: `test/features/exercise/presentation/exercise_bloc_test.dart`

- [ ] **Step 4.1: Actualizar exercise_event.dart**

Reemplaza el contenido de `lib/features/exercise/presentation/bloc/exercise_event.dart`:

```dart
import 'package:equatable/equatable.dart';

abstract class ExerciseEvent extends Equatable {
  const ExerciseEvent();

  @override
  List<Object?> get props => [];
}

// ── Carga ────────────────────────────────────────────────────────────────────

class ExerciseLoaded extends ExerciseEvent {
  final DateTime date;
  const ExerciseLoaded({required this.date});
  @override
  List<Object?> get props => [date];
}

class ExercisePlanLoaded extends ExerciseEvent {
  const ExercisePlanLoaded();
}

// ── Planes ───────────────────────────────────────────────────────────────────

class ExercisePlanActivated extends ExerciseEvent {
  final int planId;
  const ExercisePlanActivated({required this.planId});
  @override
  List<Object?> get props => [planId];
}

class ExercisePlanCreated extends ExerciseEvent {
  final String name;
  const ExercisePlanCreated({required this.name});
  @override
  List<Object?> get props => [name];
}

// ── Rutinas ──────────────────────────────────────────────────────────────────

class ExerciseRoutineAdded extends ExerciseEvent {
  final int planId;
  final int dayNumber;
  final String routineName;
  const ExerciseRoutineAdded({
    required this.planId,
    required this.dayNumber,
    required this.routineName,
  });
  @override
  List<Object?> get props => [planId, dayNumber, routineName];
}

// ── Items de rutina ──────────────────────────────────────────────────────────

class ExerciseRoutineItemAdded extends ExerciseEvent {
  final int routineId;
  final String exerciseName;
  final int sets;
  final int reps;
  final double? weightKg;
  final String setType;
  final int orderIndex;
  final List<({int setNumber, int? dropOfSet, int reps, double? weightKg})>
      setDefs;

  const ExerciseRoutineItemAdded({
    required this.routineId,
    required this.exerciseName,
    required this.sets,
    required this.reps,
    this.weightKg,
    this.setType = 'normal',
    this.orderIndex = 0,
    this.setDefs = const [],
  });

  @override
  List<Object?> get props =>
      [routineId, exerciseName, sets, reps, weightKg, setType, orderIndex];
}

class ExerciseRoutineItemUpdated extends ExerciseEvent {
  final int itemId;
  final String? exerciseName;
  final int? sets;
  final int? reps;
  final double? weightKg;
  final String? setType;
  final List<({int setNumber, int? dropOfSet, int reps, double? weightKg})>?
      setDefs;

  const ExerciseRoutineItemUpdated({
    required this.itemId,
    this.exerciseName,
    this.sets,
    this.reps,
    this.weightKg,
    this.setType,
    this.setDefs,
  });

  @override
  List<Object?> get props => [itemId, exerciseName, sets, reps, weightKg, setType];
}

class ExerciseRoutineItemDeleted extends ExerciseEvent {
  final int itemId;
  final int routineId;
  const ExerciseRoutineItemDeleted({
    required this.itemId,
    required this.routineId,
  });
  @override
  List<Object?> get props => [itemId, routineId];
}

// ── Sesión ───────────────────────────────────────────────────────────────────

class ExerciseSessionStarted extends ExerciseEvent {
  final DateTime date;
  final int? routineId;
  const ExerciseSessionStarted({required this.date, this.routineId});
  @override
  List<Object?> get props => [date, routineId];
}

class ExerciseSessionEnded extends ExerciseEvent {
  final int sessionId;
  const ExerciseSessionEnded({required this.sessionId});
  @override
  List<Object?> get props => [sessionId];
}

class ExerciseItemCompleted extends ExerciseEvent {
  final int routineItemId;
  const ExerciseItemCompleted({required this.routineItemId});
  @override
  List<Object?> get props => [routineItemId];
}

// ── Sets ─────────────────────────────────────────────────────────────────────

class ExerciseSetLogged extends ExerciseEvent {
  final int sessionId;
  final String exerciseName;
  final int setNumber;
  final int reps;
  final double? weightKg;
  final String setType;
  final int? dropOfSetId;

  const ExerciseSetLogged({
    required this.sessionId,
    required this.exerciseName,
    required this.setNumber,
    required this.reps,
    this.weightKg,
    this.setType = 'normal',
    this.dropOfSetId,
  });

  @override
  List<Object?> get props =>
      [sessionId, exerciseName, setNumber, reps, weightKg, setType, dropOfSetId];
}

// ── Cardio ───────────────────────────────────────────────────────────────────

class CardioLogged extends ExerciseEvent {
  final DateTime date;
  final String cardioType;
  final int durationMinutes;
  final String? notes;

  const CardioLogged({
    required this.date,
    required this.cardioType,
    required this.durationMinutes,
    this.notes,
  });

  @override
  List<Object?> get props => [date, cardioType, durationMinutes, notes];
}

class CardioUpdated extends ExerciseEvent {
  final int cardioId;
  final String? cardioType;
  final int? durationMinutes;
  final String? notes;

  const CardioUpdated({
    required this.cardioId,
    this.cardioType,
    this.durationMinutes,
    this.notes,
  });

  @override
  List<Object?> get props => [cardioId, cardioType, durationMinutes, notes];
}

class CardioDeleted extends ExerciseEvent {
  final int cardioId;
  const CardioDeleted({required this.cardioId});
  @override
  List<Object?> get props => [cardioId];
}

// ── Ejercicio independiente ───────────────────────────────────────────────────

class IndependentExerciseLogged extends ExerciseEvent {
  final DateTime date;
  final String exerciseName;
  final int sets;
  final int reps;
  final double? weightKg;

  const IndependentExerciseLogged({
    required this.date,
    required this.exerciseName,
    required this.sets,
    required this.reps,
    this.weightKg,
  });

  @override
  List<Object?> get props => [date, exerciseName, sets, reps, weightKg];
}

class IndependentExerciseDeleted extends ExerciseEvent {
  final int sessionId;
  const IndependentExerciseDeleted({required this.sessionId});
  @override
  List<Object?> get props => [sessionId];
}

// ── Config ───────────────────────────────────────────────────────────────────

class ExerciseConfigUpdated extends ExerciseEvent {
  final int? weeklyRoutineDaysGoal;
  final int? weeklyCardioDaysGoal;
  final int? cardioMinutesGoal;

  const ExerciseConfigUpdated({
    this.weeklyRoutineDaysGoal,
    this.weeklyCardioDaysGoal,
    this.cardioMinutesGoal,
  });

  @override
  List<Object?> get props =>
      [weeklyRoutineDaysGoal, weeklyCardioDaysGoal, cardioMinutesGoal];
}

// ── Legacy ───────────────────────────────────────────────────────────────────

class ExerciseRoutineMarkedDone extends ExerciseEvent {
  final DateTime date;
  final int routineId;
  const ExerciseRoutineMarkedDone({required this.date, required this.routineId});
  @override
  List<Object?> get props => [date, routineId];
}
```

- [ ] **Step 4.2: Actualizar exercise_state.dart**

Reemplaza el contenido de `lib/features/exercise/presentation/bloc/exercise_state.dart`:

```dart
import 'package:equatable/equatable.dart';
import 'package:kiolog/core/database/app_database.dart';
import 'package:kiolog/features/exercise/domain/models/weekly_stat.dart';

enum ExerciseStatus { initial, loading, success, failure }

class ExerciseState extends Equatable {
  final ExerciseStatus status;
  final ExercisePlan? activePlan;
  final List<ExercisePlan> allPlans;
  final List<ExerciseRoutine> routines;
  final Map<int, List<ExerciseRoutineItem>> routineItemsByRoutine;
  final DailyExerciseLog? dailyLog;
  final ExerciseSessionLog? activeSession;
  final List<ExerciseSetLog> sessionSets;
  final List<ExerciseSessionLog> recentSessions;
  // IDs de ítems de rutina marcados como completos en la sesión activa
  final Set<int> completedRoutineItemIds;
  // Cardio de la semana actual
  final List<CardioLog> weeklyCardioLogs;
  // Configuración de metas
  final int routineDaysGoal;
  final int cardioDaysGoal;
  // Datos de progreso semanal para las gráficas
  final List<WeeklyStat> weeklyStats;
  final String? error;

  const ExerciseState({
    this.status = ExerciseStatus.initial,
    this.activePlan,
    this.allPlans = const [],
    this.routines = const [],
    this.routineItemsByRoutine = const {},
    this.dailyLog,
    this.activeSession,
    this.sessionSets = const [],
    this.recentSessions = const [],
    this.completedRoutineItemIds = const {},
    this.weeklyCardioLogs = const [],
    this.routineDaysGoal = 4,
    this.cardioDaysGoal = 3,
    this.weeklyStats = const [],
    this.error,
  });

  bool get hasActiveSession =>
      activeSession != null && activeSession!.gymLeftAt == null;

  List<ExerciseRoutineItem> get activeRoutineItems {
    final routineId = activeSession?.routineId;
    if (routineId == null) return const [];
    return routineItemsByRoutine[routineId] ?? const [];
  }

  ExerciseRoutine? routineById(int? id) {
    if (id == null) return null;
    for (final r in routines) {
      if (r.id == id) return r;
    }
    return null;
  }

  int get completedRoutineSessionsThisWeek => recentSessions
      .where((s) => s.routineId != null && s.gymLeftAt != null)
      .length;

  ExerciseState copyWith({
    ExerciseStatus? status,
    ExercisePlan? activePlan,
    List<ExercisePlan>? allPlans,
    List<ExerciseRoutine>? routines,
    Map<int, List<ExerciseRoutineItem>>? routineItemsByRoutine,
    DailyExerciseLog? dailyLog,
    ExerciseSessionLog? activeSession,
    List<ExerciseSetLog>? sessionSets,
    List<ExerciseSessionLog>? recentSessions,
    Set<int>? completedRoutineItemIds,
    List<CardioLog>? weeklyCardioLogs,
    int? routineDaysGoal,
    int? cardioDaysGoal,
    List<WeeklyStat>? weeklyStats,
    String? error,
  }) =>
      ExerciseState(
        status: status ?? this.status,
        activePlan: activePlan ?? this.activePlan,
        allPlans: allPlans ?? this.allPlans,
        routines: routines ?? this.routines,
        routineItemsByRoutine:
            routineItemsByRoutine ?? this.routineItemsByRoutine,
        dailyLog: dailyLog ?? this.dailyLog,
        activeSession: activeSession ?? this.activeSession,
        sessionSets: sessionSets ?? this.sessionSets,
        recentSessions: recentSessions ?? this.recentSessions,
        completedRoutineItemIds:
            completedRoutineItemIds ?? this.completedRoutineItemIds,
        weeklyCardioLogs: weeklyCardioLogs ?? this.weeklyCardioLogs,
        routineDaysGoal: routineDaysGoal ?? this.routineDaysGoal,
        cardioDaysGoal: cardioDaysGoal ?? this.cardioDaysGoal,
        weeklyStats: weeklyStats ?? this.weeklyStats,
        error: error,
      );

  @override
  List<Object?> get props => [
        status,
        activePlan,
        allPlans,
        routines,
        routineItemsByRoutine,
        dailyLog,
        activeSession,
        sessionSets,
        recentSessions,
        completedRoutineItemIds,
        weeklyCardioLogs,
        routineDaysGoal,
        cardioDaysGoal,
        weeklyStats,
        error,
      ];
}
```

- [ ] **Step 4.3: Actualizar exercise_bloc.dart**

Reemplaza `lib/features/exercise/presentation/bloc/exercise_bloc.dart`:

```dart
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:kiolog/core/database/app_database.dart';
import '../../domain/repositories/exercise_repository.dart';
import 'exercise_event.dart';
import 'exercise_state.dart';

class ExerciseBloc extends Bloc<ExerciseEvent, ExerciseState> {
  final ExerciseRepository _repository;

  ExerciseBloc(this._repository) : super(const ExerciseState()) {
    on<ExerciseLoaded>(_onLoaded);
    on<ExercisePlanLoaded>(_onPlanLoaded);
    on<ExercisePlanActivated>(_onPlanActivated);
    on<ExercisePlanCreated>(_onPlanCreated);
    on<ExerciseRoutineAdded>(_onRoutineAdded);
    on<ExerciseRoutineMarkedDone>(_onRoutineMarkedDone);
    on<ExerciseRoutineItemAdded>(_onRoutineItemAdded);
    on<ExerciseRoutineItemUpdated>(_onRoutineItemUpdated);
    on<ExerciseRoutineItemDeleted>(_onRoutineItemDeleted);
    on<ExerciseSessionStarted>(_onSessionStarted);
    on<ExerciseSessionEnded>(_onSessionEnded);
    on<ExerciseItemCompleted>(_onItemCompleted);
    on<ExerciseSetLogged>(_onSetLogged);
    on<CardioLogged>(_onCardioLogged);
    on<CardioUpdated>(_onCardioUpdated);
    on<CardioDeleted>(_onCardioDeleted);
    on<IndependentExerciseLogged>(_onIndependentExerciseLogged);
    on<IndependentExerciseDeleted>(_onIndependentExerciseDeleted);
    on<ExerciseConfigUpdated>(_onConfigUpdated);
  }

  Future<void> _onLoaded(
      ExerciseLoaded event, Emitter<ExerciseState> emit) async {
    emit(state.copyWith(status: ExerciseStatus.loading));
    try {
      final plan = await _repository.getActivePlan();
      final dailyLog = await _repository.getDailyLog(event.date);
      final config = await _repository.getExerciseConfig();

      List<ExerciseRoutine> routines = [];
      final Map<int, List<ExerciseRoutineItem>> itemsByRoutine = {};
      if (plan != null) {
        routines = await _repository.getRoutinesForPlan(plan.id);
        for (final r in routines) {
          itemsByRoutine[r.id] = await _repository.getRoutineItemsOrdered(r.id);
        }
      }

      final sessions = await _repository.getSessionsForDate(event.date);
      final activeSession = sessions.isNotEmpty && sessions.first.gymLeftAt == null
          ? sessions.first
          : null;

      List<ExerciseSetLog> sets = [];
      if (activeSession != null) {
        sets = await _repository.getSessionSets(activeSession.id);
      }

      final now = DateTime.now().toUtc();
      final monday = _mondayOf(now);
      final weeklyCardio = await _repository.getCardioLogsForWeek(monday);
      final weeklyStats = await _repository.getWeeklyStats(weeksBack: 8);

      emit(ExerciseState(
        status: ExerciseStatus.success,
        activePlan: plan,
        dailyLog: dailyLog,
        routines: routines,
        routineItemsByRoutine: itemsByRoutine,
        activeSession: activeSession,
        sessionSets: sets,
        recentSessions: sessions,
        weeklyCardioLogs: weeklyCardio,
        routineDaysGoal: config?.weeklyRoutineDaysGoal ?? 4,
        cardioDaysGoal: config?.weeklyCardioDaysGoal ?? 3,
        weeklyStats: weeklyStats,
      ));
    } catch (e) {
      emit(state.copyWith(status: ExerciseStatus.failure, error: e.toString()));
    }
  }

  Future<void> _onPlanLoaded(
      ExercisePlanLoaded event, Emitter<ExerciseState> emit) async {
    try {
      final plans = await _repository.getAllPlans();
      final active = await _repository.getActivePlan();
      emit(state.copyWith(allPlans: plans, activePlan: active));
    } catch (e) {
      emit(state.copyWith(status: ExerciseStatus.failure, error: e.toString()));
    }
  }

  Future<void> _onPlanActivated(
      ExercisePlanActivated event, Emitter<ExerciseState> emit) async {
    try {
      await _repository.activatePlan(event.planId);
      final plan = await _repository.getActivePlan();
      final plans = await _repository.getAllPlans();
      emit(state.copyWith(activePlan: plan, allPlans: plans));
    } catch (e) {
      emit(state.copyWith(status: ExerciseStatus.failure, error: e.toString()));
    }
  }

  Future<void> _onPlanCreated(
      ExercisePlanCreated event, Emitter<ExerciseState> emit) async {
    try {
      await _repository.createPlan(event.name);
      final plans = await _repository.getAllPlans();
      emit(state.copyWith(allPlans: plans));
    } catch (e) {
      emit(state.copyWith(status: ExerciseStatus.failure, error: e.toString()));
    }
  }

  Future<void> _onRoutineAdded(
      ExerciseRoutineAdded event, Emitter<ExerciseState> emit) async {
    try {
      await _repository.addRoutine(
        planId: event.planId,
        dayNumber: event.dayNumber,
        routineName: event.routineName,
      );
      add(ExerciseLoaded(date: DateTime.now()));
    } catch (e) {
      emit(state.copyWith(status: ExerciseStatus.failure, error: e.toString()));
    }
  }

  Future<void> _onRoutineMarkedDone(
      ExerciseRoutineMarkedDone event, Emitter<ExerciseState> emit) async {
    if (state.status != ExerciseStatus.success) return;
    try {
      await _repository.logDailyExercise(event.date, event.routineId);
      final log = await _repository.getDailyLog(event.date);
      emit(state.copyWith(dailyLog: log));
    } catch (e) {
      emit(state.copyWith(status: ExerciseStatus.failure, error: e.toString()));
    }
  }

  Future<void> _onRoutineItemAdded(
      ExerciseRoutineItemAdded event, Emitter<ExerciseState> emit) async {
    try {
      final itemId = await _repository.addRoutineItem(
        routineId: event.routineId,
        exerciseName: event.exerciseName,
        sets: event.sets,
        reps: event.reps,
        weightKg: event.weightKg,
        setType: event.setType,
        orderIndex: event.orderIndex,
      );
      if (event.setDefs.isNotEmpty) {
        await _repository.replaceRoutineSetDefs(
          routineItemId: itemId,
          defs: event.setDefs,
        );
      }
      final updatedItems =
          await _repository.getRoutineItemsOrdered(event.routineId);
      final updatedMap =
          Map<int, List<ExerciseRoutineItem>>.from(state.routineItemsByRoutine)
            ..[event.routineId] = updatedItems;
      emit(state.copyWith(routineItemsByRoutine: updatedMap));
    } catch (e) {
      emit(state.copyWith(status: ExerciseStatus.failure, error: e.toString()));
    }
  }

  Future<void> _onRoutineItemUpdated(
      ExerciseRoutineItemUpdated event, Emitter<ExerciseState> emit) async {
    try {
      await _repository.updateRoutineItem(
        itemId: event.itemId,
        exerciseName: event.exerciseName,
        sets: event.sets,
        reps: event.reps,
        weightKg: event.weightKg,
        setType: event.setType,
      );
      if (event.setDefs != null) {
        await _repository.replaceRoutineSetDefs(
          routineItemId: event.itemId,
          defs: event.setDefs!,
        );
      }
      // Recarga items de todas las rutinas para reflejar el cambio
      final Map<int, List<ExerciseRoutineItem>> updatedMap = {};
      for (final routineId in state.routineItemsByRoutine.keys) {
        updatedMap[routineId] =
            await _repository.getRoutineItemsOrdered(routineId);
      }
      emit(state.copyWith(routineItemsByRoutine: updatedMap));
    } catch (e) {
      emit(state.copyWith(status: ExerciseStatus.failure, error: e.toString()));
    }
  }

  Future<void> _onRoutineItemDeleted(
      ExerciseRoutineItemDeleted event, Emitter<ExerciseState> emit) async {
    try {
      await _repository.deleteRoutineItem(event.itemId);
      final updatedItems =
          await _repository.getRoutineItemsOrdered(event.routineId);
      final updatedMap =
          Map<int, List<ExerciseRoutineItem>>.from(state.routineItemsByRoutine)
            ..[event.routineId] = updatedItems;
      emit(state.copyWith(routineItemsByRoutine: updatedMap));
    } catch (e) {
      emit(state.copyWith(status: ExerciseStatus.failure, error: e.toString()));
    }
  }

  Future<void> _onSessionStarted(
      ExerciseSessionStarted event, Emitter<ExerciseState> emit) async {
    if (state.status != ExerciseStatus.success) return;
    try {
      final sessionId =
          await _repository.startSession(event.date, routineId: event.routineId);
      final session = await _repository.getSession(sessionId);
      final sessions = await _repository.getSessionsForDate(event.date);
      emit(state.copyWith(
        activeSession: session,
        recentSessions: sessions,
        sessionSets: [],
        completedRoutineItemIds: {},
      ));
    } catch (e) {
      emit(state.copyWith(status: ExerciseStatus.failure, error: e.toString()));
    }
  }

  Future<void> _onSessionEnded(
      ExerciseSessionEnded event, Emitter<ExerciseState> emit) async {
    if (state.status != ExerciseStatus.success) return;
    try {
      await _repository.endSession(event.sessionId);
      final session = await _repository.getSession(event.sessionId);
      final monday = _mondayOf(DateTime.now().toUtc());
      final weeklyStats = await _repository.getWeeklyStats(weeksBack: 8);
      emit(state.copyWith(
        activeSession: session,
        completedRoutineItemIds: {},
        weeklyStats: weeklyStats,
      ));
    } catch (e) {
      emit(state.copyWith(status: ExerciseStatus.failure, error: e.toString()));
    }
  }

  void _onItemCompleted(
      ExerciseItemCompleted event, Emitter<ExerciseState> emit) {
    final updated = Set<int>.from(state.completedRoutineItemIds)
      ..add(event.routineItemId);
    emit(state.copyWith(completedRoutineItemIds: updated));
  }

  Future<void> _onSetLogged(
      ExerciseSetLogged event, Emitter<ExerciseState> emit) async {
    if (state.status != ExerciseStatus.success) return;
    try {
      await _repository.logSet(
        sessionId: event.sessionId,
        exerciseName: event.exerciseName,
        setNumber: event.setNumber,
        reps: event.reps,
        weightKg: event.weightKg,
        setType: event.setType,
        dropOfSetId: event.dropOfSetId,
      );
      final sets = await _repository.getSessionSets(event.sessionId);
      emit(state.copyWith(sessionSets: sets));
    } catch (e) {
      emit(state.copyWith(status: ExerciseStatus.failure, error: e.toString()));
    }
  }

  Future<void> _onCardioLogged(
      CardioLogged event, Emitter<ExerciseState> emit) async {
    try {
      await _repository.logCardio(
        date: event.date,
        cardioType: event.cardioType,
        durationMinutes: event.durationMinutes,
        notes: event.notes,
      );
      final monday = _mondayOf(DateTime.now().toUtc());
      final cardioLogs = await _repository.getCardioLogsForWeek(monday);
      final weeklyStats = await _repository.getWeeklyStats(weeksBack: 8);
      emit(state.copyWith(
          weeklyCardioLogs: cardioLogs, weeklyStats: weeklyStats));
    } catch (e) {
      emit(state.copyWith(status: ExerciseStatus.failure, error: e.toString()));
    }
  }

  Future<void> _onCardioUpdated(
      CardioUpdated event, Emitter<ExerciseState> emit) async {
    try {
      await _repository.updateCardio(
        cardioId: event.cardioId,
        cardioType: event.cardioType,
        durationMinutes: event.durationMinutes,
        notes: event.notes,
      );
      final monday = _mondayOf(DateTime.now().toUtc());
      final cardioLogs = await _repository.getCardioLogsForWeek(monday);
      emit(state.copyWith(weeklyCardioLogs: cardioLogs));
    } catch (e) {
      emit(state.copyWith(status: ExerciseStatus.failure, error: e.toString()));
    }
  }

  Future<void> _onCardioDeleted(
      CardioDeleted event, Emitter<ExerciseState> emit) async {
    try {
      await _repository.deleteCardio(event.cardioId);
      final monday = _mondayOf(DateTime.now().toUtc());
      final cardioLogs = await _repository.getCardioLogsForWeek(monday);
      final weeklyStats = await _repository.getWeeklyStats(weeksBack: 8);
      emit(state.copyWith(
          weeklyCardioLogs: cardioLogs, weeklyStats: weeklyStats));
    } catch (e) {
      emit(state.copyWith(status: ExerciseStatus.failure, error: e.toString()));
    }
  }

  Future<void> _onIndependentExerciseLogged(
      IndependentExerciseLogged event, Emitter<ExerciseState> emit) async {
    try {
      final sessionId =
          await _repository.startSession(event.date, routineId: null);
      await _repository.logSet(
        sessionId: sessionId,
        exerciseName: event.exerciseName,
        setNumber: 1,
        reps: event.reps,
        weightKg: event.weightKg,
        setType: 'normal',
      );
      await _repository.endSession(sessionId);
      final sessions = await _repository.getSessionsForDate(event.date);
      emit(state.copyWith(recentSessions: sessions));
    } catch (e) {
      emit(state.copyWith(status: ExerciseStatus.failure, error: e.toString()));
    }
  }

  Future<void> _onIndependentExerciseDeleted(
      IndependentExerciseDeleted event, Emitter<ExerciseState> emit) async {
    try {
      await _repository.deleteSession(event.sessionId);
      final sessions =
          await _repository.getSessionsForDate(DateTime.now());
      emit(state.copyWith(recentSessions: sessions));
    } catch (e) {
      emit(state.copyWith(status: ExerciseStatus.failure, error: e.toString()));
    }
  }

  Future<void> _onConfigUpdated(
      ExerciseConfigUpdated event, Emitter<ExerciseState> emit) async {
    try {
      await _repository.updateExerciseConfig(
        weeklyRoutineDaysGoal: event.weeklyRoutineDaysGoal,
        weeklyCardioDaysGoal: event.weeklyCardioDaysGoal,
        cardioMinutesGoal: event.cardioMinutesGoal,
      );
      final config = await _repository.getExerciseConfig();
      emit(state.copyWith(
        routineDaysGoal: config?.weeklyRoutineDaysGoal ?? state.routineDaysGoal,
        cardioDaysGoal: config?.weeklyCardioDaysGoal ?? state.cardioDaysGoal,
      ));
    } catch (e) {
      emit(state.copyWith(status: ExerciseStatus.failure, error: e.toString()));
    }
  }

  DateTime _mondayOf(DateTime date) {
    final d = date.toUtc();
    return DateTime.utc(d.year, d.month, d.day)
        .subtract(Duration(days: d.weekday - 1));
  }
}
```

- [ ] **Step 4.4: Agregar tests del BLoC**

Agrega al final del grupo existente en `test/features/exercise/presentation/exercise_bloc_test.dart`:

```dart
    blocTest<ExerciseBloc, ExerciseState>(
      'ExerciseItemCompleted agrega id al set completedRoutineItemIds',
      build: () => ExerciseBloc(repository),
      seed: () => ExerciseState(
        status: ExerciseStatus.success,
        completedRoutineItemIds: const {1},
      ),
      act: (bloc) => bloc.add(const ExerciseItemCompleted(routineItemId: 2)),
      expect: () => [
        isA<ExerciseState>().having(
          (s) => s.completedRoutineItemIds,
          'completedIds',
          containsAll([1, 2]),
        ),
      ],
    );

    blocTest<ExerciseBloc, ExerciseState>(
      'CardioLogged llama repository.logCardio y recarga logs',
      build: () {
        when(() => repository.logCardio(
              date: any(named: 'date'),
              cardioType: any(named: 'cardioType'),
              durationMinutes: any(named: 'durationMinutes'),
              notes: any(named: 'notes'),
            )).thenAnswer((_) async => 1);
        when(() => repository.getCardioLogsForWeek(any()))
            .thenAnswer((_) async => []);
        when(() => repository.getWeeklyStats(weeksBack: any(named: 'weeksBack')))
            .thenAnswer((_) async => []);
        return ExerciseBloc(repository);
      },
      seed: () => const ExerciseState(status: ExerciseStatus.success),
      act: (bloc) => bloc.add(CardioLogged(
        date: DateTime(2026, 6, 8),
        cardioType: 'treadmill',
        durationMinutes: 30,
      )),
      verify: (_) {
        verify(() => repository.logCardio(
              date: any(named: 'date'),
              cardioType: 'treadmill',
              durationMinutes: 30,
              notes: null,
            )).called(1);
      },
    );
```

También actualiza el mock al inicio del archivo para incluir los nuevos métodos:

```dart
class MockExerciseRepository extends Mock implements ExerciseRepository {}
```

El bloc ahora llama `getRoutineItemsOrdered` en lugar de `getRoutineItems`. Actualiza el test existente `emits [loading, success]` y agrega stubs para los nuevos métodos:

```dart
// Reemplaza en el build() del test existente:
when(() => repository.getRoutineItems(any())).thenAnswer((_) async => items);
// Por:
when(() => repository.getRoutineItemsOrdered(any())).thenAnswer((_) async => items);

// Agrega:
when(() => repository.getExerciseConfig()).thenAnswer((_) async => null);
when(() => repository.getCardioLogsForWeek(any())).thenAnswer((_) async => []);
when(() => repository.getWeeklyStats(weeksBack: any(named: 'weeksBack')))
    .thenAnswer((_) async => []);
```

- [ ] **Step 4.5: Ejecutar todos los tests**

```bash
flutter test test/features/exercise/
```

Salida esperada: todos en verde.

- [ ] **Step 4.6: Verificar análisis estático**

```bash
flutter analyze lib/features/exercise/
```

Salida esperada: `No issues found!`

- [ ] **Step 4.7: Commit**

```bash
git add lib/features/exercise/presentation/bloc/ \
        test/features/exercise/presentation/exercise_bloc_test.dart
git commit -m "feat(exercise-bloc): nuevos eventos y handlers para items, cardio, config y progreso semanal"
```

---

## Task 5: Registro en DI + verificación final

**Files:**
- Modify: `lib/core/di/injection.dart`

- [ ] **Step 5.1: Registrar ExerciseConfig en el setup de DI**

Busca en `lib/core/di/injection.dart` donde se registra `ExerciseRepositoryImpl` y verifica que el `ExerciseDao` ya incluye acceso a las nuevas tablas (lo hace por la anotación `@DriftAccessor`). No se requiere cambio si el DAO ya está registrado.

Si hay un `setupDependencies()` que hace seed de datos iniciales, agrega:

```dart
// Seed exercise config con valores por defecto si no existe
final exerciseConfig = await getIt<ExerciseRepository>().getExerciseConfig();
if (exerciseConfig == null) {
  await getIt<ExerciseRepository>().updateExerciseConfig(
    weeklyRoutineDaysGoal: 4,
    weeklyCardioDaysGoal: 3,
    cardioMinutesGoal: 30,
  );
}
```

- [ ] **Step 5.2: Verificar que la app compila**

```bash
flutter build apk --debug 2>&1 | tail -5
```

Salida esperada: `Built build/app/outputs/flutter-apk/app-debug.apk`

- [ ] **Step 5.3: Ejecutar suite completa de tests**

```bash
flutter test
```

Salida esperada: todos los tests existentes siguen pasando.

- [ ] **Step 5.4: Commit final de la fase**

```bash
git add lib/core/di/injection.dart
git commit -m "feat(exercise): Fase A completa — schema v4, DAO, repository, BLoC con cardio y progreso semanal"
```
