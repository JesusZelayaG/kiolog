import 'dart:math' show sqrt;
import 'package:flutter/foundation.dart' show listEquals;
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:kiolog/core/database/app_database.dart';
import 'package:kiolog/features/nutrition/domain/models/nutrition_weekly_stat.dart';
import 'package:kiolog/features/nutrition/domain/models/option_frequency_stat.dart';
import 'package:kiolog/features/nutrition/presentation/pages/nutrition_config_page.dart';
import '../bloc/nutrition_bloc.dart';
import '../bloc/nutrition_event.dart';
import '../bloc/nutrition_state.dart';
import 'package:kiolog/shared/widgets/stat_chip.dart';

enum _Periodo { semana, mes }

class NutritionProgressPage extends StatelessWidget {
  const NutritionProgressPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Progreso Nutrición')),
      body: BlocBuilder<NutritionBloc, NutritionState>(
        builder: (context, state) {
          final isViewingActive = state.viewingPlanId == null;
          return Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              _PlanChip(state: state),
              if (isViewingActive)
                Expanded(child: _ActivePlanView(state: state))
              else
                Expanded(
                  child: _FrecuenciaTab(
                    frequencies: state.optionFrequencies,
                  ),
                ),
            ],
          );
        },
      ),
    );
  }
}

// ── Plan chip + bottom sheet ──────────────────────────────────────────────────

class _PlanChip extends StatelessWidget {
  final NutritionState state;
  const _PlanChip({required this.state});

  @override
  Widget build(BuildContext context) {
    final plan = state.viewingPlan ?? state.activePlan;
    final cs = Theme.of(context).colorScheme;
    return InkWell(
      onTap: () => _showPlanSheet(context),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
        color: cs.surface,
        child: Row(
          children: [
            Container(
              padding:
                  const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              decoration: BoxDecoration(
                color: cs.primaryContainer,
                borderRadius: BorderRadius.circular(20),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    plan?.name ?? 'Sin plan',
                    style: TextStyle(
                      fontWeight: FontWeight.w600,
                      color: cs.onPrimaryContainer,
                      fontSize: 13,
                    ),
                  ),
                  const SizedBox(width: 4),
                  Icon(Icons.expand_more,
                      size: 16, color: cs.onPrimaryContainer),
                ],
              ),
            ),
            const SizedBox(width: 8),
            if (plan != null)
              Text(
                plan.isActive ? 'activo' : _periodLabel(plan),
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: cs.onSurfaceVariant,
                    ),
              ),
          ],
        ),
      ),
    );
  }

  String _periodLabel(MealPlan plan) {
    final e = plan.periodEnd;
    if (e == null) return '';
    return 'hasta ${e.day}/${e.month}/${e.year}';
  }

  void _showPlanSheet(BuildContext context) {
    final bloc = context.read<NutritionBloc>();
    showModalBottomSheet<void>(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (_) => BlocProvider.value(
        value: bloc,
        child: const _PlanSelectorSheet(),
      ),
    );
  }
}

class _PlanSelectorSheet extends StatelessWidget {
  const _PlanSelectorSheet();

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<NutritionBloc, NutritionState>(
      builder: (context, state) {
        final cs = Theme.of(context).colorScheme;
        return Padding(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Center(
                child: Container(
                  width: 32,
                  height: 4,
                  margin: const EdgeInsets.only(bottom: 16),
                  decoration: BoxDecoration(
                    color: cs.outlineVariant,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              Text('Planes alimenticios',
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        color: Theme.of(context).colorScheme.onSurface,
                      ),
                  textAlign: TextAlign.center),
              const SizedBox(height: 12),
              if (state.activePlan != null)
                _PlanTile(
                  plan: state.activePlan!,
                  isActive: true,
                  isViewing:
                      state.viewingPlanId == null ||
                      state.viewingPlanId == state.activePlan!.id,
                  onTap: () {
                    context.read<NutritionBloc>().add(
                          NutritionProgressPlanSelected(
                              planId: state.activePlan!.id),
                        );
                    Navigator.pop(context);
                  },
                ),
              ...state.allPlans
                  .where((p) => !p.isActive)
                  .map((p) => _PlanTile(
                        plan: p,
                        isActive: false,
                        isViewing: state.viewingPlanId == p.id,
                        onTap: () {
                          context.read<NutritionBloc>().add(
                                NutritionProgressPlanSelected(planId: p.id),
                              );
                          Navigator.pop(context);
                        },
                      )),
              const SizedBox(height: 8),
              InkWell(
                onTap: () {
                  final bloc = context.read<NutritionBloc>();
                  Navigator.pop(context);
                  Navigator.of(context).push(
                    MaterialPageRoute<void>(
                      builder: (_) => NutritionConfigPage(
                        onComplete: () => bloc
                            .add(NutritionLoaded(date: DateTime.now())),
                      ),
                    ),
                  );
                },
                borderRadius: BorderRadius.circular(10),
                child: Container(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 16, vertical: 12),
                  decoration: BoxDecoration(
                    border: Border.all(
                        color: cs.primary,
                        width: 1.5),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Row(
                    children: [
                      Icon(Icons.add_circle_outline, color: cs.primary),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Nueva consulta',
                              style: TextStyle(
                                fontWeight: FontWeight.w600,
                                color: cs.primary,
                              ),
                            ),
                            Text(
                              'Crear el plan de la nueva sesión',
                              style: Theme.of(context)
                                  .textTheme
                                  .bodySmall
                                  ?.copyWith(color: cs.onSurfaceVariant),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}

class _PlanTile extends StatelessWidget {
  final MealPlan plan;
  final bool isActive;
  final bool isViewing;
  final VoidCallback onTap;

  const _PlanTile({
    required this.plan,
    required this.isActive,
    required this.isViewing,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final start = plan.periodStart;
    final end = plan.periodEnd;
    final dateLabel = start == null
        ? ''
        : end == null
            ? 'desde ${start.day}/${start.month}/${start.year}'
            : '${start.day}/${start.month}/${start.year} – '
                '${end.day}/${end.month}/${end.year}';

    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(10),
        child: Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: isViewing
                ? cs.primaryContainer.withValues(alpha: 0.3)
                : cs.surfaceContainerHighest,
            border: isViewing
                ? Border.all(color: cs.primary, width: 1.5)
                : null,
            borderRadius: BorderRadius.circular(10),
          ),
          child: Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(plan.name,
                        style: TextStyle(
                            fontWeight: FontWeight.w600,
                            color: cs.onSurface)),
                    if (dateLabel.isNotEmpty)
                      Text(
                        dateLabel,
                        style: Theme.of(context).textTheme.bodySmall?.copyWith(
                              color: cs.onSurfaceVariant,
                            ),
                      ),
                  ],
                ),
              ),
              if (isActive)
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                  decoration: BoxDecoration(
                    color: cs.primary,
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Text(
                    'ACTIVO',
                    style: TextStyle(
                        fontSize: 10,
                        color: cs.onPrimary,
                        fontWeight: FontWeight.w700),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

// ── Vista plan activo: tabs Adherencia + Frecuencia ───────────────────────────

class _ActivePlanView extends StatefulWidget {
  final NutritionState state;
  const _ActivePlanView({required this.state});

  @override
  State<_ActivePlanView> createState() => _ActivePlanViewState();
}

class _ActivePlanViewState extends State<_ActivePlanView>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  _Periodo _periodo = _Periodo.semana;
  int _weekOffset = 0;
  int _monthOffset = 0;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        TabBar(
          controller: _tabController,
          tabs: const [
            Tab(text: 'Adherencia'),
            Tab(text: 'Frecuencia'),
          ],
        ),
        Expanded(
          child: TabBarView(
            controller: _tabController,
            children: [
              _buildAdherenciaContent(),
              _FrecuenciaTab(
                  frequencies: widget.state.optionFrequencies),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildAdherenciaContent() {
    final stats = widget.state.weeklyAdherence;
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
            _buildSemanaChips(widget.state)
          else
            _buildMesChips(widget.state),
          const SizedBox(height: 20),
          if (_periodo == _Periodo.semana)
            _buildWeekBarChart(stats)
          else
            _buildMonthBarChart(stats),
        ],
      ),
    );
  }

  DateTime _currentWeekMonday() {
    final now = DateTime.now().toUtc();
    final today = DateTime.utc(now.year, now.month, now.day);
    return today.subtract(Duration(days: today.weekday - 1));
  }

  DateTime _weekMondayAt(int offset) =>
      _currentWeekMonday().add(Duration(days: 7 * offset));

  DateTime _monthStartAt(int offset) {
    final now = DateTime.now().toUtc();
    return DateTime.utc(now.year, now.month + offset, 1);
  }

  NutritionWeeklyStat? _statAt(
      List<NutritionWeeklyStat> stats, int weekOffset) {
    final idx = stats.length - 1 + weekOffset;
    if (idx < 0 || idx >= stats.length) return null;
    return stats[idx];
  }

  List<NutritionWeeklyStat> _weeksInMonth(
      List<NutritionWeeklyStat> stats, int monthOffset) {
    final ms = _monthStartAt(monthOffset);
    return stats
        .where((s) =>
            s.weekStart.month == ms.month && s.weekStart.year == ms.year)
        .toList();
  }

  Widget _buildSemanaChips(NutritionState state) {
    final cs = Theme.of(context).colorScheme;
    final stat = _statAt(state.weeklyAdherence, _weekOffset);
    final pct = stat == null || stat.mealsExpected == 0
        ? null
        : (stat.adherencePct * 100).round();
    final logged = stat?.mealsLogged ?? 0;
    final offPlan = stat?.offPlanMeals ?? 0;
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
      children: [
        StatChip(value: pct == null ? '—' : '$pct%', label: 'Adherencia'),
        StatChip(value: '$logged', label: 'En plan'),
        StatChip(value: '$offPlan', label: 'Fuera plan', color: cs.error),
      ],
    );
  }

  Widget _buildMesChips(NutritionState state) {
    final cs = Theme.of(context).colorScheme;
    final weeks = _weeksInMonth(state.weeklyAdherence, _monthOffset);
    final totalLogged = weeks.fold(0, (s, w) => s + w.mealsLogged);
    final totalExpected = weeks.fold(0, (s, w) => s + w.mealsExpected);
    final totalOff = weeks.fold(0, (s, w) => s + w.offPlanMeals);
    final pct = totalExpected == 0
        ? null
        : (totalLogged / totalExpected * 100).round();
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
      children: [
        StatChip(value: pct == null ? '—' : '$pct%', label: 'Adherencia'),
        StatChip(value: '$totalLogged', label: 'En plan'),
        StatChip(value: '$totalOff', label: 'Fuera plan', color: cs.error),
      ],
    );
  }

  Widget _buildWeekNavigator(List<NutritionWeeklyStat> stats) {
    final monday = _weekMondayAt(_weekOffset);
    final sunday = monday.add(const Duration(days: 6));
    const months = [
      'ene','feb','mar','abr','may','jun',
      'jul','ago','sep','oct','nov','dic'
    ];
    final String label;
    if (monday.month == sunday.month) {
      label =
          '${monday.day} – ${sunday.day} ${months[monday.month - 1]} ${monday.year}';
    } else {
      label =
          '${monday.day} ${months[monday.month - 1]} – ${sunday.day} ${months[sunday.month - 1]} ${monday.year}';
    }
    final sub = _weekOffset == 0
        ? 'semana actual'
        : 'hace ${-_weekOffset} semana${-_weekOffset == 1 ? '' : 's'}';
    final canGoBack =
        stats.isNotEmpty && _weekOffset > -(stats.length - 1);
    return _Navigator(
      label: label,
      subtitle: sub,
      onBack: canGoBack ? () => setState(() => _weekOffset--) : null,
      onForward:
          _weekOffset < 0 ? () => setState(() => _weekOffset++) : null,
    );
  }

  Widget _buildMonthNavigator(List<NutritionWeeklyStat> stats) {
    final ms = _monthStartAt(_monthOffset);
    const months = [
      'Enero','Febrero','Marzo','Abril','Mayo','Junio',
      'Julio','Agosto','Septiembre','Octubre','Noviembre','Diciembre'
    ];
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
      onForward:
          _monthOffset < 0 ? () => setState(() => _monthOffset++) : null,
    );
  }

  Widget _buildWeekBarChart(List<NutritionWeeklyStat> stats) {
    if (stats.isEmpty) return const SizedBox.shrink();
    return _AdherenceBarChart(
      bars: stats.map((s) => (s.mealsLogged, s.mealsExpected)).toList(),
      barColor: Theme.of(context).colorScheme.primaryContainer,
      lastBarIsPartial: true,
    );
  }

  Widget _buildMonthBarChart(List<NutritionWeeklyStat> stats) {
    final weeks = _weeksInMonth(stats, _monthOffset);
    if (weeks.isEmpty) return const SizedBox.shrink();
    return _AdherenceBarChart(
      bars: weeks.map((s) => (s.mealsLogged, s.mealsExpected)).toList(),
      barColor: Theme.of(context).colorScheme.primaryContainer,
      lastBarIsPartial: _monthOffset == 0,
    );
  }
}

// ── Tab Frecuencia ────────────────────────────────────────────────────────────

class _FrecuenciaTab extends StatelessWidget {
  final List<OptionFrequencyStat> frequencies;
  const _FrecuenciaTab({required this.frequencies});

  @override
  Widget build(BuildContext context) {
    if (frequencies.isEmpty) {
      return Center(
        child: Text(
          'Sin registros de frecuencia',
          style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                color: Theme.of(context).colorScheme.onSurfaceVariant,
              ),
        ),
      );
    }

    final grouped = <String, List<OptionFrequencyStat>>{};
    for (final f in frequencies) {
      grouped.putIfAbsent(f.mealType, () => []).add(f);
    }

    return ListView(
      padding: const EdgeInsets.all(16),
      children: grouped.entries.map((entry) {
        final mealType = entry.key;
        final opts = entry.value;
        final maxCount =
            opts.map((o) => o.count).fold(0, (a, b) => a > b ? a : b);
        return Padding(
          padding: const EdgeInsets.only(bottom: 16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                mealType.toUpperCase(),
                style: Theme.of(context).textTheme.labelSmall?.copyWith(
                      color: Theme.of(context)
                          .colorScheme
                          .onSurfaceVariant,
                      fontWeight: FontWeight.w700,
                      letterSpacing: 0.5,
                    ),
              ),
              const SizedBox(height: 8),
              Container(
                decoration: BoxDecoration(
                  color: Theme.of(context).colorScheme.surfaceContainerHighest,
                  borderRadius: BorderRadius.circular(12),
                ),
                padding: const EdgeInsets.all(12),
                child: Column(
                  children: opts.map((opt) {
                    final frac = maxCount == 0
                        ? 0.0
                        : opt.count / maxCount;
                    return Padding(
                      padding: const EdgeInsets.only(bottom: 10),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            mainAxisAlignment:
                                MainAxisAlignment.spaceBetween,
                            children: [
                              Expanded(
                                child: Column(
                                  crossAxisAlignment:
                                      CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      'Opción ${opt.optionNumber}',
                                      style: Theme.of(context)
                                          .textTheme
                                          .labelSmall
                                          ?.copyWith(
                                            color: Theme.of(context)
                                                .colorScheme
                                                .onSurfaceVariant,
                                          ),
                                    ),
                                    Text(
                                      opt.description,
                                      style: Theme.of(context)
                                          .textTheme
                                          .bodySmall
                                          ?.copyWith(
                                            color: Theme.of(context)
                                                .colorScheme
                                                .onSurface,
                                          ),
                                    ),
                                  ],
                                ),
                              ),
                              const SizedBox(width: 8),
                              Text(
                                '${opt.count}×',
                                style: TextStyle(
                                    fontWeight: FontWeight.w700,
                                    fontSize: 13,
                                    color: Theme.of(context)
                                        .colorScheme
                                        .onSurface),
                              ),
                            ],
                          ),
                          const SizedBox(height: 4),
                          LinearProgressIndicator(
                            value: frac,
                            minHeight: 6,
                            borderRadius: BorderRadius.circular(3),
                            backgroundColor: Theme.of(context)
                                .colorScheme
                                .surfaceContainerHigh,
                          ),
                        ],
                      ),
                    );
                  }).toList(),
                ),
              ),
            ],
          ),
        );
      }).toList(),
    );
  }
}

// ── Sub-widgets reusables ──────────────────────────────────────────────────────

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
      IconButton(
          icon: const Icon(Icons.chevron_left), onPressed: onBack),
      Expanded(
        child: Column(children: [
          Text(label,
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    color: Theme.of(context).colorScheme.onSurface,
                  ),
              textAlign: TextAlign.center),
          Text(subtitle,
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color:
                        Theme.of(context).colorScheme.onSurfaceVariant,
                  ),
              textAlign: TextAlign.center),
        ]),
      ),
      IconButton(
          icon: const Icon(Icons.chevron_right), onPressed: onForward),
    ]);
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
              trackColor:
                  Theme.of(context).colorScheme.surfaceContainerHigh,
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
              style: Theme.of(context).textTheme.labelSmall?.copyWith(
                    color:
                        Theme.of(context).colorScheme.onSurfaceVariant,
                  ),
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
  final Color trackColor;
  final bool lastBarIsPartial;

  const _BarChartPainter({
    required this.bars,
    required this.barColor,
    required this.trackColor,
    required this.lastBarIsPartial,
  });

  @override
  bool shouldRepaint(_BarChartPainter old) =>
      old.lastBarIsPartial != lastBarIsPartial ||
      old.barColor != barColor ||
      old.trackColor != trackColor ||
      !listEquals(old.bars, bars);

  @override
  void paint(Canvas canvas, Size size) {
    if (bars.isEmpty) return;
    const gap = 4.0;
    final barW = (size.width - gap * (bars.length - 1)) / bars.length;
    final chartH = size.height;
    final goalPaint = Paint()
      ..color = barColor.withValues(alpha: 0.4)
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
          Paint()..color = trackColor,
        );
        continue;
      }
      final rect = Rect.fromLTWH(x, chartH - barH, barW, barH);
      if (isPartial) {
        canvas.drawRRect(
          RRect.fromRectAndCorners(rect,
              topLeft: const Radius.circular(3),
              topRight: const Radius.circular(3)),
          Paint()..color = barColor.withValues(alpha: 0.25),
        );
        _drawDashedRect(
            canvas,
            rect,
            Paint()
              ..color = barColor.withValues(alpha: 0.8)
              ..strokeWidth = 1
              ..style = PaintingStyle.stroke);
      } else {
        canvas.drawRRect(
          RRect.fromRectAndCorners(rect,
              topLeft: const Radius.circular(3),
              topRight: const Radius.circular(3)),
          Paint()..color = barColor.withValues(alpha: 0.85),
        );
      }
    }
  }

  void _drawDashedLine(
      Canvas canvas, Offset p1, Offset p2, Paint paint) {
    const dashLen = 4.0;
    const gapLen = 4.0;
    final dx = p2.dx - p1.dx;
    final dy = p2.dy - p1.dy;
    final dist = sqrt(dx * dx + dy * dy);
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
