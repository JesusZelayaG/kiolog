# Exercise Phase D — Progress Charts Screen Design

**Date:** 2026-06-09
**Status:** Approved

---

## Goal

Add a `ExerciseProgressPage` screen to the exercise module that shows the user their weekly and monthly exercise history as a bar chart, with summary stats chips.

---

## Placement

Accessed via a 📊 icon button in the `ExercisePage` AppBar. Tapping the icon pushes `ExerciseProgressPage` onto the navigation stack.

No new bottom-nav item. No new BLoC — the existing `ExerciseBloc` is shared via `BlocProvider.value`.

---

## Architecture

`ExerciseProgressPage` is a `StatefulWidget` with three local state variables:

- `_periodo`: enum `_Periodo { semana, mes }` — controls which chart and which stats are shown
- `_chart`: enum `_Chart { rutina, cardio }` — selects which data series is rendered
- `_weekOffset`: `int` — 0 = current week, -1 = one week ago, -2 = two weeks ago, etc. **Only `<= 0` values are allowed; future weeks are not navigable.**

The page reads all data from `ExerciseBloc`'s state via `BlocBuilder`. No new events are added to the BLoC.

---

## Data Sources

All data is already loaded by `ExerciseBloc._onLoaded`:

| Data | State field | Used for |
|------|-------------|----------|
| 8 weeks of history | `state.weeklyStats` (`List<WeeklyStat>`) | bar chart bars |
| Completed routine sessions this week | `state.completedRoutineSessionsThisWeek` | current-week stats |
| Cardio logs this week | `state.weeklyCardioLogs` | current-week stats |
| Goals | `state.routineDaysGoal`, `state.cardioDaysGoal` | meta line + chips denominator |

`WeeklyStat` fields: `weekStart`, `routineDaysDone`, `cardioDaysDone`.

---

## UI — Semana Mode

### Period toggle

Pill-shaped toggle at top: `Semana | Mes`. The active tab has a filled background.

### Week navigator

Full-width row with `‹` on the left, the current week's date range in the center, and `›` on the right.

- `‹` is always tappable (up to 7 weeks back — limited by the 8 weeks in `weeklyStats`).
- `›` is disabled (`onPressed: null`) when `_weekOffset == 0` (current week). The widget appears grayed out.
- Center label shows: `"9 – 15 jun 2026"` (formatted from the week's Monday + 6 days).
- Subtitle below the date: `"semana actual"` when `_weekOffset == 0`, otherwise `"hace N semana(s)"`.

### Stats chips — Semana

Three chips in a `Row`, equal width:

| Chip | Value | Color |
|------|-------|-------|
| días rutina | `routineDaysDone / routineDaysGoal` (e.g. `3/4`) | green |
| días cardio | `cardioDaysDone / cardioDaysGoal` (e.g. `2/3`) | blue |
| sesiones | total completed sessions that week (routine + cardio + independent combined) | amber |

For the current week (`_weekOffset == 0`), derive stats from `state.completedRoutineSessionsThisWeek` and `state.weeklyCardioLogs`. For past weeks, read from `state.weeklyStats[index]`.

### Chart toggle

Pill-shaped toggle: `🏋️ Rutina | 🏃 Cardio`. Switches `_chart` between the two series.

### Bar chart — 8 weeks

Rendered with `CustomPaint` / `CustomPainter`. No external chart dependencies.

- 8 bars, oldest on the left, current week on the right.
- Bar height = `daysDone / goal` (clamped to 1.0 max). A dashed horizontal line marks the 100% / goal level.
- Current week's bar (`_weekOffset == 0` context only — the rightmost bar in the overview chart) is rendered with a dashed border and reduced opacity to indicate it is in progress.
- Color: green for Rutina, blue for Cardio.
- X-axis labels: `"sem −7"` on the left, `"actual"` (tinted green/blue) on the right.

---

## UI — Mes Mode

### Period toggle

Same pill toggle; `Mes` tab is active.

### Month navigator

Same row layout as the week navigator but shows `"Junio 2026"` in the center.

- `›` disabled when `_monthOffset == 0` (current month).
- Subtitle: `"mes actual"` or `"hace N mes(es)"`.
- `_monthOffset` is a separate local state variable, `int <= 0`.

### Stats chips — Mes

Same three chips but values are monthly aggregates:

| Chip | Value |
|------|-------|
| rutina | `%` = total routine days done / (weeks in month × `routineDaysGoal`) |
| cardio | `%` = total cardio days done / (weeks in month × `cardioDaysGoal`) |
| sesiones | total sessions in the month |

### Bar chart — 4 weeks

4 bars for the weeks of the selected month (S1–S4). Same `CustomPainter` widget, parameterized with a list of `(done, goal)` pairs. Current week shown as dashed/partial if the selected month is the current month.

---

## CustomPainter

A single reusable widget `_WeekBarChart` takes:

```dart
class _WeekBarChart extends StatelessWidget {
  final List<(int done, int goal)> bars;   // up to 8 entries
  final Color barColor;
  final bool lastBarIsPartial;             // draws dashed border on last bar
}
```

`CustomPainter` draws: bars, dashed goal line, x-axis labels. No text outside the canvas except `_weekOffset`-derived labels below.

---

## File Structure

| File | Action |
|------|--------|
| `lib/features/exercise/presentation/pages/exercise_progress_page.dart` | Create — full screen widget |
| `lib/features/exercise/presentation/pages/exercise_page.dart` | Modify — add 📊 AppBar action + navigator push |
| `test/features/exercise/presentation/exercise_progress_page_test.dart` | Create — widget tests |

---

## Testing

Widget tests for `ExerciseProgressPage`:

1. Renders stats chips with correct values from mock `ExerciseState`.
2. `›` button is disabled on the current week; tapping `‹` enables it.
3. Toggling `Semana/Mes` switches stats format (absolute → percentage).
4. Toggling `Rutina/Cardio` does not crash and repaints the chart.
5. `_WeekBarChart` renders without error for 0, 4, and 8 bars.

---

## Out of Scope

- Tapping a bar to drill into a specific week (future enhancement).
- Session-level breakdown (sets, reps, exercises logged that week).
- Export or share.
- Any new BLoC events or repository queries — all data already in state.
