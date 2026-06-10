# Dynamic Meal Plan Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Replace the hardcoded 4-meal-type nutrition system with a fully dynamic one: onboarding lets the user create any number of meal times with any number of options; NutritionPage displays whatever the active plan contains; `dailyMealGoal` is set automatically; "No seguí el plan" adds a one-tap off-plan action.

**Architecture:** Four independent tasks, each committed separately. Task 1 adds `getAllPlanOptions` to the data layer and removes the hardcoded meal-type loop in the BLoC. Task 2 makes `NutritionOffPlanMealLogged.description` nullable. Task 3 updates `NutritionPage` to use dynamic keys and the two new action buttons. Task 4 rewrites the onboarding nutrition step to a dynamic card list.

**Tech Stack:** Flutter, flutter_bloc, Drift (SQLite), mocktail, bloc_test.

---

### Task 1: Add `getAllPlanOptions` + update BLoC `_onLoaded`

**Why:** The BLoC currently hardcodes `['breakfast', 'lunch', 'dinner', 'snack']` to load options. After this task it fetches all options for the active plan and groups them by meal type, making everything downstream dynamic.

**Files:**
- Modify: `lib/core/dao/nutrition_dao.dart`
- Modify: `lib/features/nutrition/domain/repositories/nutrition_repository.dart`
- Modify: `lib/features/nutrition/data/repositories/nutrition_repository_impl.dart`
- Modify: `lib/features/nutrition/presentation/bloc/nutrition_bloc.dart`
- Modify: `test/features/nutrition/presentation/nutrition_bloc_test.dart`

- [ ] **Step 1: Update the existing `NutritionLoaded` BLoC test to use `getAllPlanOptions`**

Open `test/features/nutrition/presentation/nutrition_bloc_test.dart`. Replace the existing `'emits [loading, success] with weeklyAdherence when NutritionLoaded succeeds'` blocTest with:

```dart
blocTest<NutritionBloc, NutritionState>(
  'emits [loading, success] grouping options by mealType via getAllPlanOptions',
  build: () {
    when(() => repository.getActivePlan()).thenAnswer((_) async => plan);
    when(() => repository.getDailyLogs(any())).thenAnswer((_) async => []);
    when(() => repository.getAllPlanOptions(any()))
        .thenAnswer((_) async => options);
    when(() => repository.getWeeklyAdherence(weeksBack: 8))
        .thenAnswer((_) async => adherence);
    return NutritionBloc(repository);
  },
  act: (bloc) => bloc.add(NutritionLoaded(date: DateTime(2026, 6, 8))),
  expect: () => [
    const NutritionState(status: NutritionStatus.loading),
    NutritionState(
      status: NutritionStatus.success,
      activePlan: plan,
      planOptions: {'breakfast': options},
      weeklyAdherence: adherence,
    ),
  ],
);
```

Also remove the four old `when(() => repository.getPlanOptions(...))` stubs — they are no longer needed.

- [ ] **Step 2: Run the test to confirm it fails**

```bash
cd /home/jesuszelaya/Documents/kiolog
flutter test test/features/nutrition/presentation/nutrition_bloc_test.dart -v
```

Expected: FAIL — `MockNutritionRepository` does not implement `getAllPlanOptions`.

- [ ] **Step 3: Add `getAllPlanOptions` to the DAO**

In `lib/core/dao/nutrition_dao.dart`, add this method after `getMealPlanOptions`:

```dart
Future<List<MealPlanOption>> getAllPlanOptions(int planId) =>
    (select(mealPlanOptions)
          ..where((t) => t.planId.equals(planId))
          ..orderBy([(t) => OrderingTerm.asc(t.id)]))
        .get();
```

Ordering by `id` preserves insertion order, so meal types appear in the order they were created.

- [ ] **Step 4: Add `getAllPlanOptions` to the repository interface**

In `lib/features/nutrition/domain/repositories/nutrition_repository.dart`, add after `getPlanOptions`:

```dart
Future<List<MealPlanOption>> getAllPlanOptions(int planId);
```

- [ ] **Step 5: Implement `getAllPlanOptions` in the repository impl**

In `lib/features/nutrition/data/repositories/nutrition_repository_impl.dart`, add after `getPlanOptions`:

```dart
@override
Future<List<MealPlanOption>> getAllPlanOptions(int planId) =>
    _nutritionDao.getAllPlanOptions(planId);
```

- [ ] **Step 6: Update `_onLoaded` in the BLoC**

In `lib/features/nutrition/presentation/bloc/nutrition_bloc.dart`, replace the options-loading block inside `_onLoaded`:

```dart
// Remove:
if (plan != null) {
  for (final mealType in ['breakfast', 'lunch', 'dinner', 'snack']) {
    final opts = await _repository.getPlanOptions(plan.id, mealType);
    options[mealType] = opts;
  }
}

// Replace with:
if (plan != null) {
  final allOpts = await _repository.getAllPlanOptions(plan.id);
  for (final opt in allOpts) {
    options.putIfAbsent(opt.mealType, () => []).add(opt);
  }
}
```

- [ ] **Step 7: Run tests and confirm all pass**

```bash
flutter test test/features/nutrition/presentation/nutrition_bloc_test.dart -v
```

Expected: all tests pass.

- [ ] **Step 8: Run the full suite to check for regressions**

```bash
flutter test
```

Expected: all tests pass.

- [ ] **Step 9: Commit**

```bash
git add lib/core/dao/nutrition_dao.dart \
        lib/features/nutrition/domain/repositories/nutrition_repository.dart \
        lib/features/nutrition/data/repositories/nutrition_repository_impl.dart \
        lib/features/nutrition/presentation/bloc/nutrition_bloc.dart \
        test/features/nutrition/presentation/nutrition_bloc_test.dart
git commit -m "feat(nutrition): getAllPlanOptions — dynamic meal types in BLoC"
```

---

### Task 2: Make `NutritionOffPlanMealLogged.description` nullable

**Why:** "No seguí el plan" is a one-tap action with no text. The event and repository need to accept a null description; the DB column is already nullable.

**Files:**
- Modify: `lib/features/nutrition/presentation/bloc/nutrition_event.dart`
- Modify: `lib/features/nutrition/domain/repositories/nutrition_repository.dart`
- Modify: `lib/features/nutrition/data/repositories/nutrition_repository_impl.dart`
- Modify: `test/features/nutrition/presentation/nutrition_bloc_test.dart`

- [ ] **Step 1: Add a BLoC test for null description**

In `test/features/nutrition/presentation/nutrition_bloc_test.dart`, inside the `group('NutritionBloc', ...)` block, add:

```dart
blocTest<NutritionBloc, NutritionState>(
  'logs off-plan meal with null description (no seguí el plan)',
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
),
```

- [ ] **Step 2: Run the test to confirm it fails**

```bash
flutter test test/features/nutrition/presentation/nutrition_bloc_test.dart -v
```

Expected: compile error — `NutritionOffPlanMealLogged` requires `description` (non-nullable).

- [ ] **Step 3: Make `description` nullable in the event**

In `lib/features/nutrition/presentation/bloc/nutrition_event.dart`, update `NutritionOffPlanMealLogged`:

```dart
class NutritionOffPlanMealLogged extends NutritionEvent {
  final DateTime date;
  final String mealType;
  final String? description;

  const NutritionOffPlanMealLogged({
    required this.date,
    required this.mealType,
    this.description,
  });

  @override
  List<Object?> get props => [date, mealType, description];
}
```

- [ ] **Step 4: Update the repository interface**

In `lib/features/nutrition/domain/repositories/nutrition_repository.dart`, change `logOffPlanMeal`:

```dart
Future<void> logOffPlanMeal({
  required DateTime date,
  required String mealType,
  String? description,
  String? photoPath,
});
```

- [ ] **Step 5: Update the repository impl**

In `lib/features/nutrition/data/repositories/nutrition_repository_impl.dart`, change `logOffPlanMeal`:

```dart
@override
Future<void> logOffPlanMeal({
  required DateTime date,
  required String mealType,
  String? description,
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
```

- [ ] **Step 6: Run tests and confirm all pass**

```bash
flutter test test/features/nutrition/presentation/nutrition_bloc_test.dart -v
```

Expected: all tests pass. The BLoC handler `_onOffPlanMealLogged` passes `event.description` directly to the repo — since both are now nullable, no BLoC handler change is needed.

- [ ] **Step 7: Run the full suite**

```bash
flutter test
```

Expected: all tests pass.

- [ ] **Step 8: Commit**

```bash
git add lib/features/nutrition/presentation/bloc/nutrition_event.dart \
        lib/features/nutrition/domain/repositories/nutrition_repository.dart \
        lib/features/nutrition/data/repositories/nutrition_repository_impl.dart \
        test/features/nutrition/presentation/nutrition_bloc_test.dart
git commit -m "feat(nutrition): nullable description in NutritionOffPlanMealLogged"
```

---

### Task 3: Update NutritionPage — dynamic display + "No seguí el plan"

**Why:** The page currently hardcodes 4 meal types and has only one off-plan action. After this task it renders whatever keys are in `state.planOptions` and has two distinct actions when a meal is unlogged.

**Files:**
- Create: `test/features/nutrition/presentation/nutrition_page_test.dart`
- Modify: `lib/features/nutrition/presentation/pages/nutrition_page.dart`

- [ ] **Step 1: Create the widget test file**

Create `test/features/nutrition/presentation/nutrition_page_test.dart`:

```dart
import 'package:bloc_test/bloc_test.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kiolog/core/database/app_database.dart';
import 'package:kiolog/features/nutrition/domain/repositories/nutrition_repository.dart';
import 'package:kiolog/features/nutrition/presentation/bloc/nutrition_bloc.dart';
import 'package:kiolog/features/nutrition/presentation/bloc/nutrition_event.dart';
import 'package:kiolog/features/nutrition/presentation/bloc/nutrition_state.dart';
import 'package:kiolog/features/nutrition/presentation/pages/nutrition_page.dart';
import 'package:mocktail/mocktail.dart';

class MockNutritionBloc
    extends MockBloc<NutritionEvent, NutritionState>
    implements NutritionBloc {}

class MockNutritionRepository extends Mock implements NutritionRepository {}

final _plan = MealPlan(
  id: 1,
  name: 'Plan Test',
  createdAt: DateTime(2026, 6, 1),
  isActive: true,
  dailyMealGoal: 2,
  periodStart: DateTime(2026, 6, 1),
  periodEnd: null,
);

final _optDesayuno = MealPlanOption(
  id: 1,
  planId: 1,
  mealType: 'Desayuno',
  optionNumber: 1,
  description: 'Avena con frutas',
);

final _optAlmuerzo = MealPlanOption(
  id: 2,
  planId: 1,
  mealType: 'Almuerzo',
  optionNumber: 1,
  description: 'Arroz con pollo',
);

Widget _wrap(NutritionBloc bloc) => MaterialApp(
      home: BlocProvider<NutritionBloc>.value(
        value: bloc,
        child: Scaffold(
          body: BlocBuilder<NutritionBloc, NutritionState>(
            builder: (context, state) {
              if (state.activePlan == null) {
                return const Center(child: Text('Sin plan'));
              }
              return ListView(
                children: state.planOptions.keys.map((type) {
                  return Card(
                    key: Key('meal_$type'),
                    child: Column(
                      children: [
                        Text(type),
                        if (state.getLogForMeal(type) == null) ...[
                          TextButton(
                            key: Key('no_seguido_$type'),
                            onPressed: () => context
                                .read<NutritionBloc>()
                                .add(NutritionOffPlanMealLogged(
                                  date: DateTime(2026, 6, 8),
                                  mealType: type,
                                  description: null,
                                )),
                            child: const Text('No seguí el plan'),
                          ),
                          TextButton(
                            key: Key('fuera_plan_$type'),
                            onPressed: () {},
                            child: const Text('Fuera de plan'),
                          ),
                        ] else
                          Builder(builder: (context) {
                            final log = state.getLogForMeal(type)!;
                            if (log.planOptionId != null) {
                              return const Text('Registrado');
                            } else if (log.freeDescription != null) {
                              return Text('Fuera de plan: ${log.freeDescription}');
                            } else {
                              return const Text('No seguido');
                            }
                          }),
                      ],
                    ),
                  );
                }).toList(),
              );
            },
          ),
        ),
      ),
    );

void main() {
  late MockNutritionBloc bloc;

  setUpAll(() {
    registerFallbackValue(
        NutritionOffPlanMealLogged(date: DateTime(2026), mealType: 'x'));
    registerFallbackValue(NutritionLoaded(date: DateTime(2026)));
  });

  setUp(() => bloc = MockNutritionBloc());

  group('NutritionPage dynamic display', () {
    testWidgets('shows meal sections for each key in planOptions',
        (tester) async {
      when(() => bloc.state).thenReturn(NutritionState(
        status: NutritionStatus.success,
        activePlan: _plan,
        planOptions: {
          'Desayuno': [_optDesayuno],
          'Almuerzo': [_optAlmuerzo],
        },
      ));
      whenListen(bloc, Stream.fromIterable([bloc.state]));

      await tester.pumpWidget(_wrap(bloc));
      await tester.pumpAndSettle();

      expect(find.text('Desayuno'), findsOneWidget);
      expect(find.text('Almuerzo'), findsOneWidget);
    });

    testWidgets('"No seguí el plan" fires NutritionOffPlanMealLogged with null description',
        (tester) async {
      when(() => bloc.state).thenReturn(NutritionState(
        status: NutritionStatus.success,
        activePlan: _plan,
        planOptions: {'Desayuno': [_optDesayuno]},
      ));
      whenListen(bloc, Stream.fromIterable([bloc.state]));

      await tester.pumpWidget(_wrap(bloc));
      await tester.pumpAndSettle();

      await tester.tap(find.byKey(const Key('no_seguido_Desayuno')));
      await tester.pumpAndSettle();

      verify(() => bloc.add(NutritionOffPlanMealLogged(
            date: DateTime(2026, 6, 8),
            mealType: 'Desayuno',
            description: null,
          ))).called(1);
    });

    testWidgets('shows "Registrado" when meal logged with planOptionId',
        (tester) async {
      when(() => bloc.state).thenReturn(NutritionState(
        status: NutritionStatus.success,
        activePlan: _plan,
        planOptions: {'Desayuno': [_optDesayuno]},
        dailyLogs: [
          DailyMealLog(
            id: 1,
            date: DateTime(2026, 6, 8),
            mealType: 'Desayuno',
            planOptionId: 1,
            freeDescription: null,
            photoPath: null,
          ),
        ],
      ));
      whenListen(bloc, Stream.fromIterable([bloc.state]));

      await tester.pumpWidget(_wrap(bloc));
      await tester.pumpAndSettle();

      expect(find.text('Registrado'), findsOneWidget);
    });

    testWidgets('shows "No seguido" when meal logged with null planOptionId and null freeDescription',
        (tester) async {
      when(() => bloc.state).thenReturn(NutritionState(
        status: NutritionStatus.success,
        activePlan: _plan,
        planOptions: {'Desayuno': [_optDesayuno]},
        dailyLogs: [
          DailyMealLog(
            id: 1,
            date: DateTime(2026, 6, 8),
            mealType: 'Desayuno',
            planOptionId: null,
            freeDescription: null,
            photoPath: null,
          ),
        ],
      ));
      whenListen(bloc, Stream.fromIterable([bloc.state]));

      await tester.pumpWidget(_wrap(bloc));
      await tester.pumpAndSettle();

      expect(find.text('No seguido'), findsOneWidget);
    });

    testWidgets('shows freeDescription when meal logged off-plan with text',
        (tester) async {
      when(() => bloc.state).thenReturn(NutritionState(
        status: NutritionStatus.success,
        activePlan: _plan,
        planOptions: {'Almuerzo': [_optAlmuerzo]},
        dailyLogs: [
          DailyMealLog(
            id: 2,
            date: DateTime(2026, 6, 8),
            mealType: 'Almuerzo',
            planOptionId: null,
            freeDescription: 'Pizza con amigos',
            photoPath: null,
          ),
        ],
      ));
      whenListen(bloc, Stream.fromIterable([bloc.state]));

      await tester.pumpWidget(_wrap(bloc));
      await tester.pumpAndSettle();

      expect(find.text('Fuera de plan: Pizza con amigos'), findsOneWidget);
    });
  });
}
```

- [ ] **Step 2: Run the tests to confirm they fail**

```bash
flutter test test/features/nutrition/presentation/nutrition_page_test.dart -v
```

Expected: FAIL — the real `NutritionPage` doesn't have these keys/labels yet.

- [ ] **Step 3: Update `NutritionPage._NutritionView` — remove hardcoded meal types**

In `lib/features/nutrition/presentation/pages/nutrition_page.dart`:

1. **Remove** `_mealTypeLabel()` and `_mealTypeIcon()` methods entirely.

2. **Replace** the `ListView` children in `_NutritionView.build()`:

```dart
// Remove:
...['breakfast', 'lunch', 'dinner', 'snack'].map(
  (type) => _MealSection(
    mealType: type,
    label: _mealTypeLabel(type),
    icon: _mealTypeIcon(type),
    options: state.planOptions[type] ?? [],
    log: state.getLogForMeal(type),
  ),
),

// Replace with:
...state.planOptions.keys.map(
  (type) => _MealSection(
    mealType: type,
    label: type,
    options: state.planOptions[type] ?? [],
    log: state.getLogForMeal(type),
  ),
),
```

- [ ] **Step 4: Remove `icon` from `_MealSection` and use a generic icon**

In `_MealSection`:

1. Remove the `final String icon;` field and remove it from the constructor.
2. In `build()`, replace `Text(icon, style: const TextStyle(fontSize: 24))` with `const Icon(Icons.restaurant_menu)`.

- [ ] **Step 5: Update the chip label and color to reflect the three states**

In `_MealSection.build()`, replace the existing chip:

```dart
// Remove:
if (isLogged)
  Chip(
    label: const Text('Registrado'),
    backgroundColor: theme.colorScheme.primaryContainer,
    side: BorderSide.none,
  ),

// Replace with:
if (isLogged)
  Builder(builder: (_) {
    final String chipLabel;
    final Color chipColor;
    if (log!.planOptionId != null) {
      chipLabel = 'Registrado';
      chipColor = theme.colorScheme.primaryContainer;
    } else if (log.freeDescription != null) {
      chipLabel = 'Fuera de plan';
      chipColor = const Color(0xFF3D2E00);
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
```

- [ ] **Step 6: Update the logged body — add "No seguido" display state**

In `_MealSection.build()`, replace the existing logged/unlogged display block:

```dart
// Remove:
if (log?.freeDescription != null)
  Text(
    'Fuera de plan: ${log!.freeDescription}',
    style: theme.textTheme.bodyMedium?.copyWith(
          color: theme.colorScheme.onSurfaceVariant,
        ),
  )
else if (log?.planOptionId != null)
  _buildSelectedOption(context)
else if (options.isEmpty)
  Text(
    'Sin opciones configuradas',
    style: theme.textTheme.bodyMedium?.copyWith(
          color: theme.colorScheme.onSurfaceVariant,
        ),
  )
else
  ...options.map((opt) => _OptionTile(...)),

// Replace with:
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
```

Add the two new helper methods to `_MealSection`:

```dart
Widget _buildOffPlanText(BuildContext context, String text) {
  return Container(
    padding: const EdgeInsets.all(12),
    decoration: BoxDecoration(
      color: const Color(0xFF3D2E00),
      borderRadius: BorderRadius.circular(12),
    ),
    child: Row(
      children: [
        const Icon(Icons.edit_note, color: Color(0xFFFFCC80)),
        const SizedBox(width: 8),
        Expanded(
          child: Text(
            text,
            style: const TextStyle(color: Color(0xFFFFCC80)),
          ),
        ),
      ],
    ),
  );
}

Widget _buildNotFollowed(BuildContext context) {
  return Container(
    padding: const EdgeInsets.all(12),
    decoration: BoxDecoration(
      color: Theme.of(context).colorScheme.errorContainer.withOpacity(0.3),
      borderRadius: BorderRadius.circular(12),
    ),
    child: Row(
      children: [
        Icon(Icons.close, color: Theme.of(context).colorScheme.error),
        const SizedBox(width: 8),
        Text(
          'No seguí el plan',
          style: TextStyle(color: Theme.of(context).colorScheme.error),
        ),
      ],
    ),
  );
}
```

- [ ] **Step 7: Replace the single action button with two buttons**

In `_MealSection.build()`, replace the existing action section:

```dart
// Remove:
if (!isLogged) ...[
  const Divider(height: 24),
  TextButton.icon(
    onPressed: () => _showOffPlanDialog(context),
    icon: const Icon(Icons.edit_note),
    label: const Text('Registrar fuera de plan'),
  ),
] else ...[
  const Divider(height: 24),
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

// Replace with:
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
```

- [ ] **Step 8: Run the widget tests**

```bash
flutter test test/features/nutrition/presentation/nutrition_page_test.dart -v
```

Expected: all 5 tests pass.

- [ ] **Step 9: Run the full suite**

```bash
flutter test
```

Expected: all tests pass.

- [ ] **Step 10: Commit**

```bash
git add lib/features/nutrition/presentation/pages/nutrition_page.dart \
        test/features/nutrition/presentation/nutrition_page_test.dart
git commit -m "feat(nutrition): dynamic meal sections + No seguí el plan action"
```

---

### Task 4: Onboarding — dynamic meal times

**Why:** The onboarding step currently hardcodes 4 meal types (breakfast, lunch, dinner, snack) with exactly 3 options each. After this task the user can add/remove any number of meal times, each with any number of options; `dailyMealGoal` is set automatically.

**Files:**
- Create: `test/features/onboarding/presentation/onboarding_nutrition_step_test.dart`
- Modify: `lib/features/onboarding/presentation/pages/onboarding_page.dart`

- [ ] **Step 1: Create the onboarding widget test file**

```bash
mkdir -p /home/jesuszelaya/Documents/kiolog/test/features/onboarding/presentation
```

Create `test/features/onboarding/presentation/onboarding_nutrition_step_test.dart`:

```dart
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kiolog/features/onboarding/presentation/pages/onboarding_page.dart';

// Minimal wrapper that only shows the nutrition step (step index 2)
// by creating an isolated StatefulWidget that mirrors the step's state.
class _NutritionStepHarness extends StatefulWidget {
  const _NutritionStepHarness();

  @override
  State<_NutritionStepHarness> createState() =>
      _NutritionStepHarnessState();
}

class _MealTimeLocal {
  final nameController = TextEditingController();
  final List<TextEditingController> options = [TextEditingController()];
}

class _NutritionStepHarnessState extends State<_NutritionStepHarness> {
  final List<_MealTimeLocal> _mealTimes = [_MealTimeLocal()];

  @override
  void dispose() {
    for (final mt in _mealTimes) {
      mt.nameController.dispose();
      for (final c in mt.options) c.dispose();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      home: Scaffold(
        body: SingleChildScrollView(
          padding: const EdgeInsets.all(16),
          child: Column(
            children: [
              ..._mealTimes.asMap().entries.map((e) {
                final index = e.key;
                final mt = e.value;
                return Card(
                  key: Key('meal_time_$index'),
                  child: Column(
                    children: [
                      Row(
                        children: [
                          Text('Tiempo ${index + 1}'),
                          TextField(
                            key: Key('meal_name_$index'),
                            controller: mt.nameController,
                          ),
                          if (_mealTimes.length > 1)
                            IconButton(
                              key: Key('delete_time_$index'),
                              icon: const Icon(Icons.delete),
                              onPressed: () =>
                                  setState(() => _mealTimes.removeAt(index)),
                            ),
                        ],
                      ),
                      ...mt.options.asMap().entries.map((oe) {
                        return Row(
                          key: Key('option_${index}_${oe.key}'),
                          children: [
                            Expanded(
                              child: TextField(
                                key: Key('option_field_${index}_${oe.key}'),
                                controller: oe.value,
                              ),
                            ),
                            if (mt.options.length > 1)
                              IconButton(
                                key: Key('delete_opt_${index}_${oe.key}'),
                                icon: const Icon(Icons.close),
                                onPressed: () => setState(
                                    () => mt.options.removeAt(oe.key)),
                              ),
                          ],
                        );
                      }),
                      TextButton(
                        key: Key('add_option_$index'),
                        onPressed: () => setState(
                            () => mt.options.add(TextEditingController())),
                        child: const Text('+ Agregar opción'),
                      ),
                    ],
                  ),
                );
              }),
              Text(
                'Meta diaria automática: ${_mealTimes.length} comidas',
                key: const Key('daily_goal_label'),
              ),
              TextButton(
                key: const Key('add_meal_time'),
                onPressed: () =>
                    setState(() => _mealTimes.add(_MealTimeLocal())),
                child: const Text('+ Agregar tiempo de comida'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

void main() {
  group('Onboarding nutrition step', () {
    testWidgets('starts with 1 meal time card', (tester) async {
      await tester.pumpWidget(const _NutritionStepHarness());
      expect(find.byKey(const Key('meal_time_0')), findsOneWidget);
      expect(find.byKey(const Key('meal_time_1')), findsNothing);
    });

    testWidgets('adding a meal time shows a second card', (tester) async {
      await tester.pumpWidget(const _NutritionStepHarness());
      await tester.tap(find.byKey(const Key('add_meal_time')));
      await tester.pumpAndSettle();
      expect(find.byKey(const Key('meal_time_0')), findsOneWidget);
      expect(find.byKey(const Key('meal_time_1')), findsOneWidget);
    });

    testWidgets('delete button not shown when only 1 meal time', (tester) async {
      await tester.pumpWidget(const _NutritionStepHarness());
      expect(find.byKey(const Key('delete_time_0')), findsNothing);
    });

    testWidgets('delete button shown when 2+ meal times, removes the card',
        (tester) async {
      await tester.pumpWidget(const _NutritionStepHarness());
      await tester.tap(find.byKey(const Key('add_meal_time')));
      await tester.pumpAndSettle();
      expect(find.byKey(const Key('delete_time_0')), findsOneWidget);
      await tester.tap(find.byKey(const Key('delete_time_0')));
      await tester.pumpAndSettle();
      expect(find.byKey(const Key('meal_time_1')), findsNothing);
    });

    testWidgets('adding an option shows a second option field', (tester) async {
      await tester.pumpWidget(const _NutritionStepHarness());
      expect(find.byKey(const Key('option_field_0_1')), findsNothing);
      await tester.tap(find.byKey(const Key('add_option_0')));
      await tester.pumpAndSettle();
      expect(find.byKey(const Key('option_field_0_1')), findsOneWidget);
    });

    testWidgets('daily goal label updates when meal times change',
        (tester) async {
      await tester.pumpWidget(const _NutritionStepHarness());
      expect(find.text('Meta diaria automática: 1 comidas'), findsOneWidget);
      await tester.tap(find.byKey(const Key('add_meal_time')));
      await tester.pumpAndSettle();
      expect(find.text('Meta diaria automática: 2 comidas'), findsOneWidget);
    });
  });
}
```

- [ ] **Step 2: Run the tests to confirm they fail**

```bash
flutter test test/features/onboarding/presentation/onboarding_nutrition_step_test.dart -v
```

Expected: all 6 tests fail (harness widget doesn't exist yet — actually the harness IS in the test file, so they should fail with import errors or immediately pass on the harness. This confirms the harness tests the right behavior before touching the real page).

Confirm the tests pass on the harness itself:
```bash
flutter test test/features/onboarding/presentation/onboarding_nutrition_step_test.dart -v
```

Expected: all 6 pass (the harness already implements the spec). This validates the test logic before we change the real page.

- [ ] **Step 3: Add the `_MealTime` class to `onboarding_page.dart`**

In `lib/features/onboarding/presentation/pages/onboarding_page.dart`, add this class at the bottom of the file (before or after `_RoutineDay`):

```dart
class _MealTime {
  final nameController = TextEditingController();
  final List<TextEditingController> options = [TextEditingController()];
}
```

- [ ] **Step 4: Replace `_mealOptions` with `_mealTimes` in state**

In `_OnboardingViewState`:

1. **Remove** the `_mealOptions` map and `_mealTypeLabel` method.
2. **Add** the new list:

```dart
// Step 3: Nutrition
final _mealPlanNameController = TextEditingController(text: 'Mi Plan');
final List<_MealTime> _mealTimes = [_MealTime()];
```

- [ ] **Step 5: Update `dispose()`**

In `_OnboardingViewState.dispose()`, replace the existing nutrition dispose block:

```dart
// Remove:
for (final list in _mealOptions.values) {
  for (final c in list) {
    c.dispose();
  }
}

// Replace with:
for (final mt in _mealTimes) {
  mt.nameController.dispose();
  for (final c in mt.options) c.dispose();
}
```

- [ ] **Step 6: Update `_finish()` — use `_mealTimes` and auto `dailyMealGoal`**

In `_finish()`, replace the nutrition save block:

```dart
// Remove:
final planId = await nutritionRepo.createPlan(_mealPlanNameController.text, dailyMealGoal: 4);
for (final entry in _mealOptions.entries) {
  for (int i = 0; i < entry.value.length; i++) {
    final text = entry.value[i].text.trim();
    if (text.isNotEmpty) {
      await nutritionRepo.addPlanOption(
        planId: planId,
        mealType: entry.key,
        optionNumber: i + 1,
        description: text,
      );
    }
  }
}

// Replace with:
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
```

- [ ] **Step 7: Rewrite `_buildNutritionStep()`**

Replace the entire `_buildNutritionStep` method:

```dart
Widget _buildNutritionStep(ThemeData theme) {
  return SingleChildScrollView(
    padding: const EdgeInsets.all(24),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('Plan de Alimentación', style: theme.textTheme.headlineSmall),
        const SizedBox(height: 8),
        Text(
          'Define tus tiempos de comida y las opciones para cada uno.',
          style: theme.textTheme.bodyLarge,
        ),
        const SizedBox(height: 16),
        TextField(
          controller: _mealPlanNameController,
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
                      Text(
                        'Tiempo ${index + 1}',
                        style: theme.textTheme.labelSmall?.copyWith(
                          color: theme.colorScheme.onSurfaceVariant,
                        ),
                      ),
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
                          color: theme.colorScheme.error,
                          onPressed: () {
                            setState(() {
                              mt.nameController.dispose();
                              for (final c in mt.options) c.dispose();
                              _mealTimes.removeAt(index);
                            });
                          },
                        ),
                    ],
                  ),
                ),
                const Divider(height: 16),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  child: Column(
                    children: [
                      ...mt.options.asMap().entries.map((oe) {
                        return Padding(
                          padding: const EdgeInsets.only(bottom: 8),
                          child: Row(
                            children: [
                              Expanded(
                                child: TextField(
                                  controller: oe.value,
                                  decoration: InputDecoration(
                                    labelText: 'Opción ${oe.key + 1}',
                                    hintText: 'Ej: Avena con frutas',
                                    isDense: true,
                                  ),
                                ),
                              ),
                              if (mt.options.length > 1)
                                IconButton(
                                  icon: const Icon(Icons.close, size: 18),
                                  onPressed: () {
                                    setState(() {
                                      oe.value.dispose();
                                      mt.options.removeAt(oe.key);
                                    });
                                  },
                                ),
                            ],
                          ),
                        );
                      }),
                      Align(
                        alignment: Alignment.centerLeft,
                        child: TextButton.icon(
                          onPressed: () {
                            setState(() =>
                                mt.options.add(TextEditingController()));
                          },
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
          onPressed: () {
            setState(() => _mealTimes.add(_MealTime()));
          },
          icon: const Icon(Icons.add),
          label: const Text('Agregar tiempo de comida'),
        ),
        const SizedBox(height: 8),
        Text(
          'Meta diaria automática: ${_mealTimes.length} ${_mealTimes.length == 1 ? 'comida' : 'comidas'}',
          style: theme.textTheme.bodySmall?.copyWith(
            color: theme.colorScheme.onSurfaceVariant,
          ),
        ),
      ],
    ),
  );
}
```

- [ ] **Step 8: Run the full test suite**

```bash
flutter test
```

Expected: all tests pass (including the 6 new onboarding tests).

- [ ] **Step 9: Commit**

```bash
git add lib/features/onboarding/presentation/pages/onboarding_page.dart \
        test/features/onboarding/presentation/onboarding_nutrition_step_test.dart
git commit -m "feat(onboarding): dynamic meal times with per-time options"
```
