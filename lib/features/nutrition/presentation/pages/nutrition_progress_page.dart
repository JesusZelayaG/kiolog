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

  DateTime _currentWeekMonday() {
    final now = DateTime.now().toUtc();
    final today = DateTime.utc(now.year, now.month, now.day);
    return today.subtract(Duration(days: today.weekday - 1));
  }

  DateTime _weekMondayAt(int offset) =>
      _currentWeekMonday().add(Duration(days: 7 * offset));

  DateTime _monthStartAt(int offset) {
    final now = DateTime.now().toUtc();
    final totalMonths = now.month - 1 + offset;
    final year = now.year + (totalMonths ~/ 12);
    final month = (totalMonths % 12) + 1;
    return DateTime.utc(year, month, 1);
  }

  NutritionWeeklyStat? _statAt(List<NutritionWeeklyStat> stats, int weekOffset) {
    final idx = stats.length - 1 + weekOffset;
    if (idx < 0 || idx >= stats.length) return null;
    return stats[idx];
  }

  List<NutritionWeeklyStat> _weeksInMonth(
      List<NutritionWeeklyStat> stats, int monthOffset) {
    final ms = _monthStartAt(monthOffset);
    return stats
        .where((s) => s.weekStart.month == ms.month && s.weekStart.year == ms.year)
        .toList();
  }

  Widget _buildSemanaChips(NutritionState state) {
    final stat = _statAt(state.weeklyAdherence, _weekOffset);
    final pct = stat == null || stat.mealsExpected == 0
        ? null
        : (stat.adherencePct * 100).round();
    final logged = stat?.mealsLogged ?? 0;
    final offPlan = stat?.offPlanMeals ?? 0;

    return Row(children: [
      _Chip(value: pct == null ? '—' : '$pct%', label: 'adherencia', color: _orange),
      const SizedBox(width: 8),
      _Chip(value: '$logged', label: 'comidas plan', color: Colors.green),
      const SizedBox(width: 8),
      _Chip(value: '$offPlan', label: 'fuera plan', color: Colors.blueGrey),
    ]);
  }

  Widget _buildMesChips(NutritionState state) {
    final weeks = _weeksInMonth(state.weeklyAdherence, _monthOffset);
    final totalLogged = weeks.fold(0, (s, w) => s + w.mealsLogged);
    final totalExpected = weeks.fold(0, (s, w) => s + w.mealsExpected);
    final totalOff = weeks.fold(0, (s, w) => s + w.offPlanMeals);
    final pct = totalExpected == 0
        ? null
        : (totalLogged / totalExpected * 100).round();

    return Row(children: [
      _Chip(value: pct == null ? '—' : '$pct%', label: 'adherencia', color: _orange),
      const SizedBox(width: 8),
      _Chip(value: '$totalLogged', label: 'comidas plan', color: Colors.green),
      const SizedBox(width: 8),
      _Chip(value: '$totalOff', label: 'fuera plan', color: Colors.blueGrey),
    ]);
  }

  Widget _buildWeekNavigator(List<NutritionWeeklyStat> stats) {
    final monday = _weekMondayAt(_weekOffset);
    final sunday = monday.add(const Duration(days: 6));
    final months = ['ene','feb','mar','abr','may','jun','jul','ago','sep','oct','nov','dic'];

    final String label;
    if (monday.month == sunday.month) {
      label = '${monday.day} – ${sunday.day} ${months[monday.month - 1]} ${monday.year}';
    } else {
      label = '${monday.day} ${months[monday.month - 1]} – ${sunday.day} ${months[sunday.month - 1]} ${monday.year}';
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

  Widget _buildMonthNavigator(List<NutritionWeeklyStat> stats) {
    final ms = _monthStartAt(_monthOffset);
    final months = ['Enero','Febrero','Marzo','Abril','Mayo','Junio','Julio','Agosto',
        'Septiembre','Octubre','Noviembre','Diciembre'];
    final label = '${months[ms.month - 1]} ${ms.year}';
    final sub = _monthOffset == 0
        ? 'mes actual'
        : 'hace ${-_monthOffset} mes${-_monthOffset == 1 ? '' : 'es'}';
    final canGoBack = stats.any(
        (s) => s.weekStart.isBefore(DateTime.utc(ms.year, ms.month, 1)));

    return _Navigator(
      label: label,
      subtitle: sub,
      onBack: canGoBack ? () => setState(() => _monthOffset--) : null,
      onForward: _monthOffset < 0 ? () => setState(() => _monthOffset++) : null,
    );
  }

  Widget _buildWeekBarChart(List<NutritionWeeklyStat> stats) {
    if (stats.isEmpty) return const SizedBox.shrink();
    final bars = stats.map((s) => (s.mealsLogged, s.mealsExpected)).toList();
    return _AdherenceBarChart(bars: bars, barColor: _orange, lastBarIsPartial: true);
  }

  Widget _buildMonthBarChart(List<NutritionWeeklyStat> stats) {
    final weeks = _weeksInMonth(stats, _monthOffset);
    if (weeks.isEmpty) return const SizedBox.shrink();
    final bars = weeks.map((s) => (s.mealsLogged, s.mealsExpected)).toList();
    return _AdherenceBarChart(
        bars: bars, barColor: _orange, lastBarIsPartial: _monthOffset == 0);
  }

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
                _PeriodToggle(
                  selected: _periodo,
                  onChanged: (p) => setState(() => _periodo = p),
                ),
                const SizedBox(height: 16),
                if (_periodo == _Periodo.semana)
                  _buildWeekNavigator(stats)
                else
                  _buildMonthNavigator(stats),
                const SizedBox(height: 16),
                if (_periodo == _Periodo.semana)
                  _buildSemanaChips(state)
                else
                  _buildMesChips(state),
                const SizedBox(height: 20),
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

// ── sub-widgets ────────────────────────────────────────────────────────────

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
      IconButton(icon: const Icon(Icons.chevron_left), onPressed: onBack),
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
      IconButton(icon: const Icon(Icons.chevron_right), onPressed: onForward),
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
                  fontSize: 20, fontWeight: FontWeight.bold, color: color)),
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
              style: Theme.of(context)
                  .textTheme
                  .labelSmall
                  ?.copyWith(color: Theme.of(context).colorScheme.onSurfaceVariant),
            ),
            Text('actual',
                style: Theme.of(context)
                    .textTheme
                    .labelSmall
                    ?.copyWith(color: barColor)),
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
      old.lastBarIsPartial != lastBarIsPartial || !listEquals(old.bars, bars);

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
    _drawDashedLine(canvas, Offset.zero, Offset(size.width, 0), goalPaint);

    for (int i = 0; i < bars.length; i++) {
      final (logged, expected) = bars[i];
      final x = i * (barW + gap);
      final pct = expected == 0 ? 0.0 : (logged / expected).clamp(0.0, 1.0);
      final barH = pct * chartH;
      final isPartial = lastBarIsPartial && i == bars.length - 1;
      final isNoData = expected == 0;

      if (isNoData) {
        canvas.drawRRect(
          RRect.fromRectAndCorners(
            Rect.fromLTWH(x, chartH - 4, barW, 4),
            topLeft: const Radius.circular(2),
            topRight: const Radius.circular(2),
          ),
          Paint()..color = Colors.grey.shade800,
        );
        continue;
      }

      final rect = Rect.fromLTWH(x, chartH - barH, barW, barH);
      if (isPartial) {
        canvas.drawRRect(
          RRect.fromRectAndCorners(rect,
              topLeft: const Radius.circular(3),
              topRight: const Radius.circular(3)),
          Paint()..color = barColor.withOpacity(0.25),
        );
        _drawDashedRect(canvas, rect,
            Paint()
              ..color = barColor.withOpacity(0.8)
              ..strokeWidth = 1
              ..style = PaintingStyle.stroke);
      } else {
        canvas.drawRRect(
          RRect.fromRectAndCorners(rect,
              topLeft: const Radius.circular(3),
              topRight: const Radius.circular(3)),
          Paint()..color = barColor.withOpacity(0.85),
        );
      }
    }
  }

  void _drawDashedLine(Canvas canvas, Offset p1, Offset p2, Paint paint) {
    const dashLen = 4.0;
    const gapLen = 4.0;
    final dx = p2.dx - p1.dx;
    final dy = p2.dy - p1.dy;
    final dist = ((dx * dx + dy * dy)).abs();
    final steps = (dist / (dashLen + gapLen)).floor();
    if (steps == 0) return;
    final stepX = dx / (steps * 2);
    final stepY = dy / (steps * 2);
    for (int i = 0; i < steps; i++) {
      final start = Offset(p1.dx + i * 2 * stepX, p1.dy + i * 2 * stepY);
      final end = Offset(start.dx + stepX, start.dy + stepY);
      canvas.drawLine(start, end, paint);
    }
  }

  void _drawDashedRect(Canvas canvas, Rect rect, Paint paint) {
    _drawDashedLine(canvas, rect.topLeft, rect.topRight, paint);
    _drawDashedLine(canvas, rect.topRight, rect.bottomRight, paint);
    _drawDashedLine(canvas, rect.bottomRight, rect.bottomLeft, paint);
    _drawDashedLine(canvas, rect.bottomLeft, rect.topLeft, paint);
  }
}
