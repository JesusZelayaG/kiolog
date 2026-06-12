# Detailed Report PDF Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Expand the health report with detailed nutrition (meal plan + frequency bars) and exercise (weekly compliance bars + cardio/libre counts) sections, exported as a shareable PDF via `share_plus`.

**Architecture:** Sub-models + PDF service. `ReportData` gains two nullable nested objects (`NutritionReportData`, `ExerciseReportData`). A new `PdfReportService` static class handles all PDF generation. `report_page.dart` stays thin — it shows a matching in-app preview and delegates PDF export to the service.

**Tech Stack:** Flutter/Dart, Drift ORM, `pdf: ^3.10.7`, `share_plus: ^12.0.2`, `path_provider: ^2.1.4`, `intl: ^0.19.0`

---

## File Map

| Action | File |
|--------|------|
| Modify | `lib/features/reports/domain/repositories/report_repository.dart` |
| Modify | `lib/core/dao/exercise_dao.dart` |
| Modify | `lib/features/reports/data/repositories/report_repository_impl.dart` |
| Create | `lib/features/reports/data/pdf_report_service.dart` |
| Modify | `lib/features/reports/presentation/pages/report_page.dart` |
| Modify | `test/dao/exercise_dao_test.dart` |
| Modify | `test/features/reports/data/report_repository_test.dart` |

---

## Task 1: Expand data models in report_repository.dart

**Files:**
- Modify: `lib/features/reports/domain/repositories/report_repository.dart`

- [ ] **Step 1: Add the 4 new model classes and expand `ReportData`**

Replace the entire file with:

```dart
import 'package:kiolog/core/database/app_database.dart';

class MealFrequencyEntry {
  final String mealType;
  final String description;
  final int count;

  const MealFrequencyEntry({
    required this.mealType,
    required this.description,
    required this.count,
  });
}

class WeeklyComplianceEntry {
  final String weekLabel;
  final int daysDone;
  final int daysGoal;

  const WeeklyComplianceEntry({
    required this.weekLabel,
    required this.daysDone,
    required this.daysGoal,
  });
}

class NutritionReportData {
  final String? planName;
  final List<MealFrequencyEntry> mealFrequencies;

  const NutritionReportData({
    required this.planName,
    required this.mealFrequencies,
  });
}

class ExerciseReportData {
  final String? planName;
  final List<WeeklyComplianceEntry> weeklyCompliance;
  final int totalRoutineSessions;
  final int cardioSessionsCount;
  final int freeExerciseCount;

  const ExerciseReportData({
    required this.planName,
    required this.weeklyCompliance,
    required this.totalRoutineSessions,
    required this.cardioSessionsCount,
    required this.freeExerciseCount,
  });
}

class ReportData {
  final DateTime start;
  final DateTime end;
  final int waterGoalDays;
  final int waterTotalDays;
  final int mealsLogged;
  final int mealsTotal;
  final int exerciseDays;
  final int exerciseTotalDays;
  final double? sleepAverage;
  final List<WeightLog> weightLogs;
  final Measurement? latestMeasurement;
  final NutritionReportData? nutritionDetail;
  final ExerciseReportData? exerciseDetail;

  ReportData({
    required this.start,
    required this.end,
    required this.waterGoalDays,
    required this.waterTotalDays,
    required this.mealsLogged,
    required this.mealsTotal,
    required this.exerciseDays,
    required this.exerciseTotalDays,
    this.sleepAverage,
    required this.weightLogs,
    this.latestMeasurement,
    this.nutritionDetail,
    this.exerciseDetail,
  });

  double get waterCompliance =>
      waterTotalDays > 0 ? waterGoalDays / waterTotalDays : 0.0;

  double get nutritionCompliance =>
      mealsTotal > 0 ? mealsLogged / mealsTotal : 0.0;

  double get exerciseCompliance =>
      exerciseTotalDays > 0 ? exerciseDays / exerciseTotalDays : 0.0;
}

abstract class ReportRepository {
  Future<ReportData> generateReport(DateTime start, DateTime end);
}
```

- [ ] **Step 2: Run analyze to confirm no errors**

```bash
flutter analyze lib/features/reports/domain/repositories/report_repository.dart
```

Expected: no errors.

- [ ] **Step 3: Commit**

```bash
git add lib/features/reports/domain/repositories/report_repository.dart
git commit -m "feat(reports): add NutritionReportData, ExerciseReportData, expand ReportData"
```

---

## Task 2: Add two new DAO methods to ExerciseDao

**Files:**
- Modify: `lib/core/dao/exercise_dao.dart`
- Test: `test/dao/exercise_dao_test.dart`

- [ ] **Step 1: Write failing tests**

Add to the end of `test/dao/exercise_dao_test.dart` (inside `main()`'s last `group`, or add a new one):

```dart
group('getCardioLogsInRange', () {
  test('returns only logs within inclusive date range', () async {
    await db.exerciseDao.insertCardioLog(CardioLogsCompanion(
      date: Value(DateTime.utc(2026, 6, 3)),
      cardioType: const Value('Correr'),
      durationMinutes: const Value(30),
    ));
    await db.exerciseDao.insertCardioLog(CardioLogsCompanion(
      date: Value(DateTime.utc(2026, 6, 10)),
      cardioType: const Value('Bici'),
      durationMinutes: const Value(45),
    ));
    final logs = await db.exerciseDao.getCardioLogsInRange(
      DateTime.utc(2026, 6, 1),
      DateTime.utc(2026, 6, 7),
    );
    expect(logs.length, 1);
    expect(logs.first.cardioType, 'Correr');
  });

  test('includes logs on start and end boundary dates', () async {
    await db.exerciseDao.insertCardioLog(CardioLogsCompanion(
      date: Value(DateTime.utc(2026, 6, 1)),
      cardioType: const Value('Correr'),
      durationMinutes: const Value(20),
    ));
    await db.exerciseDao.insertCardioLog(CardioLogsCompanion(
      date: Value(DateTime.utc(2026, 6, 7)),
      cardioType: const Value('Nadar'),
      durationMinutes: const Value(30),
    ));
    final logs = await db.exerciseDao.getCardioLogsInRange(
      DateTime.utc(2026, 6, 1),
      DateTime.utc(2026, 6, 7),
    );
    expect(logs.length, 2);
  });
});

group('getSessionsInRange', () {
  test('returns only completed sessions in range, excludes incomplete', () async {
    final planId = await db.exerciseDao.insertExercisePlan(
      ExercisePlansCompanion(name: const Value('Plan')),
    );
    final routineId = await db.exerciseDao.insertExerciseRoutine(
      ExerciseRoutinesCompanion(
        planId: Value(planId),
        dayNumber: const Value(1),
        routineName: const Value('Pecho'),
      ),
    );
    // Completed session inside range
    await db.exerciseDao.insertExerciseSession(ExerciseSessionLogsCompanion(
      date: Value(DateTime.utc(2026, 6, 3)),
      routineId: Value(routineId),
      gymArrivedAt: Value(DateTime.utc(2026, 6, 3, 9)),
      gymLeftAt: Value(DateTime.utc(2026, 6, 3, 10)),
    ));
    // Incomplete session inside range — must be excluded
    await db.exerciseDao.insertExerciseSession(ExerciseSessionLogsCompanion(
      date: Value(DateTime.utc(2026, 6, 4)),
      routineId: Value(routineId),
      gymArrivedAt: Value(DateTime.utc(2026, 6, 4, 9)),
    ));
    // Completed session outside range — must be excluded
    await db.exerciseDao.insertExerciseSession(ExerciseSessionLogsCompanion(
      date: Value(DateTime.utc(2026, 6, 15)),
      routineId: Value(routineId),
      gymArrivedAt: Value(DateTime.utc(2026, 6, 15, 9)),
      gymLeftAt: Value(DateTime.utc(2026, 6, 15, 10)),
    ));
    final sessions = await db.exerciseDao.getSessionsInRange(
      DateTime.utc(2026, 6, 1),
      DateTime.utc(2026, 6, 7),
    );
    expect(sessions.length, 1);
    expect(sessions.first.date, DateTime.utc(2026, 6, 3));
  });

  test('returns free exercise sessions (routineId null) in range', () async {
    await db.exerciseDao.insertExerciseSession(ExerciseSessionLogsCompanion(
      date: Value(DateTime.utc(2026, 6, 5)),
      gymArrivedAt: Value(DateTime.utc(2026, 6, 5, 8)),
      gymLeftAt: Value(DateTime.utc(2026, 6, 5, 9)),
    ));
    final sessions = await db.exerciseDao.getSessionsInRange(
      DateTime.utc(2026, 6, 1),
      DateTime.utc(2026, 6, 7),
    );
    expect(sessions.any((s) => s.routineId == null), isTrue);
  });
});
```

- [ ] **Step 2: Run tests — confirm they fail**

```bash
flutter test test/dao/exercise_dao_test.dart 2>&1 | tail -5
```

Expected: failures with "method not found" errors.

- [ ] **Step 3: Add the two new methods to `ExerciseDao`**

Add these two methods just before the `// ── Exercise Config ───` comment in `lib/core/dao/exercise_dao.dart`:

```dart
/// Returns all cardio logs where start ≤ date ≤ end (both dates inclusive).
Future<List<CardioLog>> getCardioLogsInRange(DateTime start, DateTime end) {
  final s = DateTime.utc(start.year, start.month, start.day);
  final e =
      DateTime.utc(end.year, end.month, end.day).add(const Duration(days: 1));
  return (select(cardioLogs)
        ..where((t) =>
            t.date.isBiggerOrEqualValue(s) & t.date.isSmallerThanValue(e)))
      .get();
}

/// Returns all completed sessions (gymLeftAt != null) where start ≤ date ≤ end (both inclusive).
Future<List<ExerciseSessionLog>> getSessionsInRange(DateTime start, DateTime end) {
  final s = DateTime.utc(start.year, start.month, start.day);
  final e =
      DateTime.utc(end.year, end.month, end.day).add(const Duration(days: 1));
  return (select(exerciseSessionLogs)
        ..where((t) =>
            t.date.isBiggerOrEqualValue(s) &
            t.date.isSmallerThanValue(e) &
            t.gymLeftAt.isNotNull()))
      .get();
}
```

- [ ] **Step 4: Run tests — confirm they pass**

```bash
flutter test test/dao/exercise_dao_test.dart 2>&1 | tail -5
```

Expected: all tests pass.

- [ ] **Step 5: Commit**

```bash
git add lib/core/dao/exercise_dao.dart test/dao/exercise_dao_test.dart
git commit -m "feat(dao): add getCardioLogsInRange and getSessionsInRange to ExerciseDao"
```

---

## Task 3: Expand ReportRepositoryImpl with nutrition + exercise detail

**Files:**
- Modify: `lib/features/reports/data/repositories/report_repository_impl.dart`
- Test: `test/features/reports/data/report_repository_test.dart`

- [ ] **Step 1: Write failing tests**

Add these two test groups to `test/features/reports/data/report_repository_test.dart` (inside `group('ExerciseRepositoryImpl', ...)` or as top-level groups inside `main()`). The file already imports `app_database.dart` and uses `createTestDatabase()`:

```dart
group('nutritionDetail', () {
  test('is null when no active meal plan exists', () async {
    final data = await repository.generateReport(
      DateTime.utc(2026, 6, 1),
      DateTime.utc(2026, 6, 7),
    );
    expect(data.nutritionDetail, isNull);
  });

  test('contains planName and meal frequencies for logs in range', () async {
    final planId = await db.nutritionDao.insertMealPlan(MealPlansCompanion(
      name: const Value('Plan Semana'),
      periodStart: Value(DateTime.utc(2026, 6, 1)),
    ));
    final optId = await db.nutritionDao.insertMealPlanOption(
      MealPlanOptionsCompanion(
        planId: Value(planId),
        mealType: const Value('desayuno'),
        optionNumber: const Value(1),
        description: const Value('Avena'),
      ),
    );
    // Log the option twice within the range
    await db.nutritionDao.insertDailyMealLog(DailyMealLogsCompanion(
      date: Value(DateTime.utc(2026, 6, 2)),
      mealType: const Value('desayuno'),
      planOptionId: Value(optId),
    ));
    await db.nutritionDao.insertDailyMealLog(DailyMealLogsCompanion(
      date: Value(DateTime.utc(2026, 6, 3)),
      mealType: const Value('desayuno'),
      planOptionId: Value(optId),
    ));
    // Log outside range — must not count
    await db.nutritionDao.insertDailyMealLog(DailyMealLogsCompanion(
      date: Value(DateTime.utc(2026, 6, 20)),
      mealType: const Value('desayuno'),
      planOptionId: Value(optId),
    ));

    final data = await repository.generateReport(
      DateTime.utc(2026, 6, 1),
      DateTime.utc(2026, 6, 7),
    );

    expect(data.nutritionDetail, isNotNull);
    expect(data.nutritionDetail!.planName, 'Plan Semana');
    expect(data.nutritionDetail!.mealFrequencies.length, 1);
    expect(data.nutritionDetail!.mealFrequencies.first.count, 2);
    expect(data.nutritionDetail!.mealFrequencies.first.description, 'Avena');
  });

  test('drops options with count 0 from mealFrequencies', () async {
    final planId = await db.nutritionDao.insertMealPlan(MealPlansCompanion(
      name: const Value('Plan'),
      periodStart: Value(DateTime.utc(2026, 6, 1)),
    ));
    // Option that is never logged
    await db.nutritionDao.insertMealPlanOption(
      MealPlanOptionsCompanion(
        planId: Value(planId),
        mealType: const Value('almuerzo'),
        optionNumber: const Value(1),
        description: const Value('Ensalada'),
      ),
    );

    final data = await repository.generateReport(
      DateTime.utc(2026, 6, 1),
      DateTime.utc(2026, 6, 7),
    );

    expect(data.nutritionDetail!.mealFrequencies, isEmpty);
  });
});

group('exerciseDetail', () {
  test('is null when no active exercise plan exists', () async {
    final data = await repository.generateReport(
      DateTime.utc(2026, 6, 1),
      DateTime.utc(2026, 6, 7),
    );
    expect(data.exerciseDetail, isNull);
  });

  test('contains planName, weeklyCompliance, and session counts', () async {
    final planId = await db.exerciseDao.insertExercisePlan(
      ExercisePlansCompanion(name: const Value('Mi Rutina')),
    );
    final routineId = await db.exerciseDao.insertExerciseRoutine(
      ExerciseRoutinesCompanion(
        planId: Value(planId),
        dayNumber: const Value(1),
        routineName: const Value('Pecho'),
      ),
    );
    // 2 completed routine sessions on different days in week 1
    for (final day in [2, 3]) {
      await db.exerciseDao.insertExerciseSession(ExerciseSessionLogsCompanion(
        date: Value(DateTime.utc(2026, 6, day)),
        routineId: Value(routineId),
        gymArrivedAt: Value(DateTime.utc(2026, 6, day, 9)),
        gymLeftAt: Value(DateTime.utc(2026, 6, day, 10)),
      ));
    }
    // 1 cardio log in range
    await db.exerciseDao.insertCardioLog(CardioLogsCompanion(
      date: Value(DateTime.utc(2026, 6, 4)),
      cardioType: const Value('Correr'),
      durationMinutes: const Value(30),
    ));
    // 1 free exercise session in range
    await db.exerciseDao.insertExerciseSession(ExerciseSessionLogsCompanion(
      date: Value(DateTime.utc(2026, 6, 5)),
      gymArrivedAt: Value(DateTime.utc(2026, 6, 5, 8)),
      gymLeftAt: Value(DateTime.utc(2026, 6, 5, 9)),
    ));

    final data = await repository.generateReport(
      DateTime.utc(2026, 6, 1),
      DateTime.utc(2026, 6, 7),
    );

    expect(data.exerciseDetail, isNotNull);
    expect(data.exerciseDetail!.planName, 'Mi Rutina');
    expect(data.exerciseDetail!.totalRoutineSessions, 2);
    expect(data.exerciseDetail!.cardioSessionsCount, 1);
    expect(data.exerciseDetail!.freeExerciseCount, 1);
    expect(data.exerciseDetail!.weeklyCompliance.length, 1);
    expect(data.exerciseDetail!.weeklyCompliance.first.daysDone, 2);
    expect(data.exerciseDetail!.weeklyCompliance.first.weekLabel, 'Sem 1');
  });
});
```

Also add this import at the top of the test file if not already present:
```dart
import 'package:drift/drift.dart' hide isNotNull, isNull;
```

- [ ] **Step 2: Run tests — confirm they fail**

```bash
flutter test test/features/reports/data/report_repository_test.dart 2>&1 | tail -8
```

Expected: failures (methods not yet implemented).

- [ ] **Step 3: Implement the expanded `report_repository_impl.dart`**

Replace the entire file:

```dart
import 'package:kiolog/core/dao/config_dao.dart';
import 'package:kiolog/core/dao/exercise_dao.dart';
import 'package:kiolog/core/dao/measurements_dao.dart';
import 'package:kiolog/core/dao/nutrition_dao.dart';
import 'package:kiolog/core/dao/water_sleep_dao.dart';
import 'package:kiolog/core/database/app_database.dart';
import '../../domain/repositories/report_repository.dart';

class ReportRepositoryImpl implements ReportRepository {
  final WaterSleepDao _waterSleepDao;
  final NutritionDao _nutritionDao;
  final ExerciseDao _exerciseDao;
  final MeasurementsDao _measurementsDao;
  final ConfigDao _configDao;

  ReportRepositoryImpl(
    this._waterSleepDao,
    this._nutritionDao,
    this._exerciseDao,
    this._measurementsDao,
    this._configDao,
  );

  DateTime _dateOnly(DateTime date) =>
      DateTime.utc(date.year, date.month, date.day);

  @override
  Future<ReportData> generateReport(DateTime start, DateTime end) async {
    final waterConfig = await _configDao.getWaterConfig();
    final dailyGoal = waterConfig?.dailyGoalMl ?? 3000;

    int waterGoalDays = 0;
    int waterTotalDays = 0;
    int mealsLogged = 0;
    int mealsTotal = 0;
    int exerciseDays = 0;
    int exerciseTotalDays = 0;
    double sleepTotal = 0;
    int sleepDays = 0;

    var current = _dateOnly(start);
    final last = _dateOnly(end);

    while (!current.isAfter(last)) {
      final water = await _waterSleepDao.getDailyWaterTotalMl(current);
      if (water > 0) waterTotalDays++;
      if (water >= dailyGoal) waterGoalDays++;

      final meals = await _nutritionDao.getDailyMealLogs(current);
      mealsLogged += meals.length;
      mealsTotal += 4;

      final exerciseLog = await _exerciseDao.getDailyExerciseLog(current);
      final sessions = await _exerciseDao.getSessionsForDate(current);
      if (exerciseLog?.completed == true || sessions.isNotEmpty) {
        exerciseDays++;
      }
      if (current.weekday <= 5) exerciseTotalDays++;

      final sleepLogs = await _waterSleepDao.getSleepLogsForDate(current);
      if (sleepLogs.isNotEmpty) {
        sleepTotal += sleepLogs.fold(0.0, (s, l) => s + l.hoursCalculated);
        sleepDays++;
      }

      current = current.add(const Duration(days: 1));
    }

    final results = await Future.wait([
      _measurementsDao.getWeightLogs(start, end),
      _measurementsDao.getLatestMeasurement(),
      _buildNutritionDetail(start, end),
      _buildExerciseDetail(start, end),
    ]);

    return ReportData(
      start: start,
      end: end,
      waterGoalDays: waterGoalDays,
      waterTotalDays: waterTotalDays,
      mealsLogged: mealsLogged,
      mealsTotal: mealsTotal,
      exerciseDays: exerciseDays,
      exerciseTotalDays: exerciseTotalDays,
      sleepAverage: sleepDays > 0 ? sleepTotal / sleepDays : null,
      weightLogs: results[0] as List<WeightLog>,
      latestMeasurement: results[1] as Measurement?,
      nutritionDetail: results[2] as NutritionReportData?,
      exerciseDetail: results[3] as ExerciseReportData?,
    );
  }

  Future<NutritionReportData?> _buildNutritionDetail(
      DateTime start, DateTime end) async {
    final plan = await _nutritionDao.getActiveMealPlan();
    if (plan == null) return null;

    final endExclusive =
        _dateOnly(end).add(const Duration(days: 1));
    final logs =
        await _nutritionDao.getLogsInRange(_dateOnly(start), endExclusive);
    final options = await _nutritionDao.getAllPlanOptions(plan.id);

    if (options.isEmpty) {
      return NutritionReportData(planName: plan.name, mealFrequencies: []);
    }

    final countMap = <int, int>{};
    for (final log in logs) {
      if (log.planOptionId != null) {
        countMap[log.planOptionId!] = (countMap[log.planOptionId!] ?? 0) + 1;
      }
    }

    const mealTypeOrder = ['desayuno', 'almuerzo', 'cena', 'snack'];
    final entries = options
        .where((o) => (countMap[o.id] ?? 0) > 0)
        .map((o) => MealFrequencyEntry(
              mealType: o.mealType,
              description: o.description,
              count: countMap[o.id]!,
            ))
        .toList()
      ..sort((a, b) {
        final ai = mealTypeOrder.indexOf(a.mealType);
        final bi = mealTypeOrder.indexOf(b.mealType);
        final typeComp = (ai < 0 ? 99 : ai).compareTo(bi < 0 ? 99 : bi);
        if (typeComp != 0) return typeComp;
        return b.count.compareTo(a.count);
      });

    return NutritionReportData(planName: plan.name, mealFrequencies: entries);
  }

  Future<ExerciseReportData?> _buildExerciseDetail(
      DateTime start, DateTime end) async {
    final plan = await _exerciseDao.getActiveExercisePlan();
    if (plan == null) return null;

    final config = await _exerciseDao.getExerciseConfig();
    final daysGoal = config?.weeklyRoutineDaysGoal ?? 4;

    final routines = await _exerciseDao.getRoutinesForPlan(plan.id);
    final routineIds = routines.map((r) => r.id).toList();

    final startDay = _dateOnly(start);
    final endDay = _dateOnly(end);
    final endExclusive = endDay.add(const Duration(days: 1));

    final routineSessions = await _exerciseDao.getCompletedSessionsInPeriod(
      routineIds,
      startDay,
      endExclusive,
    );

    final weeklyCompliance = _buildWeeklyCompliance(
      sessions: routineSessions,
      rangeStart: startDay,
      rangeEnd: endDay,
      daysGoal: daysGoal,
    );

    final uniqueRoutineDays = routineSessions
        .map((s) => DateTime.utc(s.date.year, s.date.month, s.date.day))
        .toSet();

    final allSessions =
        await _exerciseDao.getSessionsInRange(startDay, endDay);
    final freeExerciseCount =
        allSessions.where((s) => s.routineId == null).length;

    final cardioLogs =
        await _exerciseDao.getCardioLogsInRange(startDay, endDay);

    return ExerciseReportData(
      planName: plan.name,
      weeklyCompliance: weeklyCompliance,
      totalRoutineSessions: uniqueRoutineDays.length,
      cardioSessionsCount: cardioLogs.length,
      freeExerciseCount: freeExerciseCount,
    );
  }

  List<WeeklyComplianceEntry> _buildWeeklyCompliance({
    required List<ExerciseSessionLog> sessions,
    required DateTime rangeStart,
    required DateTime rangeEnd,
    required int daysGoal,
  }) {
    // Monday on or before rangeStart
    final firstMonday =
        rangeStart.subtract(Duration(days: rangeStart.weekday - 1));

    final weeks = <WeeklyComplianceEntry>[];
    var weekStart = firstMonday;
    var weekIndex = 1;

    while (!weekStart.isAfter(rangeEnd)) {
      final weekEnd = weekStart.add(const Duration(days: 7));
      final uniqueDays = sessions
          .where((s) {
            final d = DateTime.utc(s.date.year, s.date.month, s.date.day);
            return !d.isBefore(weekStart) && d.isBefore(weekEnd);
          })
          .map((s) => DateTime.utc(s.date.year, s.date.month, s.date.day))
          .toSet();

      weeks.add(WeeklyComplianceEntry(
        weekLabel: 'Sem $weekIndex',
        daysDone: uniqueDays.length,
        daysGoal: daysGoal,
      ));

      weekStart = weekEnd;
      weekIndex++;
    }

    return weeks;
  }
}
```

- [ ] **Step 4: Run tests — confirm they pass**

```bash
flutter test test/features/reports/data/report_repository_test.dart 2>&1 | tail -8
```

Expected: all tests pass.

- [ ] **Step 5: Run full suite to check no regressions**

```bash
flutter test 2>&1 | tail -5
```

Expected: all tests pass.

- [ ] **Step 6: Commit**

```bash
git add lib/features/reports/data/repositories/report_repository_impl.dart \
        test/features/reports/data/report_repository_test.dart
git commit -m "feat(reports): expand generateReport with nutrition + exercise detail"
```

---

## Task 4: Create PdfReportService

**Files:**
- Create: `lib/features/reports/data/pdf_report_service.dart`

No unit tests for this task — PDF binary output is not testable with `flutter test`. Manual verification on device is specified in the spec.

- [ ] **Step 1: Create the file**

```dart
import 'dart:io';
import 'package:intl/intl.dart';
import 'package:path_provider/path_provider.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import '../../../core/database/app_database.dart';
import '../../reports/domain/repositories/report_repository.dart';

class PdfReportService {
  static final _green = PdfColor.fromHex('#22C55E');
  static final _teal = PdfColor.fromHex('#4EDEA3');
  static final _blue = PdfColor.fromHex('#AFC7FF');
  static final _track = PdfColor.fromHex('#E5E7EB');
  static final _heading = PdfColor.fromHex('#111827');
  static final _body = PdfColor.fromHex('#374151');
  static final _muted = PdfColor.fromHex('#6B7280');

  static Future<File> generate(ReportData data) async {
    final dateFmt = DateFormat.yMMMd('es');
    final doc = pw.Document();

    doc.addPage(
      pw.MultiPage(
        pageFormat: PdfPageFormat.a4,
        margin: const pw.EdgeInsets.all(32),
        build: (ctx) => [
          _header(data, dateFmt),
          pw.SizedBox(height: 16),
          _sectionHeading('RESUMEN'),
          pw.SizedBox(height: 6),
          ..._summaryRows(data),
          if (data.nutritionDetail != null) ...[
            pw.SizedBox(height: 16),
            _sectionHeading('NUTRICIÓN'),
            pw.SizedBox(height: 6),
            ..._nutritionRows(data.nutritionDetail!),
          ],
          if (data.exerciseDetail != null) ...[
            pw.SizedBox(height: 16),
            _sectionHeading('EJERCICIO'),
            pw.SizedBox(height: 6),
            ..._exerciseRows(data.exerciseDetail!),
          ],
          if (data.weightLogs.isNotEmpty ||
              data.latestMeasurement != null) ...[
            pw.SizedBox(height: 16),
            _sectionHeading('MEDIDAS'),
            pw.SizedBox(height: 6),
            ..._measuresRows(data),
          ],
          pw.SizedBox(height: 24),
          _footer(dateFmt),
        ],
      ),
    );

    final dir = await getTemporaryDirectory();
    final dateStr = DateFormat('yyyyMMdd').format(DateTime.now());
    final file = File('${dir.path}/kiolog_reporte_$dateStr.pdf');
    await file.writeAsBytes(await doc.save());
    return file;
  }

  // ── Header ────────────────────────────────────────────────────────────────

  static pw.Widget _header(ReportData data, DateFormat fmt) {
    return pw.Column(
      crossAxisAlignment: pw.CrossAxisAlignment.start,
      children: [
        pw.Text(
          'Kiolog — Reporte de Salud',
          style: pw.TextStyle(
            fontSize: 20,
            fontWeight: pw.FontWeight.bold,
            color: _heading,
          ),
        ),
        pw.SizedBox(height: 4),
        pw.Text(
          '${fmt.format(data.start)} – ${fmt.format(data.end)}',
          style: pw.TextStyle(fontSize: 11, color: _muted),
        ),
      ],
    );
  }

  // ── Section heading ───────────────────────────────────────────────────────

  static pw.Widget _sectionHeading(String text) {
    return pw.Container(
      margin: const pw.EdgeInsets.only(bottom: 4),
      padding: const pw.EdgeInsets.only(bottom: 4),
      decoration: const pw.BoxDecoration(
        border: pw.Border(
          bottom: pw.BorderSide(color: PdfColors.grey300, width: 0.5),
        ),
      ),
      child: pw.Text(
        text,
        style: pw.TextStyle(
          fontSize: 13,
          fontWeight: pw.FontWeight.bold,
          color: _heading,
        ),
      ),
    );
  }

  // ── Bar row ───────────────────────────────────────────────────────────────

  static pw.Widget _barRow({
    required String label,
    required double fraction,
    required String valueText,
    required PdfColor color,
    double labelWidth = 130,
    double barWidth = 200,
  }) {
    final filled = barWidth * fraction.clamp(0.0, 1.0);
    return pw.Padding(
      padding: const pw.EdgeInsets.symmetric(vertical: 3),
      child: pw.Row(
        crossAxisAlignment: pw.CrossAxisAlignment.center,
        children: [
          pw.SizedBox(
            width: labelWidth,
            child: pw.Text(label,
                style: pw.TextStyle(fontSize: 10, color: _body)),
          ),
          pw.SizedBox(width: 8),
          pw.Stack(
            children: [
              pw.Container(
                width: barWidth,
                height: 10,
                decoration: pw.BoxDecoration(
                  color: _track,
                  borderRadius: pw.BorderRadius.circular(5),
                ),
              ),
              pw.Container(
                width: filled,
                height: 10,
                decoration: pw.BoxDecoration(
                  color: color,
                  borderRadius: pw.BorderRadius.circular(5),
                ),
              ),
            ],
          ),
          pw.SizedBox(width: 8),
          pw.Text(
            valueText,
            style: pw.TextStyle(
              fontSize: 10,
              color: _body,
              fontWeight: pw.FontWeight.bold,
            ),
          ),
        ],
      ),
    );
  }

  // ── Summary rows ──────────────────────────────────────────────────────────

  static List<pw.Widget> _summaryRows(ReportData data) {
    return [
      _barRow(
        label: 'Agua',
        fraction: data.waterCompliance,
        valueText:
            '${(data.waterCompliance * 100).round()}%  ${data.waterGoalDays}/${data.waterTotalDays} días',
        color: _green,
      ),
      _barRow(
        label: 'Nutrición',
        fraction: data.nutritionCompliance,
        valueText:
            '${(data.nutritionCompliance * 100).round()}%  ${data.mealsLogged}/${data.mealsTotal} comidas',
        color: _teal,
      ),
      _barRow(
        label: 'Ejercicio',
        fraction: data.exerciseCompliance,
        valueText:
            '${(data.exerciseCompliance * 100).round()}%  ${data.exerciseDays}/${data.exerciseTotalDays} días',
        color: _blue,
      ),
      if (data.sleepAverage != null)
        _barRow(
          label: 'Sueño promedio',
          fraction: (data.sleepAverage! / 9.0).clamp(0.0, 1.0),
          valueText: '${data.sleepAverage!.toStringAsFixed(1)} h/noche',
          color: _teal,
        ),
    ];
  }

  // ── Nutrition rows ────────────────────────────────────────────────────────

  static List<pw.Widget> _nutritionRows(NutritionReportData detail) {
    final widgets = <pw.Widget>[];

    if (detail.planName != null) {
      widgets.add(pw.Text(
        'Plan: ${detail.planName}',
        style: pw.TextStyle(fontSize: 11, color: _muted),
      ));
      widgets.add(pw.SizedBox(height: 8));
    }

    if (detail.mealFrequencies.isEmpty) {
      widgets.add(pw.Text(
        'Sin datos en este período',
        style: pw.TextStyle(fontSize: 10, color: _muted),
      ));
      return widgets;
    }

    // Group by mealType (already sorted by the repository)
    final grouped = <String, List<MealFrequencyEntry>>{};
    for (final e in detail.mealFrequencies) {
      grouped.putIfAbsent(e.mealType, () => []).add(e);
    }

    const order = ['desayuno', 'almuerzo', 'cena', 'snack'];
    final types = order.where(grouped.containsKey).toList()
      ..addAll(grouped.keys.where((t) => !order.contains(t)));

    for (final type in types) {
      final entries = grouped[type]!;
      final maxCount =
          entries.map((e) => e.count).reduce((a, b) => a > b ? a : b);

      widgets.add(pw.Padding(
        padding: const pw.EdgeInsets.only(top: 8, bottom: 2),
        child: pw.Text(
          type.toUpperCase(),
          style: pw.TextStyle(
            fontSize: 9,
            fontWeight: pw.FontWeight.bold,
            color: _muted,
          ),
        ),
      ));

      for (final entry in entries) {
        widgets.add(_barRow(
          label: entry.description,
          fraction: maxCount > 0 ? entry.count / maxCount : 0,
          valueText: '${entry.count}×',
          color: _teal,
          labelWidth: 150,
          barWidth: 160,
        ));
      }
    }

    return widgets;
  }

  // ── Exercise rows ─────────────────────────────────────────────────────────

  static List<pw.Widget> _exerciseRows(ExerciseReportData detail) {
    final widgets = <pw.Widget>[];

    if (detail.planName != null) {
      widgets.add(pw.Text(
        'Plan: ${detail.planName}',
        style: pw.TextStyle(fontSize: 11, color: _muted),
      ));
      widgets.add(pw.SizedBox(height: 8));
    }

    if (detail.weeklyCompliance.isEmpty) {
      widgets.add(pw.Text(
        'Sin datos en este período',
        style: pw.TextStyle(fontSize: 10, color: _muted),
      ));
    } else {
      widgets.add(pw.Text(
        'Cumplimiento semanal',
        style: pw.TextStyle(
          fontSize: 11,
          fontWeight: pw.FontWeight.bold,
          color: _body,
        ),
      ));
      widgets.add(pw.SizedBox(height: 4));

      for (final week in detail.weeklyCompliance) {
        widgets.add(_barRow(
          label: week.weekLabel,
          fraction: week.daysGoal > 0 ? week.daysDone / week.daysGoal : 0,
          valueText: '${week.daysDone}/${week.daysGoal} días',
          color: _blue,
          labelWidth: 50,
          barWidth: 220,
        ));
      }
    }

    widgets.add(pw.SizedBox(height: 8));
    widgets.add(pw.Text(
      'Rutina: ${detail.totalRoutineSessions} sesiones  ·  '
      'Cardio: ${detail.cardioSessionsCount}  ·  '
      'Ejercicio libre: ${detail.freeExerciseCount}',
      style: pw.TextStyle(fontSize: 10, color: _body),
    ));

    return widgets;
  }

  // ── Measures rows ─────────────────────────────────────────────────────────

  static List<pw.Widget> _measuresRows(ReportData data) {
    final dateFmt = DateFormat.yMMMd('es');
    final widgets = <pw.Widget>[];

    if (data.weightLogs.isNotEmpty) {
      widgets.add(pw.Text(
        'Evolución de peso',
        style: pw.TextStyle(
          fontSize: 11,
          fontWeight: pw.FontWeight.bold,
          color: _body,
        ),
      ));
      widgets.add(pw.SizedBox(height: 4));
      for (final log in data.weightLogs) {
        widgets.add(pw.Padding(
          padding: const pw.EdgeInsets.symmetric(vertical: 2),
          child: pw.Row(
            children: [
              pw.SizedBox(
                width: 130,
                child: pw.Text(
                  dateFmt.format(log.date),
                  style: pw.TextStyle(fontSize: 10, color: _muted),
                ),
              ),
              pw.Text(
                '${log.weightKg} kg',
                style: pw.TextStyle(
                  fontSize: 10,
                  color: _body,
                  fontWeight: pw.FontWeight.bold,
                ),
              ),
            ],
          ),
        ));
      }
    }

    if (data.latestMeasurement != null) {
      final m = data.latestMeasurement!;
      widgets.add(pw.SizedBox(height: 8));
      widgets.add(pw.Text(
        'Última medición (${dateFmt.format(m.date)})',
        style: pw.TextStyle(
          fontSize: 11,
          fontWeight: pw.FontWeight.bold,
          color: _body,
        ),
      ));
      if (m.waistCm != null) {
        widgets.add(pw.Text(
          'Cintura: ${m.waistCm} cm',
          style: pw.TextStyle(fontSize: 10, color: _body),
        ));
      }
      if (m.hipCm != null) {
        widgets.add(pw.Text(
          'Cadera: ${m.hipCm} cm',
          style: pw.TextStyle(fontSize: 10, color: _body),
        ));
      }
    }

    return widgets;
  }

  // ── Footer ────────────────────────────────────────────────────────────────

  static pw.Widget _footer(DateFormat fmt) {
    return pw.Text(
      'Generado por Kiolog · ${fmt.format(DateTime.now())}',
      style: pw.TextStyle(fontSize: 9, color: _muted),
    );
  }
}
```

- [ ] **Step 2: Run analyze**

```bash
flutter analyze lib/features/reports/data/pdf_report_service.dart
```

Expected: no errors.

- [ ] **Step 3: Commit**

```bash
git add lib/features/reports/data/pdf_report_service.dart
git commit -m "feat(reports): add PdfReportService with horizontal bar charts"
```

---

## Task 5: Update report_page.dart — preview sections + PDF export

**Files:**
- Modify: `lib/features/reports/presentation/pages/report_page.dart`

- [ ] **Step 1: Replace the entire file**

```dart
import 'package:flutter/material.dart';
import 'package:kiolog/shared/widgets/vitality_card.dart';
import 'package:kiolog/shared/widgets/vitality_progress_bar.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:share_plus/share_plus.dart';
import '../../../../core/di/injection.dart';
import '../../domain/repositories/report_repository.dart';
import '../../data/pdf_report_service.dart';
import '../bloc/report_bloc.dart';
import '../bloc/report_event.dart';
import '../bloc/report_state.dart';

class ReportPage extends StatelessWidget {
  const ReportPage({super.key});

  @override
  Widget build(BuildContext context) {
    return BlocProvider(
      create: (_) => ReportBloc(getIt<ReportRepository>()),
      child: const _ReportView(),
    );
  }
}

class _ReportView extends StatefulWidget {
  const _ReportView();

  @override
  State<_ReportView> createState() => _ReportViewState();
}

class _ReportViewState extends State<_ReportView> {
  DateTimeRange _range = DateTimeRange(
    start: DateTime.now().subtract(const Duration(days: 7)),
    end: DateTime.now(),
  );

  bool _exporting = false;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Reporte'),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => context.go('/settings'),
        ),
      ),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            _buildDateRangeSelector(context),
            const SizedBox(height: 16),
            ElevatedButton.icon(
              onPressed: () {
                context.read<ReportBloc>().add(
                      ReportGenerated(start: _range.start, end: _range.end),
                    );
              },
              icon: const Icon(Icons.assessment),
              label: const Text('Generar reporte'),
            ),
            const SizedBox(height: 24),
            BlocBuilder<ReportBloc, ReportState>(
              builder: (context, state) {
                if (state.status == ReportStatus.loading) {
                  return const Center(child: CircularProgressIndicator());
                }
                if (state.status == ReportStatus.failure) {
                  return Text('Error: ${state.error}');
                }
                if (state.status == ReportStatus.success &&
                    state.data != null) {
                  return _buildReportContent(context, state.data!);
                }
                return const SizedBox.shrink();
              },
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildDateRangeSelector(BuildContext context) {
    return VitalityCard(
      padding: EdgeInsets.zero,
      child: ListTile(
        leading: const Icon(Icons.date_range),
        title: const Text('Período'),
        subtitle: Text(
          '${DateFormat.yMMMd('es').format(_range.start)} – ${DateFormat.yMMMd('es').format(_range.end)}',
        ),
        trailing: const Icon(Icons.edit),
        onTap: () async {
          final picked = await showDateRangePicker(
            context: context,
            firstDate: DateTime(2024),
            lastDate: DateTime.now(),
            initialDateRange: _range,
          );
          if (picked != null) {
            setState(() => _range = picked);
          }
        },
      ),
    );
  }

  Widget _buildReportContent(BuildContext context, ReportData data) {
    final theme = Theme.of(context);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // ── Resumen ─────────────────────────────────────────────────────────
        Text('Resumen', style: theme.textTheme.headlineSmall),
        const SizedBox(height: 12),
        _MetricCard(
          label: 'Agua',
          value: '${(data.waterCompliance * 100).toStringAsFixed(0)}%',
          subtitle: '${data.waterGoalDays} / ${data.waterTotalDays} días meta',
        ),
        _MetricCard(
          label: 'Nutrición',
          value: '${(data.nutritionCompliance * 100).toStringAsFixed(0)}%',
          subtitle: '${data.mealsLogged} / ${data.mealsTotal} comidas',
        ),
        _MetricCard(
          label: 'Ejercicio',
          value: '${(data.exerciseCompliance * 100).toStringAsFixed(0)}%',
          subtitle: '${data.exerciseDays} / ${data.exerciseTotalDays} días',
        ),
        if (data.sleepAverage != null)
          _MetricCard(
            label: 'Sueño promedio',
            value: '${data.sleepAverage!.toStringAsFixed(1)} h',
            subtitle: 'Por noche',
          ),

        // ── Nutrición detalle ────────────────────────────────────────────────
        if (data.nutritionDetail != null &&
            data.nutritionDetail!.mealFrequencies.isNotEmpty) ...[
          const SizedBox(height: 24),
          Text('Nutrición', style: theme.textTheme.headlineSmall),
          if (data.nutritionDetail!.planName != null)
            Text(
              'Plan: ${data.nutritionDetail!.planName}',
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
          const SizedBox(height: 12),
          ..._buildFrequencySection(context, data.nutritionDetail!),
        ],

        // ── Ejercicio detalle ────────────────────────────────────────────────
        if (data.exerciseDetail != null) ...[
          const SizedBox(height: 24),
          Text('Ejercicio', style: theme.textTheme.headlineSmall),
          if (data.exerciseDetail!.planName != null)
            Text(
              'Plan: ${data.exerciseDetail!.planName}',
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
          const SizedBox(height: 12),
          ..._buildExerciseSection(context, data.exerciseDetail!),
        ],

        // ── Export button ────────────────────────────────────────────────────
        const SizedBox(height: 24),
        ElevatedButton.icon(
          onPressed: _exporting ? null : () => _exportPdf(context, data),
          icon: _exporting
              ? const SizedBox(
                  width: 16,
                  height: 16,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : const Icon(Icons.picture_as_pdf),
          label:
              Text(_exporting ? 'Generando PDF...' : 'Exportar y compartir'),
        ),
      ],
    );
  }

  List<Widget> _buildFrequencySection(
      BuildContext context, NutritionReportData detail) {
    final theme = Theme.of(context);
    final grouped = <String, List<MealFrequencyEntry>>{};
    for (final e in detail.mealFrequencies) {
      grouped.putIfAbsent(e.mealType, () => []).add(e);
    }
    const order = ['desayuno', 'almuerzo', 'cena', 'snack'];
    final types = order.where(grouped.containsKey).toList()
      ..addAll(grouped.keys.where((t) => !order.contains(t)));

    final widgets = <Widget>[];
    for (final type in types) {
      final entries = grouped[type]!;
      final maxCount =
          entries.map((e) => e.count).reduce((a, b) => a > b ? a : b);
      widgets.add(Padding(
        padding: const EdgeInsets.only(top: 12, bottom: 4),
        child: Text(
          type.toUpperCase(),
          style: theme.textTheme.labelSmall,
        ),
      ));
      for (final entry in entries) {
        widgets.add(_FrequencyBar(
          entry: entry,
          maxCount: maxCount,
          color: theme.colorScheme.secondary,
        ));
      }
    }
    return widgets;
  }

  List<Widget> _buildExerciseSection(
      BuildContext context, ExerciseReportData detail) {
    final theme = Theme.of(context);
    final widgets = <Widget>[];

    if (detail.weeklyCompliance.isEmpty) {
      widgets.add(Text(
        'Sin datos de ejercicio en este período',
        style: theme.textTheme.bodySmall?.copyWith(
          color: theme.colorScheme.onSurfaceVariant,
        ),
      ));
    } else {
      widgets.add(Text(
        'Cumplimiento semanal',
        style: theme.textTheme.titleSmall,
      ));
      widgets.add(const SizedBox(height: 8));
      for (final week in detail.weeklyCompliance) {
        widgets.add(_WeekComplianceBar(
          entry: week,
          color: theme.colorScheme.tertiary,
        ));
      }
    }

    widgets.add(const SizedBox(height: 12));
    widgets.add(VitalityCard(
      padding: const EdgeInsets.all(12),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceAround,
        children: [
          _StatChip(label: 'Rutina', value: '${detail.totalRoutineSessions}'),
          _StatChip(label: 'Cardio', value: '${detail.cardioSessionsCount}'),
          _StatChip(label: 'Libre', value: '${detail.freeExerciseCount}'),
        ],
      ),
    ));

    return widgets;
  }

  Future<void> _exportPdf(BuildContext context, ReportData data) async {
    setState(() => _exporting = true);
    try {
      final file = await PdfReportService.generate(data);
      if (!mounted) return;
      await Share.shareXFiles(
        [XFile(file.path)],
        subject: 'Reporte Kiolog',
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error al generar PDF: $e')),
      );
    } finally {
      if (mounted) setState(() => _exporting = false);
    }
  }
}

// ── Reusable widgets ─────────────────────────────────────────────────────────

class _MetricCard extends StatelessWidget {
  final String label;
  final String value;
  final String subtitle;

  const _MetricCard({
    required this.label,
    required this.value,
    required this.subtitle,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: VitalityCard(
        padding: EdgeInsets.zero,
        child: ListTile(
          title: Text(label),
          subtitle: Text(subtitle),
          trailing: Text(
            value,
            style: Theme.of(context).textTheme.titleLarge?.copyWith(
                  color: Theme.of(context).colorScheme.primary,
                ),
          ),
        ),
      ),
    );
  }
}

class _FrequencyBar extends StatelessWidget {
  final MealFrequencyEntry entry;
  final int maxCount;
  final Color color;

  const _FrequencyBar({
    required this.entry,
    required this.maxCount,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final fraction = maxCount > 0 ? entry.count / maxCount : 0.0;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: [
          SizedBox(
            width: 140,
            child: Text(
              entry.description,
              style: theme.textTheme.bodySmall,
              overflow: TextOverflow.ellipsis,
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: VitalityProgressBar(
              value: fraction,
              color: color,
            ),
          ),
          const SizedBox(width: 8),
          SizedBox(
            width: 32,
            child: Text(
              '${entry.count}×',
              style: theme.textTheme.labelSmall?.copyWith(
                color: color,
                fontWeight: FontWeight.bold,
              ),
              textAlign: TextAlign.right,
            ),
          ),
        ],
      ),
    );
  }
}

class _WeekComplianceBar extends StatelessWidget {
  final WeeklyComplianceEntry entry;
  final Color color;

  const _WeekComplianceBar({required this.entry, required this.color});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final fraction =
        entry.daysGoal > 0 ? entry.daysDone / entry.daysGoal : 0.0;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: [
          SizedBox(
            width: 48,
            child: Text(entry.weekLabel, style: theme.textTheme.bodySmall),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: VitalityProgressBar(
              value: fraction.clamp(0.0, 1.0),
              color: color,
            ),
          ),
          const SizedBox(width: 8),
          SizedBox(
            width: 56,
            child: Text(
              '${entry.daysDone}/${entry.daysGoal} días',
              style: theme.textTheme.labelSmall?.copyWith(
                color: color,
                fontWeight: FontWeight.bold,
              ),
              textAlign: TextAlign.right,
            ),
          ),
        ],
      ),
    );
  }
}

class _StatChip extends StatelessWidget {
  final String label;
  final String value;

  const _StatChip({required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Column(
      children: [
        Text(
          value,
          style: theme.textTheme.titleMedium?.copyWith(
            color: theme.colorScheme.primary,
            fontWeight: FontWeight.bold,
          ),
        ),
        Text(label, style: theme.textTheme.labelSmall),
      ],
    );
  }
}
```

- [ ] **Step 2: Run analyze**

```bash
flutter analyze lib/features/reports/presentation/pages/report_page.dart
```

Expected: no errors.

- [ ] **Step 3: Run full test suite**

```bash
flutter test 2>&1 | tail -5
```

Expected: all tests pass.

- [ ] **Step 4: Commit**

```bash
git add lib/features/reports/presentation/pages/report_page.dart \
        lib/features/reports/data/pdf_report_service.dart
git commit -m "feat(reports): add detail preview sections and PdfReportService export"
```

---

## Verification

After all tasks are complete, verify the full feature manually:

1. Open the app → Settings → Reporte
2. Select a date range that covers at least 1 week of data
3. Tap "Generar reporte" — confirm the nutrition frequency bars and exercise compliance bars appear in the preview
4. Tap "Exportar y compartir" — confirm a PDF is generated and the share sheet opens
5. Open the PDF — confirm: header with date range, resumen bars, nutrición section with plan name and frequency bars grouped by meal type, ejercicio section with weekly compliance bars and summary row, medidas section if weight data exists
