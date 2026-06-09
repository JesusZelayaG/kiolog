# Nutrition Progress Charts Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Add meal plan adherence tracking (period dates + daily meal goal) and a NutritionProgressPage with Semana/Mes bar charts showing plan adherence over 8 weeks.

**Architecture:** Extend MealPlans table with 3 new columns (periodStart, periodEnd, dailyMealGoal), bump schema to v5. Add NutritionWeeklyStat model + getWeeklyAdherence repository method that computes adherence in Dart. NutritionProgressPage is a StatefulWidget sharing the existing NutritionBloc via BlocProvider.value.

**Tech Stack:** Flutter, Drift (SQLite), flutter_bloc, mocktail, CustomPainter (no chart libraries)

---

## File Map

| File | Action |
|------|--------|
| `lib/core/database/tables/nutrition_tables.dart` | Add 3 columns to MealPlans |
| `lib/core/database/app_database.dart` | schemaVersion 4→5, add migration |
| `lib/core/dao/nutrition_dao.dart` | Update setActivePlan, add getLogsInRange |
| `lib/features/nutrition/domain/models/nutrition_weekly_stat.dart` | New model (create dir) |
| `lib/features/nutrition/domain/repositories/nutrition_repository.dart` | Add getWeeklyAdherence, update createPlan |
| `lib/features/nutrition/data/repositories/nutrition_repository_impl.dart` | Implement both |
| `lib/features/nutrition/presentation/bloc/nutrition_event.dart` | Add dailyMealGoal to NutritionPlanCreated |
| `lib/features/nutrition/presentation/bloc/nutrition_state.dart` | Add weeklyAdherence field |
| `lib/features/nutrition/presentation/bloc/nutrition_bloc.dart` | Load adherence in _onLoaded, pass dailyMealGoal in _onPlanCreated |
| `lib/features/nutrition/presentation/pages/nutrition_page.dart` | Add 📊 AppBar icon, update plan creation dialog |
| `lib/features/nutrition/presentation/pages/nutrition_progress_page.dart` | New screen |
| `test/features/nutrition/data/nutrition_repository_test.dart` | Update existing + add adherence tests |
| `test/features/nutrition/presentation/nutrition_bloc_test.dart` | Update existing tests for new fields |
| `test/features/nutrition/presentation/nutrition_progress_page_test.dart` | New widget tests |

---

### Task 1: Schema — add 3 columns to MealPlans, bump to v5

**Files:**
- Modify: `lib/core/database/tables/nutrition_tables.dart`
- Modify: `lib/core/database/app_database.dart`

- [ ] **Step 1: Update MealPlans table**

Replace `lib/core/database/tables/nutrition_tables.dart` with:

```dart
import 'package:drift/drift.dart';

class MealPlans extends Table {
  IntColumn get id => integer().autoIncrement()();
  TextColumn get name => text()();
  DateTimeColumn get createdAt => dateTime()();
  BoolColumn get isActive => boolean().withDefault(const Constant(true))();
  DateTimeColumn get periodStart => dateTime().nullable()();
  DateTimeColumn get periodEnd => dateTime().nullable()();
  IntColumn get dailyMealGoal => integer().withDefault(const Constant(4))();
}

class MealPlanOptions extends Table {
  IntColumn get id => integer().autoIncrement()();
  IntColumn get planId => integer().references(MealPlans, #id)();
  // meal_type: breakfast | lunch | dinner | snack
  TextColumn get mealType => text()();
  // 1, 2 o 3
  IntColumn get optionNumber => integer()();
  TextColumn get description => text()();
}

class DailyMealLogs extends Table {
  IntColumn get id => integer().autoIncrement()();
  DateTimeColumn get date => dateTime()();
  TextColumn get mealType => text()();
  // null indica comida fuera del plan
  IntColumn get planOptionId => integer().nullable().references(MealPlanOptions, #id)();
  TextColumn get freeDescription => text().nullable()();
  TextColumn get photoPath => text().nullable()();
}
```

- [ ] **Step 2: Bump schemaVersion and add migration**

In `lib/core/database/app_database.dart` change `schemaVersion` and add the v5 migration block:

```dart
@override
int get schemaVersion => 5;

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
        if (from >= 3) {
          await m.addColumn(
              exerciseRoutineItems, exerciseRoutineItems.setType);
          await m.addColumn(
              exerciseRoutineItems, exerciseRoutineItems.orderIndex);
          await m.addColumn(exerciseSetLogs, exerciseSetLogs.setType);
          await m.addColumn(
              exerciseSetLogs, exerciseSetLogs.dropOfSetId);
        }
        await m.createTable(exerciseRoutineSetDefs);
        await m.createTable(cardioLogs);
        await m.createTable(exerciseConfig);
      }
      if (from < 5) {
        await m.addColumn(mealPlans, mealPlans.periodStart);
        await m.addColumn(mealPlans, mealPlans.periodEnd);
        await m.addColumn(mealPlans, mealPlans.dailyMealGoal);
      }
    },
  );
}
```

- [ ] **Step 3: Regenerate Drift code**

```bash
cd /home/jesuszelaya/Documents/kiolog
dart run build_runner build --delete-conflicting-outputs
```

Expected: exits 0, regenerates `app_database.g.dart` and `nutrition_dao.g.dart`.

- [ ] **Step 4: Fix MealPlan constructor in existing test**

The code gen changes the `MealPlan` data class to require `dailyMealGoal`, `periodStart`, `periodEnd`. Update `test/features/nutrition/presentation/nutrition_bloc_test.dart` — find the `final plan = MealPlan(...)` line and replace it:

```dart
final plan = MealPlan(
  id: 1,
  name: 'Plan',
  createdAt: DateTime.now(),
  isActive: true,
  dailyMealGoal: 4,
  periodStart: null,
  periodEnd: null,
);
```

- [ ] **Step 5: Verify no regressions**

```bash
flutter test test/features/nutrition/
```

Expected: All existing nutrition tests pass.

- [ ] **Step 6: Commit**

```bash
git add lib/core/database/tables/nutrition_tables.dart lib/core/database/app_database.dart lib/core/database/app_database.g.dart lib/core/dao/nutrition_dao.g.dart test/features/nutrition/presentation/nutrition_bloc_test.dart
git commit -m "feat(nutrition): schema v5 — periodStart, periodEnd, dailyMealGoal on MealPlans"
```

---

### Task 2: DAO — update setActivePlan + add getLogsInRange

**Files:**
- Modify: `lib/core/dao/nutrition_dao.dart`

- [ ] **Step 1: Update setActivePlan in NutritionDao**

Replace the `setActivePlan` method in `lib/core/dao/nutrition_dao.dart`:

```dart
Future<void> setActivePlan(int planId) async {
  final now = DateTime.now().toUtc();
  await db.transaction(() async {
    final plan = await (select(mealPlans)..where((t) => t.id.equals(planId)))
        .getSingleOrNull();
    if (plan == null) throw ArgumentError('Plan $planId not found');

    // Close period on currently active plan
    await (update(mealPlans)..where((t) => t.isActive.equals(true)))
        .write(MealPlansCompanion(
          isActive: const Value(false),
          periodEnd: Value(now),
        ));

    // Open period on new plan
    await (update(mealPlans)..where((t) => t.id.equals(planId)))
        .write(MealPlansCompanion(
          isActive: const Value(true),
          periodStart: Value(now),
          periodEnd: const Value(null),
        ));
  });
}
```

Add `getLogsInRange` after `getDailyMealLogs`:

```dart
Future<List<DailyMealLog>> getLogsInRange(DateTime from, DateTime to) =>
    (select(dailyMealLogs)
          ..where((t) =>
              t.date.isBiggerOrEqualValue(from) &
              t.date.isSmallerThanValue(to)))
        .get();
```

- [ ] **Step 2: Verify existing tests still pass**

```bash
flutter test test/features/nutrition/data/nutrition_repository_test.dart
```

Expected: All existing tests pass (the DAO behavior for setActivePlan is additive — period columns default to null).

- [ ] **Step 3: Commit DAO changes only**

```bash
git add lib/core/dao/nutrition_dao.dart
git commit -m "feat(nutrition): setActivePlan records period dates, add getLogsInRange"
```

---

### Task 3: NutritionWeeklyStat model + repository getWeeklyAdherence

**Files:**
- Create: `lib/features/nutrition/domain/models/nutrition_weekly_stat.dart`
- Modify: `lib/features/nutrition/domain/repositories/nutrition_repository.dart`
- Modify: `lib/features/nutrition/data/repositories/nutrition_repository_impl.dart`
- Modify: `test/features/nutrition/data/nutrition_repository_test.dart`

- [ ] **Step 1: Create the model**

Create `lib/features/nutrition/domain/models/nutrition_weekly_stat.dart`:

```dart
import 'package:equatable/equatable.dart';

class NutritionWeeklyStat extends Equatable {
  final DateTime weekStart;
  final int mealsLogged;
  final int mealsExpected;
  final int offPlanMeals;

  const NutritionWeeklyStat({
    required this.weekStart,
    required this.mealsLogged,
    required this.mealsExpected,
    required this.offPlanMeals,
  });

  double get adherencePct =>
      mealsExpected == 0 ? 0.0 : mealsLogged / mealsExpected;

  @override
  List<Object?> get props => [weekStart, mealsLogged, mealsExpected, offPlanMeals];
}
```

- [ ] **Step 2: Update repository interface**

Replace `lib/features/nutrition/domain/repositories/nutrition_repository.dart`:

```dart
import 'package:kiolog/core/database/app_database.dart';
import '../models/nutrition_weekly_stat.dart';

abstract class NutritionRepository {
  Future<MealPlan?> getActivePlan();
  Future<List<MealPlan>> getAllPlans();
  Future<void> activatePlan(int planId);
  Future<int> createPlan(String name, {required int dailyMealGoal});

  Future<List<MealPlanOption>> getPlanOptions(int planId, String mealType);
  Future<void> addPlanOption({
    required int planId,
    required String mealType,
    required int optionNumber,
    required String description,
  });

  Future<List<DailyMealLog>> getDailyLogs(DateTime date);
  Future<void> logMeal({
    required DateTime date,
    required String mealType,
    required int planOptionId,
  });
  Future<void> logOffPlanMeal({
    required DateTime date,
    required String mealType,
    required String description,
    String? photoPath,
  });
  Future<void> removeMealLog({
    required DateTime date,
    required String mealType,
  });

  Future<List<NutritionWeeklyStat>> getWeeklyAdherence({required int weeksBack});
}
```

- [ ] **Step 3: Update existing createPlan calls in repository test**

Updating the interface broke the old `createPlan('...')` calls. In `test/features/nutrition/data/nutrition_repository_test.dart`, find every `repository.createPlan(...)` call and add `dailyMealGoal: 4`:

```dart
// createPlan and getActivePlan test:
final id = await repository.createPlan('Plan Test', dailyMealGoal: 4);

// activatePlan test:
final id1 = await repository.createPlan('Plan A', dailyMealGoal: 4);
final id2 = await repository.createPlan('Plan B', dailyMealGoal: 4);

// addPlanOption test:
final planId = await repository.createPlan('Plan', dailyMealGoal: 4);

// logMeal test:
final planId = await repository.createPlan('Plan', dailyMealGoal: 4);

// logOffPlanMeal test (no createPlan call — no change needed)
```

- [ ] **Step 4: Write failing tests for getWeeklyAdherence and period tracking**

Add to `test/features/nutrition/data/nutrition_repository_test.dart` inside the `group` block:

```dart
test('getWeeklyAdherence returns correct adherence for current week', () async {
  // Create a plan with dailyMealGoal=2, activate it (sets periodStart to now)
  final planId = await repository.createPlan('Plan', dailyMealGoal: 2);
  await repository.activatePlan(planId);

  // Insert a plan option to log against
  final optId = await db.nutritionDao.insertMealPlanOption(
    MealPlanOptionsCompanion(
      planId: Value(planId),
      mealType: const Value('breakfast'),
      optionNumber: const Value(1),
      description: const Value('Avena'),
    ),
  );

  // Log 1 plan meal and 1 off-plan meal today
  final today = DateTime.now().toUtc();
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
  // mealsExpected = dailyMealGoal(2) * 1 day (today only, since periodStart is today)
  expect(stats.first.mealsExpected, greaterThan(0));
});

test('getWeeklyAdherence returns 0 expected when no plan active that week', () async {
  final stats = await repository.getWeeklyAdherence(weeksBack: 1);
  expect(stats.length, 1);
  expect(stats.first.mealsExpected, 0);
  expect(stats.first.mealsLogged, 0);
  expect(stats.first.adherencePct, 0.0);
});
```

- [ ] **Step 5: Run test to verify new tests fail**

```bash
flutter test test/features/nutrition/data/nutrition_repository_test.dart
```

Expected: FAIL — `getWeeklyAdherence` not implemented yet (existing tests should pass after Step 3).

- [ ] **Step 6: Implement createPlan and getWeeklyAdherence in NutritionRepositoryImpl**

Replace `lib/features/nutrition/data/repositories/nutrition_repository_impl.dart`:

```dart
import 'package:drift/drift.dart';
import 'package:kiolog/core/dao/nutrition_dao.dart';
import 'package:kiolog/core/database/app_database.dart';
import '../../domain/models/nutrition_weekly_stat.dart';
import '../../domain/repositories/nutrition_repository.dart';

class NutritionRepositoryImpl implements NutritionRepository {
  final NutritionDao _nutritionDao;

  NutritionRepositoryImpl(this._nutritionDao);

  DateTime _dateOnly(DateTime date) =>
      DateTime.utc(date.year, date.month, date.day);

  @override
  Future<MealPlan?> getActivePlan() => _nutritionDao.getActiveMealPlan();

  @override
  Future<List<MealPlan>> getAllPlans() => _nutritionDao.getMealPlans();

  @override
  Future<void> activatePlan(int planId) => _nutritionDao.setActivePlan(planId);

  @override
  Future<int> createPlan(String name, {required int dailyMealGoal}) =>
      _nutritionDao.insertMealPlan(
        MealPlansCompanion(
          name: Value(name),
          dailyMealGoal: Value(dailyMealGoal),
        ),
      );

  @override
  Future<List<MealPlanOption>> getPlanOptions(
    int planId,
    String mealType,
  ) =>
      _nutritionDao.getMealPlanOptions(planId, mealType);

  @override
  Future<void> addPlanOption({
    required int planId,
    required String mealType,
    required int optionNumber,
    required String description,
  }) =>
      _nutritionDao.insertMealPlanOption(
        MealPlanOptionsCompanion(
          planId: Value(planId),
          mealType: Value(mealType),
          optionNumber: Value(optionNumber),
          description: Value(description),
        ),
      );

  @override
  Future<List<DailyMealLog>> getDailyLogs(DateTime date) =>
      _nutritionDao.getDailyMealLogs(_dateOnly(date));

  @override
  Future<void> logMeal({
    required DateTime date,
    required String mealType,
    required int planOptionId,
  }) =>
      _nutritionDao.insertDailyMealLog(
        DailyMealLogsCompanion(
          date: Value(_dateOnly(date)),
          mealType: Value(mealType),
          planOptionId: Value(planOptionId),
        ),
      );

  @override
  Future<void> logOffPlanMeal({
    required DateTime date,
    required String mealType,
    required String description,
    String? photoPath,
  }) =>
      _nutritionDao.insertDailyMealLog(
        DailyMealLogsCompanion(
          date: Value(_dateOnly(date)),
          mealType: Value(mealType),
          freeDescription: Value(description),
          photoPath: Value(photoPath),
        ),
      );

  @override
  Future<void> removeMealLog({
    required DateTime date,
    required String mealType,
  }) =>
      _nutritionDao.deleteDailyMealLog(_dateOnly(date), mealType);

  @override
  Future<List<NutritionWeeklyStat>> getWeeklyAdherence(
      {required int weeksBack}) async {
    final now = DateTime.now().toUtc();
    final todayMidnight = DateTime.utc(now.year, now.month, now.day);
    final daysToMonday = todayMidnight.weekday - 1; // Monday=1
    final currentWeekMonday =
        todayMidnight.subtract(Duration(days: daysToMonday));

    final rangeStart =
        currentWeekMonday.subtract(Duration(days: 7 * (weeksBack - 1)));
    final rangeEnd = todayMidnight.add(const Duration(days: 1));

    final allPlans = await _nutritionDao.getMealPlans();
    final allLogs =
        await _nutritionDao.getLogsInRange(rangeStart, rangeEnd);

    final result = <NutritionWeeklyStat>[];

    for (int w = weeksBack - 1; w >= 0; w--) {
      final weekStart =
          currentWeekMonday.subtract(Duration(days: 7 * w));
      int mealsLogged = 0;
      int mealsExpected = 0;
      int offPlanMeals = 0;

      for (int d = 0; d < 7; d++) {
        final day = weekStart.add(Duration(days: d));
        if (day.isAfter(todayMidnight)) break;

        // Find plan active on this day
        MealPlan? activePlan;
        for (final plan in allPlans) {
          final start = plan.periodStart;
          final end = plan.periodEnd;
          if (start == null) continue;
          final startDay = DateTime.utc(start.year, start.month, start.day);
          if (startDay.isAfter(day)) continue;
          if (end != null) {
            final endDay = DateTime.utc(end.year, end.month, end.day);
            if (!endDay.isAfter(day)) continue;
          }
          activePlan = plan;
          break;
        }

        if (activePlan == null) continue;

        mealsExpected += activePlan.dailyMealGoal;

        for (final log in allLogs) {
          final logDay =
              DateTime.utc(log.date.year, log.date.month, log.date.day);
          if (logDay != day) continue;
          if (log.planOptionId != null) {
            mealsLogged++;
          } else {
            offPlanMeals++;
          }
        }
      }

      result.add(NutritionWeeklyStat(
        weekStart: weekStart,
        mealsLogged: mealsLogged,
        mealsExpected: mealsExpected,
        offPlanMeals: offPlanMeals,
      ));
    }

    return result;
  }
}
```

- [ ] **Step 7: Run tests**

```bash
flutter test test/features/nutrition/data/nutrition_repository_test.dart
```

Expected: All tests pass.

- [ ] **Step 8: Commit**

```bash
git add lib/features/nutrition/domain/models/nutrition_weekly_stat.dart \
        lib/features/nutrition/domain/repositories/nutrition_repository.dart \
        lib/features/nutrition/data/repositories/nutrition_repository_impl.dart \
        test/features/nutrition/data/nutrition_repository_test.dart
git commit -m "feat(nutrition): NutritionWeeklyStat model + getWeeklyAdherence repository method"
```

---

### Task 4: BLoC — weeklyAdherence in state, dailyMealGoal in event

**Files:**
- Modify: `lib/features/nutrition/presentation/bloc/nutrition_event.dart`
- Modify: `lib/features/nutrition/presentation/bloc/nutrition_state.dart`
- Modify: `lib/features/nutrition/presentation/bloc/nutrition_bloc.dart`
- Modify: `test/features/nutrition/presentation/nutrition_bloc_test.dart`

- [ ] **Step 1: Update NutritionPlanCreated event**

In `lib/features/nutrition/presentation/bloc/nutrition_event.dart`, replace the `NutritionPlanCreated` class:

```dart
class NutritionPlanCreated extends NutritionEvent {
  final String name;
  final int dailyMealGoal;

  const NutritionPlanCreated({required this.name, required this.dailyMealGoal});

  @override
  List<Object?> get props => [name, dailyMealGoal];
}
```

- [ ] **Step 2: Update NutritionState**

In `lib/features/nutrition/presentation/bloc/nutrition_state.dart`, add `weeklyAdherence` field:

```dart
import 'package:equatable/equatable.dart';
import 'package:kiolog/core/database/app_database.dart';
import '../../domain/models/nutrition_weekly_stat.dart';

enum NutritionStatus { initial, loading, success, failure }

class NutritionState extends Equatable {
  final NutritionStatus status;
  final MealPlan? activePlan;
  final List<MealPlan> allPlans;
  final Map<String, List<MealPlanOption>> planOptions;
  final List<DailyMealLog> dailyLogs;
  final List<NutritionWeeklyStat> weeklyAdherence;
  final String? error;

  const NutritionState({
    this.status = NutritionStatus.initial,
    this.activePlan,
    this.allPlans = const [],
    this.planOptions = const {},
    this.dailyLogs = const [],
    this.weeklyAdherence = const [],
    this.error,
  });

  bool isMealLogged(String mealType) =>
      dailyLogs.any((log) => log.mealType == mealType);

  DailyMealLog? getLogForMeal(String mealType) =>
      dailyLogs.where((log) => log.mealType == mealType).firstOrNull;

  NutritionState copyWith({
    NutritionStatus? status,
    MealPlan? activePlan,
    List<MealPlan>? allPlans,
    Map<String, List<MealPlanOption>>? planOptions,
    List<DailyMealLog>? dailyLogs,
    List<NutritionWeeklyStat>? weeklyAdherence,
    String? error,
  }) =>
      NutritionState(
        status: status ?? this.status,
        activePlan: activePlan ?? this.activePlan,
        allPlans: allPlans ?? this.allPlans,
        planOptions: planOptions ?? this.planOptions,
        dailyLogs: dailyLogs ?? this.dailyLogs,
        weeklyAdherence: weeklyAdherence ?? this.weeklyAdherence,
        error: error,
      );

  @override
  List<Object?> get props =>
      [status, activePlan, allPlans, planOptions, dailyLogs, weeklyAdherence, error];
}
```

- [ ] **Step 3: Update NutritionBloc**

In `lib/features/nutrition/presentation/bloc/nutrition_bloc.dart`:

Replace `_onLoaded` to also load `weeklyAdherence`:

```dart
Future<void> _onLoaded(NutritionLoaded event, Emitter<NutritionState> emit) async {
  emit(state.copyWith(status: NutritionStatus.loading));
  try {
    final plan = await _repository.getActivePlan();
    final logs = await _repository.getDailyLogs(event.date);
    final options = <String, List<MealPlanOption>>{};

    if (plan != null) {
      for (final mealType in ['breakfast', 'lunch', 'dinner', 'snack']) {
        final opts = await _repository.getPlanOptions(plan.id, mealType);
        options[mealType] = opts;
      }
    }

    final adherence = await _repository.getWeeklyAdherence(weeksBack: 8);

    emit(state.copyWith(
      status: NutritionStatus.success,
      activePlan: plan,
      dailyLogs: logs,
      planOptions: options,
      weeklyAdherence: adherence,
    ));
  } catch (e) {
    emit(state.copyWith(status: NutritionStatus.failure, error: e.toString()));
  }
}
```

Replace `_onPlanCreated` to pass `dailyMealGoal`:

```dart
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
```

- [ ] **Step 4: Update existing bloc tests**

Replace `test/features/nutrition/presentation/nutrition_bloc_test.dart`:

```dart
import 'package:bloc_test/bloc_test.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kiolog/core/database/app_database.dart';
import 'package:kiolog/features/nutrition/domain/models/nutrition_weekly_stat.dart';
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
      createdAt: DateTime.now(),
      isActive: true,
      dailyMealGoal: 4,
      periodStart: null,
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

    blocTest<NutritionBloc, NutritionState>(
      'emits [loading, success] when NutritionLoaded succeeds',
      build: () {
        when(() => repository.getActivePlan()).thenAnswer((_) async => plan);
        when(() => repository.getDailyLogs(any())).thenAnswer((_) async => []);
        when(() => repository.getPlanOptions(any(), 'breakfast'))
            .thenAnswer((_) async => options);
        when(() => repository.getPlanOptions(any(), 'lunch'))
            .thenAnswer((_) async => []);
        when(() => repository.getPlanOptions(any(), 'dinner'))
            .thenAnswer((_) async => []);
        when(() => repository.getPlanOptions(any(), 'snack'))
            .thenAnswer((_) async => []);
        when(() => repository.getWeeklyAdherence(weeksBack: 8))
            .thenAnswer((_) async => []);
        return NutritionBloc(repository);
      },
      act: (bloc) => bloc.add(NutritionLoaded(date: DateTime(2026, 6, 8))),
      expect: () => [
        const NutritionState(status: NutritionStatus.loading),
        NutritionState(
          status: NutritionStatus.success,
          activePlan: plan,
          planOptions: {
            'breakfast': options,
            'lunch': [],
            'dinner': [],
            'snack': []
          },
        ),
      ],
    );

    blocTest<NutritionBloc, NutritionState>(
      'logs meal and refreshes daily logs',
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
        return NutritionBloc(repository)
          ..emit(const NutritionState(status: NutritionStatus.success));
      },
      act: (bloc) => bloc.add(NutritionMealLogged(
        date: DateTime(2026, 6, 8),
        mealType: 'breakfast',
        planOptionId: 1,
      )),
      expect: () => [
        NutritionState(
          status: NutritionStatus.success,
          dailyLogs: [
            DailyMealLog(
                id: 1,
                date: DateTime(2026, 6, 8),
                mealType: 'breakfast',
                planOptionId: 1,
                freeDescription: null,
                photoPath: null),
          ],
        ),
      ],
    );

    blocTest<NutritionBloc, NutritionState>(
      'activates plan and refreshes',
      build: () {
        when(() => repository.activatePlan(any())).thenAnswer((_) async {});
        when(() => repository.getActivePlan()).thenAnswer((_) async => plan);
        when(() => repository.getAllPlans()).thenAnswer((_) async => [plan]);
        return NutritionBloc(repository);
      },
      act: (bloc) => bloc.add(const NutritionPlanActivated(planId: 1)),
      expect: () => [
        NutritionState(activePlan: plan, allPlans: [plan]),
      ],
    );

    blocTest<NutritionBloc, NutritionState>(
      'creates plan with dailyMealGoal',
      build: () {
        when(() => repository.createPlan(any(), dailyMealGoal: any(named: 'dailyMealGoal')))
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
  });
}
```

- [ ] **Step 5: Run all nutrition tests**

```bash
flutter test test/features/nutrition/
```

Expected: All tests pass.

- [ ] **Step 6: Commit**

```bash
git add lib/features/nutrition/presentation/bloc/ \
        test/features/nutrition/presentation/nutrition_bloc_test.dart
git commit -m "feat(nutrition): bloc — weeklyAdherence in state, dailyMealGoal in NutritionPlanCreated"
```

---

### Task 5: NutritionProgressPage

**Files:**
- Create: `lib/features/nutrition/presentation/pages/nutrition_progress_page.dart`
- Modify: `lib/features/nutrition/presentation/pages/nutrition_page.dart`

- [ ] **Step 1: Create NutritionProgressPage**

Create `lib/features/nutrition/presentation/pages/nutrition_progress_page.dart`:

```dart
import 'dart:math' show max;
import 'package:flutter/foundation.dart' show listEquals;
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../bloc/nutrition_bloc.dart';
import '../bloc/nutrition_state.dart';
import '../../domain/models/nutrition_weekly_stat.dart';

enum _Periodo { semana, mes }

class NutritionProgressPage extends StatefulWidget {
  const NutritionProgressPage({super.key});

  @override
  State<NutritionProgressPage> createState() => _NutritionProgressPageState();
}

class _NutritionProgressPageState extends State<NutritionProgressPage> {
  _Periodo _periodo = _Periodo.semana;
  int _weekOffset = 0;
  int _monthOffset = 0;

  static const _orange = Colors.orange;

  // ── helpers ──────────────────────────────────────────────────────────────

  DateTime _currentWeekMonday() {
    final now = DateTime.now().toUtc();
    final today = DateTime.utc(now.year, now.month, now.day);
    return today.subtract(Duration(days: today.weekday - 1));
  }

  DateTime _weekMondayAt(int offset) =>
      _currentWeekMonday().add(Duration(days: 7 * offset));

  DateTime _monthStartAt(int offset) {
    final now = DateTime.now().toUtc();
    final year = now.year + ((now.month - 1 + offset) ~/ 12);
    final month = ((now.month - 1 + offset) % 12) + 1;
    return DateTime.utc(year, month, 1);
  }

  // ── data helpers ─────────────────────────────────────────────────────────

  NutritionWeeklyStat? _statAt(
      List<NutritionWeeklyStat> stats, int weekOffset) {
    final idx = stats.length - 1 + weekOffset;
    if (idx < 0 || idx >= stats.length) return null;
    return stats[idx];
  }

  List<NutritionWeeklyStat> _weeksInMonth(
      List<NutritionWeeklyStat> stats, int monthOffset) {
    final ms = _monthStartAt(monthOffset);
    return stats.where((s) => s.weekStart.month == ms.month && s.weekStart.year == ms.year).toList();
  }

  // ── semana chips ─────────────────────────────────────────────────────────

  Widget _buildSemanaChips(NutritionState state) {
    final stat = _statAt(state.weeklyAdherence, _weekOffset);
    final pct = stat == null || stat.mealsExpected == 0
        ? null
        : (stat.adherencePct * 100).round();
    final logged = stat?.mealsLogged ?? 0;
    final offPlan = stat?.offPlanMeals ?? 0;

    return Row(children: [
      _Chip(
        value: pct == null ? '—' : '$pct%',
        label: 'adherencia',
        color: _orange,
      ),
      const SizedBox(width: 8),
      _Chip(value: '$logged', label: 'comidas plan', color: Colors.green),
      const SizedBox(width: 8),
      _Chip(
          value: '$offPlan',
          label: 'fuera plan',
          color: Colors.blueGrey),
    ]);
  }

  // ── mes chips ────────────────────────────────────────────────────────────

  Widget _buildMesChips(NutritionState state) {
    final weeks = _weeksInMonth(state.weeklyAdherence, _monthOffset);
    final totalLogged = weeks.fold(0, (s, w) => s + w.mealsLogged);
    final totalExpected = weeks.fold(0, (s, w) => s + w.mealsExpected);
    final totalOff = weeks.fold(0, (s, w) => s + w.offPlanMeals);
    final pct = totalExpected == 0
        ? null
        : (totalLogged / totalExpected * 100).round();

    return Row(children: [
      _Chip(
        value: pct == null ? '—' : '$pct%',
        label: 'adherencia',
        color: _orange,
      ),
      const SizedBox(width: 8),
      _Chip(
          value: '$totalLogged', label: 'comidas plan', color: Colors.green),
      const SizedBox(width: 8),
      _Chip(
          value: '$totalOff', label: 'fuera plan', color: Colors.blueGrey),
    ]);
  }

  // ── week navigator ───────────────────────────────────────────────────────

  Widget _buildWeekNavigator(List<NutritionWeeklyStat> stats) {
    final monday = _weekMondayAt(_weekOffset);
    final sunday = monday.add(const Duration(days: 6));
    final months = ['ene','feb','mar','abr','may','jun','jul','ago','sep','oct','nov','dic'];

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
    final canGoBack = stats.isNotEmpty && _weekOffset > -(stats.length - 1);

    return _Navigator(
      label: label,
      subtitle: sub,
      onBack: canGoBack ? () => setState(() => _weekOffset--) : null,
      onForward: _weekOffset < 0 ? () => setState(() => _weekOffset++) : null,
    );
  }

  // ── month navigator ──────────────────────────────────────────────────────

  Widget _buildMonthNavigator(List<NutritionWeeklyStat> stats) {
    final ms = _monthStartAt(_monthOffset);
    final months = ['Enero','Febrero','Marzo','Abril','Mayo','Junio','Julio','Agosto','Septiembre','Octubre','Noviembre','Diciembre'];
    final label = '${months[ms.month - 1]} ${ms.year}';
    final sub = _monthOffset == 0
        ? 'mes actual'
        : 'hace ${-_monthOffset} mes${-_monthOffset == 1 ? '' : 'es'}';

    // Can go back if there are stats older than this month
    final canGoBack = stats.any((s) =>
        s.weekStart.isBefore(DateTime.utc(ms.year, ms.month, 1)));

    return _Navigator(
      label: label,
      subtitle: sub,
      onBack: canGoBack ? () => setState(() => _monthOffset--) : null,
      onForward:
          _monthOffset < 0 ? () => setState(() => _monthOffset++) : null,
    );
  }

  // ── bar chart helpers ─────────────────────────────────────────────────────

  Widget _buildWeekBarChart(List<NutritionWeeklyStat> stats) {
    if (stats.isEmpty) return const SizedBox.shrink();
    final bars = stats
        .map((s) => (s.mealsLogged, s.mealsExpected))
        .toList();
    return _AdherenceBarChart(
      bars: bars,
      barColor: _orange,
      lastBarIsPartial: true,
    );
  }

  Widget _buildMonthBarChart(List<NutritionWeeklyStat> stats) {
    final ms = _monthStartAt(_monthOffset);
    final weeks = _weeksInMonth(stats, _monthOffset);
    if (weeks.isEmpty) return const SizedBox.shrink();
    final bars = weeks.map((s) => (s.mealsLogged, s.mealsExpected)).toList();
    final isCurrentMonth = _monthOffset == 0;
    return _AdherenceBarChart(
      bars: bars,
      barColor: _orange,
      lastBarIsPartial: isCurrentMonth,
    );
  }

  // ── build ─────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Progreso Nutrición')),
      body: BlocBuilder<NutritionBloc, NutritionState>(
        builder: (context, state) {
          final stats = state.weeklyAdherence;
          return SafeArea(
            child: ListView(
              padding: const EdgeInsets.all(16),
              children: [
                // Period toggle
                _PeriodToggle(
                  selected: _periodo,
                  onChanged: (p) => setState(() => _periodo = p),
                ),
                const SizedBox(height: 16),
                // Navigator
                if (_periodo == _Periodo.semana)
                  _buildWeekNavigator(stats)
                else
                  _buildMonthNavigator(stats),
                const SizedBox(height: 16),
                // Chips
                if (_periodo == _Periodo.semana)
                  _buildSemanaChips(state)
                else
                  _buildMesChips(state),
                const SizedBox(height: 20),
                // Chart
                if (_periodo == _Periodo.semana)
                  _buildWeekBarChart(stats)
                else
                  _buildMonthBarChart(stats),
              ],
            ),
          );
        },
      ),
    );
  }
}

// ── shared sub-widgets ────────────────────────────────────────────────────

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
        icon: const Icon(Icons.chevron_left),
        onPressed: onBack,
      ),
      Expanded(
        child: Column(children: [
          Text(label,
              style: Theme.of(context).textTheme.titleMedium,
              textAlign: TextAlign.center),
          Text(subtitle,
              style: Theme.of(context)
                  .textTheme
                  .bodySmall
                  ?.copyWith(color: Colors.orange),
              textAlign: TextAlign.center),
        ]),
      ),
      IconButton(
        icon: const Icon(Icons.chevron_right),
        onPressed: onForward,
      ),
    ]);
  }
}

class _Chip extends StatelessWidget {
  final String value;
  final String label;
  final Color color;

  const _Chip({required this.value, required this.label, required this.color});

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 10),
        decoration: BoxDecoration(
          color: color.withOpacity(0.1),
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: color.withOpacity(0.3)),
        ),
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          Text(value,
              style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                  color: color)),
          const SizedBox(height: 2),
          Text(label,
              style: Theme.of(context)
                  .textTheme
                  .labelSmall
                  ?.copyWith(color: Colors.grey)),
        ]),
      ),
    );
  }
}

// ── bar chart ─────────────────────────────────────────────────────────────

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
                    color: Theme.of(context).colorScheme.onSurfaceVariant,
                  ),
            ),
            Text(
              'actual',
              style: Theme.of(context)
                  .textTheme
                  .labelSmall
                  ?.copyWith(color: barColor),
            ),
          ],
        ),
      ]),
    );
  }
}

class _BarChartPainter extends CustomPainter {
  final List<(int logged, int expected)> bars;
  final Color barColor;
  final bool lastBarIsPartial;

  const _BarChartPainter({
    required this.bars,
    required this.barColor,
    required this.lastBarIsPartial,
  });

  @override
  bool shouldRepaint(_BarChartPainter old) =>
      old.lastBarIsPartial != lastBarIsPartial ||
      !listEquals(old.bars, bars);

  @override
  void paint(Canvas canvas, Size size) {
    if (bars.isEmpty) return;

    const gap = 4.0;
    final barW = (size.width - gap * (bars.length - 1)) / bars.length;
    final chartH = size.height;

    // Dashed goal line at top
    final goalPaint = Paint()
      ..color = barColor.withOpacity(0.4)
      ..strokeWidth = 1;
    _drawDashedLine(canvas, Offset(0, 0), Offset(size.width, 0), goalPaint);

    for (int i = 0; i < bars.length; i++) {
      final (logged, expected) = bars[i];
      final x = i * (barW + gap);
      final pct = expected == 0 ? 0.0 : (logged / expected).clamp(0.0, 1.0);
      final barH = pct * chartH;
      final isPartial = lastBarIsPartial && i == bars.length - 1;
      final isNoData = expected == 0;

      final rect = Rect.fromLTWH(x, chartH - barH, barW, barH);

      if (isNoData) {
        // Grey empty bar placeholder
        final emptyPaint = Paint()..color = Colors.grey.shade800;
        canvas.drawRRect(
          RRect.fromRectAndCorners(
            Rect.fromLTWH(x, chartH - 4, barW, 4),
            topLeft: const Radius.circular(2),
            topRight: const Radius.circular(2),
          ),
          emptyPaint,
        );
        continue;
      }

      if (isPartial) {
        // Dashed border partial bar
        final fillPaint = Paint()..color = barColor.withOpacity(0.25);
        canvas.drawRRect(
          RRect.fromRectAndCorners(rect,
              topLeft: const Radius.circular(3),
              topRight: const Radius.circular(3)),
          fillPaint,
        );
        final dashPaint = Paint()
          ..color = barColor.withOpacity(0.8)
          ..strokeWidth = 1
          ..style = PaintingStyle.stroke;
        _drawDashedRect(canvas, rect, dashPaint);
      } else {
        final fillPaint = Paint()..color = barColor.withOpacity(0.85);
        canvas.drawRRect(
          RRect.fromRectAndCorners(rect,
              topLeft: const Radius.circular(3),
              topRight: const Radius.circular(3)),
          fillPaint,
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
    final dist = (dx * dx + dy * dy).abs();
    final steps = (dist / (dashLen + gapLen)).floor();
    final stepX = dx / (steps * 2);
    final stepY = dy / (steps * 2);
    for (int i = 0; i < steps; i++) {
      final start = Offset(p1.dx + i * 2 * stepX, p1.dy + i * 2 * stepY);
      final end = Offset(start.dx + stepX, start.dy + stepY);
      canvas.drawLine(start, end, paint);
    }
  }

  void _drawDashedRect(Canvas canvas, Rect rect, Paint paint) {
    _drawDashedLine(
        canvas, rect.topLeft, rect.topRight, paint);
    _drawDashedLine(
        canvas, rect.topRight, rect.bottomRight, paint);
    _drawDashedLine(
        canvas, rect.bottomRight, rect.bottomLeft, paint);
    _drawDashedLine(
        canvas, rect.bottomLeft, rect.topLeft, paint);
  }
}
```

- [ ] **Step 2: Add 📊 icon and update plan creation dialog in NutritionPage**

In `lib/features/nutrition/presentation/pages/nutrition_page.dart`:

Add the import at the top:
```dart
import 'nutrition_progress_page.dart';
```

Replace the `appBar` in `_NutritionView.build`:
```dart
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
```

Replace `_showCreatePlanDialog` with the version that includes a `dailyMealGoal` stepper:
```dart
void _showCreatePlanDialog(BuildContext context) {
  final nameController = TextEditingController();
  int goalValue = 4;

  showDialog(
    context: context,
    builder: (dialogContext) => StatefulBuilder(
      builder: (ctx, setLocalState) => AlertDialog(
        title: const Text('Nuevo plan alimenticio'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: nameController,
              decoration: const InputDecoration(labelText: 'Nombre del plan'),
              autofocus: true,
            ),
            const SizedBox(height: 16),
            Row(children: [
              const Expanded(child: Text('Comidas por día')),
              IconButton(
                icon: const Icon(Icons.remove),
                onPressed: goalValue > 1
                    ? () => setLocalState(() => goalValue--)
                    : null,
              ),
              Text('$goalValue',
                  style: const TextStyle(
                      fontSize: 18, fontWeight: FontWeight.bold)),
              IconButton(
                icon: const Icon(Icons.add),
                onPressed: goalValue < 10
                    ? () => setLocalState(() => goalValue++)
                    : null,
              ),
            ]),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: const Text('Cancelar'),
          ),
          FilledButton(
            onPressed: () {
              if (nameController.text.isNotEmpty) {
                context.read<NutritionBloc>().add(
                      NutritionPlanCreated(
                        name: nameController.text,
                        dailyMealGoal: goalValue,
                      ),
                    );
              }
              Navigator.pop(dialogContext);
            },
            child: const Text('Crear'),
          ),
        ],
      ),
    ),
  );
}
```

- [ ] **Step 3: Verify compile**

```bash
flutter analyze lib/features/nutrition/
```

Expected: No errors.

- [ ] **Step 4: Commit**

```bash
git add lib/features/nutrition/presentation/pages/
git commit -m "feat(nutrition): NutritionProgressPage + 📊 AppBar icon + dailyMealGoal in plan dialog"
```

---

### Task 6: Widget tests for NutritionProgressPage

**Files:**
- Create: `test/features/nutrition/presentation/nutrition_progress_page_test.dart`

- [ ] **Step 1: Write all 6 widget tests**

Create `test/features/nutrition/presentation/nutrition_progress_page_test.dart`:

```dart
import 'package:bloc_test/bloc_test.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kiolog/core/database/app_database.dart';
import 'package:kiolog/features/nutrition/domain/models/nutrition_weekly_stat.dart';
import 'package:kiolog/features/nutrition/presentation/bloc/nutrition_bloc.dart';
import 'package:kiolog/features/nutrition/presentation/bloc/nutrition_event.dart';
import 'package:kiolog/features/nutrition/presentation/bloc/nutrition_state.dart';
import 'package:kiolog/features/nutrition/presentation/pages/nutrition_progress_page.dart';
import 'package:mocktail/mocktail.dart';

class MockNutritionBloc
    extends MockBloc<NutritionEvent, NutritionState>
    implements NutritionBloc {}

Widget _wrap(NutritionBloc bloc) => MaterialApp(
      home: BlocProvider<NutritionBloc>.value(
        value: bloc,
        child: const NutritionProgressPage(),
      ),
    );

NutritionState _state({
  List<NutritionWeeklyStat> weeklyAdherence = const [],
}) =>
    NutritionState(
      status: NutritionStatus.success,
      weeklyAdherence: weeklyAdherence,
    );

NutritionWeeklyStat _stat({
  required DateTime weekStart,
  int logged = 0,
  int expected = 0,
  int offPlan = 0,
}) =>
    NutritionWeeklyStat(
      weekStart: weekStart,
      mealsLogged: logged,
      mealsExpected: expected,
      offPlanMeals: offPlan,
    );

void main() {
  late MockNutritionBloc bloc;

  setUpAll(() {
    registerFallbackValue(NutritionLoaded(date: DateTime(2026)));
  });

  setUp(() => bloc = MockNutritionBloc());

  group('NutritionProgressPage', () {
    testWidgets('semana chips show correct adherence %', (tester) async {
      final now = DateTime.now().toUtc();
      final monday = now.subtract(Duration(days: now.weekday - 1));
      final weekStart = DateTime.utc(monday.year, monday.month, monday.day);

      final stats = [
        _stat(weekStart: weekStart, logged: 3, expected: 4, offPlan: 1),
      ];
      whenListen(bloc, const Stream<NutritionState>.empty(),
          initialState: _state(weeklyAdherence: stats));

      await tester.pumpWidget(_wrap(bloc));
      await tester.pump();

      // 3/4 = 75%
      expect(find.text('75%'), findsOneWidget);
      // comidas plan
      expect(find.text('3'), findsOneWidget);
      // fuera plan
      expect(find.text('1'), findsOneWidget);
    });

    testWidgets('week › button disabled at weekOffset 0', (tester) async {
      whenListen(bloc, const Stream<NutritionState>.empty(),
          initialState: _state());

      await tester.pumpWidget(_wrap(bloc));
      await tester.pump();

      final rightBtn = tester.widget<IconButton>(
          find.widgetWithIcon(IconButton, Icons.chevron_right));
      expect(rightBtn.onPressed, isNull);
    });

    testWidgets('tapping ‹ enables ›', (tester) async {
      final now = DateTime.now().toUtc();
      final monday = now.subtract(Duration(days: now.weekday - 1));
      final w1 = DateTime.utc(monday.year, monday.month, monday.day)
          .subtract(const Duration(days: 7));
      final w2 = DateTime.utc(monday.year, monday.month, monday.day);

      whenListen(bloc, const Stream<NutritionState>.empty(),
          initialState: _state(weeklyAdherence: [
            _stat(weekStart: w1),
            _stat(weekStart: w2),
          ]));

      await tester.pumpWidget(_wrap(bloc));
      await tester.pump();

      await tester.tap(find.widgetWithIcon(IconButton, Icons.chevron_left));
      await tester.pump();

      final rightBtn = tester.widget<IconButton>(
          find.widgetWithIcon(IconButton, Icons.chevron_right));
      expect(rightBtn.onPressed, isNotNull);
    });

    testWidgets('switching to Mes shows monthly % chip', (tester) async {
      final now = DateTime.now().toUtc();
      final monday = now.subtract(Duration(days: now.weekday - 1));
      final weekStart = DateTime.utc(monday.year, monday.month, monday.day);

      whenListen(bloc, const Stream<NutritionState>.empty(),
          initialState: _state(weeklyAdherence: [
            _stat(weekStart: weekStart, logged: 2, expected: 4),
          ]));

      await tester.pumpWidget(_wrap(bloc));
      await tester.pump();

      await tester.tap(find.text('Mes'));
      await tester.pump();

      // 2/4 = 50%
      expect(find.text('50%'), findsOneWidget);
    });

    testWidgets('weeks with no plan show — in adherencia chip', (tester) async {
      final now = DateTime.now().toUtc();
      final monday = now.subtract(Duration(days: now.weekday - 1));
      final weekStart = DateTime.utc(monday.year, monday.month, monday.day);

      whenListen(bloc, const Stream<NutritionState>.empty(),
          initialState: _state(weeklyAdherence: [
            _stat(weekStart: weekStart, logged: 0, expected: 0),
          ]));

      await tester.pumpWidget(_wrap(bloc));
      await tester.pump();

      expect(find.text('—'), findsOneWidget);
    });

    testWidgets('renders without crash when weeklyAdherence is empty',
        (tester) async {
      whenListen(bloc, const Stream<NutritionState>.empty(),
          initialState: _state());

      await tester.pumpWidget(_wrap(bloc));
      await tester.pump();

      expect(tester.takeException(), isNull);
    });
  });
}
```

- [ ] **Step 2: Run the tests**

```bash
flutter test test/features/nutrition/presentation/nutrition_progress_page_test.dart -v
```

Expected: All 6 tests pass.

- [ ] **Step 3: Run full test suite**

```bash
flutter test
```

Expected: All tests pass (no regressions).

- [ ] **Step 4: Commit**

```bash
git add test/features/nutrition/presentation/nutrition_progress_page_test.dart
git commit -m "test(nutrition): widget tests for NutritionProgressPage"
```
