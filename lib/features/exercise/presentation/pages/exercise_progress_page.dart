import 'dart:math' show sqrt;

import 'package:flutter/foundation.dart' show listEquals;
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../bloc/exercise_bloc.dart';
import '../bloc/exercise_state.dart';

enum _Periodo { semana, mes }

enum _Chart { rutina, cardio }

class ExerciseProgressPage extends StatefulWidget {
  const ExerciseProgressPage({super.key});

  @override
  State<ExerciseProgressPage> createState() => _ExerciseProgressPageState();
}

class _ExerciseProgressPageState extends State<ExerciseProgressPage> {
  _Periodo _periodo = _Periodo.semana;
  _Chart _chart = _Chart.rutina;
  int _weekOffset = 0; // <= 0 only
  int _monthOffset = 0; // <= 0 only

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

  Widget _buildWeekNavigator(BuildContext context, ExerciseState state) {
    final theme = Theme.of(context);
    final thisMonday = _mondayOf(DateTime.now().toUtc());
    final weekMonday = thisMonday.add(Duration(days: 7 * _weekOffset));
    final weekSunday = weekMonday.add(const Duration(days: 6));
    final label = weekMonday.month == weekSunday.month
        ? '${weekMonday.day} – ${weekSunday.day} ${_monthAbbr(weekMonday.month)} ${weekMonday.year}'
        : '${weekMonday.day} ${_monthAbbr(weekMonday.month)} – ${weekSunday.day} ${_monthAbbr(weekSunday.month)} ${weekSunday.year}';
    final sublabel =
        _weekOffset == 0 ? 'semana actual' : 'hace ${-_weekOffset} semana(s)';
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

  Widget _buildMonthNavigator(BuildContext context) {
    final theme = Theme.of(context);
    final now = DateTime.now().toUtc();
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

  Widget _buildMesChips(BuildContext context, ExerciseState state) {
    final now = DateTime.now().toUtc();
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
    final now = DateTime.now().toUtc();
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
} // end _ExerciseProgressPageState

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
      !listEquals(old.bars, bars) ||
      old.barColor != barColor ||
      old.lastBarIsPartial != lastBarIsPartial;
}
