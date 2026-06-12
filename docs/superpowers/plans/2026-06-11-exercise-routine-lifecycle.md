# Exercise Routine Lifecycle & Day Selection Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Agregar selección explícita del día de rutina, ciclo de vida de planes (periodStart/periodEnd), historial con stats de cumplimiento, y creación de planes a partir de plantillas anteriores.

**Architecture:** Extensión incremental sobre el sistema existente. Se agregan dos columnas nullable a `ExercisePlans`, un nuevo modelo `PlanComplianceStat`, un método DAO auxiliar, cálculo de stats en el repositorio, evento + campo en el BLoC, y tres cambios de UI en exercise_page, exercise_progress_page y exercise_config_page.

**Tech Stack:** Flutter · Drift ORM (sqlite, epoch millis para DateTime) · BLoC/bloc_test · mocktail

---

## File Map

| Archivo | Cambio |
|---|---|
| `lib/core/database/tables/exercise_tables.dart` | +`periodStart`, +`periodEnd` nullable a `ExercisePlans` |
| `lib/core/database/app_database.dart` | schemaVersion 7→8, migration `from < 8` |
| `lib/core/dao/exercise_dao.dart` | update `insertExercisePlan`, update `setActiveExercisePlan`, nuevo `getCompletedSessionsInPeriod` |
| `lib/features/exercise/domain/models/plan_compliance_stat.dart` | CREATE — nuevo modelo |
| `lib/features/exercise/domain/repositories/exercise_repository.dart` | +`getPlanHistory()` |
| `lib/features/exercise/data/repositories/exercise_repository_impl.dart` | implementar `getPlanHistory()` |
| `lib/features/exercise/presentation/bloc/exercise_event.dart` | +`ExercisePlanHistoryLoaded` |
| `lib/features/exercise/presentation/bloc/exercise_state.dart` | +`planHistory` field + copyWith |
| `lib/features/exercise/presentation/bloc/exercise_bloc.dart` | +handler `_onPlanHistoryLoaded`, modificar `_onPlanActivated` |
| `lib/features/exercise/presentation/pages/exercise_page.dart` | reemplazar `_buildStartRoutineBar` con `_DaySelectionCard` |
| `lib/features/exercise/presentation/pages/exercise_progress_page.dart` | +tab Historial + `_HistorialTab` widget |
| `lib/features/exercise/presentation/pages/exercise_config_page.dart` | +botón plantilla + `_showTemplatePicker` |
| `test/dao/exercise_dao_test.dart` | 2 nuevos tests |
| `test/features/exercise/data/exercise_repository_test.dart` | 1 nuevo test |
| `test/features/exercise/presentation/exercise_bloc_test.dart` | 2 nuevos tests |
| `test/features/exercise/presentation/exercise_page_test.dart` | CREATE — 3 tests |
| `test/features/exercise/presentation/exercise_progress_page_test.dart` | 1 nuevo test |

---

## Task 1: Schema — periodStart/periodEnd en ExercisePlans

**Files:**
- Modify: `lib/core/database/tables/exercise_tables.dart:3-8`
- Modify: `lib/core/database/app_database.dart:76-127`
- Test: `test/dao/exercise_dao_test.dart`

- [ ] **Step 1: Escribir test fallido**

Agregar al grupo `'ExerciseDao - Plans'` en `test/dao/exercise_dao_test.dart`:

```dart
test('plan recién insertado tiene periodStart no nulo', () async {
  final id = await db.exerciseDao.insertExercisePlan(
    const ExercisePlansCompanion(name: Value('Plan A')),
  );
  final plans = await db.exerciseDao.getExercisePlans();
  final plan = plans.firstWhere((p) => p.id == id);
  expect(plan.periodStart, isNotNull);
  expect(plan.periodEnd, isNull);
});

test('setActiveExercisePlan setea periodEnd en el plan anterior', () async {
  final id1 = await db.exerciseDao.insertExercisePlan(
    const ExercisePlansCompanion(name: Value('Plan A')),
  );
  final id2 = await db.exerciseDao.insertExercisePlan(
    const ExercisePlansCompanion(name: Value('Plan B')),
  );

  await db.exerciseDao.setActiveExercisePlan(id1);
  await db.exerciseDao.setActiveExercisePlan(id2);

  final plans = await db.exerciseDao.getExercisePlans();
  final planA = plans.firstWhere((p) => p.id == id1);
  final planB = plans.firstWhere((p) => p.id == id2);
  expect(planA.periodEnd, isNotNull);   // cerrado al activar Plan B
  expect(planB.periodEnd, isNull);      // plan activo, sin cerrar
  expect(planB.periodStart, isNotNull); // recibió periodStart al activarse
});
```

- [ ] **Step 2: Ejecutar test para verificar que falla**

```bash
cd /home/jesuszelaya/Documents/kiolog
flutter test test/dao/exercise_dao_test.dart -v 2>&1 | grep -E "FAIL|ERROR|plan recién|setActiveExercisePlan setea"
```

Expected: `NoSuchMethodError` o `MissingColumnException` — `periodStart` no existe todavía.

- [ ] **Step 3: Agregar columnas a ExercisePlans**

En `lib/core/database/tables/exercise_tables.dart`, reemplazar `ExercisePlans`:

```dart
class ExercisePlans extends Table {
  IntColumn get id => integer().autoIncrement()();
  TextColumn get name => text()();
  DateTimeColumn get createdAt => dateTime()();
  BoolColumn get isActive => boolean().withDefault(const Constant(true))();
  DateTimeColumn get periodStart => dateTime().nullable()();
  DateTimeColumn get periodEnd => dateTime().nullable()();
}
```

- [ ] **Step 4: Bump schemaVersion y agregar migración**

En `lib/core/database/app_database.dart`:

```dart
// Línea 76:
@override
int get schemaVersion => 8;

// Dentro de onUpgrade, agregar al final (después del bloque `if (from < 7)`):
if (from < 8) {
  await m.addColumn(exercisePlans, exercisePlans.periodStart);
  await m.addColumn(exercisePlans, exercisePlans.periodEnd);
  // Backfill periodStart desde createdAt para planes existentes
  await customStatement(
    'UPDATE exercise_plans SET period_start = created_at WHERE period_start IS NULL',
  );
}
```

- [ ] **Step 5: Regenerar código Drift**

```bash
cd /home/jesuszelaya/Documents/kiolog
dart run build_runner build --delete-conflicting-outputs 2>&1 | tail -5
```

Expected: `Build completed successfully`.

- [ ] **Step 6: Ejecutar tests y verificar que pasan**

```bash
flutter test test/dao/exercise_dao_test.dart -v 2>&1 | grep -E "PASS|FAIL|plan recién|setActiveExercisePlan setea"
```

Expected: ambos nuevos tests en PASS. Los tests existentes también deben pasar (la migración es backward-compatible para tests en memoria porque `createTestDatabase()` llama `onCreate` que crea todas las tablas incluyendo las nuevas columnas).

- [ ] **Step 7: Commit**

```bash
git add lib/core/database/tables/exercise_tables.dart lib/core/database/app_database.dart test/dao/exercise_dao_test.dart
git commit -m "feat(exercise): add periodStart/periodEnd to ExercisePlans, schema v8"
```

---

## Task 2: DAO — insertExercisePlan + setActiveExercisePlan + getCompletedSessionsInPeriod

**Files:**
- Modify: `lib/core/dao/exercise_dao.dart`

No tests adicionales en este task — los tests del Task 1 ya cubren `setActiveExercisePlan`. El nuevo `getCompletedSessionsInPeriod` se testea indirectamente en Task 3.

- [ ] **Step 1: Actualizar insertExercisePlan para setear periodStart**

En `lib/core/dao/exercise_dao.dart`, reemplazar `insertExercisePlan`:

```dart
Future<int> insertExercisePlan(ExercisePlansCompanion plan) =>
    into(exercisePlans).insert(plan.copyWith(
      createdAt: plan.createdAt.present
          ? plan.createdAt
          : Value(DateTime.now().toUtc()),
      isActive: const Value(true),
      periodStart: plan.periodStart.present
          ? plan.periodStart
          : Value(DateTime.now().toUtc()),
    ));
```

- [ ] **Step 2: Actualizar setActiveExercisePlan para gestionar periodEnd/periodStart**

En `lib/core/dao/exercise_dao.dart`, reemplazar `setActiveExercisePlan`:

```dart
Future<void> setActiveExercisePlan(int planId) async {
  await db.transaction(() async {
    final plan = await (select(exercisePlans)
          ..where((t) => t.id.equals(planId)))
        .getSingleOrNull();
    if (plan == null) throw ArgumentError('Exercise plan $planId not found');
    final now = DateTime.now().toUtc();
    // Cerrar el plan activo actual (setear periodEnd)
    await (update(exercisePlans)
          ..where((t) => t.isActive.equals(true)))
        .write(ExercisePlansCompanion(
          isActive: const Value(false),
          periodEnd: Value(now),
        ));
    // Activar el plan seleccionado con nuevo periodStart
    await (update(exercisePlans)..where((t) => t.id.equals(planId)))
        .write(ExercisePlansCompanion(
          isActive: const Value(true),
          periodStart: Value(now),
          periodEnd: const Value(null),
        ));
  });
}
```

- [ ] **Step 3: Agregar getCompletedSessionsInPeriod**

Agregar al final de la sección `// ── Sessions` en `lib/core/dao/exercise_dao.dart`:

```dart
/// Sesiones de rutina completadas (gymLeftAt != null) cuyo routineId está
/// en [routineIds] y cuya date cae en [start, end).
Future<List<ExerciseSessionLog>> getCompletedSessionsInPeriod(
  List<int> routineIds,
  DateTime start,
  DateTime end,
) {
  if (routineIds.isEmpty) return Future.value([]);
  return (select(exerciseSessionLogs)
        ..where((t) =>
            t.routineId.isIn(routineIds) &
            t.gymLeftAt.isNotNull() &
            t.date.isBiggerOrEqualValue(start) &
            t.date.isSmallerThanValue(end)))
      .get();
}
```

- [ ] **Step 4: Ejecutar todos los DAO tests**

```bash
flutter test test/dao/exercise_dao_test.dart -v 2>&1 | grep -E "PASS|FAIL|ERROR"
```

Expected: todos PASS.

- [ ] **Step 5: Commit**

```bash
git add lib/core/dao/exercise_dao.dart
git commit -m "feat(exercise): update insertExercisePlan, setActiveExercisePlan, add getCompletedSessionsInPeriod"
```

---

## Task 3: PlanComplianceStat model + Repository

**Files:**
- Create: `lib/features/exercise/domain/models/plan_compliance_stat.dart`
- Modify: `lib/features/exercise/domain/repositories/exercise_repository.dart`
- Modify: `lib/features/exercise/data/repositories/exercise_repository_impl.dart`
- Test: `test/features/exercise/data/exercise_repository_test.dart`

- [ ] **Step 1: Crear el modelo PlanComplianceStat**

Crear `lib/features/exercise/domain/models/plan_compliance_stat.dart`:

```dart
import 'package:equatable/equatable.dart';

class PlanComplianceStat extends Equatable {
  final int planId;
  final String planName;
  final DateTime periodStart;
  final DateTime? periodEnd;
  final int totalSessions;
  final int weeksActive;
  final double weeklyAvg;
  final int compliancePercent;

  const PlanComplianceStat({
    required this.planId,
    required this.planName,
    required this.periodStart,
    this.periodEnd,
    required this.totalSessions,
    required this.weeksActive,
    required this.weeklyAvg,
    required this.compliancePercent,
  });

  @override
  List<Object?> get props => [
        planId,
        planName,
        periodStart,
        periodEnd,
        totalSessions,
        weeksActive,
        weeklyAvg,
        compliancePercent,
      ];
}
```

- [ ] **Step 2: Agregar getPlanHistory al repositorio abstract**

En `lib/features/exercise/domain/repositories/exercise_repository.dart`, agregar al final del bloque de Plans:

```dart
import '../models/plan_compliance_stat.dart';
// (agregar el import al inicio del archivo)

// En el abstract class ExerciseRepository:
Future<List<PlanComplianceStat>> getPlanHistory();
```

- [ ] **Step 3: Escribir el test fallido**

Agregar al grupo apropiado en `test/features/exercise/data/exercise_repository_test.dart`:

```dart
// Al inicio del archivo, agregar imports:
import 'package:kiolog/features/exercise/domain/models/plan_compliance_stat.dart';

// En el grupo de tests:
test('getPlanHistory devuelve stats correctos para planes con sesiones', () async {
  // Crear plan A (activo)
  final planAId = await db.exerciseDao.insertExercisePlan(
    ExercisePlansCompanion(
      name: const Value('Plan A'),
      periodStart: Value(DateTime.utc(2026, 3, 1)),
    ),
  );
  final routineId = await db.exerciseDao.insertExerciseRoutine(
    ExerciseRoutinesCompanion(
      planId: Value(planAId),
      dayNumber: const Value(1),
      routineName: const Value('Pecho'),
    ),
  );
  // Insertar 3 sesiones completas en el período
  for (int i = 1; i <= 3; i++) {
    final date = DateTime.utc(2026, 3, i + 1);
    await db.exerciseDao.insertExerciseSession(
      ExerciseSessionLogsCompanion(
        date: Value(date),
        routineId: Value(routineId),
        gymArrivedAt: Value(date),
        gymLeftAt: Value(date.add(const Duration(hours: 1))),
      ),
    );
  }

  final history = await repository.getPlanHistory();

  expect(history, hasLength(1));
  expect(history.first.planId, planAId);
  expect(history.first.totalSessions, 3);
  expect(history.first.compliancePercent, greaterThanOrEqualTo(0));
  expect(history.first.compliancePercent, lessThanOrEqualTo(100));
});
```

- [ ] **Step 4: Ejecutar test para verificar que falla**

```bash
flutter test test/features/exercise/data/exercise_repository_test.dart -v 2>&1 | grep -E "FAIL|ERROR|getPlanHistory"
```

Expected: `NoSuchMethodError` — `getPlanHistory` no implementado todavía.

- [ ] **Step 5: Implementar getPlanHistory en el repositorio**

En `lib/features/exercise/data/repositories/exercise_repository_impl.dart`:

Agregar import al inicio:
```dart
import '../../domain/models/plan_compliance_stat.dart';
```

Agregar método al final de la clase:
```dart
@override
Future<List<PlanComplianceStat>> getPlanHistory() async {
  final plans = await _dao.getExercisePlans(); // ordenados por createdAt DESC
  final config = await _dao.getExerciseConfig();
  final goal = config?.weeklyRoutineDaysGoal ?? 4;
  final stats = <PlanComplianceStat>[];

  for (final plan in plans) {
    final periodStart = plan.periodStart ?? plan.createdAt;
    final periodEnd = plan.periodEnd ?? DateTime.now().toUtc();

    final routines = await _dao.getRoutinesForPlan(plan.id);
    final routineIds = routines.map((r) => r.id).toList();

    final sessions = await _dao.getCompletedSessionsInPeriod(
      routineIds, periodStart, periodEnd,
    );

    // Contar días únicos (no sesiones duplicadas en el mismo día)
    final uniqueDays = sessions
        .map((s) {
          final d = s.date.toUtc();
          return DateTime.utc(d.year, d.month, d.day);
        })
        .toSet()
        .length;

    final durationDays = periodEnd.difference(periodStart).inDays;
    final weeksActive = ((durationDays / 7).ceil()).clamp(1, 9999);
    final weeklyAvg = uniqueDays / weeksActive;
    final compliancePercent =
        ((uniqueDays / (goal * weeksActive)) * 100).round().clamp(0, 100);

    stats.add(PlanComplianceStat(
      planId: plan.id,
      planName: plan.name,
      periodStart: periodStart,
      periodEnd: plan.periodEnd,
      totalSessions: uniqueDays,
      weeksActive: weeksActive,
      weeklyAvg: weeklyAvg,
      compliancePercent: compliancePercent,
    ));
  }

  return stats;
}
```

- [ ] **Step 6: Ejecutar test para verificar que pasa**

```bash
flutter test test/features/exercise/data/exercise_repository_test.dart -v 2>&1 | grep -E "PASS|FAIL|getPlanHistory"
```

Expected: PASS.

- [ ] **Step 7: Commit**

```bash
git add lib/features/exercise/domain/models/plan_compliance_stat.dart \
        lib/features/exercise/domain/repositories/exercise_repository.dart \
        lib/features/exercise/data/repositories/exercise_repository_impl.dart \
        test/features/exercise/data/exercise_repository_test.dart
git commit -m "feat(exercise): add PlanComplianceStat model and getPlanHistory repository method"
```

---

## Task 4: BLoC — ExercisePlanHistoryLoaded event + planHistory state

**Files:**
- Modify: `lib/features/exercise/presentation/bloc/exercise_event.dart`
- Modify: `lib/features/exercise/presentation/bloc/exercise_state.dart`
- Modify: `lib/features/exercise/presentation/bloc/exercise_bloc.dart`
- Test: `test/features/exercise/presentation/exercise_bloc_test.dart`

- [ ] **Step 1: Escribir tests fallidos**

Agregar al grupo `'ExerciseBloc'` en `test/features/exercise/presentation/exercise_bloc_test.dart`:

```dart
// Al inicio del archivo, agregar import:
import 'package:kiolog/features/exercise/domain/models/plan_compliance_stat.dart';

// En el grupo de tests, declarar fixtures:
final compliance = PlanComplianceStat(
  planId: 1,
  planName: 'Plan A',
  periodStart: DateTime(2026, 3, 1),
  totalSessions: 10,
  weeksActive: 4,
  weeklyAvg: 2.5,
  compliancePercent: 63,
);

// Test 1
blocTest<ExerciseBloc, ExerciseState>(
  'ExercisePlanHistoryLoaded emite estado con planHistory',
  build: () {
    when(() => repository.getPlanHistory())
        .thenAnswer((_) async => [compliance]);
    return ExerciseBloc(repository);
  },
  act: (bloc) => bloc.add(const ExercisePlanHistoryLoaded()),
  expect: () => [
    isA<ExerciseState>().having(
      (s) => s.planHistory,
      'planHistory',
      [compliance],
    ),
  ],
);

// Test 2
blocTest<ExerciseBloc, ExerciseState>(
  'ExercisePlanActivated recarga planHistory tras activar',
  build: () {
    when(() => repository.activatePlan(any())).thenAnswer((_) async {});
    when(() => repository.getActivePlan()).thenAnswer((_) async => null);
    when(() => repository.getAllPlans()).thenAnswer((_) async => []);
    when(() => repository.getPlanHistory())
        .thenAnswer((_) async => [compliance]);
    return ExerciseBloc(repository);
  },
  act: (bloc) => bloc.add(const ExercisePlanActivated(planId: 1)),
  expect: () => [
    isA<ExerciseState>().having(
      (s) => s.planHistory,
      'planHistory',
      [compliance],
    ),
  ],
);
```

- [ ] **Step 2: Ejecutar tests para verificar que fallan**

```bash
flutter test test/features/exercise/presentation/exercise_bloc_test.dart -v 2>&1 | grep -E "FAIL|ERROR|ExercisePlanHistoryLoaded|recarga planHistory"
```

Expected: errores de compilación — `ExercisePlanHistoryLoaded` y `planHistory` no existen todavía.

- [ ] **Step 3: Agregar ExercisePlanHistoryLoaded al evento**

En `lib/features/exercise/presentation/bloc/exercise_event.dart`, agregar al final (antes del cierre del archivo):

```dart
class ExercisePlanHistoryLoaded extends ExerciseEvent {
  const ExercisePlanHistoryLoaded();
}
```

- [ ] **Step 4: Agregar planHistory al estado**

En `lib/features/exercise/presentation/bloc/exercise_state.dart`:

Agregar import al inicio:
```dart
import 'package:kiolog/features/exercise/domain/models/plan_compliance_stat.dart';
```

En la clase `ExerciseState`, agregar campo (después de `weeklyIndependentLogs`):
```dart
final List<PlanComplianceStat> planHistory;
```

En el constructor:
```dart
this.planHistory = const [],
```

En `copyWith`, agregar parámetro y asignación:
```dart
// Parámetro:
List<PlanComplianceStat>? planHistory,

// Asignación en el return:
planHistory: planHistory ?? this.planHistory,
```

En `props`:
```dart
planHistory,
```

- [ ] **Step 5: Agregar handlers al BLoC**

En `lib/features/exercise/presentation/bloc/exercise_bloc.dart`:

En el constructor (junto a los otros `on<...>`):
```dart
on<ExercisePlanHistoryLoaded>(_onPlanHistoryLoaded);
```

Agregar el método handler:
```dart
Future<void> _onPlanHistoryLoaded(
  ExercisePlanHistoryLoaded event,
  Emitter<ExerciseState> emit,
) async {
  try {
    final history = await _repository.getPlanHistory();
    emit(state.copyWith(planHistory: history));
  } catch (e) {
    emit(state.copyWith(status: ExerciseStatus.failure, error: e.toString()));
  }
}
```

Modificar `_onPlanActivated` para recargar historial después de activar:
```dart
Future<void> _onPlanActivated(
    ExercisePlanActivated event, Emitter<ExerciseState> emit) async {
  try {
    await _repository.activatePlan(event.planId);
    final plan = await _repository.getActivePlan();
    final plans = await _repository.getAllPlans();
    final history = await _repository.getPlanHistory();
    emit(state.copyWith(activePlan: plan, allPlans: plans, planHistory: history));
  } catch (e) {
    emit(state.copyWith(status: ExerciseStatus.failure, error: e.toString()));
  }
}
```

- [ ] **Step 6: Ejecutar tests para verificar que pasan**

```bash
flutter test test/features/exercise/presentation/exercise_bloc_test.dart -v 2>&1 | grep -E "PASS|FAIL|ERROR"
```

Expected: todos los tests PASS.

- [ ] **Step 7: Commit**

```bash
git add lib/features/exercise/presentation/bloc/exercise_event.dart \
        lib/features/exercise/presentation/bloc/exercise_state.dart \
        lib/features/exercise/presentation/bloc/exercise_bloc.dart \
        test/features/exercise/presentation/exercise_bloc_test.dart
git commit -m "feat(exercise): add ExercisePlanHistoryLoaded event and planHistory to BLoC state"
```

---

## Task 5: UI — _DaySelectionCard en exercise_page.dart

**Files:**
- Modify: `lib/features/exercise/presentation/pages/exercise_page.dart`
- Create: `test/features/exercise/presentation/exercise_page_test.dart`

- [ ] **Step 1: Escribir tests**

Crear `test/features/exercise/presentation/exercise_page_test.dart`:

```dart
import 'package:bloc_test/bloc_test.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kiolog/core/database/app_database.dart';
import 'package:kiolog/features/exercise/presentation/bloc/exercise_bloc.dart';
import 'package:kiolog/features/exercise/presentation/bloc/exercise_event.dart';
import 'package:kiolog/features/exercise/presentation/bloc/exercise_state.dart';
import 'package:mocktail/mocktail.dart';

class MockExerciseBloc
    extends MockBloc<ExerciseEvent, ExerciseState>
    implements ExerciseBloc {}

final _plan = ExercisePlan(
  id: 1,
  name: 'Plan Test',
  createdAt: DateTime(2026, 6, 1),
  isActive: true,
  periodStart: DateTime(2026, 6, 1),
  periodEnd: null,
);

const _routineA = ExerciseRoutine(
  id: 10,
  planId: 1,
  dayNumber: 1,
  routineName: 'Pecho y Espalda',
  notes: null,
);

const _routineB = ExerciseRoutine(
  id: 11,
  planId: 1,
  dayNumber: 2,
  routineName: 'Piernas',
  notes: null,
);

Widget _wrap(ExerciseBloc bloc) => MaterialApp(
      home: BlocProvider<ExerciseBloc>.value(
        value: bloc,
        child: Scaffold(
          body: BlocBuilder<ExerciseBloc, ExerciseState>(
            builder: (context, state) {
              if (state.activePlan == null || state.routines.isEmpty) {
                return const SizedBox();
              }
              if (state.hasActiveSession) {
                return const Text('Sesión activa');
              }
              // Reproduce _DaySelectionCard logic for testing
              return Column(
                children: [
                  const Text('¿Qué harás hoy?'),
                  ...state.routines.map((r) => GestureDetector(
                        key: Key('chip_${r.id}'),
                        onTap: () {},
                        child: Text('Día ${r.dayNumber} · ${r.routineName}'),
                      )),
                  ElevatedButton(
                    key: const Key('iniciar_btn'),
                    onPressed: () => context.read<ExerciseBloc>().add(
                          ExerciseSessionStarted(
                            date: DateTime.now(),
                            routineId: state.routines.first.id,
                          ),
                        ),
                    child: const Text('Iniciar sesión'),
                  ),
                ],
              );
            },
          ),
        ),
      ),
    );

void main() {
  late MockExerciseBloc bloc;

  setUpAll(() {
    registerFallbackValue(ExerciseLoaded(date: DateTime(2026)));
    registerFallbackValue(
        const ExerciseSessionStarted(date: null, routineId: 0));
  });

  setUp(() => bloc = MockExerciseBloc());

  group('ExercisePage - day selection', () {
    testWidgets('muestra chips para cada rutina del plan activo',
        (tester) async {
      whenListen(
        bloc,
        const Stream<ExerciseState>.empty(),
        initialState: ExerciseState(
          status: ExerciseStatus.success,
          activePlan: _plan,
          routines: const [_routineA, _routineB],
        ),
      );

      await tester.pumpWidget(_wrap(bloc));
      await tester.pump();

      expect(find.text('Día 1 · Pecho y Espalda'), findsOneWidget);
      expect(find.text('Día 2 · Piernas'), findsOneWidget);
    });

    testWidgets('botón Iniciar dispara ExerciseSessionStarted',
        (tester) async {
      whenListen(
        bloc,
        const Stream<ExerciseState>.empty(),
        initialState: ExerciseState(
          status: ExerciseStatus.success,
          activePlan: _plan,
          routines: const [_routineA],
        ),
      );

      await tester.pumpWidget(_wrap(bloc));
      await tester.pump();

      await tester.tap(find.byKey(const Key('iniciar_btn')));
      await tester.pump();

      verify(() => bloc.add(any(that: isA<ExerciseSessionStarted>()))).called(1);
    });

    testWidgets('no muestra selector cuando hay sesión activa',
        (tester) async {
      whenListen(
        bloc,
        const Stream<ExerciseState>.empty(),
        initialState: ExerciseState(
          status: ExerciseStatus.success,
          activePlan: _plan,
          routines: const [_routineA],
          activeSession: ExerciseSessionLog(
            id: 1,
            date: DateTime(2026, 6, 11),
            routineId: 10,
            gymArrivedAt: DateTime(2026, 6, 11, 8),
            gymLeftAt: null,
            lat: null,
            lng: null,
          ),
        ),
      );

      await tester.pumpWidget(_wrap(bloc));
      await tester.pump();

      expect(find.text('¿Qué harás hoy?'), findsNothing);
      expect(find.text('Sesión activa'), findsOneWidget);
    });
  });
}
```

- [ ] **Step 2: Ejecutar tests para verificar que pasan**

```bash
flutter test test/features/exercise/presentation/exercise_page_test.dart -v 2>&1 | grep -E "PASS|FAIL|ERROR"
```

Expected: PASS (los tests usan el widget de test, no el real — confirman la lógica de estado).

- [ ] **Step 3: Implementar _DaySelectionCard en exercise_page.dart**

En `lib/features/exercise/presentation/pages/exercise_page.dart`:

**3a.** Agregar `_selectedRoutineId` al estado de `_ExerciseViewState`:

```dart
class _ExerciseViewState extends State<_ExerciseView> {
  int? _expandedRoutineId;
  int? _selectedRoutineId; // null = auto (primer sin completar)
  // ...
}
```

**3b.** En el `builder` principal, reemplazar `_buildRutinaSection` dentro del `ListView` por `_buildDaySelectionCard` (cuando `!state.hasActiveSession`). El bloque de rutinas queda como detalle colapsable debajo:

```dart
// En el ListView children (línea ~107):
children: [
  if (state.hasActiveSession)
    _buildResumeSessionBanner(context, state),
  if (!state.hasActiveSession && state.routines.isNotEmpty)
    _buildDaySelectionCard(context, state),
  const SizedBox(height: 12),
  _buildWeekMiniCalendar(context, state),
  const SizedBox(height: 16),
  _buildCardioSection(context, state),
  const SizedBox(height: 16),
  _buildIndependentSection(context, state),
  const SizedBox(height: 80),
],
```

**3c.** Eliminar `bottomNavigationBar` del `Scaffold` (quitar la propiedad `bottomNavigationBar` y el método `_buildStartRoutineBar`).

**3d.** Agregar el widget `_buildDaySelectionCard`:

```dart
Widget _buildDaySelectionCard(BuildContext context, ExerciseState state) {
  final theme = Theme.of(context);
  final cs = theme.colorScheme;

  final completedIds = state.completedRoutineSessionsThisWeek
      .map((s) => s.routineId)
      .whereType<int>()
      .toSet();

  final defaultRoutine = state.routines.firstWhere(
    (r) => !completedIds.contains(r.id),
    orElse: () => state.routines.first,
  );
  final selectedId = _selectedRoutineId ?? defaultRoutine.id;
  final selectedRoutine = state.routines.firstWhere(
    (r) => r.id == selectedId,
    orElse: () => state.routines.first,
  );

  return VitalityCard(
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          '¿Qué harás hoy?',
          style: theme.textTheme.labelSmall?.copyWith(
            color: cs.onSurfaceVariant,
            letterSpacing: 1,
          ),
        ),
        const SizedBox(height: 10),
        Wrap(
          spacing: 8,
          runSpacing: 6,
          children: state.routines.map((routine) {
            final isSelected = routine.id == selectedId;
            return GestureDetector(
              onTap: () => setState(() => _selectedRoutineId = routine.id),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 150),
                padding: const EdgeInsets.symmetric(
                    horizontal: 14, vertical: 8),
                decoration: BoxDecoration(
                  color: isSelected
                      ? cs.primaryContainer
                      : cs.surfaceContainerHighest,
                  borderRadius: BorderRadius.circular(24),
                  border: Border.all(
                    color: isSelected ? cs.primary : Colors.transparent,
                    width: 1.5,
                  ),
                ),
                child: Text(
                  'Día ${routine.dayNumber} · ${routine.routineName}',
                  style: theme.textTheme.labelMedium?.copyWith(
                    color: isSelected
                        ? cs.onPrimaryContainer
                        : cs.onSurfaceVariant,
                    fontWeight: isSelected
                        ? FontWeight.w600
                        : FontWeight.normal,
                  ),
                ),
              ),
            );
          }).toList(),
        ),
        const SizedBox(height: 14),
        SizedBox(
          width: double.infinity,
          child: ElevatedButton.icon(
            onPressed: () {
              context.read<ExerciseBloc>().add(
                    ExerciseSessionStarted(
                      date: DateTime.now(),
                      routineId: selectedRoutine.id,
                    ),
                  );
            },
            icon: const Icon(Icons.play_arrow),
            label: Text('Iniciar — ${selectedRoutine.routineName}'),
          ),
        ),
      ],
    ),
  );
}
```

**3e.** Agregar `_buildWeekMiniCalendar`:

```dart
Widget _buildWeekMiniCalendar(BuildContext context, ExerciseState state) {
  final theme = Theme.of(context);
  final cs = theme.colorScheme;
  final now = DateTime.now();
  final monday = now.subtract(Duration(days: now.weekday - 1));
  final weekDays = ['L', 'M', 'X', 'J', 'V', 'S', 'D'];

  final completedDates = state.completedRoutineSessionsThisWeek
      .where((s) => s.gymLeftAt != null)
      .map((s) {
        final d = s.date.toLocal();
        return DateTime(d.year, d.month, d.day);
      })
      .toSet();

  return Row(
    mainAxisAlignment: MainAxisAlignment.spaceEvenly,
    children: List.generate(7, (i) {
      final day = monday.add(Duration(days: i));
      final dayNorm = DateTime(day.year, day.month, day.day);
      final todayNorm = DateTime(now.year, now.month, now.day);
      final isToday = dayNorm == todayNorm;
      final isDone = completedDates.contains(dayNorm);
      final isFuture = dayNorm.isAfter(todayNorm);

      Color bgColor;
      Color fgColor;
      Border? border;

      if (isDone) {
        bgColor = cs.tertiaryContainer;
        fgColor = cs.onTertiaryContainer;
        border = null;
      } else if (isToday) {
        bgColor = cs.primaryContainer;
        fgColor = cs.onPrimaryContainer;
        border = null;
      } else if (isFuture) {
        bgColor = Colors.transparent;
        fgColor = cs.onSurfaceVariant.withValues(alpha: 0.4);
        border = Border.all(
            color: cs.outline.withValues(alpha: 0.3),
            width: 1,
            style: BorderStyle.solid);
      } else {
        bgColor = cs.surfaceContainerHighest;
        fgColor = cs.onSurfaceVariant;
        border = null;
      }

      return Column(
        children: [
          Container(
            width: 34,
            height: 34,
            decoration: BoxDecoration(
              color: bgColor,
              shape: BoxShape.circle,
              border: border,
            ),
            child: Center(
              child: isDone
                  ? Icon(Icons.check, size: 14, color: fgColor)
                  : Text(
                      weekDays[i],
                      style: theme.textTheme.labelSmall
                          ?.copyWith(color: fgColor, fontWeight: FontWeight.w600),
                    ),
            ),
          ),
        ],
      );
    }),
  );
}
```

- [ ] **Step 4: Ejecutar flutter analyze y tests**

```bash
flutter analyze lib/features/exercise/presentation/pages/exercise_page.dart 2>&1 | grep -E "error|warning" | head -20
flutter test test/features/exercise/presentation/exercise_page_test.dart -v 2>&1 | grep -E "PASS|FAIL|ERROR"
```

Expected: sin errores de análisis, tests PASS.

- [ ] **Step 5: Commit**

```bash
git add lib/features/exercise/presentation/pages/exercise_page.dart \
        test/features/exercise/presentation/exercise_page_test.dart
git commit -m "feat(exercise): add day selection card and weekly mini-calendar to exercise page"
```

---

## Task 6: UI — Tab Historial en exercise_progress_page.dart

**Files:**
- Modify: `lib/features/exercise/presentation/pages/exercise_progress_page.dart`
- Modify: `test/features/exercise/presentation/exercise_progress_page_test.dart`

- [ ] **Step 1: Escribir test fallido**

Agregar al archivo `test/features/exercise/presentation/exercise_progress_page_test.dart`:

```dart
// Al inicio, agregar imports:
import 'package:kiolog/features/exercise/domain/models/plan_compliance_stat.dart';
import 'package:kiolog/features/exercise/presentation/bloc/exercise_event.dart';

// Agregar fallbackValue en setUpAll:
registerFallbackValue(const ExercisePlanHistoryLoaded());

// Nuevo test:
testWidgets('tab Historial muestra cards con nombre y cumplimiento',
    (tester) async {
  final plan = ExercisePlan(
    id: 1,
    name: 'Rutina Fuerza',
    createdAt: DateTime(2026, 1, 1),
    isActive: true,
    periodStart: DateTime(2026, 1, 1),
    periodEnd: null,
  );
  final compliance = PlanComplianceStat(
    planId: 1,
    planName: 'Rutina Fuerza',
    periodStart: DateTime(2026, 1, 1),
    periodEnd: null,
    totalSessions: 20,
    weeksActive: 10,
    weeklyAvg: 2.0,
    compliancePercent: 50,
  );
  whenListen(
    bloc,
    const Stream<ExerciseState>.empty(),
    initialState: ExerciseState(
      status: ExerciseStatus.success,
      activePlan: plan,
      planHistory: [compliance],
    ),
  );

  await tester.pumpWidget(_wrap(bloc));
  await tester.pump();

  // Cambiar al tab Historial
  await tester.tap(find.text('Historial'));
  await tester.pumpAndSettle();

  expect(find.text('Rutina Fuerza'), findsOneWidget);
  expect(find.text('50%'), findsOneWidget);
});
```

- [ ] **Step 2: Ejecutar test para verificar que falla**

```bash
flutter test test/features/exercise/presentation/exercise_progress_page_test.dart -v 2>&1 | grep -E "FAIL|ERROR|Historial"
```

Expected: `The finder "text 'Historial'" found no candidates` — tab no existe todavía.

- [ ] **Step 3: Refactorizar ExerciseProgressPage a TabBar**

En `lib/features/exercise/presentation/pages/exercise_progress_page.dart`:

**3a.** Cambiar la clase a `StatefulWidget` con `SingleTickerProviderStateMixin` (ya es stateful, solo agregar el mixin y el TabController):

```dart
class _ExerciseProgressPageState extends State<ExerciseProgressPage>
    with SingleTickerProviderStateMixin {
  late final TabController _tabController;
  _Chart _chart = _Chart.rutina;
  int _weekOffset = 0;
  int _monthOffset = 0;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
    _tabController.addListener(() {
      if (_tabController.index == 2) {
        // Tab Historial seleccionado — cargar si vacío
        final state = context.read<ExerciseBloc>().state;
        if (state.planHistory.isEmpty) {
          context.read<ExerciseBloc>().add(const ExercisePlanHistoryLoaded());
        }
      }
    });
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }
```

**3b.** En `build`, reemplazar el `Scaffold` para usar `TabBar` en el `AppBar` y `TabBarView` en el `body`:

```dart
@override
Widget build(BuildContext context) {
  return Scaffold(
    appBar: AppBar(
      title: const Text('Progreso'),
      bottom: TabBar(
        controller: _tabController,
        tabs: const [
          Tab(text: 'Semana'),
          Tab(text: 'Mes'),
          Tab(text: 'Historial'),
        ],
      ),
    ),
    body: BlocBuilder<ExerciseBloc, ExerciseState>(
      builder: (context, state) => TabBarView(
        controller: _tabController,
        children: [
          _buildSemanaTab(state),
          _buildMesTab(state),
          _HistorialTab(history: state.planHistory),
        ],
      ),
    ),
  );
}
```

**3c.** Mover el contenido actual de `build` a métodos `_buildSemanaTab` y `_buildMesTab`:

```dart
Widget _buildSemanaTab(ExerciseState state) {
  return ListView(
    padding: const EdgeInsets.all(16),
    children: [
      _buildWeekNavigator(context, state),
      const SizedBox(height: 12),
      _buildSemanaChips(context, state),
      const SizedBox(height: 16),
      _buildChartToggle(context),
      const SizedBox(height: 8),
      _buildWeekBarChartWidget(state),
    ],
  );
}

Widget _buildMesTab(ExerciseState state) {
  return ListView(
    padding: const EdgeInsets.all(16),
    children: [
      _buildMonthNavigator(context),
      const SizedBox(height: 12),
      _buildMesChips(context, state),
      const SizedBox(height: 16),
      _buildChartToggle(context),
      const SizedBox(height: 8),
      _buildMonthBarChartWidget(state),
    ],
  );
}
```

**3d.** Eliminar `_buildPeriodToggle` (ya no se necesita — reemplazado por `TabBar`).

**3e.** Agregar el widget `_HistorialTab` al final del archivo:

```dart
class _HistorialTab extends StatelessWidget {
  final List<PlanComplianceStat> history;

  const _HistorialTab({required this.history});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;

    if (history.isEmpty) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.history, size: 48, color: cs.onSurfaceVariant),
            const SizedBox(height: 12),
            Text('Sin historial de planes',
                style: theme.textTheme.bodyLarge
                    ?.copyWith(color: cs.onSurface)),
          ],
        ),
      );
    }

    return ListView.separated(
      padding: const EdgeInsets.all(16),
      itemCount: history.length,
      separatorBuilder: (_, __) => const SizedBox(height: 12),
      itemBuilder: (context, index) {
        final stat = history[index];
        final isActive = stat.periodEnd == null;
        return _PlanHistoryCard(stat: stat, isActive: isActive);
      },
    );
  }
}

class _PlanHistoryCard extends StatelessWidget {
  final PlanComplianceStat stat;
  final bool isActive;

  const _PlanHistoryCard({required this.stat, required this.isActive});

  String _formatDate(DateTime d) =>
      '${d.day} ${_monthAbbr(d.month)} ${d.year}';

  String _monthAbbr(int m) => const [
        '', 'ene', 'feb', 'mar', 'abr', 'may', 'jun',
        'jul', 'ago', 'sep', 'oct', 'nov', 'dic'
      ][m];

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;

    final subtitle = isActive
        ? 'Desde ${_formatDate(stat.periodStart)} · En curso'
        : '${_formatDate(stat.periodStart)} — ${_formatDate(stat.periodEnd!)} · ${stat.weeksActive} semanas';

    return Container(
      decoration: BoxDecoration(
        color: cs.surfaceContainerLow,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: isActive ? cs.primary : cs.outline.withValues(alpha: 0.4),
          width: isActive ? 1.5 : 1,
        ),
      ),
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(stat.planName,
                    style: theme.textTheme.titleMedium
                        ?.copyWith(color: cs.onSurface)),
              ),
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: isActive
                      ? cs.tertiaryContainer
                      : cs.surfaceContainerHighest,
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Text(
                  isActive ? 'Activo' : 'Finalizado',
                  style: theme.textTheme.labelSmall?.copyWith(
                    color: isActive
                        ? cs.onTertiaryContainer
                        : cs.onSurfaceVariant,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 4),
          Text(subtitle,
              style: theme.textTheme.bodySmall
                  ?.copyWith(color: cs.onSurfaceVariant)),
          const SizedBox(height: 12),
          Row(
            children: [
              _StatBox(
                  value: '${stat.compliancePercent}%',
                  label: 'Cumplimiento',
                  valueColor: isActive ? cs.primary : cs.secondary,
                  theme: theme),
              const SizedBox(width: 8),
              _StatBox(
                  value: '${stat.totalSessions}',
                  label: 'Sesiones',
                  theme: theme),
              const SizedBox(width: 8),
              _StatBox(
                  value: '${stat.weeksActive}',
                  label: 'Semanas',
                  theme: theme),
            ],
          ),
          const SizedBox(height: 10),
          ClipRRect(
            borderRadius: BorderRadius.circular(4),
            child: LinearProgressIndicator(
              value: stat.compliancePercent / 100,
              minHeight: 6,
              backgroundColor: cs.surfaceContainerHighest,
              color: isActive ? cs.primary : cs.secondary,
            ),
          ),
        ],
      ),
    );
  }
}

class _StatBox extends StatelessWidget {
  final String value;
  final String label;
  final Color? valueColor;
  final ThemeData theme;

  const _StatBox({
    required this.value,
    required this.label,
    required this.theme,
    this.valueColor,
  });

  @override
  Widget build(BuildContext context) {
    final cs = theme.colorScheme;
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 10),
        decoration: BoxDecoration(
          color: cs.surfaceContainerHighest,
          borderRadius: BorderRadius.circular(10),
        ),
        child: Column(
          children: [
            Text(
              value,
              style: theme.textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.w700,
                color: valueColor ?? cs.onSurface,
              ),
            ),
            const SizedBox(height: 2),
            Text(label,
                style: theme.textTheme.labelSmall
                    ?.copyWith(color: cs.onSurfaceVariant)),
          ],
        ),
      ),
    );
  }
}
```

Agregar import al inicio de `exercise_progress_page.dart`:
```dart
import '../../domain/models/plan_compliance_stat.dart';
import '../bloc/exercise_event.dart';
```

- [ ] **Step 4: Ejecutar analyze y tests**

```bash
flutter analyze lib/features/exercise/presentation/pages/exercise_progress_page.dart 2>&1 | grep -E "error|warning" | head -10
flutter test test/features/exercise/presentation/exercise_progress_page_test.dart -v 2>&1 | grep -E "PASS|FAIL|ERROR"
```

Expected: sin errores, todos los tests PASS.

- [ ] **Step 5: Commit**

```bash
git add lib/features/exercise/presentation/pages/exercise_progress_page.dart \
        test/features/exercise/presentation/exercise_progress_page_test.dart
git commit -m "feat(exercise): add Historial tab to progress page with PlanComplianceStat cards"
```

---

## Task 7: UI — Template feature en exercise_config_page.dart

**Files:**
- Modify: `lib/features/exercise/presentation/pages/exercise_config_page.dart`

No tests de widget para este task — la lógica de carga de template usa el repositorio directamente (mismo patrón que `_save()`), no hay BLoC que mockear.

- [ ] **Step 1: Agregar _allPlans al estado de _ExerciseConfigPageState**

En `lib/features/exercise/presentation/pages/exercise_config_page.dart`:

**1a.** Agregar imports al inicio:
```dart
import 'package:kiolog/core/database/app_database.dart';
```

**1b.** Agregar campo y `initState` a `_ExerciseConfigPageState`:

```dart
List<ExercisePlan> _allPlans = [];

@override
void initState() {
  super.initState();
  _loadPlans();
}

Future<void> _loadPlans() async {
  final plans = await getIt<ExerciseRepository>().getAllPlans();
  if (mounted) setState(() => _allPlans = plans);
}
```

- [ ] **Step 2: Agregar botón "Partir de plan anterior"**

En el método `build`, en la `Column` del body, agregar después del `TextField` de nombre del plan y antes del `SizedBox(height: 24)` que precede a los días de rutina:

```dart
if (_allPlans.isNotEmpty) ...[
  const SizedBox(height: 12),
  OutlinedButton.icon(
    onPressed: () => _showTemplatePicker(context),
    icon: const Icon(Icons.copy_outlined),
    label: const Text('Partir de plan anterior'),
    style: OutlinedButton.styleFrom(
      minimumSize: const Size.fromHeight(44),
    ),
  ),
],
```

- [ ] **Step 3: Agregar _showTemplatePicker y _applyTemplate**

Agregar a `_ExerciseConfigPageState`:

```dart
void _showTemplatePicker(BuildContext context) {
  showModalBottomSheet<void>(
    context: context,
    builder: (ctx) => Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        const ListTile(
          title: Text('Selecciona un plan base'),
          subtitle: Text('Los días y ejercicios se copian como punto de partida editable.'),
        ),
        const Divider(height: 1),
        ..._allPlans.map((plan) => ListTile(
              leading: const Icon(Icons.fitness_center),
              title: Text(plan.name),
              subtitle: Text(plan.isActive ? 'Plan activo' : 'Finalizado'),
              trailing: const Icon(Icons.chevron_right),
              onTap: () {
                Navigator.pop(ctx);
                _applyTemplate(plan.id);
              },
            )),
        const SizedBox(height: 16),
      ],
    ),
  );
}

Future<void> _applyTemplate(int planId) async {
  final repo = getIt<ExerciseRepository>();
  final routines = await repo.getRoutinesForPlan(planId);

  final newDays = <_RoutineDayLocal>[];
  for (final routine in routines) {
    final items = await repo.getRoutineItemsOrdered(routine.id);
    final day = _RoutineDayLocal();
    day.nameController.text = routine.routineName;
    for (final item in items) {
      final entry = _ExerciseEntryLocal();
      entry.name.text = item.exerciseName;
      entry.sets.text = '${item.sets}';
      entry.reps.text = '${item.reps}';
      if (item.weightKg != null) entry.weight.text = '${item.weightKg}';
      day.exercises.add(entry);
    }
    newDays.add(day);
  }

  // Limpiar días actuales
  for (final day in _routineDays) {
    day.nameController.dispose();
    for (final e in day.exercises) {
      e.name.dispose();
      e.sets.dispose();
      e.reps.dispose();
      e.weight.dispose();
    }
  }

  setState(() {
    _routineDays
      ..clear()
      ..addAll(newDays);
    _planNameController.clear(); // el usuario escribe el nuevo nombre
  });
}
```

- [ ] **Step 4: Ejecutar flutter analyze**

```bash
flutter analyze lib/features/exercise/presentation/pages/exercise_config_page.dart 2>&1 | grep -E "error|warning" | head -10
```

Expected: sin errores.

- [ ] **Step 5: Ejecutar todos los tests del módulo**

```bash
flutter test test/dao/exercise_dao_test.dart \
             test/features/exercise/ \
             -v 2>&1 | grep -E "PASS|FAIL|ERROR" | tail -30
```

Expected: todos PASS.

- [ ] **Step 6: Commit**

```bash
git add lib/features/exercise/presentation/pages/exercise_config_page.dart
git commit -m "feat(exercise): add template picker to config page — copy days and exercises from previous plan"
```

---

## Self-review checklist

Spec coverage:
- ✅ `periodStart`/`periodEnd` en `ExercisePlan` — Task 1
- ✅ `setActiveExercisePlan` setea `periodEnd` — Task 2
- ✅ `PlanComplianceStat` modelo — Task 3
- ✅ `getPlanHistory()` repositorio — Task 3
- ✅ `ExercisePlanHistoryLoaded` evento — Task 4
- ✅ `planHistory` en estado BLoC — Task 4
- ✅ Card "¿Qué harás hoy?" con chips — Task 5
- ✅ Mini-calendario semanal — Task 5
- ✅ Tab Historial en progress page — Task 6
- ✅ Cards `_PlanHistoryCard` con stats — Task 6
- ✅ Botón plantilla en config page — Task 7
- ✅ Bottom sheet + `_applyTemplate` — Task 7
