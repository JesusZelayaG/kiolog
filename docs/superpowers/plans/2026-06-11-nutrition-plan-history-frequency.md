# Nutrition — Plan History & Option Frequency Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Agregar frecuencia de opciones por plan, historial de planes navegable desde la pantalla de progreso, y flujo de nueva consulta mensual con banner de activación.

**Architecture:** Sin cambios al schema de BD. Nuevo modelo `OptionFrequencyStat` + query en DAO. El BLoC agrega `viewingPlanId` y `optionFrequencies`. `NutritionProgressPage` se refactoriza con tabs Adherencia/Frecuencia y un chip selector de plan. `NutritionPage` muestra banner cuando hay un plan pendiente de activación.

**Tech Stack:** Flutter, Drift ORM, BLoC, `collection` package, `mocktail`/`bloc_test` para tests.

---

## Archivos afectados

| Acción | Archivo |
|---|---|
| Crear | `lib/features/nutrition/domain/models/option_frequency_stat.dart` |
| Modificar | `lib/core/dao/nutrition_dao.dart` |
| Modificar | `lib/features/nutrition/domain/repositories/nutrition_repository.dart` |
| Modificar | `lib/features/nutrition/data/repositories/nutrition_repository_impl.dart` |
| Modificar | `lib/features/nutrition/presentation/bloc/nutrition_event.dart` |
| Modificar | `lib/features/nutrition/presentation/bloc/nutrition_state.dart` |
| Modificar | `lib/features/nutrition/presentation/bloc/nutrition_bloc.dart` |
| Modificar | `lib/features/nutrition/presentation/pages/nutrition_progress_page.dart` |
| Modificar | `lib/features/nutrition/presentation/pages/nutrition_page.dart` |
| Modificar | `test/dao/nutrition_dao_test.dart` |
| Modificar | `test/features/nutrition/data/nutrition_repository_test.dart` |
| Modificar | `test/features/nutrition/presentation/nutrition_bloc_test.dart` |
| Modificar | `test/features/nutrition/presentation/nutrition_progress_page_test.dart` |
| Modificar | `test/features/nutrition/presentation/nutrition_page_test.dart` |

---

## Task 1: `OptionFrequencyStat` model + DAO query

**Files:**
- Create: `lib/features/nutrition/domain/models/option_frequency_stat.dart`
- Modify: `lib/core/dao/nutrition_dao.dart`
- Test: `test/dao/nutrition_dao_test.dart`

- [ ] **Step 1: Escribir los tests que fallan**

Agregar al final del grupo `'NutritionDao - DailyMealLogs'` en `test/dao/nutrition_dao_test.dart`:

```dart
group('NutritionDao - getOptionFrequenciesForPlan', () {
  test('returns empty when plan has no options', () async {
    final planId = await db.nutritionDao.insertMealPlan(
      MealPlansCompanion(
        name: const Value('Plan'),
        createdAt: Value(DateTime.utc(2026, 6, 1)),
        periodStart: Value(DateTime.utc(2026, 6, 1)),
      ),
    );
    final result =
        await db.nutritionDao.getOptionFrequenciesForPlan(planId);
    expect(result, isEmpty);
  });

  test('returns count 0 for option with no logs', () async {
    final planId = await db.nutritionDao.insertMealPlan(
      MealPlansCompanion(
        name: const Value('Plan'),
        createdAt: Value(DateTime.utc(2026, 6, 1)),
        periodStart: Value(DateTime.utc(2026, 6, 1)),
      ),
    );
    await db.nutritionDao.insertMealPlanOption(
      MealPlanOptionsCompanion(
        planId: Value(planId),
        mealType: const Value('Desayuno'),
        optionNumber: const Value(1),
        description: const Value('Avena'),
      ),
    );
    final result =
        await db.nutritionDao.getOptionFrequenciesForPlan(planId);
    expect(result.length, 1);
    expect(result.first.count, 0);
    expect(result.first.description, 'Avena');
  });

  test('counts logs correctly within plan period', () async {
    final planId = await db.nutritionDao.insertMealPlan(
      MealPlansCompanion(
        name: const Value('Plan'),
        createdAt: Value(DateTime.utc(2026, 6, 1)),
        periodStart: Value(DateTime.utc(2026, 6, 1)),
      ),
    );
    final optId = await db.nutritionDao.insertMealPlanOption(
      MealPlanOptionsCompanion(
        planId: Value(planId),
        mealType: const Value('Desayuno'),
        optionNumber: const Value(1),
        description: const Value('Avena'),
      ),
    );
    // Log 3 veces la misma opción
    for (var i = 0; i < 3; i++) {
      await db.nutritionDao.insertDailyMealLog(
        DailyMealLogsCompanion(
          date: Value(DateTime.utc(2026, 6, i + 1)),
          mealType: const Value('Desayuno'),
          planOptionId: Value(optId),
        ),
      );
    }
    final result =
        await db.nutritionDao.getOptionFrequenciesForPlan(planId);
    expect(result.first.count, 3);
  });

  test('does not count logs outside plan period', () async {
    final planId = await db.nutritionDao.insertMealPlan(
      MealPlansCompanion(
        name: const Value('Plan'),
        createdAt: Value(DateTime.utc(2026, 6, 1)),
        periodStart: Value(DateTime.utc(2026, 6, 1)),
        periodEnd: Value(DateTime.utc(2026, 6, 10)), // terminó el 10
      ),
    );
    final optId = await db.nutritionDao.insertMealPlanOption(
      MealPlanOptionsCompanion(
        planId: Value(planId),
        mealType: const Value('Desayuno'),
        optionNumber: const Value(1),
        description: const Value('Avena'),
      ),
    );
    // Dentro del período
    await db.nutritionDao.insertDailyMealLog(
      DailyMealLogsCompanion(
        date: Value(DateTime.utc(2026, 6, 5)),
        mealType: const Value('Desayuno'),
        planOptionId: Value(optId),
      ),
    );
    // Fuera del período (después del 10)
    await db.nutritionDao.insertDailyMealLog(
      DailyMealLogsCompanion(
        date: Value(DateTime.utc(2026, 6, 15)),
        mealType: const Value('Desayuno'),
        planOptionId: Value(optId),
      ),
    );
    final result =
        await db.nutritionDao.getOptionFrequenciesForPlan(planId);
    expect(result.first.count, 1); // solo el log del día 5
  });
});
```

También agregar el import al principio del test file (ya existe `import 'package:drift/drift.dart';`).

- [ ] **Step 2: Correr los tests y verificar que fallan**

```bash
flutter test test/dao/nutrition_dao_test.dart --name "getOptionFrequenciesForPlan" 2>&1
```

Expected: FAIL — `getOptionFrequenciesForPlan` no existe aún.

- [ ] **Step 3: Crear el modelo `OptionFrequencyStat`**

Crear `lib/features/nutrition/domain/models/option_frequency_stat.dart`:

```dart
import 'package:equatable/equatable.dart';

class OptionFrequencyStat extends Equatable {
  final int planOptionId;
  final String mealType;
  final int optionNumber;
  final String description;
  final int count;

  const OptionFrequencyStat({
    required this.planOptionId,
    required this.mealType,
    required this.optionNumber,
    required this.description,
    required this.count,
  });

  @override
  List<Object?> get props =>
      [planOptionId, mealType, optionNumber, description, count];
}
```

- [ ] **Step 4: Agregar `getOptionFrequenciesForPlan` al DAO**

En `lib/core/dao/nutrition_dao.dart`, agregar el import al principio:

```dart
import 'package:kiolog/features/nutrition/domain/models/option_frequency_stat.dart';
```

Y agregar el método al final de la clase `NutritionDao` (antes del cierre `}`):

```dart
Future<List<OptionFrequencyStat>> getOptionFrequenciesForPlan(
    int planId) async {
  final plan = await (select(mealPlans)
        ..where((t) => t.id.equals(planId)))
      .getSingleOrNull();
  if (plan == null) return [];

  final start = plan.periodStart;
  if (start == null) return [];

  // Usar .toUtc() para evitar desfase de zona horaria al reconstruir la fecha
  final startUtc = start.toUtc();
  final startDay = DateTime.utc(startUtc.year, startUtc.month, startUtc.day);

  final DateTime endDay;
  if (plan.periodEnd != null) {
    final endUtc = plan.periodEnd!.toUtc();
    // periodEnd es el último día incluido, por eso +1 día para el límite exclusivo
    endDay = DateTime.utc(endUtc.year, endUtc.month, endUtc.day)
        .add(const Duration(days: 1));
  } else {
    final now = DateTime.now().toUtc();
    endDay = DateTime.utc(now.year, now.month, now.day)
        .add(const Duration(days: 1));
  }

  final opts = await (select(mealPlanOptions)
        ..where((t) => t.planId.equals(planId))
        ..orderBy([
          (t) => OrderingTerm.asc(t.mealType),
          (t) => OrderingTerm.asc(t.optionNumber),
        ]))
      .get();
  if (opts.isEmpty) return [];

  final optionIds = opts.map((o) => o.id).toList();
  final logs = await (select(dailyMealLogs)
        ..where((t) =>
            t.planOptionId.isIn(optionIds) &
            t.date.isBiggerOrEqualValue(startDay) &
            t.date.isSmallerThanValue(endDay)))
      .get();

  final countMap = <int, int>{};
  for (final log in logs) {
    if (log.planOptionId != null) {
      countMap[log.planOptionId!] =
          (countMap[log.planOptionId!] ?? 0) + 1;
    }
  }

  return opts
      .map((o) => OptionFrequencyStat(
            planOptionId: o.id,
            mealType: o.mealType,
            optionNumber: o.optionNumber,
            description: o.description,
            count: countMap[o.id] ?? 0,
          ))
      .toList();
}
```

- [ ] **Step 5: Correr los tests y verificar que pasan**

```bash
flutter test test/dao/nutrition_dao_test.dart 2>&1
```

Expected: todos los tests del DAO pasan.

- [ ] **Step 6: Commit**

```bash
git add lib/features/nutrition/domain/models/option_frequency_stat.dart \
        lib/core/dao/nutrition_dao.dart \
        test/dao/nutrition_dao_test.dart
git commit -m "feat(nutrition): add OptionFrequencyStat model + DAO query"
```

---

## Task 2: Repository layer + corregir bug de timezone en `getWeeklyAdherence`

**Files:**
- Modify: `lib/features/nutrition/domain/repositories/nutrition_repository.dart`
- Modify: `lib/features/nutrition/data/repositories/nutrition_repository_impl.dart`
- Test: `test/features/nutrition/data/nutrition_repository_test.dart`

- [ ] **Step 1: Escribir test de `getOptionFrequency`**

Agregar al grupo principal en `test/features/nutrition/data/nutrition_repository_test.dart`:

```dart
test('getOptionFrequency returns frequency stats for plan', () async {
  final planId = await repository.createPlan('Plan', dailyMealGoal: 2);
  await repository.activatePlan(planId);

  await repository.addPlanOption(
    planId: planId,
    mealType: 'Desayuno',
    optionNumber: 1,
    description: 'Avena',
  );

  // Obtener el id de la opción recién creada
  final opts = await repository.getPlanOptions(planId, 'Desayuno');
  final optId = opts.first.id;

  await repository.logMeal(
    date: DateTime.utc(2026, 6, 5),
    mealType: 'Desayuno',
    planOptionId: optId,
  );
  await repository.logMeal(
    date: DateTime.utc(2026, 6, 6),
    mealType: 'Desayuno',
    planOptionId: optId,
  );

  final result = await repository.getOptionFrequency(planId);
  expect(result.length, 1);
  expect(result.first.description, 'Avena');
  expect(result.first.count, 2);
});
```

- [ ] **Step 2: Corregir el test de `getWeeklyAdherence` que falla por zona horaria**

El test `'getWeeklyAdherence returns correct adherence for current week'` usa `DateTime.now().toUtc()` para crear logs, lo que falla en zonas UTC negativas porque Drift retorna los datetimes en hora local. Reemplazar el test completo:

```dart
test('getWeeklyAdherence returns correct adherence for current week',
    () async {
  final planId =
      await repository.createPlan('Plan', dailyMealGoal: 2);
  await repository.activatePlan(planId);

  final optId = await db.nutritionDao.insertMealPlanOption(
    MealPlanOptionsCompanion(
      planId: Value(planId),
      mealType: const Value('breakfast'),
      optionNumber: const Value(1),
      description: const Value('Avena'),
    ),
  );

  // Usar DateTime.now() local (no .toUtc()) para que _dateOnly produzca
  // la misma fecha que getWeeklyAdherence usa internamente.
  final today = DateTime.now();
  await repository.logMeal(
    date: today,
    mealType: 'breakfast',
    planOptionId: optId,
  );
  await repository.logOffPlanMeal(
    date: today,
    mealType: 'snack',
    description: 'Pizza',
  );

  final stats = await repository.getWeeklyAdherence(weeksBack: 1);
  expect(stats.length, 1);
  expect(stats.first.mealsLogged, 1);
  expect(stats.first.offPlanMeals, 1);

  // Verificar mealsExpected: días desde inicio del plan activo hasta hoy
  final nowUtc = DateTime.now().toUtc();
  final todayMidnightUtc =
      DateTime.utc(nowUtc.year, nowUtc.month, nowUtc.day);
  final daysToMonday = todayMidnightUtc.weekday - 1;
  final weekStartUtc =
      todayMidnightUtc.subtract(Duration(days: daysToMonday));

  // Obtener el plan para leer su periodStart
  final activePlan = await repository.getActivePlan();
  final ps = activePlan!.periodStart!.toUtc();
  final planStartDay = DateTime.utc(ps.year, ps.month, ps.day);
  final effectiveStart = planStartDay.isAfter(weekStartUtc)
      ? planStartDay
      : weekStartUtc;
  final daysActive =
      todayMidnightUtc.difference(effectiveStart).inDays + 1;
  expect(stats.first.mealsExpected, daysActive * 2);
});
```

- [ ] **Step 3: Correr los tests para confirmar que el test de getWeeklyAdherence falla (antes del fix del repo)**

```bash
flutter test test/features/nutrition/data/nutrition_repository_test.dart 2>&1 | grep -E "FAIL|PASS|Error"
```

Expected: `getOptionFrequency` falla (no implementado), `getWeeklyAdherence` puede fallar o pasar según zona.

- [ ] **Step 4: Corregir `getWeeklyAdherence` en el repositorio para usar `.toUtc()`**

En `lib/features/nutrition/data/repositories/nutrition_repository_impl.dart`, dentro de `getWeeklyAdherence`, cambiar el loop de logs y el de plan period para usar `.toUtc()`:

```dart
// Reemplazar el bloque de búsqueda de activePlan (lines ~132-148):
MealPlan? activePlan;
for (final plan in allPlans) {
  final start = plan.periodStart;
  final end = plan.periodEnd;
  if (start == null) continue;
  final startUtc = start.toUtc();  // ← .toUtc() agregado
  final startDay =
      DateTime.utc(startUtc.year, startUtc.month, startUtc.day);
  if (startDay.isAfter(day)) continue;
  if (end != null) {
    final endUtc = end.toUtc();  // ← .toUtc() agregado
    final endDay =
        DateTime.utc(endUtc.year, endUtc.month, endUtc.day);
    if (!endDay.isAfter(day)) continue;
  }
  activePlan = plan;
  break;
}
```

```dart
// Reemplazar el loop de conteo de logs (~lines 152-161):
for (final log in allLogs) {
  final logUtc = log.date.toUtc();  // ← .toUtc() agregado
  final logDay =
      DateTime.utc(logUtc.year, logUtc.month, logUtc.day);
  if (logDay != day) continue;
  if (log.planOptionId != null) {
    mealsLogged++;
  } else {
    offPlanMeals++;
  }
}
```

- [ ] **Step 5: Agregar `getOptionFrequency` a la interfaz y la implementación**

En `lib/features/nutrition/domain/repositories/nutrition_repository.dart`, agregar al final de la clase abstracta:

```dart
Future<List<OptionFrequencyStat>> getOptionFrequency(int planId);
```

Y agregar el import al principio:
```dart
import '../models/option_frequency_stat.dart';
```

En `lib/features/nutrition/data/repositories/nutrition_repository_impl.dart`, agregar el import:

```dart
import 'package:kiolog/features/nutrition/domain/models/option_frequency_stat.dart';
```

Y al final de la clase `NutritionRepositoryImpl`:

```dart
@override
Future<List<OptionFrequencyStat>> getOptionFrequency(int planId) =>
    _nutritionDao.getOptionFrequenciesForPlan(planId);
```

- [ ] **Step 6: Correr todos los tests del repositorio**

```bash
flutter test test/features/nutrition/data/nutrition_repository_test.dart 2>&1
```

Expected: todos pasan.

- [ ] **Step 7: Commit**

```bash
git add lib/features/nutrition/domain/repositories/nutrition_repository.dart \
        lib/features/nutrition/data/repositories/nutrition_repository_impl.dart \
        test/features/nutrition/data/nutrition_repository_test.dart
git commit -m "feat(nutrition): add getOptionFrequency + fix getWeeklyAdherence timezone"
```

---

## Task 3: BLoC — evento, estado y handlers

**Files:**
- Modify: `lib/features/nutrition/presentation/bloc/nutrition_event.dart`
- Modify: `lib/features/nutrition/presentation/bloc/nutrition_state.dart`
- Modify: `lib/features/nutrition/presentation/bloc/nutrition_bloc.dart`
- Test: `test/features/nutrition/presentation/nutrition_bloc_test.dart`

- [ ] **Step 1: Agregar `NutritionProgressPlanSelected` al event file**

En `lib/features/nutrition/presentation/bloc/nutrition_event.dart`, agregar al final:

```dart
class NutritionProgressPlanSelected extends NutritionEvent {
  final int planId;
  const NutritionProgressPlanSelected({required this.planId});
  @override
  List<Object?> get props => [planId];
}
```

- [ ] **Step 2: Reemplazar `NutritionState` completo**

Reemplazar el contenido de `lib/features/nutrition/presentation/bloc/nutrition_state.dart`:

```dart
import 'package:collection/collection.dart';
import 'package:equatable/equatable.dart';
import 'package:kiolog/core/database/app_database.dart';
import 'package:kiolog/features/nutrition/domain/models/nutrition_weekly_stat.dart';
import 'package:kiolog/features/nutrition/domain/models/option_frequency_stat.dart';

enum NutritionStatus { initial, loading, success, failure }

class NutritionState extends Equatable {
  final NutritionStatus status;
  final MealPlan? activePlan;
  final List<MealPlan> allPlans;
  final Map<String, List<MealPlanOption>> planOptions;
  final List<DailyMealLog> dailyLogs;
  final List<NutritionWeeklyStat> weeklyAdherence;
  final List<OptionFrequencyStat> optionFrequencies;
  final int? viewingPlanId;
  final String? error;

  const NutritionState({
    this.status = NutritionStatus.initial,
    this.activePlan,
    this.allPlans = const [],
    this.planOptions = const {},
    this.dailyLogs = const [],
    this.weeklyAdherence = const [],
    this.optionFrequencies = const [],
    this.viewingPlanId,
    this.error,
  });

  bool get hasPendingPlan {
    if (activePlan == null) return false;
    return allPlans.any(
        (p) => !p.isActive && p.createdAt.isAfter(activePlan!.createdAt));
  }

  MealPlan? get pendingPlan {
    if (activePlan == null) return null;
    return allPlans
        .where(
            (p) => !p.isActive && p.createdAt.isAfter(activePlan!.createdAt))
        .firstOrNull;
  }

  MealPlan? get viewingPlan => viewingPlanId == null
      ? activePlan
      : allPlans.firstWhereOrNull((p) => p.id == viewingPlanId);

  bool isMealLogged(String mealType) =>
      dailyLogs.any((log) => log.mealType == mealType);

  DailyMealLog? getLogForMeal(String mealType) =>
      dailyLogs.where((log) => log.mealType == mealType).firstOrNull;

  static const _unset = Object();

  NutritionState copyWith({
    NutritionStatus? status,
    MealPlan? activePlan,
    List<MealPlan>? allPlans,
    Map<String, List<MealPlanOption>>? planOptions,
    List<DailyMealLog>? dailyLogs,
    List<NutritionWeeklyStat>? weeklyAdherence,
    List<OptionFrequencyStat>? optionFrequencies,
    Object? viewingPlanId = _unset,
    String? error,
  }) =>
      NutritionState(
        status: status ?? this.status,
        activePlan: activePlan ?? this.activePlan,
        allPlans: allPlans ?? this.allPlans,
        planOptions: planOptions ?? this.planOptions,
        dailyLogs: dailyLogs ?? this.dailyLogs,
        weeklyAdherence: weeklyAdherence ?? this.weeklyAdherence,
        optionFrequencies: optionFrequencies ?? this.optionFrequencies,
        viewingPlanId:
            viewingPlanId == _unset ? this.viewingPlanId : viewingPlanId as int?,
        error: error,
      );

  @override
  List<Object?> get props => [
        status,
        activePlan,
        allPlans,
        planOptions,
        dailyLogs,
        weeklyAdherence,
        optionFrequencies,
        viewingPlanId,
        error,
      ];
}
```

- [ ] **Step 3: Reemplazar `NutritionBloc` completo**

Reemplazar el contenido de `lib/features/nutrition/presentation/bloc/nutrition_bloc.dart`:

```dart
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:kiolog/core/database/app_database.dart';
import 'package:kiolog/features/nutrition/domain/models/option_frequency_stat.dart';
import '../../domain/repositories/nutrition_repository.dart';
import 'nutrition_event.dart';
import 'nutrition_state.dart';

class NutritionBloc extends Bloc<NutritionEvent, NutritionState> {
  final NutritionRepository _repository;

  NutritionBloc(this._repository) : super(const NutritionState()) {
    on<NutritionLoaded>(_onLoaded);
    on<NutritionPlanLoaded>(_onPlanLoaded);
    on<NutritionMealLogged>(_onMealLogged);
    on<NutritionOffPlanMealLogged>(_onOffPlanMealLogged);
    on<NutritionMealLogRemoved>(_onMealLogRemoved);
    on<NutritionPlanActivated>(_onPlanActivated);
    on<NutritionPlanCreated>(_onPlanCreated);
    on<NutritionOptionAdded>(_onOptionAdded);
    on<NutritionProgressPlanSelected>(_onProgressPlanSelected);
  }

  Future<void> _onLoaded(
      NutritionLoaded event, Emitter<NutritionState> emit) async {
    emit(state.copyWith(status: NutritionStatus.loading));
    try {
      final plan = await _repository.getActivePlan();
      final logs = await _repository.getDailyLogs(event.date);
      final plans = await _repository.getAllPlans();
      final options = <String, List<MealPlanOption>>{};
      List<OptionFrequencyStat> frequencies = [];

      if (plan != null) {
        final allOpts = await _repository.getAllPlanOptions(plan.id);
        for (final opt in allOpts) {
          options.putIfAbsent(opt.mealType, () => []).add(opt);
        }
        frequencies = await _repository.getOptionFrequency(plan.id);
      }

      final adherence = await _repository.getWeeklyAdherence(weeksBack: 8);

      emit(state.copyWith(
        status: NutritionStatus.success,
        activePlan: plan,
        allPlans: plans,
        dailyLogs: logs,
        planOptions: options,
        weeklyAdherence: adherence,
        optionFrequencies: frequencies,
        error: null,
      ));
    } catch (e) {
      emit(state.copyWith(status: NutritionStatus.failure, error: e.toString()));
    }
  }

  Future<void> _onPlanLoaded(
    NutritionPlanLoaded event,
    Emitter<NutritionState> emit,
  ) async {
    try {
      final plans = await _repository.getAllPlans();
      final active = await _repository.getActivePlan();
      emit(state.copyWith(allPlans: plans, activePlan: active));
    } catch (e) {
      emit(state.copyWith(status: NutritionStatus.failure, error: e.toString()));
    }
  }

  Future<void> _onMealLogged(
    NutritionMealLogged event,
    Emitter<NutritionState> emit,
  ) async {
    if (state.status != NutritionStatus.success) return;
    try {
      await _repository.logMeal(
        date: event.date,
        mealType: event.mealType,
        planOptionId: event.planOptionId,
      );
      final logs = await _repository.getDailyLogs(event.date);
      final adherence = await _repository.getWeeklyAdherence(weeksBack: 8);
      final frequencies = state.activePlan != null
          ? await _repository.getOptionFrequency(state.activePlan!.id)
          : <OptionFrequencyStat>[];
      emit(state.copyWith(
          dailyLogs: logs,
          weeklyAdherence: adherence,
          optionFrequencies: frequencies));
    } catch (e) {
      emit(state.copyWith(status: NutritionStatus.failure, error: e.toString()));
    }
  }

  Future<void> _onMealLogRemoved(
    NutritionMealLogRemoved event,
    Emitter<NutritionState> emit,
  ) async {
    if (state.status != NutritionStatus.success) return;
    try {
      await _repository.removeMealLog(
        date: event.date,
        mealType: event.mealType,
      );
      final logs = await _repository.getDailyLogs(event.date);
      final adherence = await _repository.getWeeklyAdherence(weeksBack: 8);
      final frequencies = state.activePlan != null
          ? await _repository.getOptionFrequency(state.activePlan!.id)
          : <OptionFrequencyStat>[];
      emit(state.copyWith(
          dailyLogs: logs,
          weeklyAdherence: adherence,
          optionFrequencies: frequencies));
    } catch (e) {
      emit(state.copyWith(status: NutritionStatus.failure, error: e.toString()));
    }
  }

  Future<void> _onOffPlanMealLogged(
    NutritionOffPlanMealLogged event,
    Emitter<NutritionState> emit,
  ) async {
    if (state.status != NutritionStatus.success) return;
    try {
      await _repository.logOffPlanMeal(
        date: event.date,
        mealType: event.mealType,
        description: event.description,
      );
      final logs = await _repository.getDailyLogs(event.date);
      final adherence = await _repository.getWeeklyAdherence(weeksBack: 8);
      emit(state.copyWith(dailyLogs: logs, weeklyAdherence: adherence));
    } catch (e) {
      emit(state.copyWith(status: NutritionStatus.failure, error: e.toString()));
    }
  }

  Future<void> _onPlanActivated(
    NutritionPlanActivated event,
    Emitter<NutritionState> emit,
  ) async {
    try {
      await _repository.activatePlan(event.planId);
      final plan = await _repository.getActivePlan();
      final plans = await _repository.getAllPlans();
      final options = <String, List<MealPlanOption>>{};
      List<OptionFrequencyStat> frequencies = [];
      if (plan != null) {
        final allOpts = await _repository.getAllPlanOptions(plan.id);
        for (final opt in allOpts) {
          options.putIfAbsent(opt.mealType, () => []).add(opt);
        }
        frequencies = await _repository.getOptionFrequency(plan.id);
      }
      emit(state.copyWith(
        activePlan: plan,
        allPlans: plans,
        planOptions: options,
        optionFrequencies: frequencies,
      ));
    } catch (e) {
      emit(state.copyWith(status: NutritionStatus.failure, error: e.toString()));
    }
  }

  Future<void> _onPlanCreated(
    NutritionPlanCreated event,
    Emitter<NutritionState> emit,
  ) async {
    try {
      await _repository.createPlan(event.name, dailyMealGoal: event.dailyMealGoal);
      final plans = await _repository.getAllPlans();
      emit(state.copyWith(allPlans: plans));
    } catch (e) {
      emit(state.copyWith(status: NutritionStatus.failure, error: e.toString()));
    }
  }

  Future<void> _onOptionAdded(
    NutritionOptionAdded event,
    Emitter<NutritionState> emit,
  ) async {
    try {
      await _repository.addPlanOption(
        planId: event.planId,
        mealType: event.mealType,
        optionNumber: event.optionNumber,
        description: event.description,
      );
      final opts =
          await _repository.getPlanOptions(event.planId, event.mealType);
      final updated = Map<String, List<MealPlanOption>>.from(state.planOptions);
      updated[event.mealType] = opts;
      emit(state.copyWith(planOptions: updated));
    } catch (e) {
      emit(state.copyWith(status: NutritionStatus.failure, error: e.toString()));
    }
  }

  Future<void> _onProgressPlanSelected(
    NutritionProgressPlanSelected event,
    Emitter<NutritionState> emit,
  ) async {
    emit(state.copyWith(status: NutritionStatus.loading));
    try {
      final frequencies = await _repository.getOptionFrequency(event.planId);
      final isActive = state.activePlan?.id == event.planId;
      final adherence = isActive
          ? await _repository.getWeeklyAdherence(weeksBack: 8)
          : state.weeklyAdherence;
      emit(state.copyWith(
        status: NutritionStatus.success,
        viewingPlanId: event.planId,
        optionFrequencies: frequencies,
        weeklyAdherence: adherence,
        error: null,
      ));
    } catch (e) {
      emit(state.copyWith(status: NutritionStatus.failure, error: e.toString()));
    }
  }
}
```

- [ ] **Step 4: Actualizar los tests del bloc**

Reemplazar el contenido de `test/features/nutrition/presentation/nutrition_bloc_test.dart`:

```dart
import 'package:bloc_test/bloc_test.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kiolog/core/database/app_database.dart';
import 'package:kiolog/features/nutrition/domain/models/nutrition_weekly_stat.dart';
import 'package:kiolog/features/nutrition/domain/models/option_frequency_stat.dart';
import 'package:kiolog/features/nutrition/domain/repositories/nutrition_repository.dart';
import 'package:kiolog/features/nutrition/presentation/bloc/nutrition_bloc.dart';
import 'package:kiolog/features/nutrition/presentation/bloc/nutrition_event.dart';
import 'package:kiolog/features/nutrition/presentation/bloc/nutrition_state.dart';
import 'package:mocktail/mocktail.dart';

class MockNutritionRepository extends Mock implements NutritionRepository {}

void main() {
  late MockNutritionRepository repository;

  setUp(() {
    repository = MockNutritionRepository();
  });

  group('NutritionBloc', () {
    final plan = MealPlan(
      id: 1,
      name: 'Plan',
      createdAt: DateTime(2026, 6, 1),
      isActive: true,
      dailyMealGoal: 4,
      periodStart: DateTime(2026, 6, 1),
      periodEnd: null,
    );
    final options = [
      MealPlanOption(
          id: 1,
          planId: 1,
          mealType: 'breakfast',
          optionNumber: 1,
          description: 'Avena'),
    ];
    final adherence = [
      NutritionWeeklyStat(
        weekStart: DateTime.utc(2026, 6, 2),
        mealsLogged: 3,
        mealsExpected: 4,
        offPlanMeals: 1,
      ),
    ];
    const frequencies = [
      OptionFrequencyStat(
        planOptionId: 1,
        mealType: 'breakfast',
        optionNumber: 1,
        description: 'Avena',
        count: 5,
      ),
    ];

    blocTest<NutritionBloc, NutritionState>(
      'NutritionLoaded emits [loading, success] con allPlans y optionFrequencies',
      build: () {
        when(() => repository.getActivePlan()).thenAnswer((_) async => plan);
        when(() => repository.getDailyLogs(any())).thenAnswer((_) async => []);
        when(() => repository.getAllPlans()).thenAnswer((_) async => [plan]);
        when(() => repository.getAllPlanOptions(any()))
            .thenAnswer((_) async => options);
        when(() => repository.getWeeklyAdherence(weeksBack: 8))
            .thenAnswer((_) async => adherence);
        when(() => repository.getOptionFrequency(any()))
            .thenAnswer((_) async => frequencies);
        return NutritionBloc(repository);
      },
      act: (bloc) => bloc.add(NutritionLoaded(date: DateTime(2026, 6, 8))),
      expect: () => [
        const NutritionState(status: NutritionStatus.loading),
        NutritionState(
          status: NutritionStatus.success,
          activePlan: plan,
          allPlans: [plan],
          planOptions: {'breakfast': options},
          weeklyAdherence: adherence,
          optionFrequencies: frequencies,
        ),
      ],
    );

    blocTest<NutritionBloc, NutritionState>(
      'NutritionLoaded sin plan activo emite success con listas vacías',
      build: () {
        when(() => repository.getActivePlan()).thenAnswer((_) async => null);
        when(() => repository.getDailyLogs(any())).thenAnswer((_) async => []);
        when(() => repository.getAllPlans()).thenAnswer((_) async => []);
        when(() => repository.getWeeklyAdherence(weeksBack: 8))
            .thenAnswer((_) async => []);
        return NutritionBloc(repository);
      },
      act: (bloc) => bloc.add(NutritionLoaded(date: DateTime(2026, 6, 8))),
      expect: () => [
        const NutritionState(status: NutritionStatus.loading),
        const NutritionState(
          status: NutritionStatus.success,
          weeklyAdherence: [],
          allPlans: [],
        ),
      ],
    );

    blocTest<NutritionBloc, NutritionState>(
      'NutritionLoaded emite failure en error de repositorio',
      build: () {
        when(() => repository.getActivePlan())
            .thenThrow(Exception('DB error'));
        return NutritionBloc(repository);
      },
      act: (bloc) => bloc.add(NutritionLoaded(date: DateTime(2026, 6, 8))),
      expect: () => [
        const NutritionState(status: NutritionStatus.loading),
        isA<NutritionState>().having(
          (s) => s.status,
          'status',
          NutritionStatus.failure,
        ),
      ],
    );

    blocTest<NutritionBloc, NutritionState>(
      'NutritionMealLogged actualiza dailyLogs y optionFrequencies',
      build: () {
        when(() => repository.logMeal(
              date: any(named: 'date'),
              mealType: any(named: 'mealType'),
              planOptionId: any(named: 'planOptionId'),
            )).thenAnswer((_) async {});
        when(() => repository.getDailyLogs(any())).thenAnswer((_) async => [
              DailyMealLog(
                  id: 1,
                  date: DateTime(2026, 6, 8),
                  mealType: 'breakfast',
                  planOptionId: 1,
                  freeDescription: null,
                  photoPath: null),
            ]);
        when(() => repository.getWeeklyAdherence(weeksBack: 8))
            .thenAnswer((_) async => []);
        when(() => repository.getOptionFrequency(any()))
            .thenAnswer((_) async => frequencies);
        return NutritionBloc(repository)
          ..emit(NutritionState(
              status: NutritionStatus.success, activePlan: plan));
      },
      act: (bloc) => bloc.add(NutritionMealLogged(
        date: DateTime(2026, 6, 8),
        mealType: 'breakfast',
        planOptionId: 1,
      )),
      expect: () => [
        NutritionState(
          status: NutritionStatus.success,
          activePlan: plan,
          dailyLogs: [
            DailyMealLog(
                id: 1,
                date: DateTime(2026, 6, 8),
                mealType: 'breakfast',
                planOptionId: 1,
                freeDescription: null,
                photoPath: null),
          ],
          weeklyAdherence: [],
          optionFrequencies: frequencies,
        ),
      ],
    );

    blocTest<NutritionBloc, NutritionState>(
      'NutritionProgressPlanSelected carga frecuencias del plan seleccionado',
      build: () {
        when(() => repository.getOptionFrequency(2))
            .thenAnswer((_) async => frequencies);
        return NutritionBloc(repository)
          ..emit(NutritionState(
            status: NutritionStatus.success,
            activePlan: plan,
            allPlans: [
              plan,
              MealPlan(
                id: 2,
                name: 'Plan Anterior',
                createdAt: DateTime(2026, 1, 1),
                isActive: false,
                dailyMealGoal: 3,
                periodStart: DateTime(2026, 1, 1),
                periodEnd: DateTime(2026, 5, 31),
              ),
            ],
          ));
      },
      act: (bloc) =>
          bloc.add(const NutritionProgressPlanSelected(planId: 2)),
      expect: () => [
        isA<NutritionState>()
            .having((s) => s.status, 'status', NutritionStatus.loading),
        isA<NutritionState>()
            .having((s) => s.status, 'status', NutritionStatus.success)
            .having((s) => s.viewingPlanId, 'viewingPlanId', 2)
            .having(
                (s) => s.optionFrequencies, 'optionFrequencies', frequencies),
      ],
    );

    blocTest<NutritionBloc, NutritionState>(
      'NutritionPlanActivated recarga planOptions del nuevo plan activo',
      build: () {
        when(() => repository.activatePlan(any())).thenAnswer((_) async {});
        when(() => repository.getActivePlan()).thenAnswer((_) async => plan);
        when(() => repository.getAllPlans()).thenAnswer((_) async => [plan]);
        when(() => repository.getAllPlanOptions(any()))
            .thenAnswer((_) async => options);
        when(() => repository.getOptionFrequency(any()))
            .thenAnswer((_) async => frequencies);
        return NutritionBloc(repository);
      },
      act: (bloc) => bloc.add(const NutritionPlanActivated(planId: 1)),
      expect: () => [
        NutritionState(
          activePlan: plan,
          allPlans: [plan],
          planOptions: {'breakfast': options},
          optionFrequencies: frequencies,
        ),
      ],
    );

    blocTest<NutritionBloc, NutritionState>(
      'NutritionPlanCreated actualiza allPlans',
      build: () {
        when(() => repository.createPlan(any(),
                dailyMealGoal: any(named: 'dailyMealGoal')))
            .thenAnswer((_) async => 1);
        when(() => repository.getAllPlans()).thenAnswer((_) async => [plan]);
        return NutritionBloc(repository);
      },
      act: (bloc) => bloc.add(
          const NutritionPlanCreated(name: 'Plan Junio', dailyMealGoal: 5)),
      expect: () => [
        NutritionState(allPlans: [plan]),
      ],
    );

    blocTest<NutritionBloc, NutritionState>(
      'NutritionOffPlanMealLogged registra comida fuera de plan',
      build: () {
        when(() => repository.logOffPlanMeal(
              date: any(named: 'date'),
              mealType: any(named: 'mealType'),
              description: null,
            )).thenAnswer((_) async {});
        when(() => repository.getDailyLogs(any())).thenAnswer((_) async => [
              DailyMealLog(
                id: 2,
                date: DateTime(2026, 6, 8),
                mealType: 'Almuerzo',
                planOptionId: null,
                freeDescription: null,
                photoPath: null,
              ),
            ]);
        when(() => repository.getWeeklyAdherence(weeksBack: 8))
            .thenAnswer((_) async => []);
        return NutritionBloc(repository)
          ..emit(const NutritionState(status: NutritionStatus.success));
      },
      act: (bloc) => bloc.add(NutritionOffPlanMealLogged(
        date: DateTime(2026, 6, 8),
        mealType: 'Almuerzo',
        description: null,
      )),
      expect: () => [
        NutritionState(
          status: NutritionStatus.success,
          dailyLogs: [
            DailyMealLog(
              id: 2,
              date: DateTime(2026, 6, 8),
              mealType: 'Almuerzo',
              planOptionId: null,
              freeDescription: null,
              photoPath: null,
            ),
          ],
          weeklyAdherence: [],
        ),
      ],
    );
  });
}
```

- [ ] **Step 5: Correr todos los tests del bloc**

```bash
flutter test test/features/nutrition/presentation/nutrition_bloc_test.dart 2>&1
```

Expected: todos los tests pasan.

- [ ] **Step 6: Correr analyze**

```bash
flutter analyze lib/features/nutrition/presentation/bloc/ 2>&1
```

Expected: no issues.

- [ ] **Step 7: Commit**

```bash
git add lib/features/nutrition/presentation/bloc/ \
        test/features/nutrition/presentation/nutrition_bloc_test.dart
git commit -m "feat(nutrition): add viewingPlanId + optionFrequencies to BLoC"
```

---

## Task 4: Refactorizar `NutritionProgressPage`

**Files:**
- Modify: `lib/features/nutrition/presentation/pages/nutrition_progress_page.dart`
- Test: `test/features/nutrition/presentation/nutrition_progress_page_test.dart`

- [ ] **Step 1: Escribir tests nuevos que fallarán**

Agregar al final del grupo existente en `test/features/nutrition/presentation/nutrition_progress_page_test.dart`:

```dart
    testWidgets('muestra chip con nombre del plan activo',
        (tester) async {
      final plan = MealPlan(
        id: 1,
        name: 'Plan Verano',
        createdAt: DateTime(2026, 6, 1),
        isActive: true,
        dailyMealGoal: 3,
        periodStart: DateTime(2026, 6, 1),
        periodEnd: null,
      );
      whenListen(
        bloc,
        const Stream<NutritionState>.empty(),
        initialState: NutritionState(
          status: NutritionStatus.success,
          activePlan: plan,
          allPlans: [plan],
        ),
      );

      await tester.pumpWidget(_wrap(bloc));
      await tester.pump();

      expect(find.text('Plan Verano'), findsOneWidget);
    });

    testWidgets('tab Frecuencia muestra opciones con conteo',
        (tester) async {
      final plan = MealPlan(
        id: 1,
        name: 'Plan',
        createdAt: DateTime(2026, 6, 1),
        isActive: true,
        dailyMealGoal: 2,
        periodStart: DateTime(2026, 6, 1),
        periodEnd: null,
      );
      const freqs = [
        OptionFrequencyStat(
          planOptionId: 1,
          mealType: 'Desayuno',
          optionNumber: 1,
          description: 'Avena con frutas',
          count: 18,
        ),
        OptionFrequencyStat(
          planOptionId: 2,
          mealType: 'Desayuno',
          optionNumber: 2,
          description: 'Huevos revueltos',
          count: 7,
        ),
      ];
      whenListen(
        bloc,
        const Stream<NutritionState>.empty(),
        initialState: NutritionState(
          status: NutritionStatus.success,
          activePlan: plan,
          allPlans: [plan],
          optionFrequencies: freqs,
        ),
      );

      await tester.pumpWidget(_wrap(bloc));
      await tester.pump();

      // Cambiar al tab Frecuencia
      await tester.tap(find.text('Frecuencia'));
      await tester.pumpAndSettle();

      expect(find.text('Avena con frutas'), findsOneWidget);
      expect(find.text('18×'), findsOneWidget);
      expect(find.text('Huevos revueltos'), findsOneWidget);
      expect(find.text('7×'), findsOneWidget);
    });

    testWidgets(
        'ver plan anterior oculta tabs y muestra solo frecuencia',
        (tester) async {
      final active = MealPlan(
        id: 1,
        name: 'Plan Actual',
        createdAt: DateTime(2026, 6, 1),
        isActive: true,
        dailyMealGoal: 2,
        periodStart: DateTime(2026, 6, 1),
        periodEnd: null,
      );
      final prev = MealPlan(
        id: 2,
        name: 'Plan Anterior',
        createdAt: DateTime(2026, 1, 1),
        isActive: false,
        dailyMealGoal: 3,
        periodStart: DateTime(2026, 1, 1),
        periodEnd: DateTime(2026, 5, 31),
      );
      const prevFreqs = [
        OptionFrequencyStat(
          planOptionId: 10,
          mealType: 'Almuerzo',
          optionNumber: 1,
          description: 'Pollo al horno',
          count: 12,
        ),
      ];
      whenListen(
        bloc,
        const Stream<NutritionState>.empty(),
        initialState: NutritionState(
          status: NutritionStatus.success,
          activePlan: active,
          allPlans: [active, prev],
          viewingPlanId: 2, // viendo plan anterior
          optionFrequencies: prevFreqs,
        ),
      );

      await tester.pumpWidget(_wrap(bloc));
      await tester.pump();

      // No debe haber tabs cuando se ve un plan anterior
      expect(find.text('Adherencia'), findsNothing);
      expect(find.text('Frecuencia'), findsNothing);
      // Pero sí debe mostrar las frecuencias del plan anterior
      expect(find.text('Pollo al horno'), findsOneWidget);
      expect(find.text('12×'), findsOneWidget);
    });
```

También agregar los imports que faltan al principio del test file:

```dart
import 'package:kiolog/core/database/app_database.dart';
import 'package:kiolog/features/nutrition/domain/models/option_frequency_stat.dart';
```

- [ ] **Step 2: Correr los nuevos tests para verificar que fallan**

```bash
flutter test test/features/nutrition/presentation/nutrition_progress_page_test.dart --name "chip|Frecuencia|plan anterior" 2>&1
```

Expected: FAIL.

- [ ] **Step 3: Reemplazar `nutrition_progress_page.dart` completo**

```dart
import 'dart:math' show sqrt;
import 'package:collection/collection.dart';
import 'package:flutter/foundation.dart' show listEquals;
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:kiolog/core/database/app_database.dart';
import 'package:kiolog/features/nutrition/domain/models/option_frequency_stat.dart';
import 'package:kiolog/features/nutrition/presentation/pages/nutrition_config_page.dart';
import '../bloc/nutrition_bloc.dart';
import '../bloc/nutrition_event.dart';
import '../bloc/nutrition_state.dart';
import 'package:kiolog/shared/widgets/stat_chip.dart';

enum _Periodo { semana, mes }

class NutritionProgressPage extends StatelessWidget {
  const NutritionProgressPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Progreso Nutrición')),
      body: BlocBuilder<NutritionBloc, NutritionState>(
        builder: (context, state) {
          final isViewingActive = state.viewingPlanId == null;
          return Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              _PlanChip(state: state),
              if (isViewingActive)
                Expanded(child: _ActivePlanView(state: state))
              else
                Expanded(
                  child: _FrecuenciaTab(
                    frequencies: state.optionFrequencies,
                  ),
                ),
            ],
          );
        },
      ),
    );
  }
}

// ── Plan chip + bottom sheet ──────────────────────────────────────────────────

class _PlanChip extends StatelessWidget {
  final NutritionState state;
  const _PlanChip({required this.state});

  @override
  Widget build(BuildContext context) {
    final plan = state.viewingPlan ?? state.activePlan;
    final cs = Theme.of(context).colorScheme;
    return InkWell(
      onTap: () => _showPlanSheet(context),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
        color: cs.surface,
        child: Row(
          children: [
            Container(
              padding:
                  const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              decoration: BoxDecoration(
                color: cs.primaryContainer,
                borderRadius: BorderRadius.circular(20),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    plan?.name ?? 'Sin plan',
                    style: TextStyle(
                      fontWeight: FontWeight.w600,
                      color: cs.onPrimaryContainer,
                      fontSize: 13,
                    ),
                  ),
                  const SizedBox(width: 4),
                  Icon(Icons.expand_more,
                      size: 16, color: cs.onPrimaryContainer),
                ],
              ),
            ),
            const SizedBox(width: 8),
            if (plan != null)
              Text(
                plan.isActive ? 'activo' : _periodLabel(plan),
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: cs.onSurfaceVariant,
                    ),
              ),
          ],
        ),
      ),
    );
  }

  String _periodLabel(MealPlan plan) {
    final e = plan.periodEnd;
    if (e == null) return '';
    return 'hasta ${e.day}/${e.month}/${e.year}';
  }

  void _showPlanSheet(BuildContext context) {
    final bloc = context.read<NutritionBloc>();
    showModalBottomSheet<void>(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (_) => BlocProvider.value(
        value: bloc,
        child: const _PlanSelectorSheet(),
      ),
    );
  }
}

class _PlanSelectorSheet extends StatelessWidget {
  const _PlanSelectorSheet();

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<NutritionBloc, NutritionState>(
      builder: (context, state) {
        final cs = Theme.of(context).colorScheme;
        return Padding(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Center(
                child: Container(
                  width: 32,
                  height: 4,
                  margin: const EdgeInsets.only(bottom: 16),
                  decoration: BoxDecoration(
                    color: cs.outlineVariant,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              Text('Planes alimenticios',
                  style: Theme.of(context).textTheme.titleMedium,
                  textAlign: TextAlign.center),
              const SizedBox(height: 12),
              // Plan activo
              if (state.activePlan != null)
                _PlanTile(
                  plan: state.activePlan!,
                  isActive: true,
                  isViewing:
                      state.viewingPlanId == null ||
                      state.viewingPlanId == state.activePlan!.id,
                  onTap: () {
                    context.read<NutritionBloc>().add(
                          NutritionProgressPlanSelected(
                              planId: state.activePlan!.id),
                        );
                    Navigator.pop(context);
                  },
                ),
              // Planes anteriores
              ...state.allPlans
                  .where((p) => !p.isActive)
                  .map((p) => _PlanTile(
                        plan: p,
                        isActive: false,
                        isViewing: state.viewingPlanId == p.id,
                        onTap: () {
                          context.read<NutritionBloc>().add(
                                NutritionProgressPlanSelected(planId: p.id),
                              );
                          Navigator.pop(context);
                        },
                      )),
              const SizedBox(height: 8),
              // Nueva consulta
              InkWell(
                onTap: () {
                  final bloc = context.read<NutritionBloc>();
                  Navigator.pop(context);
                  Navigator.of(context).push(
                    MaterialPageRoute<void>(
                      builder: (_) => NutritionConfigPage(
                        onComplete: () => bloc
                            .add(NutritionLoaded(date: DateTime.now())),
                      ),
                    ),
                  );
                },
                borderRadius: BorderRadius.circular(10),
                child: Container(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 16, vertical: 12),
                  decoration: BoxDecoration(
                    border: Border.all(
                        color: cs.primary,
                        width: 1.5,
                        style: BorderStyle.solid),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Row(
                    children: [
                      Icon(Icons.add_circle_outline, color: cs.primary),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Nueva consulta',
                              style: TextStyle(
                                fontWeight: FontWeight.w600,
                                color: cs.primary,
                              ),
                            ),
                            Text(
                              'Crear el plan de la nueva sesión',
                              style: Theme.of(context)
                                  .textTheme
                                  .bodySmall
                                  ?.copyWith(color: cs.onSurfaceVariant),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}

class _PlanTile extends StatelessWidget {
  final MealPlan plan;
  final bool isActive;
  final bool isViewing;
  final VoidCallback onTap;

  const _PlanTile({
    required this.plan,
    required this.isActive,
    required this.isViewing,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final start = plan.periodStart;
    final end = plan.periodEnd;
    final dateLabel = start == null
        ? ''
        : end == null
            ? 'desde ${start.day}/${start.month}/${start.year}'
            : '${start.day}/${start.month}/${start.year} – '
                '${end.day}/${end.month}/${end.year}';

    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(10),
        child: Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: isViewing
                ? cs.primaryContainer.withValues(alpha: 0.3)
                : cs.surfaceContainerHighest,
            border: isViewing
                ? Border.all(color: cs.primary, width: 1.5)
                : null,
            borderRadius: BorderRadius.circular(10),
          ),
          child: Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(plan.name,
                        style: const TextStyle(fontWeight: FontWeight.w600)),
                    if (dateLabel.isNotEmpty)
                      Text(
                        dateLabel,
                        style: Theme.of(context).textTheme.bodySmall?.copyWith(
                              color: cs.onSurfaceVariant,
                            ),
                      ),
                  ],
                ),
              ),
              if (isActive)
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                  decoration: BoxDecoration(
                    color: cs.primary,
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Text(
                    'ACTIVO',
                    style: TextStyle(
                        fontSize: 10,
                        color: cs.onPrimary,
                        fontWeight: FontWeight.w700),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

// ── Vista plan activo: tabs Adherencia + Frecuencia ───────────────────────────

class _ActivePlanView extends StatefulWidget {
  final NutritionState state;
  const _ActivePlanView({required this.state});

  @override
  State<_ActivePlanView> createState() => _ActivePlanViewState();
}

class _ActivePlanViewState extends State<_ActivePlanView>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  _Periodo _periodo = _Periodo.semana;
  int _weekOffset = 0;
  int _monthOffset = 0;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        TabBar(
          controller: _tabController,
          tabs: const [
            Tab(text: 'Adherencia'),
            Tab(text: 'Frecuencia'),
          ],
        ),
        Expanded(
          child: TabBarView(
            controller: _tabController,
            children: [
              _buildAdherenciaContent(),
              _FrecuenciaTab(
                  frequencies: widget.state.optionFrequencies),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildAdherenciaContent() {
    final stats = widget.state.weeklyAdherence;
    return SafeArea(
      child: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          _PeriodToggle(
            selected: _periodo,
            onChanged: (p) => setState(() => _periodo = p),
          ),
          const SizedBox(height: 16),
          if (_periodo == _Periodo.semana)
            _buildWeekNavigator(stats)
          else
            _buildMonthNavigator(stats),
          const SizedBox(height: 16),
          if (_periodo == _Periodo.semana)
            _buildSemanaChips(widget.state)
          else
            _buildMesChips(widget.state),
          const SizedBox(height: 20),
          if (_periodo == _Periodo.semana)
            _buildWeekBarChart(stats)
          else
            _buildMonthBarChart(stats),
        ],
      ),
    );
  }

  // ── Los métodos de adherencia (sin cambios respecto al código anterior) ──

  DateTime _currentWeekMonday() {
    final now = DateTime.now().toUtc();
    final today = DateTime.utc(now.year, now.month, now.day);
    return today.subtract(Duration(days: today.weekday - 1));
  }

  DateTime _weekMondayAt(int offset) =>
      _currentWeekMonday().add(Duration(days: 7 * offset));

  DateTime _monthStartAt(int offset) {
    final now = DateTime.now().toUtc();
    return DateTime.utc(now.year, now.month + offset, 1);
  }

  NutritionWeeklyStat? _statAt(
      List<NutritionWeeklyStat> stats, int weekOffset) {
    final idx = stats.length - 1 + weekOffset;
    if (idx < 0 || idx >= stats.length) return null;
    return stats[idx];
  }

  List<NutritionWeeklyStat> _weeksInMonth(
      List<NutritionWeeklyStat> stats, int monthOffset) {
    final ms = _monthStartAt(monthOffset);
    return stats
        .where((s) =>
            s.weekStart.month == ms.month && s.weekStart.year == ms.year)
        .toList();
  }

  Widget _buildSemanaChips(NutritionState state) {
    final cs = Theme.of(context).colorScheme;
    final stat = _statAt(state.weeklyAdherence, _weekOffset);
    final pct = stat == null || stat.mealsExpected == 0
        ? null
        : (stat.adherencePct * 100).round();
    final logged = stat?.mealsLogged ?? 0;
    final offPlan = stat?.offPlanMeals ?? 0;
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
      children: [
        StatChip(value: pct == null ? '—' : '$pct%', label: 'Adherencia'),
        StatChip(value: '$logged', label: 'En plan'),
        StatChip(value: '$offPlan', label: 'Fuera plan', color: cs.error),
      ],
    );
  }

  Widget _buildMesChips(NutritionState state) {
    final cs = Theme.of(context).colorScheme;
    final weeks = _weeksInMonth(state.weeklyAdherence, _monthOffset);
    final totalLogged = weeks.fold(0, (s, w) => s + w.mealsLogged);
    final totalExpected = weeks.fold(0, (s, w) => s + w.mealsExpected);
    final totalOff = weeks.fold(0, (s, w) => s + w.offPlanMeals);
    final pct = totalExpected == 0
        ? null
        : (totalLogged / totalExpected * 100).round();
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
      children: [
        StatChip(value: pct == null ? '—' : '$pct%', label: 'Adherencia'),
        StatChip(value: '$totalLogged', label: 'En plan'),
        StatChip(value: '$totalOff', label: 'Fuera plan', color: cs.error),
      ],
    );
  }

  Widget _buildWeekNavigator(List<NutritionWeeklyStat> stats) {
    final monday = _weekMondayAt(_weekOffset);
    final sunday = monday.add(const Duration(days: 6));
    const months = [
      'ene','feb','mar','abr','may','jun',
      'jul','ago','sep','oct','nov','dic'
    ];
    final String label;
    if (monday.month == sunday.month) {
      label =
          '${monday.day} – ${sunday.day} ${months[monday.month - 1]} ${monday.year}';
    } else {
      label =
          '${monday.day} ${months[monday.month - 1]} – ${sunday.day} ${months[sunday.month - 1]} ${monday.year}';
    }
    final sub = _weekOffset == 0
        ? 'semana actual'
        : 'hace ${-_weekOffset} semana${-_weekOffset == 1 ? '' : 's'}';
    final canGoBack =
        stats.isNotEmpty && _weekOffset > -(stats.length - 1);
    return _Navigator(
      label: label,
      subtitle: sub,
      onBack: canGoBack ? () => setState(() => _weekOffset--) : null,
      onForward:
          _weekOffset < 0 ? () => setState(() => _weekOffset++) : null,
    );
  }

  Widget _buildMonthNavigator(List<NutritionWeeklyStat> stats) {
    final ms = _monthStartAt(_monthOffset);
    const months = [
      'Enero','Febrero','Marzo','Abril','Mayo','Junio',
      'Julio','Agosto','Septiembre','Octubre','Noviembre','Diciembre'
    ];
    final label = '${months[ms.month - 1]} ${ms.year}';
    final sub = _monthOffset == 0
        ? 'mes actual'
        : 'hace ${-_monthOffset} mes${-_monthOffset == 1 ? '' : 'es'}';
    final canGoBack = stats.any(
        (s) => s.weekStart.isBefore(DateTime.utc(ms.year, ms.month, 1)));
    return _Navigator(
      label: label,
      subtitle: sub,
      onBack: canGoBack ? () => setState(() => _monthOffset--) : null,
      onForward:
          _monthOffset < 0 ? () => setState(() => _monthOffset++) : null,
    );
  }

  Widget _buildWeekBarChart(List<NutritionWeeklyStat> stats) {
    if (stats.isEmpty) return const SizedBox.shrink();
    return _AdherenceBarChart(
      bars: stats.map((s) => (s.mealsLogged, s.mealsExpected)).toList(),
      barColor: Theme.of(context).colorScheme.primaryContainer,
      lastBarIsPartial: true,
    );
  }

  Widget _buildMonthBarChart(List<NutritionWeeklyStat> stats) {
    final weeks = _weeksInMonth(stats, _monthOffset);
    if (weeks.isEmpty) return const SizedBox.shrink();
    return _AdherenceBarChart(
      bars: weeks.map((s) => (s.mealsLogged, s.mealsExpected)).toList(),
      barColor: Theme.of(context).colorScheme.primaryContainer,
      lastBarIsPartial: _monthOffset == 0,
    );
  }
}

// ── Tab Frecuencia ────────────────────────────────────────────────────────────

class _FrecuenciaTab extends StatelessWidget {
  final List<OptionFrequencyStat> frequencies;
  const _FrecuenciaTab({required this.frequencies});

  @override
  Widget build(BuildContext context) {
    if (frequencies.isEmpty) {
      return Center(
        child: Text(
          'Sin registros de frecuencia',
          style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                color: Theme.of(context).colorScheme.onSurfaceVariant,
              ),
        ),
      );
    }

    // Agrupar por mealType preservando el orden de aparición
    final grouped = <String, List<OptionFrequencyStat>>{};
    for (final f in frequencies) {
      grouped.putIfAbsent(f.mealType, () => []).add(f);
    }

    return ListView(
      padding: const EdgeInsets.all(16),
      children: grouped.entries.map((entry) {
        final mealType = entry.key;
        final opts = entry.value;
        final maxCount =
            opts.map((o) => o.count).fold(0, (a, b) => a > b ? a : b);
        return Padding(
          padding: const EdgeInsets.only(bottom: 16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                mealType.toUpperCase(),
                style: Theme.of(context).textTheme.labelSmall?.copyWith(
                      color: Theme.of(context)
                          .colorScheme
                          .onSurfaceVariant,
                      fontWeight: FontWeight.w700,
                      letterSpacing: 0.5,
                    ),
              ),
              const SizedBox(height: 8),
              Container(
                decoration: BoxDecoration(
                  color: Theme.of(context).colorScheme.surfaceContainerHighest,
                  borderRadius: BorderRadius.circular(12),
                ),
                padding: const EdgeInsets.all(12),
                child: Column(
                  children: opts.map((opt) {
                    final frac = maxCount == 0
                        ? 0.0
                        : opt.count / maxCount;
                    return Padding(
                      padding: const EdgeInsets.only(bottom: 10),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            mainAxisAlignment:
                                MainAxisAlignment.spaceBetween,
                            children: [
                              Expanded(
                                child: Text(
                                  'Opción ${opt.optionNumber} — ${opt.description}',
                                  style: Theme.of(context)
                                      .textTheme
                                      .bodySmall,
                                ),
                              ),
                              const SizedBox(width: 8),
                              Text(
                                '${opt.count}×',
                                style: const TextStyle(
                                    fontWeight: FontWeight.w700,
                                    fontSize: 13),
                              ),
                            ],
                          ),
                          const SizedBox(height: 4),
                          LinearProgressIndicator(
                            value: frac,
                            minHeight: 6,
                            borderRadius: BorderRadius.circular(3),
                            backgroundColor: Theme.of(context)
                                .colorScheme
                                .surfaceContainerHigh,
                          ),
                        ],
                      ),
                    );
                  }).toList(),
                ),
              ),
            ],
          ),
        );
      }).toList(),
    );
  }
}

// ── Sub-widgets reusables (sin cambios) ──────────────────────────────────────

class _PeriodToggle extends StatelessWidget {
  final _Periodo selected;
  final ValueChanged<_Periodo> onChanged;

  const _PeriodToggle({required this.selected, required this.onChanged});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Container(
      decoration: BoxDecoration(
        color: cs.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(24),
      ),
      padding: const EdgeInsets.all(4),
      child: Row(children: [
        _tab(context, 'Semana', _Periodo.semana),
        _tab(context, 'Mes', _Periodo.mes),
      ]),
    );
  }

  Widget _tab(BuildContext context, String label, _Periodo value) {
    final active = selected == value;
    final cs = Theme.of(context).colorScheme;
    return Expanded(
      child: GestureDetector(
        onTap: () => onChanged(value),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 150),
          padding: const EdgeInsets.symmetric(vertical: 8),
          decoration: BoxDecoration(
            color: active ? cs.primary : Colors.transparent,
            borderRadius: BorderRadius.circular(20),
          ),
          child: Text(
            label,
            textAlign: TextAlign.center,
            style: TextStyle(
              fontWeight: FontWeight.bold,
              color: active ? cs.onPrimary : cs.onSurfaceVariant,
            ),
          ),
        ),
      ),
    );
  }
}

class _Navigator extends StatelessWidget {
  final String label;
  final String subtitle;
  final VoidCallback? onBack;
  final VoidCallback? onForward;

  const _Navigator({
    required this.label,
    required this.subtitle,
    this.onBack,
    this.onForward,
  });

  @override
  Widget build(BuildContext context) {
    return Row(children: [
      IconButton(
          icon: const Icon(Icons.chevron_left), onPressed: onBack),
      Expanded(
        child: Column(children: [
          Text(label,
              style: Theme.of(context).textTheme.titleMedium,
              textAlign: TextAlign.center),
          Text(subtitle,
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color:
                        Theme.of(context).colorScheme.onSurfaceVariant,
                  ),
              textAlign: TextAlign.center),
        ]),
      ),
      IconButton(
          icon: const Icon(Icons.chevron_right), onPressed: onForward),
    ]);
  }
}

class _AdherenceBarChart extends StatelessWidget {
  final List<(int logged, int expected)> bars;
  final Color barColor;
  final bool lastBarIsPartial;

  const _AdherenceBarChart({
    required this.bars,
    required this.barColor,
    required this.lastBarIsPartial,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text('Adherencia al plan',
            style: Theme.of(context).textTheme.labelSmall?.copyWith(
                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                )),
        const SizedBox(height: 8),
        SizedBox(
          height: 100,
          child: CustomPaint(
            painter: _BarChartPainter(
              bars: bars,
              barColor: barColor,
              trackColor:
                  Theme.of(context).colorScheme.surfaceContainerHigh,
              lastBarIsPartial: lastBarIsPartial,
            ),
            size: Size.infinite,
          ),
        ),
        const SizedBox(height: 4),
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              bars.length > 1 ? 'sem −${bars.length - 1}' : '',
              style: Theme.of(context).textTheme.labelSmall?.copyWith(
                    color:
                        Theme.of(context).colorScheme.onSurfaceVariant,
                  ),
            ),
            Text('actual',
                style: Theme.of(context)
                    .textTheme
                    .labelSmall
                    ?.copyWith(color: barColor)),
          ],
        ),
      ]),
    );
  }
}

class _BarChartPainter extends CustomPainter {
  final List<(int logged, int expected)> bars;
  final Color barColor;
  final Color trackColor;
  final bool lastBarIsPartial;

  const _BarChartPainter({
    required this.bars,
    required this.barColor,
    required this.trackColor,
    required this.lastBarIsPartial,
  });

  @override
  bool shouldRepaint(_BarChartPainter old) =>
      old.lastBarIsPartial != lastBarIsPartial ||
      old.barColor != barColor ||
      old.trackColor != trackColor ||
      !listEquals(old.bars, bars);

  @override
  void paint(Canvas canvas, Size size) {
    if (bars.isEmpty) return;
    const gap = 4.0;
    final barW = (size.width - gap * (bars.length - 1)) / bars.length;
    final chartH = size.height;
    final goalPaint = Paint()
      ..color = barColor.withValues(alpha: 0.4)
      ..strokeWidth = 1;
    _drawDashedLine(canvas, Offset.zero, Offset(size.width, 0), goalPaint);
    for (int i = 0; i < bars.length; i++) {
      final (logged, expected) = bars[i];
      final x = i * (barW + gap);
      final pct = expected == 0 ? 0.0 : (logged / expected).clamp(0.0, 1.0);
      final barH = pct * chartH;
      final isPartial = lastBarIsPartial && i == bars.length - 1;
      final isNoData = expected == 0;
      if (isNoData) {
        canvas.drawRRect(
          RRect.fromRectAndCorners(
            Rect.fromLTWH(x, chartH - 4, barW, 4),
            topLeft: const Radius.circular(2),
            topRight: const Radius.circular(2),
          ),
          Paint()..color = trackColor,
        );
        continue;
      }
      final rect = Rect.fromLTWH(x, chartH - barH, barW, barH);
      if (isPartial) {
        canvas.drawRRect(
          RRect.fromRectAndCorners(rect,
              topLeft: const Radius.circular(3),
              topRight: const Radius.circular(3)),
          Paint()..color = barColor.withValues(alpha: 0.25),
        );
        _drawDashedRect(
            canvas,
            rect,
            Paint()
              ..color = barColor.withValues(alpha: 0.8)
              ..strokeWidth = 1
              ..style = PaintingStyle.stroke);
      } else {
        canvas.drawRRect(
          RRect.fromRectAndCorners(rect,
              topLeft: const Radius.circular(3),
              topRight: const Radius.circular(3)),
          Paint()..color = barColor.withValues(alpha: 0.85),
        );
      }
    }
  }

  void _drawDashedLine(
      Canvas canvas, Offset p1, Offset p2, Paint paint) {
    const dashLen = 4.0;
    const gapLen = 4.0;
    final dx = p2.dx - p1.dx;
    final dy = p2.dy - p1.dy;
    final dist = sqrt(dx * dx + dy * dy);
    final steps = (dist / (dashLen + gapLen)).floor();
    if (steps == 0) return;
    final stepX = dx / (steps * 2);
    final stepY = dy / (steps * 2);
    for (int i = 0; i < steps; i++) {
      final start = Offset(p1.dx + i * 2 * stepX, p1.dy + i * 2 * stepY);
      final end = Offset(start.dx + stepX, start.dy + stepY);
      canvas.drawLine(start, end, paint);
    }
  }

  void _drawDashedRect(Canvas canvas, Rect rect, Paint paint) {
    _drawDashedLine(canvas, rect.topLeft, rect.topRight, paint);
    _drawDashedLine(canvas, rect.topRight, rect.bottomRight, paint);
    _drawDashedLine(canvas, rect.bottomRight, rect.bottomLeft, paint);
    _drawDashedLine(canvas, rect.bottomLeft, rect.topLeft, paint);
  }
}
```

- [ ] **Step 4: Actualizar el helper `_state` y los imports en el test**

En `test/features/nutrition/presentation/nutrition_progress_page_test.dart`, reemplazar el helper `_state` para que acepte el nuevo campo (los tests existentes siguen funcionando porque `optionFrequencies` tiene default):

```dart
// Reemplazar la función _state:
NutritionState _state({
  List<NutritionWeeklyStat> weeklyAdherence = const [],
  List<OptionFrequencyStat> optionFrequencies = const [],
  MealPlan? activePlan,
  int? viewingPlanId,
}) =>
    NutritionState(
      status: NutritionStatus.success,
      weeklyAdherence: weeklyAdherence,
      optionFrequencies: optionFrequencies,
      activePlan: activePlan,
      viewingPlanId: viewingPlanId,
    );
```

Y agregar en `setUpAll` el fallback para el nuevo evento:

```dart
setUpAll(() {
  registerFallbackValue(NutritionLoaded(date: DateTime(2026)));
  registerFallbackValue(const NutritionProgressPlanSelected(planId: 0));
});
```

- [ ] **Step 5: Correr todos los tests de progress page**

```bash
flutter test test/features/nutrition/presentation/nutrition_progress_page_test.dart 2>&1
```

Expected: todos los tests pasan (incluidos los nuevos).

- [ ] **Step 6: Correr analyze**

```bash
flutter analyze lib/features/nutrition/presentation/pages/nutrition_progress_page.dart 2>&1
```

Expected: no issues.

- [ ] **Step 7: Commit**

```bash
git add lib/features/nutrition/presentation/pages/nutrition_progress_page.dart \
        test/features/nutrition/presentation/nutrition_progress_page_test.dart
git commit -m "feat(nutrition): refactor NutritionProgressPage with tabs and plan selector"
```

---

## Task 5: `NutritionPage` — banner de plan pendiente + crear plan simplificado

**Files:**
- Modify: `lib/features/nutrition/presentation/pages/nutrition_page.dart`
- Test: `test/features/nutrition/presentation/nutrition_page_test.dart`

- [ ] **Step 1: Escribir tests que fallan**

Agregar al grupo principal en `test/features/nutrition/presentation/nutrition_page_test.dart`:

```dart
    testWidgets('muestra banner cuando hay plan pendiente de activación',
        (tester) async {
      final activePlan = MealPlan(
        id: 1,
        name: 'Plan Actual',
        createdAt: DateTime(2026, 5, 1),
        isActive: true,
        dailyMealGoal: 3,
        periodStart: DateTime(2026, 5, 1),
        periodEnd: null,
      );
      final pendingPlan = MealPlan(
        id: 2,
        name: 'Plan Junio',
        createdAt: DateTime(2026, 6, 1),
        isActive: false,
        dailyMealGoal: 4,
        periodStart: null,
        periodEnd: null,
      );
      whenListen(
        bloc,
        const Stream<NutritionState>.empty(),
        initialState: NutritionState(
          status: NutritionStatus.success,
          activePlan: activePlan,
          allPlans: [activePlan, pendingPlan],
          planOptions: {},
        ),
      );

      await tester.pumpWidget(_wrap(bloc));
      await tester.pump();

      expect(find.text('Plan Junio'), findsOneWidget);
      expect(find.text('Activar'), findsOneWidget);
    });

    testWidgets('no muestra banner cuando no hay plan pendiente',
        (tester) async {
      whenListen(
        bloc,
        const Stream<NutritionState>.empty(),
        initialState: NutritionState(
          status: NutritionStatus.success,
          activePlan: _plan,
          allPlans: [_plan],
          planOptions: {},
        ),
      );

      await tester.pumpWidget(_wrap(bloc));
      await tester.pump();

      expect(find.text('Activar'), findsNothing);
    });
```

- [ ] **Step 2: Correr los tests para verificar que fallan**

```bash
flutter test test/features/nutrition/presentation/nutrition_page_test.dart --name "banner" 2>&1
```

Expected: FAIL.

- [ ] **Step 3: Reemplazar `nutrition_page.dart`**

```dart
import 'package:collection/collection.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:kiolog/core/database/app_database.dart';
import 'package:kiolog/core/domain/app_module.dart';
import 'package:kiolog/core/modules/cubit/modules_cubit.dart';
import 'package:kiolog/core/modules/cubit/modules_state.dart';
import 'package:kiolog/shared/widgets/inactive_module_page.dart';
import 'package:kiolog/shared/widgets/vitality_card.dart';
import '../../../../core/di/injection.dart';
import '../../domain/repositories/nutrition_repository.dart';
import '../bloc/nutrition_bloc.dart';
import '../bloc/nutrition_event.dart';
import '../bloc/nutrition_state.dart';
import 'nutrition_config_page.dart';
import 'nutrition_progress_page.dart';

class NutritionPage extends StatelessWidget {
  const NutritionPage({super.key});

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<ModulesCubit, ModulesState>(
      builder: (context, modulesState) {
        if (!modulesState.isEnabled(AppModule.nutrition)) {
          return const InactiveModulePage(module: AppModule.nutrition);
        }
        return BlocProvider(
          create: (_) => NutritionBloc(getIt<NutritionRepository>())
            ..add(NutritionLoaded(date: DateTime.now())),
          child: const _NutritionView(),
        );
      },
    );
  }
}

class _NutritionView extends StatelessWidget {
  const _NutritionView();

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Nutrición'),
        actions: [
          IconButton(
            icon: const Icon(Icons.bar_chart),
            onPressed: () {
              final bloc = context.read<NutritionBloc>();
              Navigator.of(context).push(
                MaterialPageRoute<void>(
                  builder: (_) => BlocProvider.value(
                    value: bloc,
                    child: const NutritionProgressPage(),
                  ),
                ),
              );
            },
          ),
          IconButton(
            icon: const Icon(Icons.history),
            onPressed: () => _showPlansDialog(context),
          ),
        ],
      ),
      body: BlocBuilder<NutritionBloc, NutritionState>(
        builder: (context, state) {
          if (state.status == NutritionStatus.loading &&
              state.activePlan == null) {
            return const Center(child: CircularProgressIndicator());
          }
          if (state.status == NutritionStatus.failure) {
            return Center(child: Text('Error: ${state.error}'));
          }

          if (state.activePlan == null) {
            return _buildNoPlanView(context);
          }

          return Column(
            children: [
              if (state.hasPendingPlan)
                _PendingPlanBanner(plan: state.pendingPlan!),
              Expanded(
                child: ListView(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
                  children: [
                    Text(
                      state.activePlan!.name,
                      style: Theme.of(context).textTheme.titleLarge,
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'Plan activo',
                      style:
                          Theme.of(context).textTheme.bodyMedium?.copyWith(
                                color: Theme.of(context)
                                    .colorScheme
                                    .onSurfaceVariant,
                              ),
                    ),
                    const SizedBox(height: 16),
                    ...state.planOptions.keys.map(
                      (type) => _MealSection(
                        mealType: type,
                        label: type,
                        options: state.planOptions[type] ?? [],
                        log: state.getLogForMeal(type),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          );
        },
      ),
    );
  }

  Widget _buildNoPlanView(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.restaurant_menu,
                size: 64,
                color: Theme.of(context).colorScheme.onSurfaceVariant),
            const SizedBox(height: 16),
            Text(
              'Sin plan activo',
              style: Theme.of(context).textTheme.headlineSmall,
            ),
            const SizedBox(height: 8),
            const Text(
              'Crea un plan alimenticio para empezar a registrar tus comidas.',
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 24),
            ElevatedButton.icon(
              onPressed: () => _navigateToConfigPage(context),
              icon: const Icon(Icons.add),
              label: const Text('Crear plan'),
            ),
          ],
        ),
      ),
    );
  }

  void _navigateToConfigPage(BuildContext context) {
    final bloc = context.read<NutritionBloc>();
    Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => NutritionConfigPage(
          onComplete: () => bloc.add(NutritionLoaded(date: DateTime.now())),
        ),
      ),
    );
  }

  void _showPlansDialog(BuildContext context) {
    context.read<NutritionBloc>().add(const NutritionPlanLoaded());
    showDialog<void>(
      context: context,
      builder: (dialogContext) => BlocProvider.value(
        value: context.read<NutritionBloc>(),
        child: const _PlansDialog(),
      ),
    );
  }
}

// ── Banner plan pendiente ────────────────────────────────────────────────────

class _PendingPlanBanner extends StatelessWidget {
  final MealPlan plan;
  const _PendingPlanBanner({required this.plan});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Container(
      color: cs.primaryContainer.withValues(alpha: 0.5),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      child: Row(
        children: [
          Icon(Icons.new_releases_outlined, color: cs.primary),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(plan.name,
                    style: Theme.of(context).textTheme.labelLarge),
                Text(
                  'Listo para activar',
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: cs.onSurfaceVariant,
                      ),
                ),
              ],
            ),
          ),
          TextButton(
            onPressed: () => context
                .read<NutritionBloc>()
                .add(NutritionPlanActivated(planId: plan.id)),
            child: const Text('Activar'),
          ),
        ],
      ),
    );
  }
}

// ── Diálogo de planes ────────────────────────────────────────────────────────

class _PlansDialog extends StatelessWidget {
  const _PlansDialog();

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Planes alimenticios'),
      content: SizedBox(
        width: double.maxFinite,
        child: BlocBuilder<NutritionBloc, NutritionState>(
          builder: (context, state) {
            return Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                if (state.allPlans.isEmpty)
                  const Text('No hay planes registrados.')
                else
                  Flexible(
                    child: ListView.builder(
                      shrinkWrap: true,
                      itemCount: state.allPlans.length,
                      itemBuilder: (context, index) {
                        final plan = state.allPlans[index];
                        final isActive = plan.id == state.activePlan?.id;
                        return ListTile(
                          title: Text(plan.name),
                          subtitle: Text(plan.isActive ? 'Activo' : 'Inactivo'),
                          trailing: isActive
                              ? Icon(Icons.check_circle,
                                  color: Theme.of(context).colorScheme.primary)
                              : TextButton(
                                  onPressed: () {
                                    context.read<NutritionBloc>().add(
                                          NutritionPlanActivated(
                                              planId: plan.id),
                                        );
                                    Navigator.pop(context);
                                  },
                                  child: const Text('Activar'),
                                ),
                        );
                      },
                    ),
                  ),
                const SizedBox(height: 8),
                TextButton.icon(
                  onPressed: () {
                    final bloc = context.read<NutritionBloc>();
                    Navigator.pop(context);
                    Navigator.of(context).push(
                      MaterialPageRoute<void>(
                        builder: (_) => NutritionConfigPage(
                          onComplete: () =>
                              bloc.add(NutritionLoaded(date: DateTime.now())),
                        ),
                      ),
                    );
                  },
                  icon: const Icon(Icons.add),
                  label: const Text('Nueva consulta'),
                ),
              ],
            );
          },
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Cerrar'),
        ),
      ],
    );
  }
}

// ── Sección de comida ────────────────────────────────────────────────────────

class _MealSection extends StatelessWidget {
  final String mealType;
  final String label;
  final List<MealPlanOption> options;
  final DailyMealLog? log;

  const _MealSection({
    required this.mealType,
    required this.label,
    required this.options,
    this.log,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isLogged = log != null;

    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: VitalityCard(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Icon(Icons.restaurant_menu),
                const SizedBox(width: 8),
                Text(label, style: theme.textTheme.titleMedium),
                const Spacer(),
                if (isLogged)
                  Builder(builder: (_) {
                    final l = log!;
                    final String chipLabel;
                    final Color chipColor;
                    if (l.planOptionId != null) {
                      chipLabel = 'Registrado';
                      chipColor = theme.colorScheme.primaryContainer;
                    } else if (l.freeDescription != null) {
                      chipLabel = 'Fuera de plan';
                      chipColor =
                          theme.colorScheme.surfaceContainerHighest;
                    } else {
                      chipLabel = 'No seguido';
                      chipColor = theme.colorScheme.errorContainer;
                    }
                    return Chip(
                      label: Text(chipLabel),
                      backgroundColor: chipColor,
                      side: BorderSide.none,
                    );
                  }),
              ],
            ),
            const SizedBox(height: 12),
            if (log?.planOptionId != null)
              _buildSelectedOption(context)
            else if (log?.freeDescription != null)
              _buildOffPlanText(context, log!.freeDescription!)
            else if (log != null)
              _buildNotFollowed(context)
            else if (options.isEmpty)
              Text(
                'Sin opciones configuradas',
                style: theme.textTheme.bodyMedium?.copyWith(
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
              )
            else
              ...options.map((opt) => _OptionTile(
                    option: opt,
                    isSelected: false,
                    onTap: () {
                      context.read<NutritionBloc>().add(
                            NutritionMealLogged(
                              date: DateTime.now(),
                              mealType: mealType,
                              planOptionId: opt.id,
                            ),
                          );
                    },
                  )),
            const Divider(height: 24),
            if (!isLogged) ...[
              Row(
                children: [
                  Expanded(
                    child: TextButton.icon(
                      onPressed: () {
                        context.read<NutritionBloc>().add(
                              NutritionOffPlanMealLogged(
                                date: DateTime.now(),
                                mealType: mealType,
                                description: null,
                              ),
                            );
                      },
                      icon: const Icon(Icons.close),
                      label: const Text('No seguí el plan'),
                    ),
                  ),
                  Expanded(
                    child: TextButton.icon(
                      onPressed: () => _showOffPlanDialog(context),
                      icon: const Icon(Icons.edit_note),
                      label: const Text('Fuera de plan'),
                    ),
                  ),
                ],
              ),
            ] else ...[
              TextButton.icon(
                onPressed: () {
                  context.read<NutritionBloc>().add(
                        NutritionMealLogRemoved(
                          date: DateTime.now(),
                          mealType: mealType,
                        ),
                      );
                },
                icon: const Icon(Icons.undo),
                label: const Text('Cambiar selección'),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildSelectedOption(BuildContext context) {
    final opt = options.firstWhereOrNull((o) => o.id == log!.planOptionId);
    if (opt == null) return const SizedBox.shrink();
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Theme.of(context)
            .colorScheme
            .primaryContainer
            .withValues(alpha: 0.4),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        children: [
          Icon(Icons.check_circle,
              color: Theme.of(context).colorScheme.primary),
          const SizedBox(width: 8),
          Expanded(
              child: Text(
                  'Opción ${opt.optionNumber}: ${opt.description}')),
        ],
      ),
    );
  }

  Widget _buildOffPlanText(BuildContext context, String text) {
    final cs = Theme.of(context).colorScheme;
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: cs.errorContainer.withValues(alpha: 0.3),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        children: [
          Icon(Icons.edit_note, color: cs.error),
          const SizedBox(width: 8),
          Expanded(
            child: Text(text,
                style: TextStyle(color: cs.onErrorContainer)),
          ),
        ],
      ),
    );
  }

  Widget _buildNotFollowed(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Theme.of(context)
            .colorScheme
            .errorContainer
            .withValues(alpha: 0.3),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        children: [
          Icon(Icons.close,
              color: Theme.of(context).colorScheme.error),
          const SizedBox(width: 8),
          Text(
            'No seguí el plan',
            style: TextStyle(
                color: Theme.of(context).colorScheme.error),
          ),
        ],
      ),
    );
  }

  void _showOffPlanDialog(BuildContext context) {
    final controller = TextEditingController();
    showDialog<void>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Comida fuera de plan'),
        content: TextField(
          controller: controller,
          decoration: const InputDecoration(
            labelText: '¿Qué comiste?',
            hintText: 'Ej: Pizza con amigos',
          ),
          maxLines: 2,
          autofocus: true,
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: const Text('Cancelar'),
          ),
          ElevatedButton(
            onPressed: () {
              if (controller.text.isNotEmpty) {
                context.read<NutritionBloc>().add(
                      NutritionOffPlanMealLogged(
                        date: DateTime.now(),
                        mealType: mealType,
                        description: controller.text,
                      ),
                    );
              }
              Navigator.pop(dialogContext);
            },
            child: const Text('Guardar'),
          ),
        ],
      ),
    );
  }
}

class _OptionTile extends StatelessWidget {
  final MealPlanOption option;
  final bool isSelected;
  final VoidCallback onTap;

  const _OptionTile({
    required this.option,
    required this.isSelected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return ListTile(
      dense: true,
      contentPadding: EdgeInsets.zero,
      leading: CircleAvatar(
        backgroundColor: isSelected
            ? Theme.of(context).colorScheme.primaryContainer
            : Theme.of(context).colorScheme.surfaceContainerHighest,
        child: Text('${option.optionNumber}'),
      ),
      title: Text(option.description),
      trailing: isSelected
          ? Icon(Icons.check_circle,
              color: Theme.of(context).colorScheme.primary)
          : const Icon(Icons.radio_button_unchecked),
      onTap: onTap,
    );
  }
}
```

- [ ] **Step 4: Correr todos los tests de nutrition_page**

```bash
flutter test test/features/nutrition/presentation/nutrition_page_test.dart 2>&1
```

Expected: todos los tests pasan.

- [ ] **Step 5: Correr todos los tests de nutrition**

```bash
flutter test test/features/nutrition/ test/dao/nutrition_dao_test.dart 2>&1
```

Expected: todos los tests pasan.

- [ ] **Step 6: Correr analyze global**

```bash
flutter analyze lib/features/nutrition/ lib/core/dao/nutrition_dao.dart 2>&1
```

Expected: no issues (o solo los 3 pre-existentes menores que ya estaban antes de esta feature).

- [ ] **Step 7: Commit final**

```bash
git add lib/features/nutrition/presentation/pages/nutrition_page.dart \
        test/features/nutrition/presentation/nutrition_page_test.dart
git commit -m "feat(nutrition): add pending plan banner + simplify plan creation flow"
```
