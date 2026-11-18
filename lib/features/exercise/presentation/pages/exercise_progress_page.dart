import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:iconsax_plus/iconsax_plus.dart';
import 'package:intl/intl.dart';
import 'package:kiolog/core/domain/day.dart';
import 'package:kiolog/core/theme/app_theme.dart';
import 'package:kiolog/shared/widgets/entrance.dart';
import 'package:kiolog/shared/widgets/kiolog_glyphs.dart';
import 'package:kiolog/shared/widgets/progress_ring.dart';
import 'package:kiolog/shared/widgets/themed_page.dart';

import '../../domain/models/weekly_stat.dart';
import '../bloc/exercise_bloc.dart';
import '../bloc/exercise_state.dart';

const _settle = Cubic(.3, .9, .25, 1);

enum _Period { week, month }

enum _Chart { routine, cardio }

/// Lo hecho en un periodo: días de rutina y de cardio, y sus metas.
typedef _Totals = ({int routine, int routineGoal, int cardio, int cardioGoal, int sessions});

class ExerciseProgressPage extends StatefulWidget {
  const ExerciseProgressPage({super.key});

  @override
  State<ExerciseProgressPage> createState() => _ExerciseProgressPageState();
}

class _ExerciseProgressPageState extends State<ExerciseProgressPage> {
  _Period _period = _Period.week;
  _Chart _chart = _Chart.routine;
  int _weekOffset = 0;
  int _monthOffset = 0;

  @override
  Widget build(BuildContext context) {
    return ThemedPage(
      child: BlocBuilder<ExerciseBloc, ExerciseState>(
        builder: (context, state) {
          final items = <Widget>[
            const _Header(),
            GradientSegmented<_Period>(
              value: _period,
              options: const {_Period.week: 'Semana', _Period.month: 'Mes'},
              onChanged: (p) => setState(() => _period = p),
            ),
            _summaryCard(context, state),
            _chartCard(context, state),
          ];
          return ListView.separated(
            padding: const EdgeInsets.fromLTRB(18, 14, 18, 32),
            itemCount: items.length,
            separatorBuilder: (_, __) => const SizedBox(height: 14),
            itemBuilder: (context, i) => Entrance(index: i, child: items[i]),
          );
        },
      ),
    );
  }

  // ── Datos ───────────────────────────────────────────────────────────────

  _Totals _weekTotals(ExerciseState state) {
    if (_weekOffset == 0) {
      // La semana en curso, con lo registrado hasta ahora.
      return (
        routine: state.completedRoutineSessionsThisWeek.map((s) => storedDay(s.date)).toSet().length,
        routineGoal: state.routineDaysGoal,
        cardio: state.weeklyCardioLogs.map((c) => storedDay(c.date)).toSet().length,
        cardioGoal: state.cardioDaysGoal,
        sessions: state.completedRoutineSessionsThisWeek.length +
            state.weeklyCardioLogs.length +
            state.weeklyIndependentLogs.length,
      );
    }
    final i = state.weeklyStats.length - 1 + _weekOffset;
    final s = i >= 0 && i < state.weeklyStats.length ? state.weeklyStats[i] : null;
    return (
      routine: s?.routineDaysDone ?? 0,
      routineGoal: state.routineDaysGoal,
      cardio: s?.cardioDaysDone ?? 0,
      cardioGoal: state.cardioDaysGoal,
      sessions: (s?.routineDaysDone ?? 0) + (s?.cardioDaysDone ?? 0),
    );
  }

  DateTime get _month {
    final now = DateTime.now();
    return DateTime(now.year, now.month + _monthOffset);
  }

  List<WeeklyStat> _monthWeeks(ExerciseState state) => state.weeklyStats
      .where((s) => s.weekStart.year == _month.year && s.weekStart.month == _month.month)
      .toList();

  _Totals _monthTotals(ExerciseState state) {
    final weeks = _monthWeeks(state);
    final n = weeks.isEmpty ? 1 : weeks.length;
    final routine = weeks.fold(0, (sum, s) => sum + s.routineDaysDone);
    final cardio = weeks.fold(0, (sum, s) => sum + s.cardioDaysDone);
    return (
      routine: routine,
      routineGoal: state.routineDaysGoal * n,
      cardio: cardio,
      cardioGoal: state.cardioDaysGoal * n,
      sessions: routine + cardio,
    );
  }

  // ── Resumen del periodo ─────────────────────────────────────────────────

  Widget _summaryCard(BuildContext context, ExerciseState state) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;
    final kc = context.kc;
    final week = _period == _Period.week;
    final totals = week ? _weekTotals(state) : _monthTotals(state);

    late final String label;
    late final String subtitle;
    VoidCallback? back;
    VoidCallback? forward;
    if (week) {
      final today = todayUtcDay();
      final monday = today.subtract(Duration(days: today.weekday - 1 - 7 * _weekOffset));
      final f = DateFormat('d MMM', 'es');
      label = '${f.format(monday)} – ${f.format(monday.add(const Duration(days: 6)))}';
      subtitle = _weekOffset == 0 ? 'Esta semana' : 'Hace ${-_weekOffset} ${_weekOffset == -1 ? 'semana' : 'semanas'}';
      back = _weekOffset > -(state.weeklyStats.length - 1) ? () => setState(() => _weekOffset--) : null;
      forward = _weekOffset < 0 ? () => setState(() => _weekOffset++) : null;
    } else {
      final m = DateFormat.yMMMM('es').format(_month);
      label = m[0].toUpperCase() + m.substring(1);
      subtitle = _monthOffset == 0 ? 'Este mes' : 'Hace ${-_monthOffset} ${_monthOffset == -1 ? 'mes' : 'meses'}';
      final firstWeek = state.weeklyStats.isEmpty ? null : state.weeklyStats.first.weekStart;
      back = firstWeek != null && firstWeek.isBefore(DateTime.utc(_month.year, _month.month))
          ? () => setState(() => _monthOffset--)
          : null;
      forward = _monthOffset < 0 ? () => setState(() => _monthOffset++) : null;
    }
    final share = totals.routineGoal == 0 ? 0.0 : (totals.routine / totals.routineGoal).clamp(0.0, 1.0);

    return _Card(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              _Round(icon: IconsaxPlusLinear.arrow_right_3, flip: true, tooltip: 'Anterior', onTap: back),
              Expanded(
                child: Column(
                  children: [
                    Text(label, style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w800)),
                    Text(subtitle, style: theme.textTheme.bodySmall),
                  ],
                ),
              ),
              _Round(icon: IconsaxPlusLinear.arrow_right_3, tooltip: 'Siguiente', onTap: forward),
            ],
          ),
          const SizedBox(height: 18),
          Row(
            children: [
              SizedBox(
                width: 116,
                height: 116,
                child: TweenAnimationBuilder<double>(
                  key: ValueKey('$_period$_weekOffset$_monthOffset'),
                  tween: Tween(begin: 0, end: share),
                  duration: const Duration(milliseconds: 1000),
                  curve: _settle,
                  builder: (context, v, _) => CustomPaint(
                    painter: GradientRing(progress: v, gradient: kc.brandGradient, track: context.hc.ringTrack, width: 12),
                    child: Center(
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text('${(v * 100).round()}%', style: theme.textTheme.displayMedium?.copyWith(fontSize: 26)),
                          Text('de rutina', style: theme.textTheme.bodySmall),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  children: [
                    _StatTile(
                      icon: KiologGlyph(KiologGlyphKind.dumbbell, size: 20, color: cs.primary),
                      color: cs.primary,
                      value: '${totals.routine}/${totals.routineGoal}',
                      label: 'días de rutina',
                    ),
                    const SizedBox(height: 8),
                    _StatTile(
                      icon: Icon(IconsaxPlusLinear.activity, size: 20, color: kc.waterInk),
                      color: kc.waterInk,
                      value: '${totals.cardio}/${totals.cardioGoal}',
                      label: 'días de cardio',
                    ),
                    const SizedBox(height: 8),
                    _StatTile(
                      icon: Icon(IconsaxPlusBold.flash, size: 20, color: kc.foodInk),
                      color: kc.foodInk,
                      value: '${totals.sessions}',
                      label: totals.sessions == 1 ? 'sesión' : 'sesiones',
                    ),
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  // ── Gráfica ─────────────────────────────────────────────────────────────

  Widget _chartCard(BuildContext context, ExerciseState state) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;
    final kc = context.kc;
    final routine = _chart == _Chart.routine;
    final weeks = _period == _Period.week ? state.weeklyStats : _monthWeeks(state);
    final goal = routine ? state.routineDaysGoal : state.cardioDaysGoal;
    final selected = _period == _Period.week ? state.weeklyStats.length - 1 + _weekOffset : null;
    final f = DateFormat('d MMM', 'es');

    return _Card(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            _period == _Period.week ? 'ÚLTIMAS ${weeks.length} SEMANAS' : 'SEMANAS DEL MES',
            style: theme.textTheme.labelSmall?.copyWith(fontSize: 11),
          ),
          const SizedBox(height: 10),
          GradientSegmented<_Chart>(
            value: _chart,
            options: const {_Chart.routine: 'Rutina', _Chart.cardio: 'Cardio'},
            onChanged: (c) => setState(() => _chart = c),
            small: true,
          ),
          const SizedBox(height: 16),
          if (weeks.isEmpty)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 24),
              child: Text('Todavía no hay semanas registradas.', textAlign: TextAlign.center, style: theme.textTheme.bodyMedium),
            )
          else ...[
            SizedBox(
              height: 140,
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  for (var i = 0; i < weeks.length; i++) ...[
                    if (i > 0) const SizedBox(width: 8),
                    Expanded(
                      child: Builder(builder: (context) {
                        final done = routine ? weeks[i].routineDaysDone : weeks[i].cardioDaysDone;
                        final share = goal == 0 ? 0.0 : (done / goal).clamp(0.0, 1.0);
                        final current = _period == _Period.week && i == weeks.length - 1;
                        final isSelected = selected == i;
                        final colors = routine ? kc.brandGradient.colors : [kc.waterInk, kc.waterInk];
                        return Column(
                          mainAxisAlignment: MainAxisAlignment.end,
                          children: [
                            Text(
                              '$done',
                              style: theme.textTheme.labelSmall?.copyWith(
                                fontSize: 11,
                                color: isSelected ? cs.primary : cs.onSurfaceVariant,
                              ),
                            ),
                            const SizedBox(height: 4),
                            TweenAnimationBuilder<double>(
                              tween: Tween(begin: 0, end: share),
                              duration: Duration(milliseconds: 700 + i * 70),
                              curve: _settle,
                              builder: (context, v, _) => Container(
                                height: 6 + 100 * v,
                                decoration: BoxDecoration(
                                  gradient: done == 0
                                      ? null
                                      : LinearGradient(
                                          begin: Alignment.bottomCenter,
                                          end: Alignment.topCenter,
                                          colors: [for (final c in colors) current ? c.withValues(alpha: 0.55) : c],
                                        ),
                                  color: done == 0 ? context.hc.ringTrack : null,
                                  borderRadius: BorderRadius.circular(8),
                                  border: isSelected ? Border.all(color: cs.onSurface, width: 1.5) : null,
                                ),
                              ),
                            ),
                          ],
                        );
                      }),
                    ),
                  ],
                ],
              ),
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                Text(f.format(weeks.first.weekStart.toUtc()), style: theme.textTheme.bodySmall),
                const Spacer(),
                Text('Meta: $goal días por semana', style: theme.textTheme.bodySmall?.copyWith(color: cs.primary)),
              ],
            ),
          ],
        ],
      ),
    );
  }
}

class _Header extends StatelessWidget {
  const _Header();

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;
    return Row(
      children: [
        Material(
          color: cs.surfaceContainerLowest,
          borderRadius: BorderRadius.circular(16),
          child: InkWell(
            borderRadius: BorderRadius.circular(16),
            onTap: () => Navigator.of(context).maybePop(),
            child: Tooltip(
              message: 'Volver',
              child: SizedBox(width: 44, height: 44, child: Icon(IconsaxPlusLinear.arrow_left, color: cs.onSurface)),
            ),
          ),
        ),
        const SizedBox(width: 14),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('PROGRESO', style: theme.textTheme.labelSmall?.copyWith(fontSize: 11, color: cs.primary)),
              Text('Ejercicio', style: theme.textTheme.displayMedium?.copyWith(fontSize: 26)),
            ],
          ),
        ),
      ],
    );
  }
}

class _Card extends StatelessWidget {
  const _Card({required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.all(18),
        decoration: BoxDecoration(
          color: Theme.of(context).colorScheme.surfaceContainerLowest,
          borderRadius: BorderRadius.circular(28),
          boxShadow: [context.kc.shadow],
        ),
        child: child,
      );
}

class _Round extends StatelessWidget {
  const _Round({required this.icon, required this.tooltip, required this.onTap, this.flip = false});

  final IconData icon;
  final String tooltip;
  final VoidCallback? onTap;

  /// Voltea el ícono: la flecha izquierda de Iconsax no hace juego con la derecha.
  final bool flip;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Material(
      color: cs.surfaceContainerHigh,
      shape: const CircleBorder(),
      child: InkWell(
        customBorder: const CircleBorder(),
        onTap: onTap,
        child: Tooltip(
          message: tooltip,
          child: SizedBox(
            width: 40,
            height: 40,
            child: Transform.flip(
              flipX: flip,
              child: Icon(icon, size: 18, color: onTap == null ? cs.outline : cs.onSurface),
            ),
          ),
        ),
      ),
    );
  }
}

class _StatTile extends StatelessWidget {
  const _StatTile({required this.icon, required this.color, required this.value, required this.label});

  final Widget icon;
  final Color color;
  final String value;
  final String label;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(color: color.withValues(alpha: 0.12), borderRadius: BorderRadius.circular(14)),
      child: Row(
        children: [
          icon,
          const SizedBox(width: 8),
          Text(value, style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w800)),
          const SizedBox(width: 6),
          Expanded(child: Text(label, style: theme.textTheme.bodySmall, maxLines: 1, overflow: TextOverflow.ellipsis)),
        ],
      ),
    );
  }
}
