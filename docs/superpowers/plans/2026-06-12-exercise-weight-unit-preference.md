# Exercise Weight Unit Global Preference — Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Store a global kg/lbs preference in SharedPreferences (default: lbs) and display it via a toggle inside the exercise section, replacing all hardcoded "kg" labels.

**Architecture:** `ExerciseWeightUnitService` wraps SharedPreferences. `ExerciseWeightUnitCubit` (state = `String`) reads/writes via the service and is provided alongside `ExerciseBloc` inside `ExercisePage`. All exercise screens read the cubit for the unit label. Toggle UI is a compact `SegmentedButton<String>` inside `_buildRutinaSection`.

**Tech Stack:** Flutter, flutter_bloc, shared_preferences, get_it

---

## File Map

| Action | Path | Responsibility |
|--------|------|---------------|
| Modify | `pubspec.yaml` | Add `shared_preferences` dependency |
| Modify | `lib/core/di/injection.dart` | Init SharedPreferences, register service as singleton |
| **Create** | `lib/features/exercise/data/services/exercise_weight_unit_service.dart` | Persist/read unit in SharedPreferences |
| **Create** | `lib/features/exercise/presentation/cubit/exercise_weight_unit_cubit.dart` | Cubit: state = current unit string |
| **Create** | `test/unit/exercise_weight_unit_test.dart` | Unit tests for service + cubit |
| Modify | `lib/features/exercise/presentation/pages/exercise_page.dart` | Provide cubit, add toggle, consume cubit |
| Modify | `lib/features/exercise/presentation/pages/exercise_session_page.dart` | Consume cubit instead of `state.planWeightUnit` |
| Modify | `lib/features/exercise/presentation/bloc/exercise_state.dart` | Remove `planWeightUnit` getter (now from cubit) |

---

## Task 1: Add shared_preferences + init in DI

**Files:**
- Modify: `pubspec.yaml`
- Modify: `lib/core/di/injection.dart`

- [ ] **Step 1: Add dependency**

In `pubspec.yaml`, under `dependencies:` (after `intl: ^0.19.0`), add:

```yaml
  shared_preferences: ^2.3.0
```

- [ ] **Step 2: Run pub get**

```bash
flutter pub get
```

Expected output: package resolved, no errors.

- [ ] **Step 3: Initialize SharedPreferences in setupDependencies**

In `lib/core/di/injection.dart`, add import at the top:

```dart
import 'package:shared_preferences/shared_preferences.dart';
import '../../features/exercise/data/services/exercise_weight_unit_service.dart';
```

In `setupDependencies()`, add BEFORE the existing `getIt.registerSingleton<AppDatabase>` line:

```dart
  final prefs = await SharedPreferences.getInstance();
  getIt.registerSingleton<SharedPreferences>(prefs);
  getIt.registerLazySingleton<ExerciseWeightUnitService>(
    () => ExerciseWeightUnitService(getIt<SharedPreferences>()),
  );
```

- [ ] **Step 4: Verify no compile errors**

```bash
flutter analyze lib/core/di/injection.dart
```

Expected: no errors (file doesn't compile fully until service exists — proceed to Task 2).

- [ ] **Step 5: Commit**

```bash
git add pubspec.yaml pubspec.lock lib/core/di/injection.dart
git commit -m "chore: add shared_preferences, register ExerciseWeightUnitService in DI"
```

---

## Task 2: ExerciseWeightUnitService + tests

**Files:**
- Create: `lib/features/exercise/data/services/exercise_weight_unit_service.dart`
- Create: `test/unit/exercise_weight_unit_test.dart`

- [ ] **Step 1: Write the failing tests first**

Create `test/unit/exercise_weight_unit_test.dart`:

```dart
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:kiolog/features/exercise/data/services/exercise_weight_unit_service.dart';

void main() {
  group('ExerciseWeightUnitService', () {
    setUp(() {
      SharedPreferences.setMockInitialValues({});
    });

    test('getUnit returns lbs by default', () async {
      final prefs = await SharedPreferences.getInstance();
      final service = ExerciseWeightUnitService(prefs);
      expect(await service.getUnit(), 'lbs');
    });

    test('setUnit persists and getUnit returns new value', () async {
      final prefs = await SharedPreferences.getInstance();
      final service = ExerciseWeightUnitService(prefs);
      await service.setUnit('kg');
      expect(await service.getUnit(), 'kg');
    });

    test('getUnit returns stored value on second instance', () async {
      final prefs = await SharedPreferences.getInstance();
      await ExerciseWeightUnitService(prefs).setUnit('kg');
      final service2 = ExerciseWeightUnitService(prefs);
      expect(await service2.getUnit(), 'kg');
    });
  });
}
```

- [ ] **Step 2: Run tests — expect failure**

```bash
flutter test test/unit/exercise_weight_unit_test.dart
```

Expected: compilation error — `ExerciseWeightUnitService` not found.

- [ ] **Step 3: Implement service**

Create `lib/features/exercise/data/services/exercise_weight_unit_service.dart`:

```dart
import 'package:shared_preferences/shared_preferences.dart';

class ExerciseWeightUnitService {
  static const _key = 'exercise_weight_unit';
  static const _default = 'lbs';

  final SharedPreferences _prefs;

  ExerciseWeightUnitService(this._prefs);

  Future<String> getUnit() async => _prefs.getString(_key) ?? _default;

  Future<void> setUnit(String unit) async =>
      _prefs.setString(_key, unit);
}
```

- [ ] **Step 4: Run tests — expect pass**

```bash
flutter test test/unit/exercise_weight_unit_test.dart
```

Expected: 3 tests pass.

- [ ] **Step 5: Commit**

```bash
git add lib/features/exercise/data/services/exercise_weight_unit_service.dart test/unit/exercise_weight_unit_test.dart
git commit -m "feat(exercise): ExerciseWeightUnitService with SharedPreferences, default lbs"
```

---

## Task 3: ExerciseWeightUnitCubit + tests

**Files:**
- Create: `lib/features/exercise/presentation/cubit/exercise_weight_unit_cubit.dart`
- Modify: `test/unit/exercise_weight_unit_test.dart`

- [ ] **Step 1: Write failing cubit tests**

Append to `test/unit/exercise_weight_unit_test.dart` (add import at top):

```dart
import 'package:bloc_test/bloc_test.dart';
import 'package:kiolog/features/exercise/presentation/cubit/exercise_weight_unit_cubit.dart';
```

Add this group inside `main()` after the existing group:

```dart
  group('ExerciseWeightUnitCubit', () {
    setUp(() {
      SharedPreferences.setMockInitialValues({});
    });

    blocTest<ExerciseWeightUnitCubit, String>(
      'emits lbs on init when no stored value',
      build: () async {
        final prefs = await SharedPreferences.getInstance();
        return ExerciseWeightUnitCubit(ExerciseWeightUnitService(prefs));
      },
      act: (c) async => c.init(),
      expect: () => ['lbs'],
    );

    blocTest<ExerciseWeightUnitCubit, String>(
      'emits kg on init when kg was stored',
      setUp: () async {
        SharedPreferences.setMockInitialValues(
            {'exercise_weight_unit': 'kg'});
      },
      build: () async {
        final prefs = await SharedPreferences.getInstance();
        return ExerciseWeightUnitCubit(ExerciseWeightUnitService(prefs));
      },
      act: (c) async => c.init(),
      expect: () => ['kg'],
    );

    blocTest<ExerciseWeightUnitCubit, String>(
      'setUnit emits new value and persists',
      build: () async {
        final prefs = await SharedPreferences.getInstance();
        return ExerciseWeightUnitCubit(ExerciseWeightUnitService(prefs));
      },
      act: (c) async {
        await c.init();
        await c.setUnit('kg');
      },
      expect: () => ['lbs', 'kg'],
    );
  });
```

- [ ] **Step 2: Run tests — expect failure**

```bash
flutter test test/unit/exercise_weight_unit_test.dart
```

Expected: compilation error — `ExerciseWeightUnitCubit` not found.

- [ ] **Step 3: Implement cubit**

Create `lib/features/exercise/presentation/cubit/exercise_weight_unit_cubit.dart`:

```dart
import 'package:flutter_bloc/flutter_bloc.dart';
import '../../data/services/exercise_weight_unit_service.dart';

class ExerciseWeightUnitCubit extends Cubit<String> {
  final ExerciseWeightUnitService _service;

  ExerciseWeightUnitCubit(this._service) : super('lbs');

  Future<void> init() async => emit(await _service.getUnit());

  Future<void> setUnit(String unit) async {
    await _service.setUnit(unit);
    emit(unit);
  }
}
```

- [ ] **Step 4: Run tests — expect pass**

```bash
flutter test test/unit/exercise_weight_unit_test.dart
```

Expected: all 6 tests pass.

- [ ] **Step 5: Commit**

```bash
git add lib/features/exercise/presentation/cubit/exercise_weight_unit_cubit.dart test/unit/exercise_weight_unit_test.dart
git commit -m "feat(exercise): ExerciseWeightUnitCubit — global kg/lbs preference"
```

---

## Task 4: Wire cubit into ExercisePage + session navigation

**Files:**
- Modify: `lib/features/exercise/presentation/pages/exercise_page.dart`

The `ExercisePage.build()` currently creates a single `BlocProvider<ExerciseBloc>`. Wrap it with `MultiBlocProvider` to also provide `ExerciseWeightUnitCubit`.

The session page is pushed with `BlocProvider.value` — we must also pass the cubit there.

- [ ] **Step 1: Add imports to exercise_page.dart**

At the top of `lib/features/exercise/presentation/pages/exercise_page.dart`, add:

```dart
import '../../../../core/di/injection.dart'; // already present
import '../../data/services/exercise_weight_unit_service.dart';
import '../cubit/exercise_weight_unit_cubit.dart';
```

(The `injection.dart` import is already there — only add the two new ones.)

- [ ] **Step 2: Replace BlocProvider with MultiBlocProvider in ExercisePage.build()**

Find this block in `ExercisePage.build()`:

```dart
        return BlocProvider(
          create: (_) => ExerciseBloc(getIt<ExerciseRepository>())
            ..add(ExerciseLoaded(date: DateTime.now())),
          child: const _ExerciseView(),
        );
```

Replace with:

```dart
        return MultiBlocProvider(
          providers: [
            BlocProvider(
              create: (_) => ExerciseBloc(getIt<ExerciseRepository>())
                ..add(ExerciseLoaded(date: DateTime.now())),
            ),
            BlocProvider(
              create: (_) => ExerciseWeightUnitCubit(
                  getIt<ExerciseWeightUnitService>())
                ..init(),
            ),
          ],
          child: const _ExerciseView(),
        );
```

- [ ] **Step 3: Pass cubit when navigating to session page**

Find the session navigation inside `_ExerciseViewState.build()` (inside the `BlocConsumer.listener`):

```dart
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
```

Replace with:

```dart
            final weightCubit =
                context.read<ExerciseWeightUnitCubit>();
            Navigator.of(context).push(
              MaterialPageRoute<void>(
                builder: (_) => MultiBlocProvider(
                  providers: [
                    BlocProvider.value(value: bloc),
                    BlocProvider.value(value: weightCubit),
                  ],
                  child: ExerciseSessionPage(
                    sessionId: state.activeSession!.id,
                  ),
                ),
              ),
            );
```

- [ ] **Step 4: Pass cubit when navigating to progress page**

Find the progress page navigation in `_ExerciseViewState.build()` (inside AppBar actions):

```dart
              Navigator.of(context).push(
                MaterialPageRoute<void>(
                  builder: (_) => BlocProvider.value(
                    value: bloc,
                    child: const ExerciseProgressPage(),
                  ),
                ),
              );
```

Replace with:

```dart
              final weightCubit =
                  context.read<ExerciseWeightUnitCubit>();
              Navigator.of(context).push(
                MaterialPageRoute<void>(
                  builder: (_) => MultiBlocProvider(
                    providers: [
                      BlocProvider.value(value: bloc),
                      BlocProvider.value(value: weightCubit),
                    ],
                    child: const ExerciseProgressPage(),
                  ),
                ),
              );
```

- [ ] **Step 5: Verify compile**

```bash
flutter analyze lib/features/exercise/presentation/pages/exercise_page.dart
```

Expected: no errors.

- [ ] **Step 6: Commit**

```bash
git add lib/features/exercise/presentation/pages/exercise_page.dart
git commit -m "feat(exercise): provide ExerciseWeightUnitCubit in ExercisePage and pass to sub-routes"
```

---

## Task 5: Add toggle UI in exercise page

**Files:**
- Modify: `lib/features/exercise/presentation/pages/exercise_page.dart`

The toggle is a compact `SegmentedButton<String>` placed right before the routine day cards (after the progress bar and `SizedBox(height: 10)`) in `_buildRutinaSection`.

- [ ] **Step 1: Add toggle in _buildRutinaSection**

In `_buildRutinaSection`, find:

```dart
        const SizedBox(height: 10),
        if (state.routines.isEmpty)
```

Insert between those two lines:

```dart
        const SizedBox(height: 10),
        Align(
          alignment: Alignment.centerRight,
          child: BlocBuilder<ExerciseWeightUnitCubit, String>(
            builder: (ctx, unit) => SegmentedButton<String>(
              segments: const [
                ButtonSegment(value: 'lbs', label: Text('lbs')),
                ButtonSegment(value: 'kg', label: Text('kg')),
              ],
              selected: {unit},
              onSelectionChanged: (s) =>
                  ctx.read<ExerciseWeightUnitCubit>().setUnit(s.first),
              style: SegmentedButton.styleFrom(
                visualDensity: VisualDensity.compact,
                tapTargetSize: MaterialTapTargetSize.shrinkWrap,
              ),
            ),
          ),
        ),
        const SizedBox(height: 8),
        if (state.routines.isEmpty)
```

(Remove the old `const SizedBox(height: 10),` — the new block provides spacing before and after.)

- [ ] **Step 2: Verify compile**

```bash
flutter analyze lib/features/exercise/presentation/pages/exercise_page.dart
```

Expected: no errors.

- [ ] **Step 3: Commit**

```bash
git add lib/features/exercise/presentation/pages/exercise_page.dart
git commit -m "feat(exercise): add kg/lbs toggle SegmentedButton in rutina section"
```

---

## Task 6: Replace state.planWeightUnit with cubit in all displays

**Files:**
- Modify: `lib/features/exercise/presentation/pages/exercise_page.dart`
- Modify: `lib/features/exercise/presentation/pages/exercise_session_page.dart`
- Modify: `lib/features/exercise/presentation/bloc/exercise_state.dart`

`state.planWeightUnit` was a temporary getter added in the prior session. Now the cubit is the source of truth. Replace every usage.

- [ ] **Step 1: Update exercise_page.dart — _buildRutinaSection call site**

Find:

```dart
            ...items.map((item) =>
                _buildItemRow(context, item, routine.id, state.planWeightUnit)),
```

Replace with:

```dart
            ...items.map((item) => _buildItemRow(
                context,
                item,
                routine.id,
                context.read<ExerciseWeightUnitCubit>().state)),
```

- [ ] **Step 2: Update exercise_page.dart — _showExerciseDialog call sites**

`_showExerciseDialog` reads `state.planWeightUnit` as `weightUnit` inside the method. Change that line:

Find (inside `_showExerciseDialog`):

```dart
    final weightUnit = state.planWeightUnit;
```

Replace with:

```dart
    final weightUnit = context.read<ExerciseWeightUnitCubit>().state;
```

- [ ] **Step 3: Update exercise_page.dart — _buildIndependentSection and _showIndependentExerciseDialog**

Find:

```dart
        ...state.weeklyIndependentLogs
            .map((log) =>
                _buildIndependentItem(context, log, state.planWeightUnit)),
        _buildDashedAddButton(
          context: context,
          label: '＋ Registrar ejercicio libre',
          color: theme.colorScheme.secondary,
          onTap: () =>
              _showIndependentExerciseDialog(context, state.planWeightUnit),
```

Replace with:

```dart
        ...state.weeklyIndependentLogs
            .map((log) => _buildIndependentItem(
                context,
                log,
                context.read<ExerciseWeightUnitCubit>().state)),
        _buildDashedAddButton(
          context: context,
          label: '＋ Registrar ejercicio libre',
          color: theme.colorScheme.secondary,
          onTap: () => _showIndependentExerciseDialog(
              context,
              context.read<ExerciseWeightUnitCubit>().state),
```

- [ ] **Step 4: Update exercise_session_page.dart — three occurrences**

In `exercise_session_page.dart`, add import at top:

```dart
import '../cubit/exercise_weight_unit_cubit.dart';
```

Then replace all three `state.planWeightUnit` references:

**Occurrence 1** — in `_buildItemTile`, subtitle Text:

Find:
```dart
              subtitle: Text('${item.sets} series × ${item.reps} reps'
                  '${item.weightKg != null ? ' @ ${item.weightKg}${state.planWeightUnit}' : ''}'),
```
Replace with:
```dart
              subtitle: Text('${item.sets} series × ${item.reps} reps'
                  '${item.weightKg != null ? ' @ ${item.weightKg}${context.read<ExerciseWeightUnitCubit>().state}' : ''}'),
```

**Occurrence 2** — in `_buildItemTile`, historical last session text:

Find:
```dart
                '  Serie ${s.setNumber}: ${s.reps} reps'
                '${s.weightKg != null ? ' @ ${s.weightKg}${state.planWeightUnit}' : ''}',
```
Replace with:
```dart
                '  Serie ${s.setNumber}: ${s.reps} reps'
                '${s.weightKg != null ? ' @ ${s.weightKg}${context.read<ExerciseWeightUnitCubit>().state}' : ''}',
```

**Occurrence 3** — in `_buildItemTile`, table header:

Find:
```dart
                    _TableHeader('Peso ${state.planWeightUnit}'),
```
Replace with:
```dart
                    _TableHeader(
                        'Peso ${context.read<ExerciseWeightUnitCubit>().state}'),
```

- [ ] **Step 5: Remove planWeightUnit getter from ExerciseState**

In `lib/features/exercise/presentation/bloc/exercise_state.dart`, remove:

```dart
  String get planWeightUnit => activePlan?.weightUnit ?? 'kg';
```

- [ ] **Step 6: Verify compile — no errors**

```bash
flutter analyze lib/features/exercise/
```

Expected: zero errors (pre-existing deprecation infos are acceptable).

- [ ] **Step 7: Run all tests**

```bash
flutter test
```

Expected: all tests pass.

- [ ] **Step 8: Commit**

```bash
git add lib/features/exercise/presentation/pages/exercise_page.dart \
        lib/features/exercise/presentation/pages/exercise_session_page.dart \
        lib/features/exercise/presentation/bloc/exercise_state.dart
git commit -m "feat(exercise): consume ExerciseWeightUnitCubit for weight unit display in all exercise screens"
```

---

## Self-Review

**Spec coverage:**
- ✅ SharedPreferences wrapper (`ExerciseWeightUnitService`) — Task 2
- ✅ Cubit with `init()` + `setUnit()` — Task 3
- ✅ Default `lbs` — service constant + cubit initial state
- ✅ DI registration — Task 1
- ✅ Toggle UI in exercise section — Task 5
- ✅ All screens use cubit — Task 6
- ✅ Per-plan getter removed — Task 6 Step 5

**Placeholder scan:** No TBDs, all code blocks complete.

**Type consistency:** `ExerciseWeightUnitService` referenced consistently across Tasks 1-3-4. `ExerciseWeightUnitCubit` state is `String` throughout. `getIt<ExerciseWeightUnitService>()` registered in Task 1 before it's consumed in Task 4.
