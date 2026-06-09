# Exercise Phase C — Dashboard Semanal Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Redesign `ExercisePage` as a weekly dashboard with routine, cardio, and independent exercise sections.

**Architecture:** Add `IndependentExerciseLog` domain model + DAO query; extend `ExerciseState` with 2 new fields loaded in `_onLoaded`; rewrite `_ExerciseView` as StatefulWidget with 3 sections + sticky bottom bar. No new BLoC events needed — existing `ExerciseRoutineItemAdded/Updated` already carry `setDefs`.

**Tech Stack:** Flutter · flutter_bloc · Drift (SQLite) · mocktail · bloc_test

---

## File Map

| File | Change |
|------|--------|
| `lib/features/exercise/domain/models/independent_exercise_log.dart` | **Create** — domain model |
| `lib/core/dao/exercise_dao.dart` | Add `getIndependentSessionsForWeek` |
| `lib/features/exercise/domain/repositories/exercise_repository.dart` | Add method to interface |
| `lib/features/exercise/data/repositories/exercise_repository_impl.dart` | Implement method |
| `lib/features/exercise/presentation/bloc/exercise_state.dart` | 2 new fields + copyWith + props |
| `lib/features/exercise/presentation/bloc/exercise_bloc.dart` | Extend `_onLoaded`, update 2 handlers |
| `lib/features/exercise/presentation/pages/exercise_page.dart` | Full rewrite of `_ExerciseView` |
| `test/features/exercise/presentation/exercise_bloc_test.dart` | Update existing test, add 2 new tests |

---

### Task 1: IndependentExerciseLog model

**Files:**
- Create: `lib/features/exercise/domain/models/independent_exercise_log.dart`

- [ ] **Step 1: Create the model file**

```dart
// lib/features/exercise/domain/models/independent_exercise_log.dart
import 'package:equatable/equatable.dart';

class IndependentExerciseLog extends Equatable {
  final int sessionId;
  final DateTime date;
  final String exerciseName;
  final int sets;
  final int reps;
  final double? weightKg;

  const IndependentExerciseLog({
    required this.sessionId,
    required this.date,
    required this.exerciseName,
    required this.sets,
    required this.reps,
    this.weightKg,
  });

  @override
  List<Object?> get props =>
      [sessionId, date, exerciseName, sets, reps, weightKg];
}
```

- [ ] **Step 2: Verify it compiles**

```bash
flutter analyze lib/features/exercise/domain/models/independent_exercise_log.dart
```

Expected: no issues.

- [ ] **Step 3: Commit**

```bash
git add lib/features/exercise/domain/models/independent_exercise_log.dart
git commit -m "feat(exercise): add IndependentExerciseLog domain model"
```

---

### Task 2: DAO — getIndependentSessionsForWeek

**Files:**
- Modify: `lib/core/dao/exercise_dao.dart`

The DAO returns raw `List<ExerciseSessionLog>` filtered by `routineId IS NULL AND gymLeftAt IS NOT NULL`. The domain model construction happens in the repository.

- [ ] **Step 1: Add the method to the DAO after `getCompletedRoutineSessionsForWeek` (line ~157)**

```dart
// In lib/core/dao/exercise_dao.dart, after getCompletedRoutineSessionsForWeek:

Future<List<ExerciseSessionLog>> getIndependentSessionsForWeek(
  DateTime weekStart,
) {
  final start =
      DateTime.utc(weekStart.year, weekStart.month, weekStart.day);
  final end = start.add(const Duration(days: 7));
  return (select(exerciseSessionLogs)
        ..where((t) =>
            t.date.isBiggerOrEqualValue(start) &
            t.date.isSmallerThanValue(end) &
            t.routineId.isNull() &
            t.gymLeftAt.isNotNull())
        ..orderBy([(t) => OrderingTerm.desc(t.gymArrivedAt)]))
      .get();
}
```

- [ ] **Step 2: Verify it compiles**

```bash
flutter analyze lib/core/dao/exercise_dao.dart
```

Expected: no issues.

- [ ] **Step 3: Commit**

```bash
git add lib/core/dao/exercise_dao.dart
git commit -m "feat(exercise): add getIndependentSessionsForWeek to DAO"
```

---

### Task 3: Repository interface + implementation

**Files:**
- Modify: `lib/features/exercise/domain/repositories/exercise_repository.dart`
- Modify: `lib/features/exercise/data/repositories/exercise_repository_impl.dart`

- [ ] **Step 1: Add the method to the repository interface**

In `exercise_repository.dart`, add after `getCompletedRoutineSessionsForWeek`:

```dart
// Add import at the top of the file:
import '../models/independent_exercise_log.dart';

// Add method after getCompletedRoutineSessionsForWeek:
Future<List<IndependentExerciseLog>> getIndependentSessionsForWeek(
  DateTime weekStart,
);
```

- [ ] **Step 2: Implement in the repository**

In `exercise_repository_impl.dart`, add the import and method:

```dart
// Add import at the top (after existing imports):
import '../../domain/models/independent_exercise_log.dart';

// Add method after getCompletedRoutineSessionsForWeek:
@override
Future<List<IndependentExerciseLog>> getIndependentSessionsForWeek(
  DateTime weekStart,
) async {
  final sessions =
      await _dao.getIndependentSessionsForWeek(_utcDate(weekStart));
  final result = <IndependentExerciseLog>[];
  for (final s in sessions) {
    final sets = await _dao.getSessionSets(s.id);
    if (sets.isEmpty) continue;
    result.add(IndependentExerciseLog(
      sessionId: s.id,
      date: s.date,
      exerciseName: sets.first.exerciseName,
      sets: sets.length,
      reps: sets.first.reps,
      weightKg: sets.first.weightKg,
    ));
  }
  return result;
}
```

- [ ] **Step 3: Verify it compiles**

```bash
flutter analyze lib/features/exercise/domain/repositories/exercise_repository.dart lib/features/exercise/data/repositories/exercise_repository_impl.dart
```

Expected: no issues.

- [ ] **Step 4: Commit**

```bash
git add lib/features/exercise/domain/repositories/exercise_repository.dart \
        lib/features/exercise/data/repositories/exercise_repository_impl.dart
git commit -m "feat(exercise): add getIndependentSessionsForWeek to repository"
```

---

### Task 4: ExerciseState new fields + _onLoaded + tests

**Files:**
- Modify: `lib/features/exercise/presentation/bloc/exercise_state.dart`
- Modify: `lib/features/exercise/presentation/bloc/exercise_bloc.dart`
- Modify: `test/features/exercise/presentation/exercise_bloc_test.dart`

- [ ] **Step 1: Add import and 2 new fields to ExerciseState**

In `exercise_state.dart`, add the import and fields:

```dart
// Add to imports at top:
import 'package:kiolog/features/exercise/domain/models/independent_exercise_log.dart';
import 'package:kiolog/core/database/app_database.dart'; // already present

// In the class body, add after weeklyStats:
final List<ExerciseSessionLog> completedRoutineSessionsThisWeek;
final List<IndependentExerciseLog> weeklyIndependentLogs;
```

Update the constructor default values:

```dart
// In const ExerciseState({...}), add:
this.completedRoutineSessionsThisWeek = const [],
this.weeklyIndependentLogs = const [],
```

Update `copyWith`:

```dart
// Add parameters:
List<ExerciseSessionLog>? completedRoutineSessionsThisWeek,
List<IndependentExerciseLog>? weeklyIndependentLogs,

// Add to the return:
completedRoutineSessionsThisWeek:
    completedRoutineSessionsThisWeek ?? this.completedRoutineSessionsThisWeek,
weeklyIndependentLogs:
    weeklyIndependentLogs ?? this.weeklyIndependentLogs,
```

Update `props`:

```dart
// Add to props list:
completedRoutineSessionsThisWeek,
weeklyIndependentLogs,
```

- [ ] **Step 2: Write the failing test**

In `exercise_bloc_test.dart`, add a new test after the existing `ExerciseLoaded` test. Also update the existing `ExerciseLoaded` test to stub the 2 new methods:

```dart
// Update the existing 'emits [loading, success] when ExerciseLoaded succeeds' test
// to add these two stubs inside the build: callback:
when(() => repository.getCompletedRoutineSessionsForWeek(any()))
    .thenAnswer((_) async => []);
when(() => repository.getIndependentSessionsForWeek(any()))
    .thenAnswer((_) async => []);
```

Add a new test:

```dart
blocTest<ExerciseBloc, ExerciseState>(
  'ExerciseLoaded populates completedRoutineSessionsThisWeek and weeklyIndependentLogs',
  build: () {
    final session = ExerciseSessionLog(
      id: 1,
      date: DateTime(2026, 6, 9),
      gymArrivedAt: DateTime(2026, 6, 9, 7, 0),
      gymLeftAt: DateTime(2026, 6, 9, 8, 0),
      routineId: 1,
    );
    when(() => repository.getActivePlan()).thenAnswer((_) async => null);
    when(() => repository.getDailyLog(any())).thenAnswer((_) async => null);
    when(() => repository.getSessionsForDate(any())).thenAnswer((_) async => []);
    when(() => repository.getExerciseConfig()).thenAnswer((_) async => null);
    when(() => repository.getCardioLogsForWeek(any()))
        .thenAnswer((_) async => []);
    when(() => repository.getWeeklyStats(weeksBack: any(named: 'weeksBack')))
        .thenAnswer((_) async => []);
    when(() => repository.getCompletedRoutineSessionsForWeek(any()))
        .thenAnswer((_) async => [session]);
    when(() => repository.getIndependentSessionsForWeek(any()))
        .thenAnswer((_) async => []);
    return ExerciseBloc(repository);
  },
  act: (bloc) => bloc.add(ExerciseLoaded(date: DateTime(2026, 6, 9))),
  expect: () => [
    const ExerciseState(status: ExerciseStatus.loading),
    ExerciseState(
      status: ExerciseStatus.success,
      completedRoutineSessionsThisWeek: [
        ExerciseSessionLog(
          id: 1,
          date: DateTime(2026, 6, 9),
          gymArrivedAt: DateTime(2026, 6, 9, 7, 0),
          gymLeftAt: DateTime(2026, 6, 9, 8, 0),
          routineId: 1,
        ),
      ],
    ),
  ],
);
```

- [ ] **Step 3: Run tests — expect failure**

```bash
flutter test test/features/exercise/presentation/exercise_bloc_test.dart
```

Expected: failures on the new test (fields not yet in state) and the updated existing test (missing mock stubs).

- [ ] **Step 4: Update `_onLoaded` in exercise_bloc.dart**

Replace the sequential calls at the end of `_onLoaded` (lines ~61–79) with a parallel `Future.wait`. The full updated `_onLoaded` body from `final monday =` onwards:

```dart
final monday = _mondayOf(DateTime.now().toUtc());
final results = await Future.wait([
  _repository.getCardioLogsForWeek(monday),
  _repository.getCompletedRoutineSessionsForWeek(monday),
  _repository.getIndependentSessionsForWeek(monday),
  _repository.getWeeklyStats(weeksBack: 8),
]);
final weeklyCardio = results[0] as List<CardioLog>;
final completedSessions = results[1] as List<ExerciseSessionLog>;
final independentLogs = results[2] as List<IndependentExerciseLog>;
final weeklyStats = results[3] as List<WeeklyStat>;

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
  completedRoutineSessionsThisWeek: completedSessions,
  weeklyIndependentLogs: independentLogs,
  routineDaysGoal: config?.weeklyRoutineDaysGoal ?? 4,
  cardioDaysGoal: config?.weeklyCardioDaysGoal ?? 3,
  cardioMinutesGoal: config?.cardioMinutesGoal ?? 30,
  weeklyStats: weeklyStats,
));
```

Also add the missing import in `exercise_bloc.dart`:

```dart
import 'package:kiolog/features/exercise/domain/models/independent_exercise_log.dart';
```

- [ ] **Step 5: Run tests — expect pass**

```bash
flutter test test/features/exercise/presentation/exercise_bloc_test.dart
```

Expected: all tests pass.

- [ ] **Step 6: Commit**

```bash
git add lib/features/exercise/presentation/bloc/exercise_state.dart \
        lib/features/exercise/presentation/bloc/exercise_bloc.dart \
        test/features/exercise/presentation/exercise_bloc_test.dart
git commit -m "feat(exercise): add completedRoutineSessionsThisWeek and weeklyIndependentLogs to state"
```

---

### Task 5: Update independent exercise handlers

**Files:**
- Modify: `lib/features/exercise/presentation/bloc/exercise_bloc.dart`
- Modify: `test/features/exercise/presentation/exercise_bloc_test.dart`

Currently `_onIndependentExerciseLogged` and `_onIndependentExerciseDeleted` only reload `recentSessions`. They must also reload `weeklyIndependentLogs`.

- [ ] **Step 1: Write failing test for IndependentExerciseLogged**

```dart
blocTest<ExerciseBloc, ExerciseState>(
  'IndependentExerciseLogged reloads weeklyIndependentLogs',
  build: () {
    when(() => repository.startSession(any(), routineId: any(named: 'routineId')))
        .thenAnswer((_) async => 42);
    when(() => repository.logSet(
          sessionId: any(named: 'sessionId'),
          exerciseName: any(named: 'exerciseName'),
          setNumber: any(named: 'setNumber'),
          reps: any(named: 'reps'),
          weightKg: any(named: 'weightKg'),
          setType: any(named: 'setType'),
        )).thenAnswer((_) async {});
    when(() => repository.endSession(any())).thenAnswer((_) async {});
    when(() => repository.getSessionsForDate(any())).thenAnswer((_) async => []);
    when(() => repository.getIndependentSessionsForWeek(any()))
        .thenAnswer((_) async => [
              IndependentExerciseLog(
                sessionId: 42,
                date: DateTime(2026, 6, 9),
                exerciseName: 'Abdominales',
                sets: 3,
                reps: 20,
              ),
            ]);
    return ExerciseBloc(repository)
      ..emit(const ExerciseState(status: ExerciseStatus.success));
  },
  act: (bloc) => bloc.add(IndependentExerciseLogged(
    date: DateTime(2026, 6, 9),
    exerciseName: 'Abdominales',
    sets: 3,
    reps: 20,
  )),
  expect: () => [
    isA<ExerciseState>().having(
      (s) => s.weeklyIndependentLogs.length,
      'weeklyIndependentLogs length',
      1,
    ),
  ],
);
```

- [ ] **Step 2: Run test — expect failure**

```bash
flutter test test/features/exercise/presentation/exercise_bloc_test.dart --name "IndependentExerciseLogged reloads"
```

Expected: FAIL — `weeklyIndependentLogs` is empty.

- [ ] **Step 3: Update `_onIndependentExerciseLogged`**

Replace the emit at the end of `_onIndependentExerciseLogged`:

```dart
// Replace:
final sessions = await _repository.getSessionsForDate(event.date);
emit(state.copyWith(recentSessions: sessions));

// With:
final monday = _mondayOf(DateTime.now().toUtc());
final sessions = await _repository.getSessionsForDate(event.date);
final logs = await _repository.getIndependentSessionsForWeek(monday);
emit(state.copyWith(recentSessions: sessions, weeklyIndependentLogs: logs));
```

- [ ] **Step 4: Update `_onIndependentExerciseDeleted`**

Replace the emit at the end of `_onIndependentExerciseDeleted`:

```dart
// Replace:
final sessions = await _repository.getSessionsForDate(DateTime.now());
emit(state.copyWith(recentSessions: sessions));

// With:
final monday = _mondayOf(DateTime.now().toUtc());
final sessions = await _repository.getSessionsForDate(DateTime.now());
final logs = await _repository.getIndependentSessionsForWeek(monday);
emit(state.copyWith(recentSessions: sessions, weeklyIndependentLogs: logs));
```

- [ ] **Step 5: Run tests — expect pass**

```bash
flutter test test/features/exercise/presentation/exercise_bloc_test.dart
```

Expected: all tests pass.

- [ ] **Step 6: Commit**

```bash
git add lib/features/exercise/presentation/bloc/exercise_bloc.dart \
        test/features/exercise/presentation/exercise_bloc_test.dart
git commit -m "feat(exercise): reload weeklyIndependentLogs on independent exercise logged/deleted"
```

---

### Task 6: ExercisePage — scaffold + rutina section

**Files:**
- Modify: `lib/features/exercise/presentation/pages/exercise_page.dart`

`_ExerciseView` becomes a `StatefulWidget` to track which day card is expanded. The `BlocConsumer` with its existing `listenWhen` for session navigation is preserved intact.

- [ ] **Step 1: Convert `_ExerciseView` to StatefulWidget and rebuild scaffold**

Replace the entire `_ExerciseView` class (and everything after `ExercisePage`) with the following. Keep `ExercisePage` unchanged.

```dart
class _ExerciseView extends StatefulWidget {
  const _ExerciseView();

  @override
  State<_ExerciseView> createState() => _ExerciseViewState();
}

class _ExerciseViewState extends State<_ExerciseView> {
  int? _expandedRoutineId;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Ejercicio'),
        actions: [
          IconButton(
            icon: const Icon(Icons.history),
            onPressed: () => _showPlansDialog(context),
          ),
        ],
      ),
      body: BlocConsumer<ExerciseBloc, ExerciseState>(
        listenWhen: (prev, curr) =>
            prev.status == ExerciseStatus.success &&
            !prev.hasActiveSession &&
            curr.hasActiveSession,
        listener: (context, state) {
          final bloc = context.read<ExerciseBloc>();
          Navigator.of(context).push(
            MaterialPageRoute<void>(
              builder: (_) => BlocProvider.value(
                value: bloc,
                child: ExerciseSessionPage(
                  sessionId: state.activeSession!.id,
                ),
              ),
            ),
          );
        },
        builder: (context, state) {
          if (state.status == ExerciseStatus.loading &&
              state.activePlan == null) {
            return const Center(child: CircularProgressIndicator());
          }
          if (state.status == ExerciseStatus.failure) {
            return Center(child: Text('Error: ${state.error}'));
          }
          if (state.activePlan == null) {
            return _buildNoPlanView(context);
          }
          return SafeArea(
            child: ListView(
              padding: const EdgeInsets.all(16),
              children: [
                if (state.hasActiveSession)
                  _buildResumeSessionBanner(context, state),
                const SizedBox(height: 12),
                _buildRutinaSection(context, state),
                const SizedBox(height: 16),
                _buildCardioSection(context, state),
                const SizedBox(height: 16),
                _buildIndependentSection(context, state),
                const SizedBox(height: 80),
              ],
            ),
          );
        },
      ),
      bottomNavigationBar: BlocBuilder<ExerciseBloc, ExerciseState>(
        builder: (context, state) {
          if (state.activePlan == null) return const SizedBox.shrink();
          return _buildStartRoutineBar(context, state);
        },
      ),
    );
  }
```

- [ ] **Step 2: Add `_buildNoPlanView` and `_buildResumeSessionBanner` (same as before)**

These are unchanged from the current implementation. Paste them verbatim from the current `exercise_page.dart` (lines 90–261).

- [ ] **Step 3: Add `_buildRutinaSection`**

```dart
Widget _buildRutinaSection(BuildContext context, ExerciseState state) {
  final theme = Theme.of(context);
  final completedIds = state.completedRoutineSessionsThisWeek
      .map((s) => s.routineId)
      .whereType<int>()
      .toSet();
  final done = completedIds.length;
  final goal = state.routineDaysGoal;

  return Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Row(
        children: [
          Text('🏋️ Rutina semanal',
              style: theme.textTheme.titleMedium
                  ?.copyWith(fontWeight: FontWeight.bold)),
          const Spacer(),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 2),
            decoration: BoxDecoration(
              color: done >= goal
                  ? theme.colorScheme.tertiaryContainer
                  : theme.colorScheme.surfaceVariant,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Text(
              '$done / $goal días',
              style: theme.textTheme.labelSmall?.copyWith(
                color: done >= goal
                    ? theme.colorScheme.onTertiaryContainer
                    : theme.colorScheme.onSurfaceVariant,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
        ],
      ),
      const SizedBox(height: 6),
      LinearProgressIndicator(
        value: goal > 0 ? (done / goal).clamp(0.0, 1.0) : 0,
        backgroundColor: theme.colorScheme.surfaceVariant,
        color: theme.colorScheme.tertiary,
        borderRadius: BorderRadius.circular(2),
      ),
      const SizedBox(height: 10),
      if (state.routines.isEmpty)
        Card(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              children: [
                const Text('Sin días de rutina configurados.',
                    textAlign: TextAlign.center),
                const SizedBox(height: 12),
                FilledButton.icon(
                  onPressed: () => _showAddRoutineDialog(context, state),
                  icon: const Icon(Icons.add),
                  label: const Text('Agregar día de rutina'),
                ),
              ],
            ),
          ),
        )
      else
        ...state.routines.map((routine) {
          final isCompleted = completedIds.contains(routine.id);
          final isExpanded = _expandedRoutineId == routine.id;
          final items =
              state.routineItemsByRoutine[routine.id] ?? const [];

          return _buildRoutineDayCard(
            context: context,
            state: state,
            routine: routine,
            items: items,
            isCompleted: isCompleted,
            isExpanded: isExpanded,
          );
        }),
    ],
  );
}

Widget _buildRoutineDayCard({
  required BuildContext context,
  required ExerciseState state,
  required ExerciseRoutine routine,
  required List<ExerciseRoutineItem> items,
  required bool isCompleted,
  required bool isExpanded,
}) {
  final theme = Theme.of(context);
  final Color borderColor = isCompleted
      ? theme.colorScheme.tertiary
      : isExpanded
          ? theme.colorScheme.primary
          : theme.colorScheme.outline;
  final Color bgColor = isCompleted
      ? theme.colorScheme.tertiaryContainer.withOpacity(0.3)
      : isExpanded
          ? theme.colorScheme.primaryContainer.withOpacity(0.2)
          : Colors.transparent;

  return Card(
    margin: const EdgeInsets.only(bottom: 6),
    shape: RoundedRectangleBorder(
      borderRadius: BorderRadius.circular(8),
      side: BorderSide(color: borderColor, width: isExpanded ? 1.5 : 1),
    ),
    color: bgColor,
    child: Column(
      children: [
        // Header row
        InkWell(
          borderRadius: BorderRadius.circular(8),
          onTap: () => setState(() {
            _expandedRoutineId =
                isExpanded ? null : routine.id;
          }),
          child: Padding(
            padding:
                const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
            child: Row(
              children: [
                CircleAvatar(
                  radius: 14,
                  backgroundColor: isCompleted
                      ? theme.colorScheme.tertiary
                      : theme.colorScheme.surfaceVariant,
                  child: isCompleted
                      ? Icon(Icons.check,
                          size: 14,
                          color: theme.colorScheme.onTertiary)
                      : Text(
                          '${routine.dayNumber}',
                          style: theme.textTheme.labelSmall,
                        ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(routine.routineName,
                          style: theme.textTheme.titleSmall?.copyWith(
                            color: isCompleted
                                ? theme.colorScheme.tertiary
                                : null,
                          )),
                      if (isCompleted)
                        Text(
                          'Completado esta semana',
                          style: theme.textTheme.bodySmall?.copyWith(
                            color: theme.colorScheme.tertiary,
                          ),
                        )
                      else
                        Text(
                          '${items.length} ejercicio(s)',
                          style: theme.textTheme.bodySmall?.copyWith(
                            color: theme.colorScheme.onSurfaceVariant,
                          ),
                        ),
                    ],
                  ),
                ),
                Icon(
                  isExpanded
                      ? Icons.keyboard_arrow_up
                      : Icons.keyboard_arrow_down,
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ],
            ),
          ),
        ),
        // Expanded body
        if (isExpanded) ...[
          const Divider(height: 1),
          ...items.map((item) => _buildItemRow(context, item, routine.id)),
          Padding(
            padding: const EdgeInsets.fromLTRB(12, 4, 12, 8),
            child: Align(
              alignment: Alignment.centerRight,
              child: OutlinedButton.icon(
                onPressed: () =>
                    _showExerciseDialog(context, state, routineId: routine.id),
                icon: const Icon(Icons.add, size: 16),
                label: const Text('Ejercicio'),
                style: OutlinedButton.styleFrom(
                  visualDensity: VisualDensity.compact,
                ),
              ),
            ),
          ),
        ],
      ],
    ),
  );
}

Widget _buildItemRow(BuildContext context, ExerciseRoutineItem item, int routineId) {
  final theme = Theme.of(context);
  final weightStr =
      item.weightKg != null ? ' @ ${item.weightKg}kg' : '';
  return ListTile(
    dense: true,
    contentPadding: const EdgeInsets.only(left: 16, right: 4),
    title: Text(item.exerciseName, style: theme.textTheme.bodyMedium),
    subtitle: Text(
      '${item.sets}×${item.reps}$weightStr · ${item.setType}',
      style: theme.textTheme.bodySmall
          ?.copyWith(color: theme.colorScheme.onSurfaceVariant),
    ),
    trailing: Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        IconButton(
          icon: const Icon(Icons.edit_outlined, size: 18),
          onPressed: () =>
              _showExerciseDialog(context, context.read<ExerciseBloc>().state,
                  item: item, routineId: routineId),
          visualDensity: VisualDensity.compact,
        ),
        IconButton(
          icon: const Icon(Icons.delete_outline, size: 18),
          color: theme.colorScheme.error,
          onPressed: () => _confirmDeleteItem(context, item),
          visualDensity: VisualDensity.compact,
        ),
      ],
    ),
  );
}
```

- [ ] **Step 4: Add `_showExerciseDialog`**

This is the add/edit dialog. Uses `StatefulBuilder` to manage per-set detail rows.

```dart
void _showExerciseDialog(
  BuildContext context,
  ExerciseState state, {
  ExerciseRoutineItem? item,
  required int routineId,
}) {
  final nameCtrl =
      TextEditingController(text: item?.exerciseName ?? '');
  final setsCtrl =
      TextEditingController(text: item != null ? '${item.sets}' : '');
  final repsCtrl =
      TextEditingController(text: item != null ? '${item.reps}' : '');
  final weightCtrl = TextEditingController(
      text: item?.weightKg != null ? '${item!.weightKg}' : '');
  String selectedType = item?.setType ?? 'normal';

  // Per-set rows: List of (repsCtrl, weightCtrl)
  List<(TextEditingController, TextEditingController)> setRows = [];

  void rebuildRows(int count, StateSetter setInner) {
    setInner(() {
      while (setRows.length < count) {
        setRows.add((TextEditingController(), TextEditingController()));
      }
      while (setRows.length > count) {
        setRows.last.$1.dispose();
        setRows.last.$2.dispose();
        setRows.removeLast();
      }
    });
  }

  showDialog(
    context: context,
    builder: (dialogContext) => StatefulBuilder(
      builder: (ctx, setInner) {
        final isNormal = selectedType == 'normal';
        final setsCount = int.tryParse(setsCtrl.text) ?? 0;

        return AlertDialog(
          title: Text(item == null ? 'Agregar ejercicio' : 'Editar ejercicio'),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                TextField(
                  controller: nameCtrl,
                  decoration:
                      const InputDecoration(labelText: 'Nombre *'),
                  autofocus: item == null,
                ),
                const SizedBox(height: 8),
                Row(
                  children: [
                    Expanded(
                      child: TextField(
                        controller: setsCtrl,
                        decoration:
                            const InputDecoration(labelText: 'Series *'),
                        keyboardType: TextInputType.number,
                        onChanged: (v) {
                          if (!isNormal) {
                            rebuildRows(
                                int.tryParse(v) ?? 0, setInner);
                          }
                        },
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: TextField(
                        controller: repsCtrl,
                        decoration:
                            const InputDecoration(labelText: 'Reps *'),
                        keyboardType: TextInputType.number,
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: TextField(
                        controller: weightCtrl,
                        decoration:
                            const InputDecoration(labelText: 'kg'),
                        keyboardType: const TextInputType.numberWithOptions(
                            decimal: true),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                DropdownButtonFormField<String>(
                  value: selectedType,
                  decoration:
                      const InputDecoration(labelText: 'Tipo de serie'),
                  items: const [
                    DropdownMenuItem(
                        value: 'normal', child: Text('Normal')),
                    DropdownMenuItem(
                        value: 'pyramid', child: Text('Pirámide')),
                    DropdownMenuItem(
                        value: 'pyramid_drop',
                        child: Text('Pirámide + Drop')),
                  ],
                  onChanged: (v) {
                    if (v == null) return;
                    setInner(() => selectedType = v);
                    if (v != 'normal') {
                      rebuildRows(setsCount, setInner);
                    } else {
                      setInner(() {
                        for (final r in setRows) {
                          r.$1.dispose();
                          r.$2.dispose();
                        }
                        setRows = [];
                      });
                    }
                  },
                ),
                if (!isNormal && setRows.isNotEmpty) ...[
                  const SizedBox(height: 12),
                  Text('Detalle por serie',
                      style: Theme.of(ctx).textTheme.labelSmall),
                  const SizedBox(height: 4),
                  ...List.generate(setRows.length, (i) {
                    final (rCtrl, wCtrl) = setRows[i];
                    return Padding(
                      padding: const EdgeInsets.only(bottom: 4),
                      child: Row(
                        children: [
                          SizedBox(
                              width: 24,
                              child: Text('${i + 1}',
                                  style: Theme.of(ctx)
                                      .textTheme
                                      .bodySmall)),
                          const SizedBox(width: 8),
                          Expanded(
                            child: TextField(
                              controller: rCtrl,
                              decoration: const InputDecoration(
                                  labelText: 'Reps',
                                  isDense: true),
                              keyboardType: TextInputType.number,
                            ),
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: TextField(
                              controller: wCtrl,
                              decoration: const InputDecoration(
                                  labelText: 'kg', isDense: true),
                              keyboardType:
                                  const TextInputType.numberWithOptions(
                                      decimal: true),
                            ),
                          ),
                        ],
                      ),
                    );
                  }),
                ],
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () {
                for (final r in setRows) {
                  r.$1.dispose();
                  r.$2.dispose();
                }
                Navigator.pop(dialogContext);
              },
              child: const Text('Cancelar'),
            ),
            FilledButton(
              onPressed: () {
                final name = nameCtrl.text.trim();
                final sets = int.tryParse(setsCtrl.text);
                final reps = int.tryParse(repsCtrl.text);
                if (name.isEmpty || sets == null || reps == null) return;
                final weight =
                    double.tryParse(weightCtrl.text.replaceAll(',', '.'));

                final defs = setRows.isNotEmpty
                    ? List.generate(setRows.length, (i) {
                        final (rCtrl, wCtrl) = setRows[i];
                        return (
                          setNumber: i + 1,
                          dropOfSetNumber: null as int?,
                          reps:
                              int.tryParse(rCtrl.text) ?? reps,
                          weightKg: double.tryParse(
                              wCtrl.text.replaceAll(',', '.')),
                        );
                      })
                    : <({int setNumber, int? dropOfSetNumber, int reps, double? weightKg})>[];

                if (item == null) {
                  context.read<ExerciseBloc>().add(
                        ExerciseRoutineItemAdded(
                          routineId: routineId,
                          exerciseName: name,
                          sets: sets,
                          reps: reps,
                          weightKg: weight,
                          setType: selectedType,
                          setDefs: defs,
                        ),
                      );
                } else {
                  context.read<ExerciseBloc>().add(
                        ExerciseRoutineItemUpdated(
                          itemId: item.id,
                          exerciseName: name,
                          sets: sets,
                          reps: reps,
                          weightKg: weight,
                          setType: selectedType,
                          setDefs: defs.isEmpty ? null : defs,
                        ),
                      );
                }
                for (final r in setRows) {
                  r.$1.dispose();
                  r.$2.dispose();
                }
                Navigator.pop(dialogContext);
              },
              child: const Text('Guardar'),
            ),
          ],
        );
      },
    ),
  );
}

void _confirmDeleteItem(BuildContext context, ExerciseRoutineItem item) {
  showDialog<void>(
    context: context,
    builder: (dialogContext) => AlertDialog(
      title: const Text('¿Eliminar ejercicio?'),
      content: Text('Se eliminará "${item.exerciseName}" de la rutina.'),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(dialogContext),
          child: const Text('Cancelar'),
        ),
        FilledButton(
          onPressed: () {
            context.read<ExerciseBloc>().add(ExerciseRoutineItemDeleted(
                  itemId: item.id,
                  routineId: item.routineId,
                ));
            Navigator.pop(dialogContext);
          },
          style: FilledButton.styleFrom(
            backgroundColor: Theme.of(context).colorScheme.error,
          ),
          child: const Text('Eliminar'),
        ),
      ],
    ),
  );
}
```

- [ ] **Step 5: Run the app and smoke-test the rutina section**

```bash
flutter run
```

Navigate to ejercicio. Verify:
- Rutina section shows with progress chip and LinearProgressIndicator
- Day cards are visible, tapping expands/collapses (only one at a time)
- "＋ Ejercicio" opens dialog; can add an exercise; it appears in the list
- Edit icon opens pre-filled dialog
- Delete icon shows confirmation, then removes the item

- [ ] **Step 6: Commit**

```bash
git add lib/features/exercise/presentation/pages/exercise_page.dart
git commit -m "feat(exercise): dashboard semanal — scaffold y sección rutina"
```

---

### Task 7: ExercisePage — cardio section + dialog

**Files:**
- Modify: `lib/features/exercise/presentation/pages/exercise_page.dart`

- [ ] **Step 1: Add `_buildCardioSection`**

```dart
Widget _buildCardioSection(BuildContext context, ExerciseState state) {
  final theme = Theme.of(context);
  final done = state.weeklyCardioLogs.length;
  final goal = state.cardioDaysGoal;

  return Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Row(
        children: [
          Text('🏃 Cardio semanal',
              style: theme.textTheme.titleMedium
                  ?.copyWith(fontWeight: FontWeight.bold)),
          const Spacer(),
          Container(
            padding:
                const EdgeInsets.symmetric(horizontal: 10, vertical: 2),
            decoration: BoxDecoration(
              color: done >= goal
                  ? theme.colorScheme.tertiaryContainer
                  : theme.colorScheme.surfaceVariant,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Text(
              '$done / $goal días',
              style: theme.textTheme.labelSmall?.copyWith(
                fontWeight: FontWeight.bold,
                color: done >= goal
                    ? theme.colorScheme.onTertiaryContainer
                    : theme.colorScheme.onSurfaceVariant,
              ),
            ),
          ),
        ],
      ),
      const SizedBox(height: 6),
      LinearProgressIndicator(
        value: goal > 0 ? (done / goal).clamp(0.0, 1.0) : 0,
        backgroundColor: theme.colorScheme.surfaceVariant,
        color: theme.colorScheme.primary,
        borderRadius: BorderRadius.circular(2),
      ),
      const SizedBox(height: 10),
      ...state.weeklyCardioLogs.map((log) => _buildCardioItem(context, log)),
      _buildDashedAddButton(
        context: context,
        label: '＋ Registrar cardio',
        color: theme.colorScheme.primary,
        onTap: () => _showCardioDialog(context),
      ),
    ],
  );
}

Widget _buildCardioItem(BuildContext context, CardioLog log) {
  final theme = Theme.of(context);
  final weekday = _weekdayName(log.date.weekday);
  final icon = _cardioIcon(log.cardioType);
  return Card(
    margin: const EdgeInsets.only(bottom: 6),
    child: ListTile(
      leading: Text(icon, style: const TextStyle(fontSize: 20)),
      title: Text(log.cardioType),
      subtitle: Text('${log.durationMinutes} min · $weekday'),
      trailing: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          IconButton(
            icon: const Icon(Icons.edit_outlined, size: 18),
            onPressed: () => _showCardioDialog(context, log: log),
            visualDensity: VisualDensity.compact,
          ),
          IconButton(
            icon: const Icon(Icons.delete_outline, size: 18),
            color: theme.colorScheme.error,
            onPressed: () => context
                .read<ExerciseBloc>()
                .add(CardioDeleted(cardioId: log.id)),
            visualDensity: VisualDensity.compact,
          ),
        ],
      ),
    ),
  );
}

String _cardioIcon(String type) {
  switch (type.toLowerCase()) {
    case 'correr':
      return '🏃';
    case 'bici':
      return '🚴';
    case 'elíptica':
    case 'eliptica':
      return '⬡';
    case 'nadar':
      return '🏊';
    default:
      return '💧';
  }
}
```

- [ ] **Step 2: Add `_showCardioDialog`**

```dart
void _showCardioDialog(BuildContext context, {CardioLog? log}) {
  const types = ['Correr', 'Bici', 'Elíptica', 'Nadar', 'Otro'];
  String selectedType = log?.cardioType ?? types.first;
  final durationCtrl = TextEditingController(
      text: log != null ? '${log.durationMinutes}' : '');

  showDialog<void>(
    context: context,
    builder: (dialogContext) => StatefulBuilder(
      builder: (ctx, setInner) => AlertDialog(
        title: Text(log == null ? 'Registrar cardio' : 'Editar cardio'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            DropdownButtonFormField<String>(
              value: selectedType,
              decoration: const InputDecoration(labelText: 'Tipo'),
              items: types
                  .map((t) =>
                      DropdownMenuItem(value: t, child: Text(t)))
                  .toList(),
              onChanged: (v) {
                if (v != null) setInner(() => selectedType = v);
              },
            ),
            const SizedBox(height: 8),
            TextField(
              controller: durationCtrl,
              decoration:
                  const InputDecoration(labelText: 'Duración (minutos) *'),
              keyboardType: TextInputType.number,
              autofocus: log == null,
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: const Text('Cancelar'),
          ),
          FilledButton(
            onPressed: () {
              final duration = int.tryParse(durationCtrl.text);
              if (duration == null || duration <= 0) return;
              if (log == null) {
                context.read<ExerciseBloc>().add(CardioLogged(
                      date: DateTime.now(),
                      cardioType: selectedType,
                      durationMinutes: duration,
                    ));
              } else {
                context.read<ExerciseBloc>().add(CardioUpdated(
                      cardioId: log.id,
                      cardioType: selectedType,
                      durationMinutes: duration,
                    ));
              }
              Navigator.pop(dialogContext);
            },
            child: const Text('Guardar'),
          ),
        ],
      ),
    ),
  );
}
```

- [ ] **Step 3: Run the app and smoke-test the cardio section**

```bash
flutter run
```

Verify:
- Cardio section shows with chip and progress bar
- "+ Registrar cardio" opens dialog with dropdown and duration field
- Saving adds the item to the list
- Edit icon opens pre-filled dialog; delete removes immediately

- [ ] **Step 4: Commit**

```bash
git add lib/features/exercise/presentation/pages/exercise_page.dart
git commit -m "feat(exercise): dashboard semanal — sección cardio"
```

---

### Task 8: ExercisePage — ejercicio libre section + sticky button

**Files:**
- Modify: `lib/features/exercise/presentation/pages/exercise_page.dart`

- [ ] **Step 1: Add shared helpers (move to this task since `_buildCardioSection` in Task 7 already uses them)**

Add these at the bottom of `_ExerciseViewState`, before `_showPlansDialog`:

```dart
Widget _buildDashedAddButton({
  required BuildContext context,
  required String label,
  required Color color,
  required VoidCallback onTap,
}) {
  return GestureDetector(
    onTap: onTap,
    child: Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(vertical: 10),
      decoration: BoxDecoration(
        border: Border.all(color: color.withOpacity(0.5), width: 1),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Center(
        child: Text(label,
            style: TextStyle(color: color, fontWeight: FontWeight.w500)),
      ),
    ),
  );
}

String _weekdayName(int weekday) {
  const names = [
    '', 'lunes', 'martes', 'miércoles',
    'jueves', 'viernes', 'sábado', 'domingo'
  ];
  return names[weekday.clamp(1, 7)];
}
```

- [ ] **Step 2: Add `_buildIndependentSection`**

```dart
Widget _buildIndependentSection(BuildContext context, ExerciseState state) {
  final theme = Theme.of(context);

  return Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Row(
        children: [
          Text('💪 Ejercicio libre',
              style: theme.textTheme.titleMedium
                  ?.copyWith(fontWeight: FontWeight.bold)),
          const Spacer(),
          Text('esta semana',
              style: theme.textTheme.bodySmall
                  ?.copyWith(color: theme.colorScheme.onSurfaceVariant)),
        ],
      ),
      const SizedBox(height: 10),
      ...state.weeklyIndependentLogs
          .map((log) => _buildIndependentItem(context, log)),
      _buildDashedAddButton(
        context: context,
        label: '＋ Registrar ejercicio libre',
        color: theme.colorScheme.secondary,
        onTap: () => _showIndependentExerciseDialog(context),
      ),
    ],
  );
}

Widget _buildIndependentItem(BuildContext context, IndependentExerciseLog log) {
  final theme = Theme.of(context);
  final weightStr =
      log.weightKg != null ? ' @ ${log.weightKg}kg' : '';
  final weekday = _weekdayName(log.date.weekday);
  return Card(
    margin: const EdgeInsets.only(bottom: 6),
    child: ListTile(
      title: Text(log.exerciseName),
      subtitle: Text('${log.sets}×${log.reps}$weightStr · $weekday'),
      trailing: IconButton(
        icon: const Icon(Icons.delete_outline, size: 18),
        color: theme.colorScheme.error,
        onPressed: () => context
            .read<ExerciseBloc>()
            .add(IndependentExerciseDeleted(sessionId: log.sessionId)),
        visualDensity: VisualDensity.compact,
      ),
    ),
  );
}
```

- [ ] **Step 3: Add `_showIndependentExerciseDialog`**

```dart
void _showIndependentExerciseDialog(BuildContext context) {
  final nameCtrl = TextEditingController();
  final setsCtrl = TextEditingController();
  final repsCtrl = TextEditingController();
  final weightCtrl = TextEditingController();

  showDialog<void>(
    context: context,
    builder: (dialogContext) => AlertDialog(
      title: const Text('Registrar ejercicio libre'),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          TextField(
            controller: nameCtrl,
            decoration: const InputDecoration(labelText: 'Nombre *'),
            autofocus: true,
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              Expanded(
                child: TextField(
                  controller: setsCtrl,
                  decoration:
                      const InputDecoration(labelText: 'Series *'),
                  keyboardType: TextInputType.number,
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: TextField(
                  controller: repsCtrl,
                  decoration: const InputDecoration(labelText: 'Reps *'),
                  keyboardType: TextInputType.number,
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: TextField(
                  controller: weightCtrl,
                  decoration: const InputDecoration(labelText: 'kg'),
                  keyboardType: const TextInputType.numberWithOptions(
                      decimal: true),
                ),
              ),
            ],
          ),
        ],
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(dialogContext),
          child: const Text('Cancelar'),
        ),
        FilledButton(
          onPressed: () {
            final name = nameCtrl.text.trim();
            final sets = int.tryParse(setsCtrl.text);
            final reps = int.tryParse(repsCtrl.text);
            if (name.isEmpty || sets == null || reps == null) return;
            final weight = double.tryParse(
                weightCtrl.text.replaceAll(',', '.'));
            context.read<ExerciseBloc>().add(IndependentExerciseLogged(
                  date: DateTime.now(),
                  exerciseName: name,
                  sets: sets,
                  reps: reps,
                  weightKg: weight,
                ));
            Navigator.pop(dialogContext);
          },
          child: const Text('Guardar'),
        ),
      ],
    ),
  );
}
```

- [ ] **Step 4: Add sticky button builder**

```dart
Widget _buildStartRoutineBar(BuildContext context, ExerciseState state) {
  final completedIds = state.completedRoutineSessionsThisWeek
      .map((s) => s.routineId)
      .whereType<int>()
      .toSet();

  final nextRoutine = state.routines.isEmpty
      ? null
      : state.routines.firstWhere(
          (r) => !completedIds.contains(r.id),
          orElse: () => state.routines.first,
        );

  final enabled = nextRoutine != null && !state.hasActiveSession;

  return SafeArea(
    child: Padding(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
      child: FilledButton.icon(
        onPressed: enabled
            ? () => context.read<ExerciseBloc>().add(
                  ExerciseSessionStarted(
                    date: DateTime.now(),
                    routineId: nextRoutine!.id,
                  ),
                )
            : null,
        icon: const Icon(Icons.play_arrow),
        label: Text(state.hasActiveSession
            ? 'Sesión en curso'
            : state.routines.isEmpty
                ? 'Sin rutinas configuradas'
                : 'Iniciar rutina del día'),
        style: FilledButton.styleFrom(
          minimumSize: const Size.fromHeight(48),
        ),
      ),
    ),
  );
}
```

- [ ] **Step 5: Add missing imports to exercise_page.dart**

At the top of the file, add:

```dart
import 'package:kiolog/features/exercise/domain/models/independent_exercise_log.dart';
```

- [ ] **Step 6: Run full test suite**

```bash
flutter test
```

Expected: all existing tests pass (91+). Fix any compilation errors if found.

- [ ] **Step 7: Run the app and smoke-test end-to-end**

```bash
flutter run
```

Verify full golden path:
1. Dashboard shows all 3 sections
2. Rutina: tap day → expands; add exercise; edit exercise; delete exercise
3. Cardio: add cardio session → appears in list; edit; delete
4. Ejercicio libre: add entry → appears in list; delete
5. "Iniciar rutina del día" button auto-selects first uncompleted day and navigates to session
6. After completing a session and returning, the completed day card turns green
7. Resume session banner appears if session is in progress

- [ ] **Step 8: Commit**

```bash
git add lib/features/exercise/presentation/pages/exercise_page.dart
git commit -m "feat(exercise): dashboard semanal — sección ejercicio libre y botón sticky"
```

---

## Final check

```bash
flutter test && flutter analyze
```

Expected: all tests pass, no analysis issues.
