# History Improvements Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Mejorar la pantalla de historial con textos en blanco, resumen de cumplimiento por segmento (agua/comida/ejercicio) con barras de progreso, y una pantalla de detalle al tocar un día del calendario.

**Architecture:** Se añade `MonthCompliance` al estado del `HistoryBloc` (calculado en el propio bloc desde los `DaySummary` ya cargados). La pantalla de detalle tiene su propio `DayDetailBloc` que consulta directamente los DAOs existentes. La navegación usa `context.push('/history/day/:date')` como subruta del `GoRoute` de `/history`.

**Tech Stack:** Flutter/Dart, BLoC (`flutter_bloc`), Drift DAOs, `go_router`, `intl`, `bloc_test`, `mocktail`, `equatable`.

---

## File Map

| Archivo | Acción |
|---------|--------|
| `lib/features/history/presentation/bloc/history_state.dart` | Modificar: añadir `MonthCompliance` + campo `compliance` |
| `lib/features/history/presentation/bloc/history_bloc.dart` | Modificar: calcular compliance al emitir éxito |
| `test/features/history/presentation/history_bloc_test.dart` | Modificar: actualizar expected states con compliance |
| `lib/features/history/presentation/pages/history_page.dart` | Modificar: texto blanco, compliance bars, onTap |
| `lib/core/dao/nutrition_dao.dart` | Modificar: añadir `getMealPlanOptionsByIds` |
| `lib/features/history/presentation/bloc/day_detail_event.dart` | Nuevo |
| `lib/features/history/presentation/bloc/day_detail_state.dart` | Nuevo |
| `lib/features/history/presentation/bloc/day_detail_bloc.dart` | Nuevo |
| `test/features/history/presentation/day_detail_bloc_test.dart` | Nuevo |
| `lib/features/history/presentation/pages/day_detail_page.dart` | Nuevo |
| `lib/core/router/app_router.dart` | Modificar: subruta `day/:date` bajo `/history` |

---

## Task 1: MonthCompliance model + HistoryState + HistoryBloc

**Files:**
- Modify: `lib/features/history/presentation/bloc/history_state.dart`
- Modify: `lib/features/history/presentation/bloc/history_bloc.dart`

- [ ] **Step 1: Añadir `MonthCompliance` y `computeMonthCompliance` en history_state.dart**

Reemplazar el contenido de `lib/features/history/presentation/bloc/history_state.dart`:

```dart
import 'package:equatable/equatable.dart';
import '../../domain/repositories/history_repository.dart';

class MonthCompliance extends Equatable {
  final double water;
  final double meals;
  final double exercise;

  const MonthCompliance({
    required this.water,
    required this.meals,
    required this.exercise,
  });

  @override
  List<Object?> get props => [water, meals, exercise];
}

MonthCompliance computeMonthCompliance(List<DaySummary> days) {
  final todayUtc = DateTime.utc(
    DateTime.now().year,
    DateTime.now().month,
    DateTime.now().day,
  );
  final counted = days.where((d) => !d.date.isAfter(todayUtc)).toList();
  if (counted.isEmpty) {
    return const MonthCompliance(water: 0, meals: 0, exercise: 0);
  }
  final n = counted.length;
  return MonthCompliance(
    water: counted.where((d) => d.hasWater).length / n,
    meals: counted.where((d) => d.hasMeals).length / n,
    exercise: counted.where((d) => d.hasExercise).length / n,
  );
}

enum HistoryStatus { initial, loading, success, failure }

class HistoryState extends Equatable {
  final HistoryStatus status;
  final DateTime currentMonth;
  final List<DaySummary> days;
  final MonthCompliance compliance;
  final String? error;

  const HistoryState({
    this.status = HistoryStatus.initial,
    required this.currentMonth,
    this.days = const [],
    this.compliance = const MonthCompliance(water: 0, meals: 0, exercise: 0),
    this.error,
  });

  HistoryState copyWith({
    HistoryStatus? status,
    DateTime? currentMonth,
    List<DaySummary>? days,
    MonthCompliance? compliance,
    String? error,
  }) =>
      HistoryState(
        status: status ?? this.status,
        currentMonth: currentMonth ?? this.currentMonth,
        days: days ?? this.days,
        compliance: compliance ?? this.compliance,
        error: error,
      );

  @override
  List<Object?> get props => [status, currentMonth, days, compliance, error];
}
```

- [ ] **Step 2: Actualizar HistoryBloc para emitir compliance**

En `lib/features/history/presentation/bloc/history_bloc.dart`, en `_onMonthLoaded`, añadir `compliance: computeMonthCompliance(days)` al emit de éxito:

```dart
import 'package:flutter_bloc/flutter_bloc.dart';
import '../../domain/repositories/history_repository.dart';
import 'history_event.dart';
import 'history_state.dart';

class HistoryBloc extends Bloc<HistoryEvent, HistoryState> {
  final HistoryRepository _repository;

  HistoryBloc(this._repository)
      : super(HistoryState(currentMonth: DateTime.now())) {
    on<HistoryMonthLoaded>(_onMonthLoaded);
    on<HistoryPreviousMonth>(_onPreviousMonth);
    on<HistoryNextMonth>(_onNextMonth);
  }

  Future<void> _onMonthLoaded(
    HistoryMonthLoaded event,
    Emitter<HistoryState> emit,
  ) async {
    emit(state.copyWith(status: HistoryStatus.loading));
    try {
      final days = await _repository.getMonthSummary(event.month);
      emit(state.copyWith(
        status: HistoryStatus.success,
        currentMonth: event.month,
        days: days,
        compliance: computeMonthCompliance(days),
      ));
    } catch (e) {
      emit(state.copyWith(status: HistoryStatus.failure, error: e.toString()));
    }
  }

  void _onPreviousMonth(
    HistoryPreviousMonth event,
    Emitter<HistoryState> emit,
  ) {
    final month = DateTime(
      state.currentMonth.year,
      state.currentMonth.month - 1,
    );
    add(HistoryMonthLoaded(month: month));
  }

  void _onNextMonth(
    HistoryNextMonth event,
    Emitter<HistoryState> emit,
  ) {
    final month = DateTime(
      state.currentMonth.year,
      state.currentMonth.month + 1,
    );
    add(HistoryMonthLoaded(month: month));
  }
}
```

- [ ] **Step 3: Actualizar history_bloc_test.dart**

El expected success state ahora debe incluir `compliance`. Los datos del test son: 1 día (junio 1, 2026) con water=true, meals=true, exercise=false → compliance(water:1.0, meals:1.0, exercise:0.0).

Reemplazar `test/features/history/presentation/history_bloc_test.dart`:

```dart
import 'package:bloc_test/bloc_test.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kiolog/features/history/domain/repositories/history_repository.dart';
import 'package:kiolog/features/history/presentation/bloc/history_bloc.dart';
import 'package:kiolog/features/history/presentation/bloc/history_event.dart';
import 'package:kiolog/features/history/presentation/bloc/history_state.dart';
import 'package:mocktail/mocktail.dart';

class MockHistoryRepository extends Mock implements HistoryRepository {}

void main() {
  late MockHistoryRepository repository;

  setUp(() {
    repository = MockHistoryRepository();
  });

  group('HistoryBloc', () {
    final days = [
      DaySummary(
        date: DateTime(2026, 6, 1),
        hasWater: true,
        hasSleep: false,
        hasMeals: true,
        hasExercise: false,
      ),
    ];

    blocTest<HistoryBloc, HistoryState>(
      'emits [loading, success] when month loaded',
      build: () {
        when(() => repository.getMonthSummary(any()))
            .thenAnswer((_) async => days);
        return HistoryBloc(repository)
          ..emit(HistoryState(currentMonth: DateTime(2026, 5, 1)));
      },
      act: (bloc) => bloc.add(HistoryMonthLoaded(month: DateTime(2026, 6))),
      expect: () => [
        HistoryState(
          status: HistoryStatus.loading,
          currentMonth: DateTime(2026, 5, 1),
        ),
        HistoryState(
          status: HistoryStatus.success,
          currentMonth: DateTime(2026, 6),
          days: days,
          compliance: computeMonthCompliance(days),
        ),
      ],
    );

    group('computeMonthCompliance', () {
      test('returns zeros when no days', () {
        final result = computeMonthCompliance([]);
        expect(result.water, 0.0);
        expect(result.meals, 0.0);
        expect(result.exercise, 0.0);
      });

      test('returns zeros when all days are in the future', () {
        final future = DateTime.now().add(const Duration(days: 30));
        final futureDays = [
          DaySummary(
            date: DateTime.utc(future.year, future.month, future.day),
            hasWater: true,
            hasSleep: false,
            hasMeals: true,
            hasExercise: true,
          ),
        ];
        final result = computeMonthCompliance(futureDays);
        expect(result.water, 0.0);
        expect(result.meals, 0.0);
        expect(result.exercise, 0.0);
      });

      test('counts past days only and computes correct ratios', () {
        final yesterday = DateTime.now().subtract(const Duration(days: 1));
        final pastDay = DateTime.utc(
            yesterday.year, yesterday.month, yesterday.day);
        final pastDays = [
          DaySummary(
            date: pastDay,
            hasWater: true,
            hasSleep: false,
            hasMeals: false,
            hasExercise: true,
          ),
        ];
        final result = computeMonthCompliance(pastDays);
        expect(result.water, 1.0);
        expect(result.meals, 0.0);
        expect(result.exercise, 1.0);
      });
    });
  });
}
```

- [ ] **Step 4: Correr los tests**

```bash
cd /home/jesuszelaya/Documents/kiolog
flutter test test/features/history/presentation/history_bloc_test.dart --reporter compact
```

Expected: todos pasan.

- [ ] **Step 5: Commit**

```bash
git add lib/features/history/presentation/bloc/history_state.dart \
        lib/features/history/presentation/bloc/history_bloc.dart \
        test/features/history/presentation/history_bloc_test.dart
git commit -m "feat(history): add MonthCompliance model and compute per-segment compliance in bloc"
```

---

## Task 2: Añadir getMealPlanOptionsByIds a NutritionDao

**Files:**
- Modify: `lib/core/dao/nutrition_dao.dart`

- [ ] **Step 1: Agregar el método al final de la clase `NutritionDao` (antes del `}`)**

En `lib/core/dao/nutrition_dao.dart`, dentro de la clase `NutritionDao`, añadir después de `getOptionFrequenciesForPlan`:

```dart
  Future<List<MealPlanOption>> getMealPlanOptionsByIds(List<int> ids) {
    if (ids.isEmpty) return Future.value([]);
    return (select(mealPlanOptions)..where((t) => t.id.isIn(ids))).get();
  }
```

- [ ] **Step 2: Correr tests existentes para verificar que no se rompió nada**

```bash
flutter test test/ --reporter compact
```

Expected: todos pasan.

- [ ] **Step 3: Commit**

```bash
git add lib/core/dao/nutrition_dao.dart
git commit -m "feat(nutrition): add getMealPlanOptionsByIds to NutritionDao"
```

---

## Task 3: DayDetailBloc — event, state, bloc

**Files:**
- Create: `lib/features/history/presentation/bloc/day_detail_event.dart`
- Create: `lib/features/history/presentation/bloc/day_detail_state.dart`
- Create: `lib/features/history/presentation/bloc/day_detail_bloc.dart`
- Create: `test/features/history/presentation/day_detail_bloc_test.dart`

- [ ] **Step 1: Escribir el test que falla primero**

Crear `test/features/history/presentation/day_detail_bloc_test.dart`:

```dart
import 'package:bloc_test/bloc_test.dart';
import 'package:drift/drift.dart' hide isNull, isNotNull;
import 'package:flutter_test/flutter_test.dart';
import 'package:kiolog/core/database/app_database.dart';
import 'package:kiolog/features/history/presentation/bloc/day_detail_bloc.dart';
import 'package:kiolog/features/history/presentation/bloc/day_detail_event.dart';
import 'package:kiolog/features/history/presentation/bloc/day_detail_state.dart';

import '../../../../helpers/database_helper.dart';

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
```

- [ ] **Step 2: Correr el test para confirmar que falla (archivos no existen aún)**

```bash
flutter test test/features/history/presentation/day_detail_bloc_test.dart --reporter compact
```

Expected: falla con error de import.

- [ ] **Step 3: Crear day_detail_event.dart**

```dart
import 'package:equatable/equatable.dart';

abstract class DayDetailEvent extends Equatable {
  const DayDetailEvent();

  @override
  List<Object?> get props => [];
}

class DayDetailLoaded extends DayDetailEvent {
  final DateTime date;

  const DayDetailLoaded({required this.date});

  @override
  List<Object?> get props => [date];
}
```

Guardar en `lib/features/history/presentation/bloc/day_detail_event.dart`.

- [ ] **Step 4: Crear day_detail_state.dart**

```dart
import 'package:equatable/equatable.dart';
import 'package:kiolog/core/database/app_database.dart';

enum DayDetailStatus { initial, loading, success, failure }

class DayDetailState extends Equatable {
  final DayDetailStatus status;
  final DateTime date;
  final List<DailyWaterLog> waterLogs;
  final List<DailyMealLog> mealLogs;
  final Map<int, MealPlanOption> mealOptions;
  final List<ExerciseSessionLog> exerciseSessions;
  final DailyExerciseLog? exerciseLog;
  final String? error;

  const DayDetailState({
    this.status = DayDetailStatus.initial,
    required this.date,
    this.waterLogs = const [],
    this.mealLogs = const [],
    this.mealOptions = const {},
    this.exerciseSessions = const [],
    this.exerciseLog,
    this.error,
  });

  int get totalWaterMl =>
      waterLogs.fold(0, (sum, log) => sum + log.amountMl);

  bool get hasWater => waterLogs.isNotEmpty;
  bool get hasMeals => mealLogs.isNotEmpty;
  bool get hasExercise =>
      (exerciseLog?.completed ?? false) || exerciseSessions.isNotEmpty;

  int get completedSegments =>
      (hasWater ? 1 : 0) + (hasMeals ? 1 : 0) + (hasExercise ? 1 : 0);

  DayDetailState copyWith({
    DayDetailStatus? status,
    DateTime? date,
    List<DailyWaterLog>? waterLogs,
    List<DailyMealLog>? mealLogs,
    Map<int, MealPlanOption>? mealOptions,
    List<ExerciseSessionLog>? exerciseSessions,
    DailyExerciseLog? exerciseLog,
    bool clearExerciseLog = false,
    String? error,
  }) =>
      DayDetailState(
        status: status ?? this.status,
        date: date ?? this.date,
        waterLogs: waterLogs ?? this.waterLogs,
        mealLogs: mealLogs ?? this.mealLogs,
        mealOptions: mealOptions ?? this.mealOptions,
        exerciseSessions: exerciseSessions ?? this.exerciseSessions,
        exerciseLog: clearExerciseLog ? null : (exerciseLog ?? this.exerciseLog),
        error: error,
      );

  @override
  List<Object?> get props => [
        status,
        date,
        waterLogs,
        mealLogs,
        mealOptions,
        exerciseSessions,
        exerciseLog,
        error,
      ];
}
```

Guardar en `lib/features/history/presentation/bloc/day_detail_state.dart`.

- [ ] **Step 5: Crear day_detail_bloc.dart**

```dart
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:kiolog/core/dao/exercise_dao.dart';
import 'package:kiolog/core/dao/nutrition_dao.dart';
import 'package:kiolog/core/dao/water_sleep_dao.dart';
import 'day_detail_event.dart';
import 'day_detail_state.dart';

class DayDetailBloc extends Bloc<DayDetailEvent, DayDetailState> {
  final WaterSleepDao _waterSleepDao;
  final NutritionDao _nutritionDao;
  final ExerciseDao _exerciseDao;

  DayDetailBloc(this._waterSleepDao, this._nutritionDao, this._exerciseDao)
      : super(DayDetailState(date: DateTime.now())) {
    on<DayDetailLoaded>(_onLoaded);
  }

  Future<void> _onLoaded(
    DayDetailLoaded event,
    Emitter<DayDetailState> emit,
  ) async {
    emit(state.copyWith(status: DayDetailStatus.loading, date: event.date));
    try {
      final waterLogs =
          await _waterSleepDao.getDailyWaterLogs(event.date);
      final mealLogs =
          await _nutritionDao.getDailyMealLogs(event.date);
      final sessions =
          await _exerciseDao.getSessionsForDate(event.date);
      final exerciseLog =
          await _exerciseDao.getDailyExerciseLog(event.date);

      final optionIds = mealLogs
          .map((l) => l.planOptionId)
          .whereType<int>()
          .toList();
      final options =
          await _nutritionDao.getMealPlanOptionsByIds(optionIds);
      final mealOptions = {for (final o in options) o.id: o};

      emit(state.copyWith(
        status: DayDetailStatus.success,
        date: event.date,
        waterLogs: waterLogs,
        mealLogs: mealLogs,
        mealOptions: mealOptions,
        exerciseSessions: sessions,
        exerciseLog: exerciseLog,
        clearExerciseLog: exerciseLog == null,
      ));
    } catch (e) {
      emit(state.copyWith(
          status: DayDetailStatus.failure, error: e.toString()));
    }
  }
}
```

Guardar en `lib/features/history/presentation/bloc/day_detail_bloc.dart`.

- [ ] **Step 6: Correr los tests**

```bash
flutter test test/features/history/presentation/day_detail_bloc_test.dart --reporter compact
```

Expected: los 3 tests pasan.

- [ ] **Step 7: Commit**

```bash
git add lib/features/history/presentation/bloc/day_detail_event.dart \
        lib/features/history/presentation/bloc/day_detail_state.dart \
        lib/features/history/presentation/bloc/day_detail_bloc.dart \
        test/features/history/presentation/day_detail_bloc_test.dart
git commit -m "feat(history): add DayDetailBloc with water/meal/exercise loading"
```

---

## Task 4: DayDetailPage

**Files:**
- Create: `lib/features/history/presentation/pages/day_detail_page.dart`

- [ ] **Step 1: Crear day_detail_page.dart**

```dart
import 'package:collection/collection.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:intl/intl.dart';
import 'package:kiolog/core/database/app_database.dart';
import '../../../../core/di/injection.dart';
import '../../../../core/dao/exercise_dao.dart';
import '../../../../core/dao/nutrition_dao.dart';
import '../../../../core/dao/water_sleep_dao.dart';
import '../bloc/day_detail_bloc.dart';
import '../bloc/day_detail_event.dart';
import '../bloc/day_detail_state.dart';

class DayDetailPage extends StatelessWidget {
  final DateTime date;

  const DayDetailPage({super.key, required this.date});

  @override
  Widget build(BuildContext context) {
    return BlocProvider(
      create: (_) => DayDetailBloc(
        getIt<WaterSleepDao>(),
        getIt<NutritionDao>(),
        getIt<ExerciseDao>(),
      )..add(DayDetailLoaded(date: date)),
      child: _DayDetailView(date: date),
    );
  }
}

class _DayDetailView extends StatelessWidget {
  final DateTime date;

  const _DayDetailView({required this.date});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final title = DateFormat('EEEE d MMM yyyy', 'es').format(date);

    return Scaffold(
      appBar: AppBar(
        title: Text(title),
      ),
      body: BlocBuilder<DayDetailBloc, DayDetailState>(
        builder: (context, state) {
          if (state.status == DayDetailStatus.loading ||
              state.status == DayDetailStatus.initial) {
            return const Center(child: CircularProgressIndicator());
          }
          if (state.status == DayDetailStatus.failure) {
            return Center(child: Text('Error: ${state.error}'));
          }

          return ListView(
            padding: const EdgeInsets.all(16),
            children: [
              Padding(
                padding: const EdgeInsets.only(bottom: 12),
                child: Text(
                  '${state.completedSegments} de 3 segmentos con registro',
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                ),
              ),
              _SegmentCard(
                icon: '💧',
                iconBackground: const Color(0xFF1E3A5F),
                title: 'Agua',
                accentColor: const Color(0xFF60A5FA),
                hasData: state.hasWater,
                child: _WaterContent(state: state),
              ),
              const SizedBox(height: 8),
              _SegmentCard(
                icon: '🍽️',
                iconBackground: const Color(0xFF3D2000),
                title: 'Nutrición',
                accentColor: const Color(0xFFFB923C),
                hasData: state.hasMeals,
                child: _NutritionContent(state: state),
              ),
              const SizedBox(height: 8),
              _SegmentCard(
                icon: '🏋️',
                iconBackground: const Color(0xFF3D0A0A),
                title: 'Ejercicio',
                accentColor: const Color(0xFFF87171),
                hasData: state.hasExercise,
                child: _ExerciseContent(state: state),
              ),
            ],
          );
        },
      ),
    );
  }
}

class _SegmentCard extends StatelessWidget {
  final String icon;
  final Color iconBackground;
  final String title;
  final Color accentColor;
  final bool hasData;
  final Widget child;

  const _SegmentCard({
    required this.icon,
    required this.iconBackground,
    required this.title,
    required this.accentColor,
    required this.hasData,
    required this.child,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Row(
                  children: [
                    Container(
                      width: 28,
                      height: 28,
                      decoration: BoxDecoration(
                        color: iconBackground,
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Center(child: Text(icon, style: const TextStyle(fontSize: 14))),
                    ),
                    const SizedBox(width: 8),
                    Text(title,
                        style: theme.textTheme.bodyMedium
                            ?.copyWith(fontWeight: FontWeight.w600)),
                  ],
                ),
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                  decoration: BoxDecoration(
                    color: hasData
                        ? const Color(0xFF1A3D27)
                        : theme.colorScheme.surfaceContainerHighest,
                    borderRadius: BorderRadius.circular(99),
                  ),
                  child: Text(
                    hasData ? 'Cumplido' : 'Sin registro',
                    style: theme.textTheme.labelSmall?.copyWith(
                      color: hasData
                          ? const Color(0xFF4BE277)
                          : theme.colorScheme.onSurfaceVariant,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ],
            ),
            const Divider(height: 20),
            child,
          ],
        ),
      ),
    );
  }
}

class _WaterContent extends StatelessWidget {
  final DayDetailState state;

  const _WaterContent({required this.state});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    if (!state.hasWater) {
      return _EmptyNote(text: 'No hay tomas registradas');
    }
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text('Total del día', style: theme.textTheme.bodySmall),
            Text(
              '${state.totalWaterMl} ml',
              style: theme.textTheme.bodySmall?.copyWith(
                fontWeight: FontWeight.w700,
                color: const Color(0xFF60A5FA),
              ),
            ),
          ],
        ),
        const SizedBox(height: 6),
        Wrap(
          spacing: 6,
          runSpacing: 4,
          children: state.waterLogs.map((log) {
            final time = DateFormat('HH:mm').format(log.timestamp.toLocal());
            return Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
              decoration: BoxDecoration(
                color: const Color(0xFF1E3A5F),
                borderRadius: BorderRadius.circular(6),
              ),
              child: Text(
                '$time · ${log.amountMl} ml',
                style: theme.textTheme.labelSmall?.copyWith(
                  color: const Color(0xFF93C5FD),
                ),
              ),
            );
          }).toList(),
        ),
      ],
    );
  }
}

class _NutritionContent extends StatelessWidget {
  final DayDetailState state;

  const _NutritionContent({required this.state});

  static const _mealOrder = ['breakfast', 'lunch', 'dinner', 'snack'];
  static const _mealLabel = {
    'breakfast': 'Desayuno',
    'lunch': 'Almuerzo',
    'dinner': 'Cena',
    'snack': 'Snack',
  };

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    if (!state.hasMeals) {
      return _EmptyNote(text: 'No hay comidas registradas');
    }
    return Column(
      children: _mealOrder.map((type) {
        final log = state.mealLogs
            .where((l) => l.mealType == type)
            .firstOrNull;
        final label = _mealLabel[type]!;
        String value;
        if (log == null) {
          value = '—';
        } else if (log.planOptionId != null &&
            state.mealOptions.containsKey(log.planOptionId)) {
          value =
              'Opción ${state.mealOptions[log.planOptionId]!.optionNumber}';
        } else if (log.freeDescription != null) {
          value = log.freeDescription!;
        } else {
          value = 'Registrado';
        }
        return Padding(
          padding: const EdgeInsets.symmetric(vertical: 3),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(label, style: theme.textTheme.bodySmall),
              Text(
                value,
                style: theme.textTheme.bodySmall?.copyWith(
                  fontWeight: FontWeight.w600,
                  color: log != null
                      ? const Color(0xFFFB923C)
                      : theme.colorScheme.onSurfaceVariant,
                ),
              ),
            ],
          ),
        );
      }).toList(),
    );
  }
}

class _ExerciseContent extends StatelessWidget {
  final DayDetailState state;

  const _ExerciseContent({required this.state});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    if (!state.hasExercise) {
      return _EmptyNote(text: 'No hay sesiones registradas este día');
    }

    if (state.exerciseSessions.isEmpty && (state.exerciseLog?.completed ?? false)) {
      return Text(
        'Ejercicio completado sin sesión registrada',
        style: theme.textTheme.bodySmall,
      );
    }

    return Column(
      children: state.exerciseSessions.asMap().entries.map((entry) {
        final i = entry.key;
        final session = entry.value;
        final arrived =
            DateFormat('HH:mm').format(session.gymArrivedAt.toLocal());
        final left = session.gymLeftAt != null
            ? DateFormat('HH:mm').format(session.gymLeftAt!.toLocal())
            : 'En curso';
        return Padding(
          padding: const EdgeInsets.symmetric(vertical: 3),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text('Sesión ${i + 1}', style: theme.textTheme.bodySmall),
              Text(
                '$arrived – $left',
                style: theme.textTheme.bodySmall?.copyWith(
                  fontWeight: FontWeight.w600,
                  color: const Color(0xFFF87171),
                ),
              ),
            ],
          ),
        );
      }).toList(),
    );
  }
}

class _EmptyNote extends StatelessWidget {
  final String text;

  const _EmptyNote({required this.text});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 4),
        child: Text(
          text,
          style: Theme.of(context).textTheme.bodySmall?.copyWith(
                fontStyle: FontStyle.italic,
                color: Theme.of(context).colorScheme.onSurfaceVariant,
              ),
        ),
      ),
    );
  }
}
```

- [ ] **Step 2: Verificar que compila**

```bash
flutter analyze lib/features/history/presentation/pages/day_detail_page.dart
```

Expected: sin errores.

- [ ] **Step 3: Commit**

```bash
git add lib/features/history/presentation/pages/day_detail_page.dart
git commit -m "feat(history): add DayDetailPage with water/nutrition/exercise cards"
```

---

## Task 5: Router — subruta day/:date

**Files:**
- Modify: `lib/core/router/app_router.dart`

- [ ] **Step 1: Añadir import de DayDetailPage y convertir `/history` en GoRoute con subruta**

En `lib/core/router/app_router.dart`, añadir el import:

```dart
import '../../features/history/presentation/pages/day_detail_page.dart';
```

Luego reemplazar el bloque del GoRoute de `/history` (líneas ~54-57):

```dart
        GoRoute(
          path: '/history',
          builder: (context, state) => const HistoryPage(),
        ),
```

por:

```dart
        GoRoute(
          path: '/history',
          builder: (context, state) => const HistoryPage(),
          routes: [
            GoRoute(
              path: 'day/:date',
              builder: (context, state) {
                final parts =
                    state.pathParameters['date']!.split('-');
                final date = DateTime.utc(
                  int.parse(parts[0]),
                  int.parse(parts[1]),
                  int.parse(parts[2]),
                );
                return DayDetailPage(date: date);
              },
            ),
          ],
        ),
```

- [ ] **Step 2: Verificar que compila**

```bash
flutter analyze lib/core/router/app_router.dart
```

Expected: sin errores.

- [ ] **Step 3: Commit**

```bash
git add lib/core/router/app_router.dart
git commit -m "feat(router): add /history/day/:date subroute for day detail"
```

---

## Task 6: HistoryPage — texto blanco + compliance bars + onTap

**Files:**
- Modify: `lib/features/history/presentation/pages/history_page.dart`

- [ ] **Step 1: Reemplazar history_page.dart completo**

```dart
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import '../../../../core/di/injection.dart';
import '../../domain/repositories/history_repository.dart';
import '../bloc/history_bloc.dart';
import '../bloc/history_event.dart';
import '../bloc/history_state.dart';

class HistoryPage extends StatelessWidget {
  const HistoryPage({super.key});

  @override
  Widget build(BuildContext context) {
    return BlocProvider(
      create: (_) => HistoryBloc(getIt<HistoryRepository>())
        ..add(HistoryMonthLoaded(month: DateTime.now())),
      child: const _HistoryView(),
    );
  }
}

class _HistoryView extends StatelessWidget {
  const _HistoryView();

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Historial'),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => context.go('/'),
        ),
      ),
      body: BlocBuilder<HistoryBloc, HistoryState>(
        builder: (context, state) {
          if (state.status == HistoryStatus.loading && state.days.isEmpty) {
            return const Center(child: CircularProgressIndicator());
          }
          if (state.status == HistoryStatus.failure) {
            return Center(child: Text('Error: ${state.error}'));
          }

          return SafeArea(
            child: Column(
              children: [
                Padding(
                  padding: const EdgeInsets.all(16),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      IconButton(
                        icon: const Icon(Icons.chevron_left),
                        onPressed: () => context
                            .read<HistoryBloc>()
                            .add(const HistoryPreviousMonth()),
                      ),
                      Text(
                        DateFormat.yMMMM('es').format(state.currentMonth),
                        style: Theme.of(context).textTheme.titleLarge,
                      ),
                      IconButton(
                        icon: const Icon(Icons.chevron_right),
                        onPressed: () => context
                            .read<HistoryBloc>()
                            .add(const HistoryNextMonth()),
                      ),
                    ],
                  ),
                ),
                Expanded(
                  child: GridView.builder(
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    gridDelegate:
                        const SliverGridDelegateWithFixedCrossAxisCount(
                      crossAxisCount: 7,
                      childAspectRatio: 0.85,
                    ),
                    itemCount: state.days.length,
                    itemBuilder: (context, index) {
                      final day = state.days[index];
                      return _DayCell(day: day);
                    },
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
                  child: _ComplianceSection(compliance: state.compliance),
                ),
              ],
            ),
          );
        },
      ),
    );
  }
}

class _DayCell extends StatelessWidget {
  final DaySummary day;

  const _DayCell({required this.day});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final count = day.completedCount;

    return GestureDetector(
      onTap: () {
        final dateStr = DateFormat('yyyy-MM-dd').format(day.date);
        context.push('/history/day/$dateStr');
      },
      child: Card(
        margin: const EdgeInsets.all(2),
        color: count == 4
            ? theme.colorScheme.primaryContainer
            : theme.colorScheme.surfaceContainerHighest.withValues(alpha: 0.3),
        child: Padding(
          padding: const EdgeInsets.all(4),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text(
                '${day.date.day}',
                style: theme.textTheme.bodySmall?.copyWith(
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 4),
              Wrap(
                spacing: 2,
                runSpacing: 2,
                alignment: WrapAlignment.center,
                children: [
                  if (day.hasWater) const _MiniDot(color: Color(0xFF3B82F6)),
                  if (day.hasMeals) const _MiniDot(color: Color(0xFFF97316)),
                  if (day.hasExercise) const _MiniDot(color: Color(0xFFEF4444)),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _MiniDot extends StatelessWidget {
  final Color color;

  const _MiniDot({required this.color});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 6,
      height: 6,
      decoration: BoxDecoration(
        color: color,
        shape: BoxShape.circle,
      ),
    );
  }
}

class _ComplianceSection extends StatelessWidget {
  final MonthCompliance compliance;

  const _ComplianceSection({required this.compliance});

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Cumplimiento del mes',
              style: Theme.of(context).textTheme.labelSmall?.copyWith(
                    color: Theme.of(context).colorScheme.onSurfaceVariant,
                    letterSpacing: 0.5,
                  ),
            ),
            const SizedBox(height: 10),
            _SegmentRow(
              icon: '💧',
              iconBackground: const Color(0xFF1E3A5F),
              label: 'Agua',
              value: compliance.water,
              barColor: const Color(0xFF3B82F6),
              valueColor: const Color(0xFF60A5FA),
            ),
            const SizedBox(height: 8),
            _SegmentRow(
              icon: '🍽️',
              iconBackground: const Color(0xFF3D2000),
              label: 'Comida',
              value: compliance.meals,
              barColor: const Color(0xFFF97316),
              valueColor: const Color(0xFFFB923C),
            ),
            const SizedBox(height: 8),
            _SegmentRow(
              icon: '🏋️',
              iconBackground: const Color(0xFF3D0A0A),
              label: 'Ejercicio',
              value: compliance.exercise,
              barColor: const Color(0xFFEF4444),
              valueColor: const Color(0xFFF87171),
            ),
          ],
        ),
      ),
    );
  }
}

class _SegmentRow extends StatelessWidget {
  final String icon;
  final Color iconBackground;
  final String label;
  final double value;
  final Color barColor;
  final Color valueColor;

  const _SegmentRow({
    required this.icon,
    required this.iconBackground,
    required this.label,
    required this.value,
    required this.barColor,
    required this.valueColor,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final pct = (value * 100).round();

    return Row(
      children: [
        Container(
          width: 24,
          height: 24,
          decoration: BoxDecoration(
            color: iconBackground,
            borderRadius: BorderRadius.circular(6),
          ),
          child: Center(
            child: Text(icon, style: const TextStyle(fontSize: 13)),
          ),
        ),
        const SizedBox(width: 8),
        SizedBox(
          width: 60,
          child: Text(label, style: theme.textTheme.bodySmall),
        ),
        Expanded(
          child: ClipRRect(
            borderRadius: BorderRadius.circular(100),
            child: LinearProgressIndicator(
              value: value,
              minHeight: 6,
              backgroundColor: theme.colorScheme.surfaceContainerHighest,
              valueColor: AlwaysStoppedAnimation<Color>(barColor),
            ),
          ),
        ),
        const SizedBox(width: 8),
        SizedBox(
          width: 32,
          child: Text(
            '$pct%',
            textAlign: TextAlign.right,
            style: theme.textTheme.bodySmall?.copyWith(
              fontWeight: FontWeight.w700,
              color: valueColor,
            ),
          ),
        ),
      ],
    );
  }
}
```

- [ ] **Step 2: Verificar que compila**

```bash
flutter analyze lib/features/history/presentation/pages/history_page.dart
```

Expected: sin errores.

- [ ] **Step 3: Correr todos los tests**

```bash
flutter test test/ --reporter compact
```

Expected: todos pasan.

- [ ] **Step 4: Commit final**

```bash
git add lib/features/history/presentation/pages/history_page.dart
git commit -m "feat(history): white text, per-segment compliance bars, tap-to-detail navigation"
```
