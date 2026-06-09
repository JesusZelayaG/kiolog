# Nutrition Progress Charts Design

**Date:** 2026-06-09
**Status:** Approved

---

## Goal

Add a `NutritionProgressPage` screen to the nutrition module that shows the user their weekly and monthly meal plan adherence as a bar chart, with summary stats chips. Also adds plan period tracking (start/end dates) and a configurable daily meal goal per plan.

---

## Placement

Accessed via a 📊 icon button in the `NutritionPage` AppBar. Tapping the icon pushes `NutritionProgressPage` onto the navigation stack. No new bottom-nav item. No new BLoC — the existing `NutritionBloc` is shared via `BlocProvider.value`.

---

## Schema Changes

Three new columns added to `MealPlans`:

| Column | Type | Default | Description |
|--------|------|---------|-------------|
| `periodStart` | `DateTime?` | null | Date the plan was activated (UTC) |
| `periodEnd` | `DateTime?` | null | Date the plan was deactivated (null = still active) |
| `dailyMealGoal` | `int` | 4 | Expected number of plan meals per day |

Drift schema version bumped. Migration uses `ALTER TABLE meal_plans ADD COLUMN` for each new column.

Existing plans get `periodStart = null` and `periodEnd = null` (treated as weeks without plan data in the charts).

### `setActivePlan` behavior change

When activating plan X:
1. Find the currently active plan Y (if any) → set `Y.periodEnd = DateTime.now().toUtc()`
2. Set `X.periodStart = DateTime.now().toUtc()`, `X.periodEnd = null`
3. Set `X.isActive = true`, all others `isActive = false`

---

## New Model: `NutritionWeeklyStat`

```dart
class NutritionWeeklyStat {
  final DateTime weekStart;    // Monday of the week (UTC)
  final int mealsLogged;       // plan meals logged (planOptionId != null)
  final int mealsExpected;     // dailyMealGoal × days with an active plan
  final int offPlanMeals;      // meals logged with planOptionId == null

  double get adherencePct =>
      mealsExpected == 0 ? 0.0 : mealsLogged / mealsExpected;
}
```

`mealsExpected == 0` means no plan was active during that week — the bar renders as empty/grey.

---

## Adherence Calculation

For each week (`weeksBack` = 0..7, where 0 = current week):

```
weekStart = Monday of that week (UTC midnight)
weekEnd   = weekStart + 7 days

for each day in [weekStart, weekEnd):
  find plan where periodStart <= day < periodEnd (or periodEnd == null)
  if plan found:
    mealsExpected += plan.dailyMealGoal
    mealsLogged   += COUNT(DailyMealLogs where date == day AND planOptionId IS NOT NULL)
    offPlanMeals  += COUNT(DailyMealLogs where date == day AND planOptionId IS NULL)
```

Calculation done in Dart (not SQL) using:
1. All plans loaded with their `periodStart`/`periodEnd`
2. All `DailyMealLogs` for the 8-week range loaded via `getLogsInRange(from, to)`

Ordering: `weeklyAdherence[0]` = 7 weeks ago, `[7]` = current week.

---

## Repository Changes

```dart
// New method
Future<List<NutritionWeeklyStat>> getWeeklyAdherence({required int weeksBack});

// Updated signature
Future<int> createPlan(String name, {required int dailyMealGoal});
```

### New DAO query

```dart
Future<List<DailyMealLog>> getLogsInRange(DateTime from, DateTime to);
```

---

## BLoC Changes

### `NutritionState`

New field:
```dart
final List<NutritionWeeklyStat> weeklyAdherence;  // default: const []
```

Included in `copyWith` and `props`.

### `NutritionBloc._onLoaded`

After loading the existing data, also calls:
```dart
final adherence = await _repository.getWeeklyAdherence(weeksBack: 8);
```
Emitted together in the same `NutritionStatus.success` state.

### `NutritionPlanCreated` event

```dart
// before
NutritionPlanCreated({required String name})
// after
NutritionPlanCreated({required String name, required int dailyMealGoal})
```

---

## UI — NutritionProgressPage

`StatefulWidget` with local state:
- `_periodo: _Periodo` — enum `{ semana, mes }`
- `_weekOffset: int` — `<= 0` only; `›` disabled at 0 (current week)
- `_monthOffset: int` — `<= 0` only; `›` disabled at 0 (current month)

Reads all data from `NutritionBloc` state via `BlocBuilder`. No new events.

All `DateTime.now()` calls use `.toUtc()` for consistency with UTC-stored `weekStart`.

### Period toggle

Pill-shaped toggle at top: `Semana | Mes`.

### Week navigator (Semana mode)

Full-width row: `‹` left, date range center, `›` right.
- `‹` always tappable (up to 7 weeks back — limited by 8 entries in `weeklyAdherence`)
- `›` disabled (`onPressed: null`) when `_weekOffset == 0`
- Label: `"9 – 15 jun 2026"` (Monday + 6 days); cross-month: `"28 may – 3 jun 2026"`
- Subtitle: `"semana actual"` at offset 0, `"hace N semana(s)"` otherwise

`statIndex = weeklyAdherence.length - 1 + _weekOffset`

### Stats chips — Semana

Three chips in a `Row`, equal width:

| Chip | Value | Color |
|------|-------|-------|
| adherencia | `adherencePct` as `%` (e.g. `72%`) | orange |
| comidas plan | `mealsLogged` for that week | green |
| fuera plan | `offPlanMeals` for that week | blue-grey |

When `mealsExpected == 0` (no plan active): adherencia chip shows `—`.

### Bar chart — 8 weeks (Semana mode)

`CustomPaint` / `CustomPainter`. No external chart dependencies.

- 8 bars, oldest left, current week right
- Bar height = `adherencePct` (clamped to 1.0 max)
- Color: `Colors.orange` for bars with data; grey (`Colors.grey.shade800`) for weeks with `mealsExpected == 0`
- Dashed horizontal goal line at 100%
- Current week bar (rightmost) drawn with dashed border + reduced opacity (partial/in-progress)
- X-axis labels: `"sem −7"` left, `"actual"` (orange-tinted) right

Reuses the same `_WeekBarChart` / `_BarChartPainter` pattern from `ExerciseProgressPage` — the widget is local to `NutritionProgressPage` (not shared) to avoid coupling.

`shouldRepaint` uses `listEquals` from `flutter/foundation.dart`.

### Month navigator (Mes mode)

Same row layout; shows `"Junio 2026"` center.
- `›` disabled at `_monthOffset == 0`
- Subtitle: `"mes actual"` or `"hace N mes(es)"`

### Stats chips — Mes

Same three chips but monthly aggregates:

| Chip | Value |
|------|-------|
| adherencia | `totalMealsLogged / totalMealsExpected` as `%` for the month |
| comidas plan | sum of `mealsLogged` for all weeks in the month |
| fuera plan | sum of `offPlanMeals` for all weeks in the month |

Weeks with `mealsExpected == 0` excluded from monthly adherence denominator.

### Bar chart — 4 weeks (Mes mode)

4 bars (S1–S4) for weeks whose `weekStart` falls in the selected month. Same `_WeekBarChart` widget, parameterized with the filtered list. Current week shown as partial if selected month is current month.

---

## UI — Plan Creation Dialog Change

`_showCreatePlanDialog` adds a second input: **comidas por día** (integer, default 4, range 1–10).

Layout:
```
┌─ Nuevo plan alimenticio ────────┐
│ Nombre del plan: [____________] │
│ Comidas por día: [  4  ] ▲▼    │
│                                 │
│          [Cancelar]  [Crear]    │
└─────────────────────────────────┘
```

`▲` / `▼` are `IconButton`s (increment/decrement, clamped to 1–10). Value stored in a `StatefulBuilder` local variable, passed to `NutritionPlanCreated(name: ..., dailyMealGoal: ...)`.

---

## File Structure

| File | Action |
|------|--------|
| `lib/core/database/tables/nutrition_tables.dart` | Add 3 columns to `MealPlans` |
| `lib/core/database/app_database.dart` | Bump `schemaVersion`, add migration |
| `lib/core/dao/nutrition_dao.dart` | Update `setActivePlan`, add `getLogsInRange` |
| `lib/core/dao/nutrition_dao.g.dart` | Regenerated (dart run build_runner build) |
| `lib/core/database/app_database.g.dart` | Regenerated |
| `lib/features/nutrition/domain/models/nutrition_weekly_stat.dart` | New model |
| `lib/features/nutrition/domain/repositories/nutrition_repository.dart` | Add `getWeeklyAdherence`, update `createPlan` |
| `lib/features/nutrition/data/repositories/nutrition_repository_impl.dart` | Implement changes |
| `lib/features/nutrition/presentation/bloc/nutrition_event.dart` | Update `NutritionPlanCreated` |
| `lib/features/nutrition/presentation/bloc/nutrition_state.dart` | Add `weeklyAdherence` |
| `lib/features/nutrition/presentation/bloc/nutrition_bloc.dart` | Load adherence in `_onLoaded` |
| `lib/features/nutrition/presentation/pages/nutrition_page.dart` | Add 📊 icon, update dialog |
| `lib/features/nutrition/presentation/pages/nutrition_progress_page.dart` | New screen |
| `test/features/nutrition/presentation/nutrition_progress_page_test.dart` | Widget tests |

---

## Testing

Widget tests for `NutritionProgressPage`:

1. Renders adherencia chip with correct `%` from mock `NutritionState`.
2. `›` button is disabled on current week; tapping `‹` enables it.
3. Toggling `Semana/Mes` switches chips from `%` counts to monthly aggregates.
4. Weeks with `mealsExpected == 0` show `—` in adherencia chip.
5. Empty `weeklyAdherence` list does not crash.
6. Month navigator `›` disabled at `_monthOffset == 0`.

---

## Out of Scope

- Expanding the nutrition page to show more than 4 fixed meal sections (future work if `dailyMealGoal > 4`).
- Tapping a bar to drill into a specific week.
- Export or share.
- Any new BLoC events for the progress page — all data already in state.
- Photo attachments for off-plan meals (existing feature, unchanged).
