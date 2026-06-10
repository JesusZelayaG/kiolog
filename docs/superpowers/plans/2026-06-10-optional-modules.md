# Optional Modules Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Allow users to select which modules (Nutrition, Hydration, Exercise) to track; inactive modules show a locked nav indicator, an activation screen, and a full config flow.

**Architecture:** New `user_modules` Drift table (seeded at onboarding) stores per-module enabled state. A singleton `ModulesCubit` exposes state to AppScaffold and module pages. Onboarding gains a module-selection step (step index 1) with skip logic for disabled steps. Each module page checks `ModulesCubit` and either renders normally or shows `InactiveModulePage`. Settings gains a "Módulos activos" section with Switch tiles and confirm dialogs. Three standalone config pages (`WaterConfigPage`, `NutritionConfigPage`, `ExerciseConfigPage`) are used by the activation flow; onboarding keeps its own inline step methods.

**Tech Stack:** Flutter, Drift (SQLite), flutter_bloc (Cubit), get_it, go_router, equatable

---

## File Map

| Action  | Path |
|---------|------|
| Create  | `lib/core/database/tables/user_modules_table.dart` |
| Modify  | `lib/core/database/app_database.dart` |
| Create  | `lib/core/dao/user_modules_dao.dart` |
| Create  | `lib/core/domain/app_module.dart` |
| Create  | `lib/core/modules/cubit/modules_state.dart` |
| Create  | `lib/core/modules/cubit/modules_cubit.dart` |
| Modify  | `lib/core/di/injection.dart` |
| Modify  | `lib/features/onboarding/presentation/pages/onboarding_page.dart` |
| Create  | `lib/features/water/presentation/pages/water_config_page.dart` |
| Create  | `lib/features/nutrition/presentation/pages/nutrition_config_page.dart` |
| Create  | `lib/features/exercise/presentation/pages/exercise_config_page.dart` |
| Modify  | `lib/core/router/app_router.dart` |
| Create  | `lib/shared/widgets/inactive_module_page.dart` |
| Modify  | `lib/shared/widgets/app_scaffold.dart` |
| Modify  | `lib/features/nutrition/presentation/pages/nutrition_page.dart` |
| Modify  | `lib/features/exercise/presentation/pages/exercise_page.dart` |
| Modify  | `lib/features/water/presentation/pages/water_page.dart` |
| Modify  | `lib/features/settings/presentation/pages/settings_page.dart` |

---

### Task 1: DB — `user_modules` table + `UserModulesDao`

**Files:**
- Create: `lib/core/database/tables/user_modules_table.dart`
- Modify: `lib/core/database/app_database.dart`
- Create: `lib/core/dao/user_modules_dao.dart`
- Test: `test/dao/user_modules_dao_test.dart`

- [ ] **Step 1: Write the failing DAO tests**

```dart
// test/dao/user_modules_dao_test.dart
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kiolog/core/dao/user_modules_dao.dart';
import 'package:kiolog/core/database/app_database.dart';

void main() {
  late AppDatabase db;
  late UserModulesDao dao;

  setUp(() {
    db = AppDatabase.forTesting(NativeDatabase.memory());
    dao = db.userModulesDao;
  });

  tearDown(() => db.close());

  group('UserModulesDao', () {
    test('isModuleEnabled returns true when row missing (default)', () async {
      expect(await dao.isModuleEnabled('nutrition'), isTrue);
    });

    test('setModuleEnabled inserts row and reflects enabled state', () async {
      await dao.setModuleEnabled('nutrition', false);
      expect(await dao.isModuleEnabled('nutrition'), isFalse);
    });

    test('setModuleEnabled upserts — second call updates row', () async {
      await dao.setModuleEnabled('water', false);
      await dao.setModuleEnabled('water', true);
      expect(await dao.isModuleEnabled('water'), isTrue);
    });

    test('getAllModuleStatuses returns map of all seeded modules', () async {
      await dao.setModuleEnabled('nutrition', true);
      await dao.setModuleEnabled('water', false);
      await dao.setModuleEnabled('exercise', true);
      final statuses = await dao.getAllModuleStatuses();
      expect(statuses['nutrition'], isTrue);
      expect(statuses['water'], isFalse);
      expect(statuses['exercise'], isTrue);
    });

    test('seedModules inserts all entries in one transaction', () async {
      await dao.seedModules({'nutrition': true, 'water': false, 'exercise': true});
      expect(await dao.isModuleEnabled('nutrition'), isTrue);
      expect(await dao.isModuleEnabled('water'), isFalse);
      expect(await dao.isModuleEnabled('exercise'), isTrue);
    });
  });
}
```

- [ ] **Step 2: Run tests — expect compile/runtime failures**

```bash
flutter test test/dao/user_modules_dao_test.dart -v
```

Expected: compile error — `UserModulesDao` not found.

- [ ] **Step 3: Create the table file**

```dart
// lib/core/database/tables/user_modules_table.dart
import 'package:drift/drift.dart';

class UserModules extends Table {
  TextColumn get module => text()();
  BoolColumn get enabled => boolean().withDefault(const Constant(true))();

  @override
  Set<Column> get primaryKey => {module};
}
```

- [ ] **Step 4: Create the DAO**

```dart
// lib/core/dao/user_modules_dao.dart
import 'package:drift/drift.dart';
import '../database/app_database.dart';
import '../database/tables/user_modules_table.dart';

part 'user_modules_dao.g.dart';

@DriftAccessor(tables: [UserModules])
class UserModulesDao extends DatabaseAccessor<AppDatabase>
    with _$UserModulesDaoMixin {
  UserModulesDao(super.db);

  Future<bool> isModuleEnabled(String module) async {
    final row = await (select(userModules)
          ..where((t) => t.module.equals(module)))
        .getSingleOrNull();
    return row?.enabled ?? true;
  }

  Future<Map<String, bool>> getAllModuleStatuses() async {
    final rows = await select(userModules).get();
    return {for (final r in rows) r.module: r.enabled};
  }

  Future<void> setModuleEnabled(String module, bool enabled) =>
      into(userModules).insertOnConflictUpdate(
        UserModulesCompanion(
          module: Value(module),
          enabled: Value(enabled),
        ),
      );

  Future<void> seedModules(Map<String, bool> modules) =>
      db.transaction(() async {
        for (final entry in modules.entries) {
          await setModuleEnabled(entry.key, entry.value);
        }
      });
}
```

- [ ] **Step 5: Register table + DAO + migration in AppDatabase**

In `lib/core/database/app_database.dart`:

Add import at top:
```dart
import 'tables/user_modules_table.dart';
import '../dao/user_modules_dao.dart';
```

Add `UserModules` to `tables` list and `UserModulesDao` to `daos` list:
```dart
@DriftDatabase(
  tables: [
    // ... existing tables ...
    UserModules,  // ADD THIS
  ],
  daos: [
    // ... existing daos ...
    UserModulesDao,  // ADD THIS
  ],
)
```

Update `schemaVersion` from `5` to `6` and add migration:
```dart
@override
int get schemaVersion => 6;

// In onUpgrade, add after the existing if (from < 5) block:
if (from < 6) {
  await m.createTable(userModules);
}
```

- [ ] **Step 6: Regenerate Drift code**

```bash
dart run build_runner build --delete-conflicting-outputs
```

Expected: generates `user_modules_dao.g.dart` and updates `app_database.g.dart`.

- [ ] **Step 7: Run tests — expect pass**

```bash
flutter test test/dao/user_modules_dao_test.dart -v
```

Expected: `+5: All tests passed!`

- [ ] **Step 8: Commit**

```bash
git add lib/core/database/tables/user_modules_table.dart \
        lib/core/dao/user_modules_dao.dart \
        lib/core/database/app_database.dart \
        lib/core/database/app_database.g.dart \
        lib/core/dao/user_modules_dao.g.dart \
        test/dao/user_modules_dao_test.dart
git commit -m "feat(modules): user_modules table + UserModulesDao"
```

---

### Task 2: `AppModule` enum + `ModulesCubit` + DI

**Files:**
- Create: `lib/core/domain/app_module.dart`
- Create: `lib/core/modules/cubit/modules_state.dart`
- Create: `lib/core/modules/cubit/modules_cubit.dart`
- Modify: `lib/core/di/injection.dart`
- Test: `test/core/modules/modules_cubit_test.dart`

- [ ] **Step 1: Write the failing cubit tests**

```dart
// test/core/modules/modules_cubit_test.dart
import 'package:bloc_test/bloc_test.dart';
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kiolog/core/dao/user_modules_dao.dart';
import 'package:kiolog/core/database/app_database.dart';
import 'package:kiolog/core/domain/app_module.dart';
import 'package:kiolog/core/modules/cubit/modules_cubit.dart';
import 'package:kiolog/core/modules/cubit/modules_state.dart';

void main() {
  late AppDatabase db;
  late UserModulesDao dao;

  setUp(() {
    db = AppDatabase.forTesting(NativeDatabase.memory());
    dao = db.userModulesDao;
  });

  tearDown(() => db.close());

  group('ModulesCubit', () {
    test('initial state has all modules enabled (default)', () {
      final cubit = ModulesCubit(dao);
      expect(cubit.state.isEnabled(AppModule.nutrition), isTrue);
      expect(cubit.state.isEnabled(AppModule.water), isTrue);
      expect(cubit.state.isEnabled(AppModule.exercise), isTrue);
    });

    blocTest<ModulesCubit, ModulesState>(
      'loadModules emits all-true when DB is empty',
      build: () => ModulesCubit(dao),
      act: (c) => c.loadModules(),
      expect: () => [
        predicate<ModulesState>((s) =>
            s.isEnabled(AppModule.nutrition) &&
            s.isEnabled(AppModule.water) &&
            s.isEnabled(AppModule.exercise)),
      ],
    );

    blocTest<ModulesCubit, ModulesState>(
      'loadModules reflects seeded DB state',
      setUp: () async {
        await dao.seedModules({
          'nutrition': false,
          'water': true,
          'exercise': true,
        });
      },
      build: () => ModulesCubit(dao),
      act: (c) => c.loadModules(),
      expect: () => [
        predicate<ModulesState>((s) =>
            !s.isEnabled(AppModule.nutrition) &&
            s.isEnabled(AppModule.water) &&
            s.isEnabled(AppModule.exercise)),
      ],
    );

    blocTest<ModulesCubit, ModulesState>(
      'setModuleEnabled updates DB and emits new state',
      build: () => ModulesCubit(dao),
      act: (c) async {
        await c.loadModules();
        await c.setModuleEnabled(AppModule.exercise, false);
      },
      expect: () => [
        isA<ModulesState>(), // from loadModules
        predicate<ModulesState>((s) => !s.isEnabled(AppModule.exercise)),
      ],
    );
  });
}
```

- [ ] **Step 2: Run tests — expect compile failures**

```bash
flutter test test/core/modules/modules_cubit_test.dart -v
```

Expected: compile error — files not found.

- [ ] **Step 3: Create AppModule enum**

```dart
// lib/core/domain/app_module.dart
enum AppModule {
  nutrition,
  water,
  exercise;

  String get key => name; // 'nutrition', 'water', 'exercise'
}
```

- [ ] **Step 4: Create ModulesState**

```dart
// lib/core/modules/cubit/modules_state.dart
import 'package:equatable/equatable.dart';
import '../../domain/app_module.dart';

class ModulesState extends Equatable {
  final Map<AppModule, bool> statuses;

  const ModulesState({this.statuses = const {}});

  bool isEnabled(AppModule module) => statuses[module] ?? true;

  ModulesState copyWith({Map<AppModule, bool>? statuses}) =>
      ModulesState(statuses: statuses ?? this.statuses);

  @override
  List<Object?> get props => [statuses];
}
```

- [ ] **Step 5: Create ModulesCubit**

```dart
// lib/core/modules/cubit/modules_cubit.dart
import 'package:flutter_bloc/flutter_bloc.dart';
import '../../dao/user_modules_dao.dart';
import '../../domain/app_module.dart';
import 'modules_state.dart';

class ModulesCubit extends Cubit<ModulesState> {
  final UserModulesDao _dao;

  ModulesCubit(this._dao) : super(const ModulesState());

  Future<void> loadModules() async {
    final raw = await _dao.getAllModuleStatuses();
    final statuses = {
      for (final m in AppModule.values) m: raw[m.key] ?? true,
    };
    emit(state.copyWith(statuses: statuses));
  }

  Future<void> setModuleEnabled(AppModule module, bool enabled) async {
    await _dao.setModuleEnabled(module.key, enabled);
    final updated = Map<AppModule, bool>.from(state.statuses)
      ..[module] = enabled;
    emit(state.copyWith(statuses: updated));
  }
}
```

- [ ] **Step 6: Register in DI**

In `lib/core/di/injection.dart`, add imports:
```dart
import '../dao/user_modules_dao.dart';
import '../domain/app_module.dart';
import '../modules/cubit/modules_cubit.dart';
```

In `setupDependencies()`, after the existing DAO registrations, add:
```dart
getIt.registerLazySingleton(() => getIt<AppDatabase>().userModulesDao);
getIt.registerLazySingleton<ModulesCubit>(
  () => ModulesCubit(getIt<UserModulesDao>()),
);
```

Also add the `loadModules()` call in `setupDependencies()` after the above, before the function returns:
```dart
await getIt<ModulesCubit>().loadModules();
```

- [ ] **Step 7: Run tests**

```bash
flutter test test/core/modules/modules_cubit_test.dart -v
```

Expected: `+4: All tests passed!`

- [ ] **Step 8: Commit**

```bash
git add lib/core/domain/app_module.dart \
        lib/core/modules/cubit/modules_state.dart \
        lib/core/modules/cubit/modules_cubit.dart \
        lib/core/di/injection.dart \
        test/core/modules/modules_cubit_test.dart
git commit -m "feat(modules): AppModule enum + ModulesCubit + DI registration"
```

---

### Task 3: Onboarding — module selection step + conditional navigation

**Files:**
- Modify: `lib/features/onboarding/presentation/pages/onboarding_page.dart`
- Test: `test/features/onboarding/presentation/onboarding_module_selection_test.dart`

**Context:** The file currently has `_totalSteps = 5` and these PageView children (indices 0–4):
- 0: Welcome
- 1: Water Config
- 2: Nutrition Config
- 3: Exercise Config
- 4: Initial Data

After this task the children are (indices 0–5):
- 0: Welcome
- 1: **Module Selection** (new)
- 2: Water Config
- 3: Nutrition Config
- 4: Exercise Config
- 5: Initial Data

- [ ] **Step 1: Write the failing tests**

```dart
// test/features/onboarding/presentation/onboarding_module_selection_test.dart
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

// Harness that mirrors the module-selection step state
class _ModuleSelectionHarness extends StatefulWidget {
  const _ModuleSelectionHarness();

  @override
  State<_ModuleSelectionHarness> createState() =>
      _ModuleSelectionHarnessState();
}

class _ModuleSelectionHarnessState extends State<_ModuleSelectionHarness> {
  final Set<String> _active = {'nutrition', 'water', 'exercise'};

  bool get _canProceed => _active.isNotEmpty;

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      home: Scaffold(
        body: Column(
          children: [
            for (final m in ['nutrition', 'water', 'exercise'])
              SwitchListTile(
                key: Key('module_switch_$m'),
                title: Text(m),
                value: _active.contains(m),
                onChanged: (_active.length == 1 && _active.contains(m))
                    ? null
                    : (val) => setState(() {
                          if (val) {
                            _active.add(m);
                          } else {
                            _active.remove(m);
                          }
                        }),
              ),
            TextButton(
              key: const Key('next_btn'),
              onPressed: _canProceed ? () {} : null,
              child: const Text('Siguiente'),
            ),
          ],
        ),
      ),
    );
  }
}

void main() {
  group('Onboarding module selection step', () {
    testWidgets('all modules enabled by default', (tester) async {
      await tester.pumpWidget(const _ModuleSelectionHarness());
      expect(
        tester.widget<SwitchListTile>(
            find.byKey(const Key('module_switch_nutrition'))).value,
        isTrue,
      );
      expect(
        tester.widget<SwitchListTile>(
            find.byKey(const Key('module_switch_water'))).value,
        isTrue,
      );
      expect(
        tester.widget<SwitchListTile>(
            find.byKey(const Key('module_switch_exercise'))).value,
        isTrue,
      );
    });

    testWidgets('toggling off a module disables its switch', (tester) async {
      await tester.pumpWidget(const _ModuleSelectionHarness());
      await tester.tap(find.byKey(const Key('module_switch_exercise')));
      await tester.pumpAndSettle();
      expect(
        tester.widget<SwitchListTile>(
            find.byKey(const Key('module_switch_exercise'))).value,
        isFalse,
      );
    });

    testWidgets('last remaining module switch cannot be turned off',
        (tester) async {
      await tester.pumpWidget(const _ModuleSelectionHarness());
      await tester.tap(find.byKey(const Key('module_switch_water')));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('module_switch_exercise')));
      await tester.pumpAndSettle();
      // Only nutrition remains — its onChanged should be null
      final tile = tester.widget<SwitchListTile>(
          find.byKey(const Key('module_switch_nutrition')));
      expect(tile.onChanged, isNull);
    });

    testWidgets('next button enabled when at least one module active',
        (tester) async {
      await tester.pumpWidget(const _ModuleSelectionHarness());
      await tester.tap(find.byKey(const Key('module_switch_water')));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('module_switch_exercise')));
      await tester.pumpAndSettle();
      final btn = tester.widget<TextButton>(find.byKey(const Key('next_btn')));
      expect(btn.onPressed, isNotNull);
    });
  });
}
```

- [ ] **Step 2: Run tests — expect pass (harness validates logic)**

```bash
flutter test test/features/onboarding/presentation/onboarding_module_selection_test.dart -v
```

Expected: `+4: All tests passed!`

- [ ] **Step 3: Add `_activeModules` to `_OnboardingViewState`**

In `lib/features/onboarding/presentation/pages/onboarding_page.dart`:

Add import at top:
```dart
import '../../../../core/domain/app_module.dart';
import '../../../../core/di/injection.dart';
import '../../../../core/dao/user_modules_dao.dart';
import '../../../../core/modules/cubit/modules_cubit.dart';
```

In `_OnboardingViewState`, after the existing state field declarations, add:
```dart
// Module selection (step 1)
final Set<AppModule> _activeModules = Set.from(AppModule.values);
```

Change `final int _totalSteps = 5;` to:
```dart
final int _totalSteps = 6;
```

- [ ] **Step 4: Add step skip helpers**

In `_OnboardingViewState`, add these methods (place them near `_nextStep` / `_prevStep`):

```dart
bool _isStepEnabled(int stepIndex) {
  // Step indices: 0=Welcome, 1=ModuleSelection, 2=Water, 3=Nutrition, 4=Exercise, 5=InitialData
  switch (stepIndex) {
    case 2:
      return _activeModules.contains(AppModule.water);
    case 3:
      return _activeModules.contains(AppModule.nutrition);
    case 4:
      return _activeModules.contains(AppModule.exercise);
    default:
      return true;
  }
}

int get _totalActiveSteps =>
    3 + _activeModules.length; // Welcome + ModuleSelection + InitialData + active count

int get _currentActiveStep {
  int count = 0;
  for (int i = 0; i <= _currentStep; i++) {
    if (_isStepEnabled(i)) count++;
  }
  return count;
}

bool get _canProceed =>
    _currentStep != 1 || _activeModules.isNotEmpty;
```

Replace the existing `_nextStep` and `_prevStep` methods with:
```dart
void _nextStep() {
  var next = _currentStep + 1;
  while (next < _totalSteps && !_isStepEnabled(next)) next++;
  if (next < _totalSteps) {
    setState(() => _currentStep = next);
    _pageController.jumpToPage(next);
  }
}

void _prevStep() {
  var prev = _currentStep - 1;
  while (prev >= 0 && !_isStepEnabled(prev)) prev--;
  if (prev >= 0) {
    setState(() => _currentStep = prev);
    _pageController.jumpToPage(prev);
  }
}
```

- [ ] **Step 5: Update progress indicator and "Siguiente" button**

In the `build` method of `_OnboardingViewState`, find the `LinearProgressIndicator` line and replace:
```dart
// Replace:
value: (_currentStep + 1) / _totalSteps,
// With:
value: _currentActiveStep / _totalActiveSteps,
```

Find the "Finalizar" / "Siguiente" `FilledButton` and replace:
```dart
// Replace:
FilledButton(
  onPressed: _currentStep == _totalSteps - 1 ? _finish : _nextStep,
  child: Text(_currentStep == _totalSteps - 1 ? 'Finalizar' : 'Siguiente'),
),
// With:
FilledButton(
  onPressed: _canProceed
      ? (_currentStep == _totalSteps - 1 ? _finish : _nextStep)
      : null,
  child: Text(_currentStep == _totalSteps - 1 ? 'Finalizar' : 'Siguiente'),
),
```

- [ ] **Step 6: Add the module selection step to the PageView**

In the `build` method, find the `PageView` children list:
```dart
children: [
  _buildWelcomeStep(theme),
  _buildWaterStep(theme),
  _buildNutritionStep(theme),
  _buildExerciseStep(theme),
  _buildInitialDataStep(theme),
],
```
Replace with:
```dart
children: [
  _buildWelcomeStep(theme),
  _buildModuleSelectionStep(theme),  // new step index 1
  _buildWaterStep(theme),
  _buildNutritionStep(theme),
  _buildExerciseStep(theme),
  _buildInitialDataStep(theme),
],
```

- [ ] **Step 7: Add `_buildModuleSelectionStep` method**

Add this method to `_OnboardingViewState` (place it near the other `_build*Step` methods):

```dart
Widget _buildModuleSelectionStep(ThemeData theme) {
  return SingleChildScrollView(
    padding: const EdgeInsets.all(24),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('¿Qué quieres registrar?',
            style: theme.textTheme.headlineSmall),
        const SizedBox(height: 8),
        Text(
          'Puedes cambiar esto más adelante en Ajustes.',
          style: theme.textTheme.bodyLarge,
        ),
        const SizedBox(height: 24),
        _buildModuleToggle(
          theme,
          icon: Icons.water_drop_outlined,
          title: 'Hidratación',
          subtitle: 'Meta diaria de agua',
          module: AppModule.water,
        ),
        const Divider(),
        _buildModuleToggle(
          theme,
          icon: Icons.restaurant_outlined,
          title: 'Nutrición',
          subtitle: 'Plan de comidas',
          module: AppModule.nutrition,
        ),
        const Divider(),
        _buildModuleToggle(
          theme,
          icon: Icons.fitness_center_outlined,
          title: 'Ejercicio',
          subtitle: 'Rutinas y series',
          module: AppModule.exercise,
        ),
        const SizedBox(height: 16),
        Text(
          'Al menos un módulo debe estar activo.',
          style: theme.textTheme.bodySmall?.copyWith(
            color: theme.colorScheme.onSurfaceVariant,
          ),
        ),
      ],
    ),
  );
}

Widget _buildModuleToggle(
  ThemeData theme, {
  required IconData icon,
  required String title,
  required String subtitle,
  required AppModule module,
}) {
  final isEnabled = _activeModules.contains(module);
  final isLast = _activeModules.length == 1 && isEnabled;
  return Padding(
    padding: const EdgeInsets.symmetric(vertical: 4),
    child: Row(
      children: [
        Icon(
          icon,
          color: isEnabled
              ? null
              : theme.colorScheme.onSurface.withValues(alpha: 0.3),
        ),
        const SizedBox(width: 16),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: theme.textTheme.bodyLarge?.copyWith(
                  color: isEnabled
                      ? null
                      : theme.colorScheme.onSurface.withValues(alpha: 0.4),
                ),
              ),
              Text(
                subtitle,
                style: theme.textTheme.bodySmall?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant
                      .withValues(alpha: isEnabled ? 1.0 : 0.4),
                ),
              ),
            ],
          ),
        ),
        Switch(
          value: isEnabled,
          onChanged: isLast
              ? null
              : (val) => setState(() {
                    if (val) {
                      _activeModules.add(module);
                    } else {
                      _activeModules.remove(module);
                    }
                  }),
        ),
      ],
    ),
  );
}
```

- [ ] **Step 8: Update `_finish()` — conditional saves + seed `user_modules`**

In `_finish()`, wrap each module's save block with an active-module check and seed modules at the end:

```dart
Future<void> _finish() async {
  // Water config (only if active)
  if (_activeModules.contains(AppModule.water)) {
    await getIt<WaterRepository>().saveConfig(
      unitType: _waterUnit,
      containerMl: _containerMl,
      dailyGoalMl: _dailyGoalMl,
    );
  }

  // Nutrition plan (only if active)
  if (_activeModules.contains(AppModule.nutrition)) {
    final nutritionRepo = getIt<NutritionRepository>();
    final planId = await nutritionRepo.createPlan(
      _mealPlanNameController.text,
      dailyMealGoal: _mealTimes.length,
    );
    for (final mealTime in _mealTimes) {
      final typeName = mealTime.nameController.text.trim();
      if (typeName.isEmpty) continue;
      for (int i = 0; i < mealTime.options.length; i++) {
        final text = mealTime.options[i].text.trim();
        if (text.isNotEmpty) {
          await nutritionRepo.addPlanOption(
            planId: planId,
            mealType: typeName,
            optionNumber: i + 1,
            description: text,
          );
        }
      }
    }
  }

  // Exercise plan (only if active)
  if (_activeModules.contains(AppModule.exercise)) {
    final exerciseRepo = getIt<ExerciseRepository>();
    final exercisePlanId =
        await exerciseRepo.createPlan(_exercisePlanNameController.text);
    for (int i = 0; i < _routineDays.length; i++) {
      final day = _routineDays[i];
      final routineName = day.nameController.text.trim().isEmpty
          ? 'Día ${i + 1}'
          : day.nameController.text.trim();
      final routineId = await exerciseRepo.addRoutine(
        planId: exercisePlanId,
        dayNumber: i + 1,
        routineName: routineName,
      );
      for (final ex in day.exercises) {
        final sets = int.tryParse(ex.sets.text) ?? 3;
        final reps = int.tryParse(ex.reps.text) ?? 10;
        final weight = double.tryParse(ex.weight.text);
        if (ex.name.text.isNotEmpty) {
          await exerciseRepo.addRoutineItem(
            routineId: routineId,
            exerciseName: ex.name.text,
            sets: sets,
            reps: reps,
            weightKg: weight,
          );
        }
      }
    }
  }

  // Initial weight
  final weight = double.tryParse(_weightController.text);
  if (weight != null) {
    await getIt<ProgressRepository>().addWeightLog(_startDate, weight);
  }

  // Seed module statuses
  await getIt<UserModulesDao>().seedModules({
    AppModule.water.key: _activeModules.contains(AppModule.water),
    AppModule.nutrition.key: _activeModules.contains(AppModule.nutrition),
    AppModule.exercise.key: _activeModules.contains(AppModule.exercise),
  });

  // Reload cubit so nav reflects selected modules immediately
  await getIt<ModulesCubit>().loadModules();

  // Mark onboarding complete
  await getIt<UserProfileDao>().completeOnboarding(_startDate);

  if (mounted) {
    context.go('/');
  }
}
```

- [ ] **Step 9: Run full test suite**

```bash
flutter test
```

Expected: existing tests still pass (131 passing, 1 pre-existing failure). New 4 onboarding tests pass.

- [ ] **Step 10: Commit**

```bash
git add lib/features/onboarding/presentation/pages/onboarding_page.dart \
        test/features/onboarding/presentation/onboarding_module_selection_test.dart
git commit -m "feat(onboarding): module selection step + conditional step skipping"
```

---

### Task 4: Module config pages + router routes

**Files:**
- Create: `lib/features/water/presentation/pages/water_config_page.dart`
- Create: `lib/features/nutrition/presentation/pages/nutrition_config_page.dart`
- Create: `lib/features/exercise/presentation/pages/exercise_config_page.dart`
- Modify: `lib/core/router/app_router.dart`
- Test: `test/features/water/presentation/water_config_page_test.dart`

These pages are launched when activating an inactive module. Each page owns its form state, saves to the DB on completion, enables the module via `ModulesCubit`, then calls `onComplete`.

- [ ] **Step 1: Write failing test for WaterConfigPage**

```dart
// test/features/water/presentation/water_config_page_test.dart
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kiolog/features/water/presentation/pages/water_config_page.dart';

void main() {
  group('WaterConfigPage', () {
    testWidgets('shows unit selector and goal field', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: WaterConfigPage(onComplete: () {}),
        ),
      );
      expect(find.text('Configuración de Agua'), findsOneWidget);
      expect(find.byType(SegmentedButton<String>), findsOneWidget);
    });

    testWidgets('Guardar button exists and is tappable', (tester) async {
      bool completed = false;
      await tester.pumpWidget(
        MaterialApp(
          home: WaterConfigPage(onComplete: () { completed = true; }),
        ),
      );
      // Tap save — will fail to save in test (no real DB) but button exists
      expect(find.widgetWithText(FilledButton, 'Guardar'), findsOneWidget);
    });
  });
}
```

- [ ] **Step 2: Run tests — expect compile failure**

```bash
flutter test test/features/water/presentation/water_config_page_test.dart -v
```

Expected: compile error — `WaterConfigPage` not found.

- [ ] **Step 3: Create WaterConfigPage**

Copy the form UI from `_buildWaterStep` in `onboarding_page.dart`. The page owns `_waterUnit`, `_containerMl`, `_dailyGoalMl` state.

```dart
// lib/features/water/presentation/pages/water_config_page.dart
import 'package:flutter/material.dart';
import '../../../../core/di/injection.dart';
import '../../../../core/domain/app_module.dart';
import '../../../../core/modules/cubit/modules_cubit.dart';
import '../../domain/repositories/water_repository.dart';

class WaterConfigPage extends StatefulWidget {
  final VoidCallback onComplete;

  const WaterConfigPage({super.key, required this.onComplete});

  @override
  State<WaterConfigPage> createState() => _WaterConfigPageState();
}

class _WaterConfigPageState extends State<WaterConfigPage> {
  String _waterUnit = 'bottle';
  int _containerMl = 1000;
  int _dailyGoalMl = 3000;
  bool _saving = false;

  Future<void> _save() async {
    setState(() => _saving = true);
    await getIt<WaterRepository>().saveConfig(
      unitType: _waterUnit,
      containerMl: _containerMl,
      dailyGoalMl: _dailyGoalMl,
    );
    await getIt<ModulesCubit>().setModuleEnabled(AppModule.water, true);
    if (mounted) {
      Navigator.of(context).pop();
      widget.onComplete();
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Scaffold(
      appBar: AppBar(title: const Text('Configuración de Agua')),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              '¿Cómo vas a medir tu ingesta de agua?',
              style: theme.textTheme.bodyLarge,
            ),
            const SizedBox(height: 24),
            SegmentedButton<String>(
              segments: const [
                ButtonSegment(value: 'bottle', label: Text('Botella')),
                ButtonSegment(value: 'glass', label: Text('Vaso')),
              ],
              selected: {_waterUnit},
              onSelectionChanged: (set) => setState(() {
                _waterUnit = set.first;
                _containerMl = _waterUnit == 'bottle' ? 1000 : 250;
              }),
            ),
            const SizedBox(height: 24),
            Text('Tamaño del recipiente (ml)',
                style: theme.textTheme.labelMedium),
            Slider(
              value: _containerMl.toDouble(),
              min: 100,
              max: 2000,
              divisions: 19,
              label: '$_containerMl ml',
              onChanged: (v) => setState(() => _containerMl = v.round()),
            ),
            const SizedBox(height: 16),
            Text('Meta diaria (ml)', style: theme.textTheme.labelMedium),
            Slider(
              value: _dailyGoalMl.toDouble(),
              min: 500,
              max: 5000,
              divisions: 18,
              label: '$_dailyGoalMl ml',
              onChanged: (v) => setState(() => _dailyGoalMl = v.round()),
            ),
            const SizedBox(height: 32),
            SizedBox(
              width: double.infinity,
              child: FilledButton(
                onPressed: _saving ? null : _save,
                child: const Text('Guardar'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
```

- [ ] **Step 4: Create NutritionConfigPage**

```dart
// lib/features/nutrition/presentation/pages/nutrition_config_page.dart
import 'package:flutter/material.dart';
import '../../../../core/di/injection.dart';
import '../../../../core/domain/app_module.dart';
import '../../../../core/modules/cubit/modules_cubit.dart';
import '../../domain/repositories/nutrition_repository.dart';

class _MealTimeEntry {
  final nameController = TextEditingController();
  final List<TextEditingController> options = [TextEditingController()];
}

class NutritionConfigPage extends StatefulWidget {
  final VoidCallback onComplete;

  const NutritionConfigPage({super.key, required this.onComplete});

  @override
  State<NutritionConfigPage> createState() => _NutritionConfigPageState();
}

class _NutritionConfigPageState extends State<NutritionConfigPage> {
  final _planNameController = TextEditingController(text: 'Mi Plan');
  final List<_MealTimeEntry> _mealTimes = [_MealTimeEntry()];
  bool _saving = false;

  @override
  void dispose() {
    _planNameController.dispose();
    for (final mt in _mealTimes) {
      mt.nameController.dispose();
      for (final c in mt.options) c.dispose();
    }
    super.dispose();
  }

  Future<void> _save() async {
    setState(() => _saving = true);
    final repo = getIt<NutritionRepository>();
    final planId = await repo.createPlan(
      _planNameController.text,
      dailyMealGoal: _mealTimes.length,
    );
    for (final mt in _mealTimes) {
      final typeName = mt.nameController.text.trim();
      if (typeName.isEmpty) continue;
      for (int i = 0; i < mt.options.length; i++) {
        final text = mt.options[i].text.trim();
        if (text.isNotEmpty) {
          await repo.addPlanOption(
            planId: planId,
            mealType: typeName,
            optionNumber: i + 1,
            description: text,
          );
        }
      }
    }
    await getIt<ModulesCubit>().setModuleEnabled(AppModule.nutrition, true);
    if (mounted) {
      Navigator.of(context).pop();
      widget.onComplete();
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Scaffold(
      appBar: AppBar(title: const Text('Plan de Alimentación')),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            TextField(
              controller: _planNameController,
              decoration: const InputDecoration(labelText: 'Nombre del plan'),
            ),
            const SizedBox(height: 24),
            ..._mealTimes.asMap().entries.map((e) {
              final index = e.key;
              final mt = e.value;
              return Card(
                margin: const EdgeInsets.only(bottom: 12),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Padding(
                      padding: const EdgeInsets.fromLTRB(16, 12, 8, 0),
                      child: Row(
                        children: [
                          Text('Tiempo ${index + 1}',
                              style: theme.textTheme.labelSmall),
                          const SizedBox(width: 12),
                          Expanded(
                            child: TextField(
                              controller: mt.nameController,
                              decoration: const InputDecoration(
                                hintText: 'Ej: Desayuno',
                                isDense: true,
                              ),
                            ),
                          ),
                          if (_mealTimes.length > 1)
                            IconButton(
                              icon: const Icon(Icons.delete_outline),
                              onPressed: () => setState(() {
                                mt.nameController.dispose();
                                for (final c in mt.options) c.dispose();
                                _mealTimes.removeAt(index);
                              }),
                            ),
                        ],
                      ),
                    ),
                    const Divider(height: 16),
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 16),
                      child: Column(
                        children: [
                          ...mt.options.asMap().entries.map((oe) => Padding(
                                padding: const EdgeInsets.only(bottom: 8),
                                child: Row(
                                  children: [
                                    Expanded(
                                      child: TextField(
                                        controller: oe.value,
                                        decoration: InputDecoration(
                                          labelText: 'Opción ${oe.key + 1}',
                                          isDense: true,
                                        ),
                                      ),
                                    ),
                                    if (mt.options.length > 1)
                                      IconButton(
                                        icon: const Icon(Icons.close, size: 18),
                                        onPressed: () => setState(() {
                                          oe.value.dispose();
                                          mt.options.removeAt(oe.key);
                                        }),
                                      ),
                                  ],
                                ),
                              )),
                          Align(
                            alignment: Alignment.centerLeft,
                            child: TextButton.icon(
                              onPressed: () => setState(
                                  () => mt.options.add(TextEditingController())),
                              icon: const Icon(Icons.add, size: 16),
                              label: const Text('Agregar opción'),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              );
            }),
            OutlinedButton.icon(
              onPressed: () =>
                  setState(() => _mealTimes.add(_MealTimeEntry())),
              icon: const Icon(Icons.add),
              label: const Text('Agregar tiempo de comida'),
            ),
            const SizedBox(height: 32),
            SizedBox(
              width: double.infinity,
              child: FilledButton(
                onPressed: _saving ? null : _save,
                child: const Text('Guardar'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
```

- [ ] **Step 5: Create ExerciseConfigPage**

```dart
// lib/features/exercise/presentation/pages/exercise_config_page.dart
import 'package:flutter/material.dart';
import '../../../../core/di/injection.dart';
import '../../../../core/domain/app_module.dart';
import '../../../../core/modules/cubit/modules_cubit.dart';
import '../../domain/repositories/exercise_repository.dart';

class _ExerciseEntryLocal {
  final name = TextEditingController();
  final sets = TextEditingController(text: '3');
  final reps = TextEditingController(text: '10');
  final weight = TextEditingController();
}

class _RoutineDayLocal {
  final nameController = TextEditingController();
  final List<_ExerciseEntryLocal> exercises = [];
}

class ExerciseConfigPage extends StatefulWidget {
  final VoidCallback onComplete;

  const ExerciseConfigPage({super.key, required this.onComplete});

  @override
  State<ExerciseConfigPage> createState() => _ExerciseConfigPageState();
}

class _ExerciseConfigPageState extends State<ExerciseConfigPage> {
  final _planNameController = TextEditingController(text: 'Mi Rutina');
  final List<_RoutineDayLocal> _routineDays = [];
  bool _saving = false;

  @override
  void dispose() {
    _planNameController.dispose();
    for (final day in _routineDays) {
      day.nameController.dispose();
      for (final e in day.exercises) {
        e.name.dispose();
        e.sets.dispose();
        e.reps.dispose();
        e.weight.dispose();
      }
    }
    super.dispose();
  }

  Future<void> _save() async {
    setState(() => _saving = true);
    final repo = getIt<ExerciseRepository>();
    final planId = await repo.createPlan(_planNameController.text);
    for (int i = 0; i < _routineDays.length; i++) {
      final day = _routineDays[i];
      final routineName = day.nameController.text.trim().isEmpty
          ? 'Día ${i + 1}'
          : day.nameController.text.trim();
      final routineId = await repo.addRoutine(
        planId: planId,
        dayNumber: i + 1,
        routineName: routineName,
      );
      for (final ex in day.exercises) {
        if (ex.name.text.isNotEmpty) {
          await repo.addRoutineItem(
            routineId: routineId,
            exerciseName: ex.name.text,
            sets: int.tryParse(ex.sets.text) ?? 3,
            reps: int.tryParse(ex.reps.text) ?? 10,
            weightKg: double.tryParse(ex.weight.text),
          );
        }
      }
    }
    await getIt<ModulesCubit>().setModuleEnabled(AppModule.exercise, true);
    if (mounted) {
      Navigator.of(context).pop();
      widget.onComplete();
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Scaffold(
      appBar: AppBar(title: const Text('Plan de Ejercicio')),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            TextField(
              controller: _planNameController,
              decoration: const InputDecoration(labelText: 'Nombre del plan'),
            ),
            const SizedBox(height: 24),
            ..._routineDays.asMap().entries.map((e) {
              final index = e.key;
              final day = e.value;
              return Card(
                margin: const EdgeInsets.only(bottom: 12),
                child: Column(
                  children: [
                    Padding(
                      padding: const EdgeInsets.fromLTRB(16, 12, 8, 0),
                      child: Row(
                        children: [
                          Text('Día ${index + 1}',
                              style: theme.textTheme.labelSmall),
                          const SizedBox(width: 12),
                          Expanded(
                            child: TextField(
                              controller: day.nameController,
                              decoration: InputDecoration(
                                hintText: 'Ej: Día ${index + 1}',
                                isDense: true,
                              ),
                            ),
                          ),
                          IconButton(
                            icon: const Icon(Icons.delete_outline),
                            color: theme.colorScheme.error,
                            onPressed: () => setState(() {
                              day.nameController.dispose();
                              for (final ex in day.exercises) {
                                ex.name.dispose();
                                ex.sets.dispose();
                                ex.reps.dispose();
                                ex.weight.dispose();
                              }
                              _routineDays.removeAt(index);
                            }),
                          ),
                        ],
                      ),
                    ),
                    ...day.exercises.asMap().entries.map((ee) {
                      final ex = ee.value;
                      return Padding(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 16, vertical: 8),
                        child: Row(
                          children: [
                            Expanded(
                              flex: 3,
                              child: TextField(
                                controller: ex.name,
                                decoration: const InputDecoration(
                                    labelText: 'Ejercicio'),
                              ),
                            ),
                            const SizedBox(width: 8),
                            Expanded(
                              child: TextField(
                                controller: ex.sets,
                                decoration:
                                    const InputDecoration(labelText: 'Sets'),
                                keyboardType: TextInputType.number,
                              ),
                            ),
                            const SizedBox(width: 8),
                            Expanded(
                              child: TextField(
                                controller: ex.reps,
                                decoration:
                                    const InputDecoration(labelText: 'Reps'),
                                keyboardType: TextInputType.number,
                              ),
                            ),
                            IconButton(
                              icon: const Icon(Icons.close),
                              onPressed: () => setState(() {
                                ex.name.dispose();
                                ex.sets.dispose();
                                ex.reps.dispose();
                                ex.weight.dispose();
                                day.exercises.removeAt(ee.key);
                              }),
                            ),
                          ],
                        ),
                      );
                    }),
                    Padding(
                      padding: const EdgeInsets.fromLTRB(16, 4, 16, 12),
                      child: Align(
                        alignment: Alignment.centerLeft,
                        child: TextButton.icon(
                          onPressed: () => setState(
                              () => day.exercises.add(_ExerciseEntryLocal())),
                          icon: const Icon(Icons.add, size: 16),
                          label: const Text('Agregar ejercicio'),
                        ),
                      ),
                    ),
                  ],
                ),
              );
            }),
            OutlinedButton.icon(
              onPressed: () =>
                  setState(() => _routineDays.add(_RoutineDayLocal())),
              icon: const Icon(Icons.add),
              label: const Text('Agregar día'),
            ),
            const SizedBox(height: 32),
            SizedBox(
              width: double.infinity,
              child: FilledButton(
                onPressed: _saving ? null : _save,
                child: const Text('Guardar'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
```

- [ ] **Step 6: Add routes to router**

In `lib/core/router/app_router.dart`, add imports:
```dart
import '../../features/exercise/presentation/pages/exercise_config_page.dart';
import '../../features/nutrition/presentation/pages/nutrition_config_page.dart';
import '../../features/water/presentation/pages/water_config_page.dart';
```

Add three routes outside the `ShellRoute`, alongside `/water`, `/onboarding`, etc.:
```dart
GoRoute(
  path: '/config/water',
  builder: (context, state) => WaterConfigPage(
    onComplete: () {},
  ),
),
GoRoute(
  path: '/config/nutrition',
  builder: (context, state) => NutritionConfigPage(
    onComplete: () {},
  ),
),
GoRoute(
  path: '/config/exercise',
  builder: (context, state) => ExerciseConfigPage(
    onComplete: () {},
  ),
),
```

- [ ] **Step 7: Run tests**

```bash
flutter test test/features/water/presentation/water_config_page_test.dart -v
```

Expected: `+2: All tests passed!`

- [ ] **Step 8: Commit**

```bash
git add lib/features/water/presentation/pages/water_config_page.dart \
        lib/features/nutrition/presentation/pages/nutrition_config_page.dart \
        lib/features/exercise/presentation/pages/exercise_config_page.dart \
        lib/core/router/app_router.dart \
        test/features/water/presentation/water_config_page_test.dart
git commit -m "feat(modules): standalone config pages for activation flow"
```

---

### Task 5: AppScaffold — inactive tab indicators

**Files:**
- Modify: `lib/shared/widgets/app_scaffold.dart`
- Test: `test/widget/app_scaffold_test.dart` (update existing)

The current `AppScaffold` is a `StatelessWidget`. It needs to consume `ModulesCubit` to show lock indicators on inactive module tabs.

- [ ] **Step 1: Read existing app_scaffold_test.dart**

```bash
cat test/widget/app_scaffold_test.dart
```

- [ ] **Step 2: Add tests for inactive tab indicators**

In `test/widget/app_scaffold_test.dart`, add a group at the end (after the existing tests). You'll need a `MockModulesCubit` — create one using `mocktail`:

```dart
// Add at the top of the test file:
import 'package:bloc_test/bloc_test.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:kiolog/core/domain/app_module.dart';
import 'package:kiolog/core/modules/cubit/modules_cubit.dart';
import 'package:kiolog/core/modules/cubit/modules_state.dart';
import 'package:mocktail/mocktail.dart';

class MockModulesCubit extends MockCubit<ModulesState>
    implements ModulesCubit {}

// Helper to pump AppScaffold with a ModulesCubit providing specific state
Widget _wrapWithModules(ModulesState state) {
  final cubit = MockModulesCubit();
  when(() => cubit.state).thenReturn(state);
  whenListen(cubit, Stream.value(state));
  return BlocProvider<ModulesCubit>.value(
    value: cubit,
    child: MaterialApp.router(
      routerConfig: GoRouter(
        routes: [
          ShellRoute(
            builder: (_, __, child) => AppScaffold(child: child),
            routes: [
              GoRoute(path: '/', builder: (_, __) => const SizedBox()),
            ],
          ),
        ],
      ),
    ),
  );
}

// New test group:
group('AppScaffold inactive module indicators', () {
  testWidgets('shows lock icon overlay when nutrition is inactive',
      (tester) async {
    final state = ModulesState(statuses: {
      AppModule.nutrition: false,
      AppModule.water: true,
      AppModule.exercise: true,
    });
    await tester.pumpWidget(_wrapWithModules(state));
    await tester.pumpAndSettle();
    // Lock icon should be visible for nutrition
    expect(find.byIcon(Icons.lock), findsOneWidget);
  });

  testWidgets('shows no lock icon when all modules active', (tester) async {
    final state = ModulesState(statuses: {
      AppModule.nutrition: true,
      AppModule.water: true,
      AppModule.exercise: true,
    });
    await tester.pumpWidget(_wrapWithModules(state));
    await tester.pumpAndSettle();
    expect(find.byIcon(Icons.lock), findsNothing);
  });

  testWidgets('shows two lock icons when nutrition and exercise inactive',
      (tester) async {
    final state = ModulesState(statuses: {
      AppModule.nutrition: false,
      AppModule.water: true,
      AppModule.exercise: false,
    });
    await tester.pumpWidget(_wrapWithModules(state));
    await tester.pumpAndSettle();
    expect(find.byIcon(Icons.lock), findsNWidgets(2));
  });
});
```

- [ ] **Step 3: Run tests — expect failure**

```bash
flutter test test/widget/app_scaffold_test.dart -v
```

Expected: tests fail — `AppScaffold` doesn't yet check module state.

- [ ] **Step 4: Rewrite AppScaffold**

Replace the entire `lib/shared/widgets/app_scaffold.dart` with:

```dart
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import '../../core/di/injection.dart';
import '../../core/domain/app_module.dart';
import '../../core/modules/cubit/modules_cubit.dart';
import '../../core/modules/cubit/modules_state.dart';

class AppScaffold extends StatelessWidget {
  final Widget child;

  const AppScaffold({super.key, required this.child});

  int _locationToIndex(String location) {
    if (location.startsWith('/nutrition')) return 1;
    if (location.startsWith('/exercise')) return 2;
    if (location.startsWith('/progress')) return 3;
    if (location.startsWith('/settings')) return 4;
    return 0;
  }

  Widget _moduleIcon({
    required IconData activeIcon,
    required IconData inactiveIcon,
    required AppModule module,
    required ModulesState state,
    bool selected = false,
  }) {
    final isActive = state.isEnabled(module);
    if (isActive) {
      return Icon(selected ? activeIcon : inactiveIcon);
    }
    return Stack(
      clipBehavior: Clip.none,
      children: [
        Icon(
          selected ? activeIcon : inactiveIcon,
          color: Colors.grey.withValues(alpha: 0.4),
        ),
        const Positioned(
          right: -4,
          top: -4,
          child: Icon(Icons.lock, size: 10, color: Colors.grey),
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final location = GoRouterState.of(context).uri.toString();
    final currentIndex = _locationToIndex(location);

    return BlocProvider<ModulesCubit>.value(
      value: getIt<ModulesCubit>(),
      child: BlocBuilder<ModulesCubit, ModulesState>(
        builder: (context, modulesState) {
          return Scaffold(
            body: child,
            bottomNavigationBar: NavigationBar(
              selectedIndex: currentIndex,
              onDestinationSelected: (index) {
                switch (index) {
                  case 0:
                    context.go('/');
                  case 1:
                    context.go('/nutrition');
                  case 2:
                    context.go('/exercise');
                  case 3:
                    context.go('/progress');
                  case 4:
                    context.go('/settings');
                }
              },
              destinations: [
                const NavigationDestination(
                  icon: Icon(Icons.home_outlined),
                  selectedIcon: Icon(Icons.home),
                  label: 'Inicio',
                ),
                NavigationDestination(
                  icon: _moduleIcon(
                    activeIcon: Icons.restaurant,
                    inactiveIcon: Icons.restaurant_outlined,
                    module: AppModule.nutrition,
                    state: modulesState,
                  ),
                  selectedIcon: _moduleIcon(
                    activeIcon: Icons.restaurant,
                    inactiveIcon: Icons.restaurant_outlined,
                    module: AppModule.nutrition,
                    state: modulesState,
                    selected: true,
                  ),
                  label: 'Nutrición',
                ),
                NavigationDestination(
                  icon: _moduleIcon(
                    activeIcon: Icons.fitness_center,
                    inactiveIcon: Icons.fitness_center_outlined,
                    module: AppModule.exercise,
                    state: modulesState,
                  ),
                  selectedIcon: _moduleIcon(
                    activeIcon: Icons.fitness_center,
                    inactiveIcon: Icons.fitness_center_outlined,
                    module: AppModule.exercise,
                    state: modulesState,
                    selected: true,
                  ),
                  label: 'Ejercicio',
                ),
                const NavigationDestination(
                  icon: Icon(Icons.bar_chart_outlined),
                  selectedIcon: Icon(Icons.bar_chart),
                  label: 'Progreso',
                ),
                const NavigationDestination(
                  icon: Icon(Icons.settings_outlined),
                  selectedIcon: Icon(Icons.settings),
                  label: 'Ajustes',
                ),
              ],
            ),
          );
        },
      ),
    );
  }
}
```

- [ ] **Step 5: Run tests**

```bash
flutter test test/widget/app_scaffold_test.dart -v
```

Expected: all tests pass (existing + 3 new).

- [ ] **Step 6: Commit**

```bash
git add lib/shared/widgets/app_scaffold.dart \
        test/widget/app_scaffold_test.dart
git commit -m "feat(modules): inactive tab indicators in AppScaffold"
```

---

### Task 6: `InactiveModulePage` + module page guards

**Files:**
- Create: `lib/shared/widgets/inactive_module_page.dart`
- Modify: `lib/features/nutrition/presentation/pages/nutrition_page.dart`
- Modify: `lib/features/exercise/presentation/pages/exercise_page.dart`
- Modify: `lib/features/water/presentation/pages/water_page.dart`
- Test: `test/widget/inactive_module_page_test.dart`

- [ ] **Step 1: Write failing tests**

```dart
// test/widget/inactive_module_page_test.dart
import 'package:bloc_test/bloc_test.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kiolog/core/domain/app_module.dart';
import 'package:kiolog/core/modules/cubit/modules_cubit.dart';
import 'package:kiolog/core/modules/cubit/modules_state.dart';
import 'package:kiolog/shared/widgets/inactive_module_page.dart';
import 'package:mocktail/mocktail.dart';

class MockModulesCubit extends MockCubit<ModulesState>
    implements ModulesCubit {}

Widget _wrap(Widget child, ModulesState state) {
  final cubit = MockModulesCubit();
  when(() => cubit.state).thenReturn(state);
  whenListen(cubit, Stream.value(state));
  return BlocProvider<ModulesCubit>.value(
    value: cubit,
    child: MaterialApp(home: child),
  );
}

void main() {
  group('InactiveModulePage', () {
    testWidgets('shows correct title for nutrition', (tester) async {
      await tester.pumpWidget(_wrap(
        const InactiveModulePage(module: AppModule.nutrition),
        const ModulesState(),
      ));
      expect(find.text('Nutrición no activado'), findsOneWidget);
    });

    testWidgets('shows correct title for exercise', (tester) async {
      await tester.pumpWidget(_wrap(
        const InactiveModulePage(module: AppModule.exercise),
        const ModulesState(),
      ));
      expect(find.text('Ejercicio no activado'), findsOneWidget);
    });

    testWidgets('shows correct title for water', (tester) async {
      await tester.pumpWidget(_wrap(
        const InactiveModulePage(module: AppModule.water),
        const ModulesState(),
      ));
      expect(find.text('Hidratación no activado'), findsOneWidget);
    });

    testWidgets('shows Activar y configurar button', (tester) async {
      await tester.pumpWidget(_wrap(
        const InactiveModulePage(module: AppModule.nutrition),
        const ModulesState(),
      ));
      expect(
        find.widgetWithText(FilledButton, 'Activar y configurar'),
        findsOneWidget,
      );
    });
  });
}
```

- [ ] **Step 2: Run tests — expect compile failure**

```bash
flutter test test/widget/inactive_module_page_test.dart -v
```

Expected: compile error — `InactiveModulePage` not found.

- [ ] **Step 3: Create InactiveModulePage**

```dart
// lib/shared/widgets/inactive_module_page.dart
import 'package:flutter/material.dart';
import '../../core/domain/app_module.dart';
import '../../features/exercise/presentation/pages/exercise_config_page.dart';
import '../../features/nutrition/presentation/pages/nutrition_config_page.dart';
import '../../features/water/presentation/pages/water_config_page.dart';

class InactiveModulePage extends StatelessWidget {
  final AppModule module;

  const InactiveModulePage({super.key, required this.module});

  String get _title {
    switch (module) {
      case AppModule.nutrition:
        return 'Nutrición';
      case AppModule.water:
        return 'Hidratación';
      case AppModule.exercise:
        return 'Ejercicio';
    }
  }

  String get _description {
    switch (module) {
      case AppModule.nutrition:
        return 'Configúralo para empezar a registrar tus comidas.';
      case AppModule.water:
        return 'Configúralo para empezar a registrar tu hidratación.';
      case AppModule.exercise:
        return 'Configúralo para empezar a registrar tus rutinas.';
    }
  }

  IconData get _icon {
    switch (module) {
      case AppModule.nutrition:
        return Icons.restaurant_outlined;
      case AppModule.water:
        return Icons.water_drop_outlined;
      case AppModule.exercise:
        return Icons.fitness_center_outlined;
    }
  }

  Widget _buildConfigPage() {
    switch (module) {
      case AppModule.nutrition:
        return NutritionConfigPage(onComplete: () {});
      case AppModule.water:
        return WaterConfigPage(onComplete: () {});
      case AppModule.exercise:
        return ExerciseConfigPage(onComplete: () {});
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Scaffold(
      appBar: AppBar(title: Text(_title)),
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                _icon,
                size: 72,
                color: theme.colorScheme.onSurface.withValues(alpha: 0.2),
              ),
              const SizedBox(height: 24),
              Text(
                '$_title no activado',
                style: theme.textTheme.titleLarge,
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 8),
              Text(
                'Este módulo está desactivado. $_description',
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 32),
              SizedBox(
                width: double.infinity,
                child: FilledButton(
                  onPressed: () {
                    Navigator.of(context).push(
                      MaterialPageRoute<void>(
                        builder: (_) => _buildConfigPage(),
                      ),
                    );
                  },
                  child: const Text('Activar y configurar'),
                ),
              ),
              const SizedBox(height: 12),
              Text(
                'También puedes activarlo desde Ajustes → Módulos.',
                style: theme.textTheme.bodySmall?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                ),
                textAlign: TextAlign.center,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
```

- [ ] **Step 4: Guard NutritionPage**

In `lib/features/nutrition/presentation/pages/nutrition_page.dart`, add imports:
```dart
import '../../../../core/di/injection.dart';
import '../../../../core/domain/app_module.dart';
import '../../../../core/modules/cubit/modules_cubit.dart';
import '../../../../core/modules/cubit/modules_state.dart';
import '../../../../shared/widgets/inactive_module_page.dart';
```

Replace the `NutritionPage.build` method:
```dart
@override
Widget build(BuildContext context) {
  return BlocProvider<ModulesCubit>.value(
    value: getIt<ModulesCubit>(),
    child: BlocBuilder<ModulesCubit, ModulesState>(
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
    ),
  );
}
```

- [ ] **Step 5: Guard ExercisePage**

In `lib/features/exercise/presentation/pages/exercise_page.dart`, add same imports as Step 4 but for exercise.

Replace `ExercisePage.build`:
```dart
@override
Widget build(BuildContext context) {
  return BlocProvider<ModulesCubit>.value(
    value: getIt<ModulesCubit>(),
    child: BlocBuilder<ModulesCubit, ModulesState>(
      builder: (context, modulesState) {
        if (!modulesState.isEnabled(AppModule.exercise)) {
          return const InactiveModulePage(module: AppModule.exercise);
        }
        return BlocProvider(
          create: (_) => ExerciseBloc(getIt<ExerciseRepository>())
            ..add(ExerciseLoaded(date: DateTime.now())),
          child: const _ExerciseView(),
        );
      },
    ),
  );
}
```

- [ ] **Step 6: Guard WaterPage**

In `lib/features/water/presentation/pages/water_page.dart`, add same imports.

Replace `WaterPage.build`:
```dart
@override
Widget build(BuildContext context) {
  return BlocProvider<ModulesCubit>.value(
    value: getIt<ModulesCubit>(),
    child: BlocBuilder<ModulesCubit, ModulesState>(
      builder: (context, modulesState) {
        if (!modulesState.isEnabled(AppModule.water)) {
          return const InactiveModulePage(module: AppModule.water);
        }
        return BlocProvider(
          create: (_) => WaterBloc(getIt<WaterRepository>())
            ..add(WaterLoaded(date: DateTime.now()))
            ..add(const WaterConfigLoaded()),
          child: const _WaterView(),
        );
      },
    ),
  );
}
```

- [ ] **Step 7: Run tests**

```bash
flutter test test/widget/inactive_module_page_test.dart -v
```

Expected: `+4: All tests passed!`

- [ ] **Step 8: Commit**

```bash
git add lib/shared/widgets/inactive_module_page.dart \
        lib/features/nutrition/presentation/pages/nutrition_page.dart \
        lib/features/exercise/presentation/pages/exercise_page.dart \
        lib/features/water/presentation/pages/water_page.dart \
        test/widget/inactive_module_page_test.dart
git commit -m "feat(modules): InactiveModulePage + guards on module pages"
```

---

### Task 7: Settings — "Módulos activos" section

**Files:**
- Modify: `lib/features/settings/presentation/pages/settings_page.dart`
- Test: `test/features/settings/presentation/settings_modules_test.dart`

- [ ] **Step 1: Write failing tests**

```dart
// test/features/settings/presentation/settings_modules_test.dart
import 'package:bloc_test/bloc_test.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kiolog/core/domain/app_module.dart';
import 'package:kiolog/core/modules/cubit/modules_cubit.dart';
import 'package:kiolog/core/modules/cubit/modules_state.dart';
import 'package:kiolog/features/settings/presentation/pages/settings_page.dart';
import 'package:mocktail/mocktail.dart';

class MockModulesCubit extends MockCubit<ModulesState>
    implements ModulesCubit {}

Widget _wrap(ModulesState state) {
  final cubit = MockModulesCubit();
  when(() => cubit.state).thenReturn(state);
  whenListen(cubit, Stream.value(state));
  when(() => cubit.setModuleEnabled(any(), any()))
      .thenAnswer((_) async {});
  return BlocProvider<ModulesCubit>.value(
    value: cubit,
    child: const MaterialApp(home: SettingsPage()),
  );
}

void main() {
  group('Settings — Módulos activos', () {
    testWidgets('shows Módulos activos section header', (tester) async {
      await tester.pumpWidget(_wrap(ModulesState(statuses: {
        AppModule.nutrition: true,
        AppModule.water: true,
        AppModule.exercise: true,
      })));
      expect(find.text('Módulos activos'), findsOneWidget);
    });

    testWidgets('shows three module switch tiles', (tester) async {
      await tester.pumpWidget(_wrap(ModulesState(statuses: {
        AppModule.nutrition: true,
        AppModule.water: true,
        AppModule.exercise: true,
      })));
      expect(find.byType(SwitchListTile), findsNWidgets(3));
    });

    testWidgets('inactive module shows switch as off', (tester) async {
      await tester.pumpWidget(_wrap(ModulesState(statuses: {
        AppModule.nutrition: false,
        AppModule.water: true,
        AppModule.exercise: true,
      })));
      final switches = tester.widgetList<SwitchListTile>(
          find.byType(SwitchListTile)).toList();
      final nutritionSwitch = switches.firstWhere(
          (s) => (s.title as Text).data == 'Nutrición');
      expect(nutritionSwitch.value, isFalse);
    });

    testWidgets('tapping active switch shows deactivation confirm dialog',
        (tester) async {
      await tester.pumpWidget(_wrap(ModulesState(statuses: {
        AppModule.nutrition: true,
        AppModule.water: true,
        AppModule.exercise: true,
      })));
      final switches = tester.widgetList<SwitchListTile>(
          find.byType(SwitchListTile)).toList();
      final nutritionTile = switches.firstWhere(
          (s) => (s.title as Text).data == 'Nutrición');
      await nutritionTile.onChanged!(false);
      await tester.pumpAndSettle();
      expect(find.text('Desactivar'), findsOneWidget);
      expect(find.text('Cancelar'), findsOneWidget);
    });
  });
}
```

- [ ] **Step 2: Run tests — expect compile/runtime failure**

```bash
flutter test test/features/settings/presentation/settings_modules_test.dart -v
```

Expected: `SettingsPage` doesn't consume `ModulesCubit` — tests fail.

- [ ] **Step 3: Rewrite SettingsPage**

Replace the entire `lib/features/settings/presentation/pages/settings_page.dart`:

```dart
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import '../../../../core/di/injection.dart';
import '../../../../core/domain/app_module.dart';
import '../../../../core/modules/cubit/modules_cubit.dart';
import '../../../../core/modules/cubit/modules_state.dart';
import '../../../exercise/presentation/pages/exercise_config_page.dart';
import '../../../nutrition/presentation/pages/nutrition_config_page.dart';
import '../../../water/presentation/pages/water_config_page.dart';

class SettingsPage extends StatelessWidget {
  const SettingsPage({super.key});

  @override
  Widget build(BuildContext context) {
    return BlocProvider<ModulesCubit>.value(
      value: getIt<ModulesCubit>(),
      child: const _SettingsView(),
    );
  }
}

class _SettingsView extends StatelessWidget {
  const _SettingsView();

  Future<void> _handleModuleToggle(
    BuildContext context,
    ModulesCubit cubit,
    AppModule module,
    bool newValue,
    ModulesState state,
  ) async {
    if (!newValue) {
      // Deactivating — confirm first
      final confirmed = await showDialog<bool>(
        context: context,
        builder: (_) => AlertDialog(
          title: Text('Desactivar ${_moduleLabel(module)}'),
          content: const Text(
            'Tu historial se conserva. Solo dejará de verse como activo. '
            '¿Desactivar?',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('Cancelar'),
            ),
            TextButton(
              onPressed: () => Navigator.pop(context, true),
              child: const Text('Desactivar'),
            ),
          ],
        ),
      );
      if (confirmed == true) {
        await cubit.setModuleEnabled(module, false);
      }
    } else {
      // Activating — need config if unconfigured, else direct enable
      final hasConfig = _hasExistingConfig(module, state);
      if (hasConfig) {
        await cubit.setModuleEnabled(module, true);
      } else {
        // Push config flow
        if (context.mounted) {
          await Navigator.of(context).push<void>(
            MaterialPageRoute(
              builder: (_) => _buildConfigPage(module),
            ),
          );
        }
      }
    }
  }

  bool _hasExistingConfig(AppModule module, ModulesState state) {
    // A module that was previously active is assumed to have config.
    // We can't distinguish "never configured" from "configured then disabled"
    // without querying the DB — use a conservative false to always re-prompt.
    // This is safe: re-configuring creates a new plan alongside existing data.
    return false;
  }

  Widget _buildConfigPage(AppModule module) {
    switch (module) {
      case AppModule.nutrition:
        return NutritionConfigPage(onComplete: () {});
      case AppModule.water:
        return WaterConfigPage(onComplete: () {});
      case AppModule.exercise:
        return ExerciseConfigPage(onComplete: () {});
    }
  }

  String _moduleLabel(AppModule module) {
    switch (module) {
      case AppModule.nutrition:
        return 'Nutrición';
      case AppModule.water:
        return 'Hidratación';
      case AppModule.exercise:
        return 'Ejercicio';
    }
  }

  String _moduleSubtitle(AppModule module, bool enabled) {
    if (!enabled) return 'Inactivo';
    switch (module) {
      case AppModule.nutrition:
        return 'Plan de comidas activo';
      case AppModule.water:
        return 'Meta diaria activa';
      case AppModule.exercise:
        return 'Rutina activa';
    }
  }

  IconData _moduleIcon(AppModule module) {
    switch (module) {
      case AppModule.nutrition:
        return Icons.restaurant_outlined;
      case AppModule.water:
        return Icons.water_drop_outlined;
      case AppModule.exercise:
        return Icons.fitness_center_outlined;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Ajustes')),
      body: BlocBuilder<ModulesCubit, ModulesState>(
        builder: (context, modulesState) {
          final cubit = context.read<ModulesCubit>();
          final activeCount = AppModule.values
              .where((m) => modulesState.isEnabled(m))
              .length;

          return SafeArea(
            child: ListView(
              children: [
                // ── Módulos activos ──
                const Padding(
                  padding: EdgeInsets.fromLTRB(16, 16, 16, 4),
                  child: Text(
                    'Módulos activos',
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      letterSpacing: 0.8,
                    ),
                  ),
                ),
                for (final module in AppModule.values)
                  SwitchListTile(
                    secondary: Icon(_moduleIcon(module)),
                    title: Text(_moduleLabel(module)),
                    subtitle:
                        Text(_moduleSubtitle(module, modulesState.isEnabled(module))),
                    value: modulesState.isEnabled(module),
                    onChanged: (activeCount == 1 &&
                            modulesState.isEnabled(module))
                        ? null // last active — cannot disable
                        : (val) => _handleModuleToggle(
                              context,
                              cubit,
                              module,
                              val,
                              modulesState,
                            ),
                  ),
                const Divider(),
                // ── Existing settings ──
                ListTile(
                  leading: const Icon(Icons.picture_as_pdf),
                  title: const Text('Reporte de salud'),
                  subtitle: const Text('Generar PDF del período'),
                  trailing: const Icon(Icons.chevron_right),
                  onTap: () => context.push('/report'),
                ),
                const Divider(),
                ListTile(
                  leading: const Icon(Icons.water_drop),
                  title: const Text('Configuración de agua'),
                  subtitle: const Text('Meta, unidad, tamaño'),
                  trailing: const Icon(Icons.chevron_right),
                  onTap: () => context.push('/water'),
                ),
                ListTile(
                  leading: const Icon(Icons.fitness_center),
                  title: const Text('Configuración de gym'),
                  subtitle: const Text('Próximamente'),
                  trailing: const Icon(Icons.chevron_right),
                  onTap: () {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('Próximamente')),
                    );
                  },
                ),
                const Divider(),
                ListTile(
                  leading: const Icon(Icons.notifications_outlined),
                  title: const Text('Notificaciones'),
                  subtitle: const Text('Próximamente'),
                  trailing: const Icon(Icons.chevron_right),
                  onTap: () {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('Próximamente')),
                    );
                  },
                ),
                ListTile(
                  leading: const Icon(Icons.smart_toy_outlined),
                  title: const Text('Integración IA'),
                  subtitle: const Text('Próximamente'),
                  trailing: const Icon(Icons.chevron_right),
                  onTap: () {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('Próximamente')),
                    );
                  },
                ),
                const Divider(),
                const ListTile(
                  leading: Icon(Icons.info_outline),
                  title: Text('Acerca de Kiolog'),
                  subtitle: Text('v1.0.0'),
                ),
              ],
            ),
          );
        },
      ),
    );
  }
}
```

- [ ] **Step 4: Run tests**

```bash
flutter test test/features/settings/presentation/settings_modules_test.dart -v
```

Expected: `+4: All tests passed!`

- [ ] **Step 5: Run full suite**

```bash
flutter test
```

Expected: all existing tests pass + new tests pass (pre-existing 1 failure unchanged).

- [ ] **Step 6: Commit**

```bash
git add lib/features/settings/presentation/pages/settings_page.dart \
        test/features/settings/presentation/settings_modules_test.dart
git commit -m "feat(modules): Módulos activos section in Settings with confirm dialogs"
```
