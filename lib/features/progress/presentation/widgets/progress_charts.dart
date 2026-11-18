import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:kiolog/core/domain/app_module.dart';
import 'package:kiolog/core/modules/cubit/modules_cubit.dart';
import 'package:kiolog/shared/widgets/vitality_card.dart';

import '../bloc/progress_overview_cubit.dart';
import 'plan_progress_card.dart';

// Checked with the dataviz palette validator: passes CVD and contrast on cream.
// Verde y naranja: se distinguen también por luminosidad. En oscuro, más claros.
const _seriesLight = [Color(0xFF00785A), Color(0xFFD97B1E)];
const _seriesDark = [Color(0xFF5FB98A), Color(0xFFF0A14A)];

List<Color> _seriesColors(BuildContext context) =>
    Theme.of(context).brightness == Brightness.dark ? _seriesDark : _seriesLight;
const _chartHeight = 150.0;
const _labelHeight = 20.0;
const _barGap = 2.0;
const _maxBarWidth = 26.0;
const _barRadius = Radius.circular(8);
const _dimmedAlpha = 0.45;
const _sleepGoalHours = 8.0;
const _nutritionGoalPercent = 100.0;

String _number(double value) =>
    value == value.roundToDouble() ? value.toStringAsFixed(0) : value.toStringAsFixed(1);

/// Gráficas de todos los módulos activos en la pestaña Progreso.
class ProgressCharts extends StatelessWidget {
  const ProgressCharts({super.key});

  @override
  Widget build(BuildContext context) {
    final modules = context.watch<ModulesCubit>().state;
    return BlocBuilder<ProgressOverviewCubit, ProgressOverviewState>(
      builder: (context, state) {
        if (state.status == OverviewStatus.loading) {
          return const Padding(
            padding: EdgeInsets.all(24),
            child: Center(child: CircularProgressIndicator()),
          );
        }
        if (state.status == OverviewStatus.failure) {
          return const VitalityCard(
            child: Text('No se pudieron cargar las gráficas.'),
          );
        }
        return Column(
          children: [
            if (modules.isEnabled(AppModule.nutrition))
              for (final progress in state.plans)
                _ChartSection(child: PlanProgressCard(progress: progress)),
            if (modules.isEnabled(AppModule.exercise))
              _ChartSection(
                child: BarChartCard(
                  title: 'Ejercicio por semana',
                  caption: 'Días entrenados, últimas 8 semanas',
                  bars: state.exercise,
                  seriesNames: const ['Rutina', 'Cardio'],
                  describe: (bar) =>
                      'Semana del ${bar.label}: ${_number(bar.values[0])} de rutina, '
                      '${_number(bar.values[1])} de cardio',
                ),
              ),
            if (modules.isEnabled(AppModule.nutrition))
              _ChartSection(
                child: BarChartCard(
                  title: 'Comidas cumplidas',
                  caption: 'Porcentaje por semana del plan actual',
                  bars: state.nutrition,
                  goal: _nutritionGoalPercent,
                  goalLabel: 'Meta 100 %',
                  describe: (bar) =>
                      'Semana del ${bar.label}: ${bar.total.toStringAsFixed(0)} %',
                ),
              ),
            if (modules.isEnabled(AppModule.water))
              _ChartSection(
                child: BarChartCard(
                  title: 'Agua',
                  caption: 'Litros por día, últimos 7 días',
                  bars: state.water,
                  goal: state.waterGoalLiters,
                  goalLabel: state.waterGoalLiters == null
                      ? null
                      : 'Meta ${_number(state.waterGoalLiters!)} L',
                  describe: (bar) => '${bar.label}: ${_number(bar.total)} L',
                ),
              ),
            _ChartSection(
              child: BarChartCard(
                title: 'Sueño',
                caption: 'Horas por día, últimos 7 días',
                bars: state.sleep,
                goal: _sleepGoalHours,
                goalLabel: 'Meta 8 h',
                describe: (bar) => '${bar.label}: ${_number(bar.total)} h',
              ),
            ),
            if (state.waist.length >= 2)
              _ChartSection(
                child: BarChartCard(
                  title: 'Cintura',
                  caption: 'Centímetros por consulta',
                  bars: state.waist,
                  describe: (bar) => '${bar.label}: ${_number(bar.total)} cm',
                ),
              ),
          ],
        );
      },
    );
  }
}

class _ChartSection extends StatelessWidget {
  const _ChartSection({required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Padding(padding: const EdgeInsets.only(bottom: 14), child: child);
  }
}

/// Barras con un solo eje; tocar una barra muestra su valor.
class BarChartCard extends StatefulWidget {
  const BarChartCard({
    super.key,
    required this.title,
    required this.caption,
    required this.bars,
    required this.describe,
    this.seriesNames = const [],
    this.goal,
    this.goalLabel,
  });

  final String title;
  final String caption;
  final List<ChartBar> bars;
  final String Function(ChartBar bar) describe;
  final List<String> seriesNames;
  final double? goal;
  final String? goalLabel;

  @override
  State<BarChartCard> createState() => _BarChartCardState();
}

class _BarChartCardState extends State<BarChartCard> {
  int? _selected;

  void _select(Offset position, double width) {
    final count = widget.bars.length;
    if (count == 0) return;
    final index = (position.dx / (width / count)).floor().clamp(0, count - 1);
    setState(() => _selected = _selected == index ? null : index);
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;
    final bars = widget.bars;
    final hasData = bars.any((bar) => bar.total > 0);
    final selected = _selected;
    final status = selected != null && selected < bars.length
        ? widget.describe(bars[selected])
        : hasData
            ? 'Toca una barra para ver su valor'
            : 'Aún sin registros';
    return VitalityCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(widget.title, style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w800)),
          Text(widget.caption, style: theme.textTheme.bodySmall),
          if (widget.seriesNames.length > 1) ...[
            const SizedBox(height: 8),
            Row(
              children: [
                for (var i = 0; i < widget.seriesNames.length; i++) ...[
                  Container(
                    width: 10,
                    height: 10,
                    decoration: BoxDecoration(
                      color: _seriesColors(context)[i],
                      borderRadius: BorderRadius.circular(3),
                    ),
                  ),
                  const SizedBox(width: 6),
                  Text(widget.seriesNames[i], style: theme.textTheme.bodySmall),
                  const SizedBox(width: 16),
                ],
              ],
            ),
          ],
          const SizedBox(height: 12),
          Semantics(
            label: [
              widget.title,
              for (final bar in bars) widget.describe(bar),
            ].join('. '),
            child: LayoutBuilder(
              builder: (context, constraints) => GestureDetector(
                behavior: HitTestBehavior.opaque,
                onTapUp: (details) => _select(details.localPosition, constraints.maxWidth),
                child: TweenAnimationBuilder<double>(
                  tween: Tween(begin: 0, end: 1),
                  duration: const Duration(milliseconds: 900),
                  curve: Curves.easeOutCubic,
                  builder: (context, t, _) => CustomPaint(
                    size: Size(constraints.maxWidth, _chartHeight + _labelHeight),
                    painter: _BarChartPainter(
                      bars: bars,
                      goal: widget.goal,
                      goalLabel: widget.goalLabel,
                      selected: selected,
                      axis: cs.surfaceContainerHigh,
                      ink: cs.onSurfaceVariant,
                      accent: cs.onSurface,
                      series: _seriesColors(context),
                      progress: t,
                    ),
                  ),
                ),
              ),
            ),
          ),
          const SizedBox(height: 8),
          Text(
            status,
            style: selected != null
                ? theme.textTheme.labelLarge?.copyWith(fontWeight: FontWeight.w800, color: cs.primary)
                : theme.textTheme.bodySmall,
          ),
        ],
      ),
    );
  }
}

class _BarChartPainter extends CustomPainter {
  _BarChartPainter({
    required this.bars,
    required this.goal,
    required this.goalLabel,
    required this.selected,
    required this.axis,
    required this.ink,
    required this.accent,
    required this.series,
    this.progress = 1,
  });

  /// 0 a 1: las barras crecen al aparecer.
  final double progress;
  final List<ChartBar> bars;
  final double? goal;
  final String? goalLabel;
  final int? selected;
  final Color axis;
  final Color ink;
  final Color accent;
  final List<Color> series;

  void _text(Canvas canvas, String text, Offset center, Color color, FontWeight weight) {
    final painter = TextPainter(
      text: TextSpan(
        text: text,
        style: TextStyle(fontSize: 10, color: color, fontWeight: weight),
      ),
      textDirection: TextDirection.ltr,
    )..layout();
    painter.paint(canvas, center - Offset(painter.width / 2, 0));
  }

  @override
  void paint(Canvas canvas, Size size) {
    if (bars.isEmpty) return;
    const top = 14.0;
    final plotHeight = _chartHeight - top;
    final peak = bars.map((bar) => bar.total).fold(goal ?? 1.0, math.max);
    final scale = plotHeight / (peak <= 0 ? 1 : peak);
    final slot = size.width / bars.length;
    final barWidth = math.min(_maxBarWidth, slot * 0.6);

    canvas.drawLine(
      const Offset(0, _chartHeight),
      Offset(size.width, _chartHeight),
      Paint()
        ..color = axis
        ..strokeWidth = 1,
    );
    final target = goal;
    if (target != null && target > 0) {
      final y = _chartHeight - target * scale;
      final dash = Paint()
        ..color = ink.withValues(alpha: 0.5)
        ..strokeWidth = 1;
      for (var x = 0.0; x < size.width; x += 8) {
        canvas.drawLine(Offset(x, y), Offset(x + 4, y), dash);
      }
      if (goalLabel != null) {
        final painter = TextPainter(
          text: TextSpan(text: goalLabel, style: TextStyle(fontSize: 10, color: ink)),
          textDirection: TextDirection.ltr,
        )..layout();
        painter.paint(canvas, Offset(size.width - painter.width, y - painter.height - 1));
      }
    }

    for (var i = 0; i < bars.length; i++) {
      final dimmed = selected != null && selected != i;
      final left = slot * i + (slot - barWidth) / 2;
      var bottom = _chartHeight;
      final values = bars[i].values;
      final topIndex = values.lastIndexWhere((v) => v > 0);
      for (var s = 0; s < values.length; s++) {
        final height = values[s] * scale * progress;
        if (height <= 0) continue;
        final rect = Rect.fromLTWH(left, bottom - height, barWidth, height);
        final color = series[s % series.length];
        canvas.drawRRect(
          RRect.fromRectAndCorners(
            rect,
            topLeft: s == topIndex ? _barRadius : Radius.zero,
            topRight: s == topIndex ? _barRadius : Radius.zero,
          ),
          Paint()
            ..shader = LinearGradient(
              begin: Alignment.bottomCenter,
              end: Alignment.topCenter,
              colors: [
                (dimmed ? color.withValues(alpha: _dimmedAlpha) : color).withValues(alpha: dimmed ? 0.3 : 0.7),
                dimmed ? color.withValues(alpha: _dimmedAlpha) : color,
              ],
            ).createShader(rect),
        );
        bottom -= height + _barGap;
      }
      _text(
        canvas,
        bars[i].label,
        Offset(slot * i + slot / 2, _chartHeight + 6),
        selected == i ? accent : ink,
        selected == i ? FontWeight.w700 : FontWeight.w500,
      );
    }
  }

  @override
  bool shouldRepaint(_BarChartPainter old) =>
      old.bars != bars ||
      old.selected != selected ||
      old.goal != goal ||
      old.series != series ||
      old.progress != progress;
}
