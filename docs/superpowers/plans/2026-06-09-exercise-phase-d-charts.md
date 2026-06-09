# Exercise Phase D — Progress Charts Screen Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Add `ExerciseProgressPage` — a progress/charts screen showing 8-week bar chart history for Rutina and Cardio, with period toggle (Semana/Mes), week navigation (no future weeks), and 3 stats chips.

**Architecture:** A `StatefulWidget` that shares the existing `ExerciseBloc` via `BlocProvider.value`. No new BLoC events or repository queries — all data already lives in `ExerciseState`. A `CustomPainter`-based `_WeekBarChart` widget renders bars with a dashed partial-week indicator; no external chart libraries.

**Tech Stack:** Flutter, flutter_bloc, CustomPaint/CustomPainter, flutter_test, bloc_test, mocktail.

---

## File Map

| File | Action |
|------|--------|
| `lib/features/exercise/presentation/pages/exercise_progress_page.dart` | Create |
| `lib/features/exercise/presentation/pages/exercise_page.dart` | Modify — add 📊 AppBar action |
| `test/features/exercise/presentation/exercise_progress_page_test.dart` | Create |

## Context: ExerciseState fields used

```dart
// All already populated by ExerciseBloc._onLoaded:
state.weeklyStats          // List<WeeklyStat> — 8 entries, oldest→newest
                           //   weeklyStats[0] = 7 weeks ago
                           //   weeklyStats[7] = current week (partial)
state.completedRoutineSessionsThisWeek  // List<ExerciseSessionLog>
state.weeklyCardioLogs     // List<CardioLog>
state.weeklyIndependentLogs // List<IndependentExerciseLog>
state.routineDaysGoal      // int (default 4)
state.cardioDaysGoal       // int (default 3)

// WeeklyStat fields:
//   weekStart: DateTime  (UTC Monday of that week)
//   routineDaysDone: int
//   cardioDaysDone: int
```

## Context: weeklyStats ordering (critical)

`getWeeklyStats(weeksBack: 8)` loops `i = 7 downto 0`, adding `thisMonday - 7*i days`:
- `weeklyStats[0]` = Monday 7 weeks ago
- `weeklyStats[7]` = this Monday (current week, partial data)

Navigation formula for chips: `statIndex = weeklyStats.length - 1 + _weekOffset`
- `_weekOffset = 0`  → use live `completedRoutineSessionsThisWeek` / `weeklyCardioLogs`
- `_weekOffset = -1` → `weeklyStats[6]` (last complete week)
- `_weekOffset = -7` → `weeklyStats[0]` (7 weeks ago)

`‹` disabled when `_weekOffset <= -(weeklyStats.length - 1)` (already at oldest available).
`›` disabled when `_weekOffset == 0` (no future weeks).

---

## Task 1: Create `exercise_progress_page.dart`

**Files:**
- Create: `lib/features/exercise/presentation/pages/exercise_progress_page.dart`

- [ ] **Step 1: Create the file with all imports and private enums**

```dart
import 'dart:math' show sqrt;

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../bloc/exercise_bloc.dart';
import '../bloc/exercise_state.dart';

enum _Periodo { semana, mes }

enum _Chart { rutina, cardio }
```

- [ ] **Step 2: Add `ExerciseProgressPage` StatefulWidget and state class skeleton**

Append to the file:

```dart
class ExerciseProgressPage extends StatefulWidget {
  const ExerciseProgressPage({super.key});

  @override
  State<ExerciseProgressPage> createState() => _ExerciseProgressPageState();
}

class _ExerciseProgressPageState extends State<ExerciseProgressPage> {
  _Periodo _periodo = _Periodo.semana;
  _Chart _chart = _Chart.rutina;
  int _weekOffset = 0;    // <= 0 only
  int _monthOffset = 0;   // <= 0 only
```

- [ ] **Step 3: Add `build` method**

```dart
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Progreso')),
      body: BlocBuilder<ExerciseBloc, ExerciseState>(
        builder: (context, state) => ListView(
          padding: const EdgeInsets.all(16),
          children: [
            _buildPeriodToggle(context),
            const SizedBox(height: 16),
            if (_periodo == _Periodo.semana) ...[
              _buildWeekNavigator(context, state),
              const SizedBox(height: 12),
              _buildSemanaChips(context, state),
              const SizedBox(height: 16),
              _buildChartToggle(context),
              const SizedBox(height: 8),
              _buildWeekBarChartWidget(state),
            ] else ...[
              _buildMonthNavigator(context),
              const SizedBox(height: 12),
              _buildMesChips(context, state),
              const SizedBox(height: 16),
              _buildChartToggle(context),
              const SizedBox(height: 8),
              _buildMonthBarChartWidget(state),
            ],
          ],
        ),
      ),
    );
  }
```

- [ ] **Step 4: Add `_buildPeriodToggle` and shared `_pillTab` helper**

```dart
  Widget _buildPeriodToggle(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      decoration: BoxDecoration(
        color: theme.colorScheme.surfaceVariant,
        borderRadius: BorderRadius.circular(24),
      ),
      padding: const EdgeInsets.all(3),
      child: Row(
        children: [
          _pillTab(context, 'Semana', _periodo == _Periodo.semana,
              () => setState(() => _periodo = _Periodo.semana)),
          _pillTab(context, 'Mes', _periodo == _Periodo.mes,
              () => setState(() => _periodo = _Periodo.mes)),
        ],
      ),
    );
  }

  Widget _pillTab(
      BuildContext context, String label, bool active, VoidCallback onTap) {
    final theme = Theme.of(context);
    return Expanded(
      child: GestureDetector(
        onTap: onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 150),
          padding: const EdgeInsets.symmetric(vertical: 8),
          decoration: BoxDecoration(
            color: active ? theme.colorScheme.primary : Colors.transparent,
            borderRadius: BorderRadius.circular(20),
          ),
          child: Text(
            label,
            textAlign: TextAlign.center,
            style: theme.textTheme.labelLarge?.copyWith(
              color: active
                  ? theme.colorScheme.onPrimary
                  : theme.colorScheme.onSurfaceVariant,
              fontWeight: active ? FontWeight.bold : FontWeight.normal,
            ),
          ),
        ),
      ),
    );
  }
```

- [ ] **Step 5: Add the shared `_navigator` widget builder**

```dart
  Widget _navigator({
    required BuildContext context,
    required String label,
    required String sublabel,
    required Color sublabelColor,
    required bool canGoBack,
    required bool canGoForward,
    required VoidCallback onBack,
    required VoidCallback onForward,
  }) {
    final theme = Theme.of(context);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 4),
      decoration: BoxDecoration(
        color: theme.colorScheme.surfaceVariant.withOpacity(0.4),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Row(
        children: [
          IconButton(
            icon: const Icon(Icons.chevron_left),
            onPressed: canGoBack ? onBack : null,
          ),
          Expanded(
            child: Column(
              children: [
                Text(label,
                    style: theme.textTheme.bodyMedium
                        ?.copyWith(fontWeight: FontWeight.bold)),
                Text(sublabel,
                    style: theme.textTheme.bodySmall
                        ?.copyWith(color: sublabelColor)),
              ],
            ),
          ),
          IconButton(
            icon: const Icon(Icons.chevron_right),
            onPressed: canGoForward ? onForward : null,
          ),
        ],
      ),
    );
  }
```

- [ ] **Step 6: Add `_buildWeekNavigator`**

```dart
  Widget _buildWeekNavigator(BuildContext context, ExerciseState state) {
    final theme = Theme.of(context);
    final thisMonday = _mondayOf(DateTime.now());
    final weekMonday = thisMonday.add(Duration(days: 7 * _weekOffset));
    final weekSunday = weekMonday.add(const Duration(days: 6));
    final label =
        '${weekMonday.day} – ${weekSunday.day} ${_monthAbbr(weekMonday.month)} ${weekMonday.year}';
    final sublabel =
        _weekOffset == 0 ? 'semana actual' : 'hace ${-_weekOffset} semana(s)';
    // weeklyStats[7] = current week → max back = index 0 → _weekOffset = -7
    final canGoBack = state.weeklyStats.isNotEmpty &&
        _weekOffset > -(state.weeklyStats.length - 1);

    return _navigator(
      context: context,
      label: label,
      sublabel: sublabel,
      sublabelColor: _weekOffset == 0
          ? theme.colorScheme.tertiary
          : theme.colorScheme.onSurfaceVariant,
      canGoBack: canGoBack,
      canGoForward: _weekOffset < 0,
      onBack: () => setState(() => _weekOffset--),
      onForward: () => setState(() => _weekOffset++),
    );
  }
```

- [ ] **Step 7: Add `_buildMonthNavigator`**

```dart
  Widget _buildMonthNavigator(BuildContext context) {
    final theme = Theme.of(context);
    final now = DateTime.now();
    final target = DateTime(now.year, now.month + _monthOffset);
    final label = '${_monthName(target.month)} ${target.year}';
    final sublabel =
        _monthOffset == 0 ? 'mes actual' : 'hace ${-_monthOffset} mes(es)';

    return _navigator(
      context: context,
      label: label,
      sublabel: sublabel,
      sublabelColor: _monthOffset == 0
          ? theme.colorScheme.primary
          : theme.colorScheme.onSurfaceVariant,
      canGoBack: true,
      canGoForward: _monthOffset < 0,
      onBack: () => setState(() => _monthOffset--),
      onForward: () => setState(() => _monthOffset++),
    );
  }
```

- [ ] **Step 8: Add shared `_chip` widget and `_buildSemanaChips`**

`_semanaStats` uses `completedRoutineSessionsThisWeek` / `weeklyCardioLogs` for `_weekOffset == 0`,
otherwise `weeklyStats[length-1 + _weekOffset]`.

```dart
  ({int routineDays, int cardioDays, int sessions}) _semanaStats(
      ExerciseState state) {
    if (_weekOffset == 0) {
      final routineDays = state.completedRoutineSessionsThisWeek
          .map((s) => DateTime.utc(s.date.year, s.date.month, s.date.day))
          .toSet()
          .length;
      final cardioDays = state.weeklyCardioLogs
          .map((c) => DateTime.utc(c.date.year, c.date.month, c.date.day))
          .toSet()
          .length;
      final sessions = state.completedRoutineSessionsThisWeek.length +
          state.weeklyCardioLogs.length +
          state.weeklyIndependentLogs.length;
      return (
        routineDays: routineDays,
        cardioDays: cardioDays,
        sessions: sessions
      );
    }
    // weeklyStats[length-1] = current week, [length-2] = 1 week ago, ...
    final statIndex = state.weeklyStats.length - 1 + _weekOffset;
    if (statIndex < 0 || statIndex >= state.weeklyStats.length) {
      return (routineDays: 0, cardioDays: 0, sessions: 0);
    }
    final s = state.weeklyStats[statIndex];
    return (
      routineDays: s.routineDaysDone,
      cardioDays: s.cardioDaysDone,
      sessions: s.routineDaysDone + s.cardioDaysDone,
    );
  }

  Widget _buildSemanaChips(BuildContext context, ExerciseState state) {
    final s = _semanaStats(state);
    return Row(
      children: [
        _chip(context, '${s.routineDays}/${state.routineDaysGoal}',
            'días rutina', Colors.green),
        const SizedBox(width: 8),
        _chip(context, '${s.cardioDays}/${state.cardioDaysGoal}',
            'días cardio', Colors.blue),
        const SizedBox(width: 8),
        _chip(context, '${s.sessions}', 'sesiones', Colors.orange),
      ],
    );
  }

  Widget _chip(
      BuildContext context, String value, String label, Color color) {
    final theme = Theme.of(context);
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 10),
        decoration: BoxDecoration(
          color: color.withOpacity(0.08),
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: color.withOpacity(0.2)),
        ),
        child: Column(
          children: [
            Text(
              value,
              style: theme.textTheme.titleMedium
                  ?.copyWith(color: color, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 2),
            Text(
              label,
              style: theme.textTheme.labelSmall
                  ?.copyWith(color: theme.colorScheme.onSurfaceVariant),
            ),
          ],
        ),
      ),
    );
  }
```

- [ ] **Step 9: Add `_buildMesChips`**

Monthly stats filter `weeklyStats` by month+year of target month. Percentages are
`totalDays / (weeksInMonth * goalPerWeek) * 100`.

```dart
  Widget _buildMesChips(BuildContext context, ExerciseState state) {
    final now = DateTime.now();
    final target = DateTime(now.year, now.month + _monthOffset);
    final monthStats = state.weeklyStats
        .where((s) =>
            s.weekStart.month == target.month &&
            s.weekStart.year == target.year)
        .toList();

    final weeks = monthStats.isEmpty ? 1 : monthStats.length;
    final totalRoutine =
        monthStats.fold(0, (sum, s) => sum + s.routineDaysDone);
    final totalCardio =
        monthStats.fold(0, (sum, s) => sum + s.cardioDaysDone);

    final routinePct = state.routineDaysGoal > 0
        ? (totalRoutine * 100 / (weeks * state.routineDaysGoal)).round()
        : 0;
    final cardioPct = state.cardioDaysGoal > 0
        ? (totalCardio * 100 / (weeks * state.cardioDaysGoal)).round()
        : 0;
    final sessions = totalRoutine + totalCardio;

    return Row(
      children: [
        _chip(context, '$routinePct%', 'rutina', Colors.green),
        const SizedBox(width: 8),
        _chip(context, '$cardioPct%', 'cardio', Colors.blue),
        const SizedBox(width: 8),
        _chip(context, '$sessions', 'sesiones', Colors.orange),
      ],
    );
  }
```

- [ ] **Step 10: Add `_buildChartToggle`**

```dart
  Widget _buildChartToggle(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surfaceVariant,
        borderRadius: BorderRadius.circular(24),
      ),
      padding: const EdgeInsets.all(3),
      child: Row(
        children: [
          _pillTab(context, '🏋️ Rutina', _chart == _Chart.rutina,
              () => setState(() => _chart = _Chart.rutina)),
          _pillTab(context, '🏃 Cardio', _chart == _Chart.cardio,
              () => setState(() => _chart = _Chart.cardio)),
        ],
      ),
    );
  }
```

- [ ] **Step 11: Add `_buildWeekBarChartWidget` and `_buildMonthBarChartWidget`**

The 8-week chart always shows all `weeklyStats` bars; `weeklyStats[7]` is current week → `lastBarIsPartial: true`.
The month chart shows the weeks of the target month filtered from `weeklyStats`.

```dart
  Widget _buildWeekBarChartWidget(ExerciseState state) {
    final isRutina = _chart == _Chart.rutina;
    final goal = isRutina ? state.routineDaysGoal : state.cardioDaysGoal;
    final bars = state.weeklyStats
        .map((s) => (isRutina ? s.routineDaysDone : s.cardioDaysDone, goal))
        .toList();
    return SizedBox(
      height: 120,
      child: _WeekBarChart(
        bars: bars,
        barColor: isRutina ? Colors.green : Colors.blue,
        lastBarIsPartial: true,
      ),
    );
  }

  Widget _buildMonthBarChartWidget(ExerciseState state) {
    final isRutina = _chart == _Chart.rutina;
    final goal = isRutina ? state.routineDaysGoal : state.cardioDaysGoal;
    final now = DateTime.now();
    final target = DateTime(now.year, now.month + _monthOffset);
    final monthStats = state.weeklyStats
        .where((s) =>
            s.weekStart.month == target.month &&
            s.weekStart.year == target.year)
        .toList();
    final bars = monthStats
        .map((s) => (isRutina ? s.routineDaysDone : s.cardioDaysDone, goal))
        .toList();
    return SizedBox(
      height: 120,
      child: _WeekBarChart(
        bars: bars,
        barColor: isRutina ? Colors.green : Colors.blue,
        lastBarIsPartial: _monthOffset == 0,
      ),
    );
  }
```

- [ ] **Step 12: Add date/string helpers**

```dart
  DateTime _mondayOf(DateTime date) =>
      date.subtract(Duration(days: date.weekday - 1));

  String _monthAbbr(int month) {
    const abbrs = [
      '', 'ene', 'feb', 'mar', 'abr', 'may', 'jun',
      'jul', 'ago', 'sep', 'oct', 'nov', 'dic'
    ];
    return abbrs[month.clamp(1, 12)];
  }

  String _monthName(int month) {
    const names = [
      '', 'enero', 'febrero', 'marzo', 'abril', 'mayo', 'junio',
      'julio', 'agosto', 'septiembre', 'octubre', 'noviembre', 'diciembre'
    ];
    return names[month.clamp(1, 12)];
  }
}  // end _ExerciseProgressPageState
```

- [ ] **Step 13: Add `_WeekBarChart` StatelessWidget**

```dart
class _WeekBarChart extends StatelessWidget {
  final List<(int done, int goal)> bars;
  final Color barColor;
  final bool lastBarIsPartial;

  const _WeekBarChart({
    required this.bars,
    required this.barColor,
    this.lastBarIsPartial = false,
  });

  @override
  Widget build(BuildContext context) {
    return CustomPaint(
      size: Size.infinite,
      painter: _BarChartPainter(
        bars: bars,
        barColor: barColor,
        lastBarIsPartial: lastBarIsPartial,
      ),
    );
  }
}
```

- [ ] **Step 14: Add `_BarChartPainter`**

```dart
class _BarChartPainter extends CustomPainter {
  final List<(int done, int goal)> bars;
  final Color barColor;
  final bool lastBarIsPartial;

  const _BarChartPainter({
    required this.bars,
    required this.barColor,
    required this.lastBarIsPartial,
  });

  @override
  void paint(Canvas canvas, Size size) {
    if (bars.isEmpty) return;

    const bottomPad = 20.0;
    final chartH = size.height - bottomPad;
    final barW = size.width / bars.length;
    const pad = 4.0;

    final filledPaint = Paint()..color = barColor.withOpacity(0.8);
    final partialFill = Paint()..color = barColor.withOpacity(0.2);
    final dashBorder = Paint()
      ..color = barColor.withOpacity(0.6)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.5;
    final goalLine = Paint()
      ..color = barColor.withOpacity(0.35)
      ..strokeWidth = 1;

    // Dashed horizontal goal line at y=0 (100%)
    _dashedHLine(canvas, 0, size.width, 0, goalLine);

    for (int i = 0; i < bars.length; i++) {
      final (done, goal) = bars[i];
      if (goal <= 0) continue;
      final frac = (done / goal).clamp(0.0, 1.0);
      final h = frac * chartH;
      final isPartial = lastBarIsPartial && i == bars.length - 1;

      final rect = Rect.fromLTRB(
        i * barW + pad,
        chartH - h,
        (i + 1) * barW - pad,
        chartH,
      );
      final rr =
          RRect.fromRectAndRadius(rect, const Radius.circular(3));

      if (isPartial) {
        canvas.drawRRect(rr, partialFill);
        _dashedRect(canvas, rect, dashBorder);
      } else {
        canvas.drawRRect(rr, filledPaint);
      }
    }
  }

  void _dashedHLine(
      Canvas canvas, double x1, double x2, double y, Paint paint) {
    const dash = 6.0, gap = 4.0;
    double x = x1;
    bool on = true;
    while (x < x2) {
      final end = (x + (on ? dash : gap)).clamp(x1, x2);
      if (on) canvas.drawLine(Offset(x, y), Offset(end, y), paint);
      x = end;
      on = !on;
    }
  }

  void _dashedRect(Canvas canvas, Rect r, Paint paint) {
    _dashedSeg(canvas, Offset(r.left, r.top), Offset(r.right, r.top), paint);
    _dashedSeg(
        canvas, Offset(r.right, r.top), Offset(r.right, r.bottom), paint);
    _dashedSeg(
        canvas, Offset(r.right, r.bottom), Offset(r.left, r.bottom), paint);
    _dashedSeg(
        canvas, Offset(r.left, r.bottom), Offset(r.left, r.top), paint);
  }

  void _dashedSeg(Canvas canvas, Offset a, Offset b, Paint paint) {
    final dx = b.dx - a.dx;
    final dy = b.dy - a.dy;
    final len = sqrt(dx * dx + dy * dy);
    if (len == 0) return;
    final ux = dx / len;
    final uy = dy / len;
    const dash = 4.0, gap = 3.0;
    double d = 0;
    bool on = true;
    while (d < len) {
      final step = on ? dash : gap;
      final end = (d + step).clamp(0.0, len);
      if (on) {
        canvas.drawLine(
          Offset(a.dx + ux * d, a.dy + uy * d),
          Offset(a.dx + ux * end, a.dy + uy * end),
          paint,
        );
      }
      d = end;
      on = !on;
    }
  }

  @override
  bool shouldRepaint(_BarChartPainter old) =>
      old.bars != bars ||
      old.barColor != barColor ||
      old.lastBarIsPartial != lastBarIsPartial;
}
```

- [ ] **Step 15: Run `flutter analyze` and fix any issues**

```bash
cd /home/jesuszelaya/Documents/kiolog
flutter analyze lib/features/exercise/presentation/pages/exercise_progress_page.dart
```

Expected: no errors or warnings.

- [ ] **Step 16: Run existing tests to confirm no regressions**

```bash
flutter test test/features/exercise/presentation/exercise_bloc_test.dart
```

Expected: all tests pass (count ≥ 93).

- [ ] **Step 17: Commit**

```bash
git add lib/features/exercise/presentation/pages/exercise_progress_page.dart
git commit -m "feat(exercise): ExerciseProgressPage — bar chart, semana/mes toggle, week nav"
```

---

## Task 2: Wire 📊 icon into `ExercisePage` AppBar

**Files:**
- Modify: `lib/features/exercise/presentation/pages/exercise_page.dart`

The `_ExerciseViewState.build()` method builds the `AppBar`. Add an `Icons.bar_chart` button
before the existing `Icons.history` button. Use `BlocProvider.value` to share the bloc.

- [ ] **Step 1: Add import for `ExerciseProgressPage` at the top of `exercise_page.dart`**

After the existing imports, add:

```dart
import 'exercise_progress_page.dart';
```

- [ ] **Step 2: Add the 📊 icon button to `AppBar.actions`**

Current `actions` list (line ~41):
```dart
actions: [
  IconButton(
    icon: const Icon(Icons.history),
    onPressed: () => _showPlansDialog(context),
  ),
],
```

Replace with:
```dart
actions: [
  IconButton(
    icon: const Icon(Icons.bar_chart),
    onPressed: () {
      final bloc = context.read<ExerciseBloc>();
      Navigator.of(context).push(
        MaterialPageRoute<void>(
          builder: (_) => BlocProvider.value(
            value: bloc,
            child: const ExerciseProgressPage(),
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
```

- [ ] **Step 3: Run `flutter analyze`**

```bash
flutter analyze lib/features/exercise/presentation/pages/exercise_page.dart
```

Expected: no errors.

- [ ] **Step 4: Run existing tests to confirm no regressions**

```bash
flutter test test/features/exercise/presentation/exercise_bloc_test.dart
```

Expected: all tests pass.

- [ ] **Step 5: Commit**

```bash
git add lib/features/exercise/presentation/pages/exercise_page.dart
git commit -m "feat(exercise): add 📊 AppBar icon to open ExerciseProgressPage"
```

---

## Task 3: Widget tests for `ExerciseProgressPage`

**Files:**
- Create: `test/features/exercise/presentation/exercise_progress_page_test.dart`

Uses `MockBloc` from `bloc_test` + `mocktail`. `ExerciseBloc` is concrete, so the mock
`implements ExerciseBloc`. `whenListen` sets both `state` and `stream`.

- [ ] **Step 1: Create the test file with imports and mock**

```dart
import 'package:bloc_test/bloc_test.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kiolog/core/database/app_database.dart';
import 'package:kiolog/features/exercise/domain/models/independent_exercise_log.dart';
import 'package:kiolog/features/exercise/domain/models/weekly_stat.dart';
import 'package:kiolog/features/exercise/presentation/bloc/exercise_bloc.dart';
import 'package:kiolog/features/exercise/presentation/bloc/exercise_event.dart';
import 'package:kiolog/features/exercise/presentation/bloc/exercise_state.dart';
import 'package:kiolog/features/exercise/presentation/pages/exercise_progress_page.dart';
import 'package:mocktail/mocktail.dart';

class MockExerciseBloc
    extends MockBloc<ExerciseEvent, ExerciseState>
    implements ExerciseBloc {}

Widget _wrap(ExerciseBloc bloc) => MaterialApp(
      home: BlocProvider<ExerciseBloc>.value(
        value: bloc,
        child: const ExerciseProgressPage(),
      ),
    );

ExerciseState _state({
  List<WeeklyStat> weeklyStats = const [],
  List<ExerciseSessionLog> completedRoutine = const [],
  List<CardioLog> cardioLogs = const [],
  List<IndependentExerciseLog> independentLogs = const [],
  int routineDaysGoal = 4,
  int cardioDaysGoal = 3,
}) =>
    ExerciseState(
      status: ExerciseStatus.success,
      weeklyStats: weeklyStats,
      completedRoutineSessionsThisWeek: completedRoutine,
      weeklyCardioLogs: cardioLogs,
      weeklyIndependentLogs: independentLogs,
      routineDaysGoal: routineDaysGoal,
      cardioDaysGoal: cardioDaysGoal,
    );
```

- [ ] **Step 2: Write test 1 — semana chips show correct current-week values**

```dart
void main() {
  late MockExerciseBloc bloc;

  setUpAll(() {
    registerFallbackValue(ExerciseLoaded(date: DateTime(2026)));
  });

  setUp(() => bloc = MockExerciseBloc());

  group('ExerciseProgressPage', () {
    testWidgets('semana chips show correct values for current week',
        (tester) async {
      final session = ExerciseSessionLog(
        id: 1,
        date: DateTime(2026, 6, 9),
        gymArrivedAt: DateTime(2026, 6, 9, 7),
        gymLeftAt: DateTime(2026, 6, 9, 8),
        routineId: 1,
      );
      final cardio = CardioLog(
        id: 1,
        date: DateTime.utc(2026, 6, 9),
        cardioType: 'Correr',
        durationMinutes: 30,
      );
      final state = _state(
        completedRoutine: [session],
        cardioLogs: [cardio],
        routineDaysGoal: 4,
        cardioDaysGoal: 3,
      );
      whenListen(bloc, const Stream<ExerciseState>.empty(),
          initialState: state);

      await tester.pumpWidget(_wrap(bloc));
      await tester.pump();

      expect(find.text('1/4'), findsOneWidget); // días rutina
      expect(find.text('1/3'), findsOneWidget); // días cardio
      expect(find.text('2'), findsOneWidget);   // sesiones (1 routine + 1 cardio + 0 independent)
    });
```

- [ ] **Step 3: Run test 1 to verify it passes**

```bash
flutter test test/features/exercise/presentation/exercise_progress_page_test.dart --name "semana chips"
```

Expected: PASS.

- [ ] **Step 4: Write test 2 — `›` is disabled at `_weekOffset == 0`**

```dart
    testWidgets('week › button is disabled when weekOffset is 0',
        (tester) async {
      whenListen(bloc, const Stream<ExerciseState>.empty(),
          initialState: _state());

      await tester.pumpWidget(_wrap(bloc));
      await tester.pump();

      final rightBtn = tester.widget<IconButton>(
          find.widgetWithIcon(IconButton, Icons.chevron_right));
      expect(rightBtn.onPressed, isNull);
    });
```

- [ ] **Step 5: Write test 3 — tapping `‹` enables `›`**

```dart
    testWidgets('tapping ‹ decrements weekOffset and enables ›',
        (tester) async {
      final stat = WeeklyStat(
        weekStart: DateTime.utc(2026, 6, 2),
        routineDaysDone: 3,
        cardioDaysDone: 2,
      );
      // Two entries so weeklyStats.length-1=1, canGoBack at _weekOffset=0
      whenListen(bloc, const Stream<ExerciseState>.empty(),
          initialState: _state(weeklyStats: [stat, stat]));

      await tester.pumpWidget(_wrap(bloc));
      await tester.pump();

      await tester.tap(find.widgetWithIcon(IconButton, Icons.chevron_left));
      await tester.pump();

      final rightBtn = tester.widget<IconButton>(
          find.widgetWithIcon(IconButton, Icons.chevron_right));
      expect(rightBtn.onPressed, isNotNull);
    });
```

- [ ] **Step 6: Write test 4 — switching to Mes shows `%` in chips**

```dart
    testWidgets('switching to Mes shows percentage chips', (tester) async {
      final stat = WeeklyStat(
        weekStart: DateTime.utc(2026, 6, 9),
        routineDaysDone: 3,
        cardioDaysDone: 2,
      );
      whenListen(bloc, const Stream<ExerciseState>.empty(),
          initialState: _state(
            weeklyStats: [stat],
            routineDaysGoal: 4,
            cardioDaysGoal: 3,
          ));

      await tester.pumpWidget(_wrap(bloc));
      await tester.pump();

      await tester.tap(find.text('Mes'));
      await tester.pump();

      // rutina: 3 / (1 * 4) = 75%
      expect(find.text('75%'), findsOneWidget);
      // at least 2 chips with % symbol (rutina and cardio)
      expect(find.textContaining('%'), findsNWidgets(2));
    });
```

- [ ] **Step 7: Write test 5 — Rutina/Cardio toggle does not throw**

```dart
    testWidgets('Rutina/Cardio toggle does not throw', (tester) async {
      whenListen(bloc, const Stream<ExerciseState>.empty(),
          initialState: _state());

      await tester.pumpWidget(_wrap(bloc));
      await tester.pump();

      await tester.tap(find.text('🏃 Cardio'));
      await tester.pump();

      expect(tester.takeException(), isNull);
    });
```

- [ ] **Step 8: Write test 6 — renders with empty `weeklyStats` (no crash)**

```dart
    testWidgets('renders without error when weeklyStats is empty',
        (tester) async {
      whenListen(bloc, const Stream<ExerciseState>.empty(),
          initialState: _state(weeklyStats: []));

      await tester.pumpWidget(_wrap(bloc));
      await tester.pump();

      expect(tester.takeException(), isNull);
    });
  });
}
```

- [ ] **Step 9: Run all new tests**

```bash
flutter test test/features/exercise/presentation/exercise_progress_page_test.dart -v
```

Expected: 6 tests, all PASS.

- [ ] **Step 10: Run full test suite to confirm no regressions**

```bash
flutter test
```

Expected: all tests pass (count ≥ 93 + 6 new = ≥ 99).

- [ ] **Step 11: Commit**

```bash
git add test/features/exercise/presentation/exercise_progress_page_test.dart
git commit -m "test(exercise): widget tests for ExerciseProgressPage"
```
