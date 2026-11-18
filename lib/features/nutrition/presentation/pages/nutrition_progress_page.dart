import 'package:collection/collection.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:iconsax_plus/iconsax_plus.dart';
import 'package:intl/intl.dart';
import 'package:kiolog/core/database/app_database.dart';
import 'package:kiolog/core/theme/app_theme.dart';
import 'package:kiolog/features/nutrition/domain/models/nutrition_weekly_stat.dart';
import 'package:kiolog/features/nutrition/domain/models/option_frequency_stat.dart';
import 'package:kiolog/features/nutrition/presentation/pages/nutrition_config_page.dart';
import 'package:kiolog/shared/widgets/entrance.dart';
import 'package:kiolog/shared/widgets/meal_icons.dart';
import 'package:kiolog/shared/widgets/meal_photo.dart';
import 'package:kiolog/shared/widgets/progress_ring.dart';
import 'package:kiolog/shared/widgets/themed_page.dart';
import '../bloc/nutrition_bloc.dart';
import '../bloc/nutrition_event.dart';
import '../bloc/nutrition_state.dart';

const _settle = Cubic(.3, .9, .25, 1);

enum _View { compliance, favorites }

enum _Period { week, month }

class NutritionProgressPage extends StatefulWidget {
  const NutritionProgressPage({super.key});

  @override
  State<NutritionProgressPage> createState() => _NutritionProgressPageState();
}

class _NutritionProgressPageState extends State<NutritionProgressPage> {
  _View _view = _View.compliance;
  _Period _period = _Period.week;
  int _weekOffset = 0;
  int _monthOffset = 0;

  @override
  Widget build(BuildContext context) {
    return ThemedPage(
      child: BlocBuilder<NutritionBloc, NutritionState>(
        builder: (context, state) {
          final viewingActive = state.viewingPlanId == null || state.viewingPlanId == state.activePlan?.id;
          final view = viewingActive ? _view : _View.favorites;
          final items = <Widget>[
            const _Header(),
            _PlanCard(state: state),
            if (viewingActive)
              _Segmented<_View>(
                value: _view,
                options: const {_View.compliance: 'Cumplimiento', _View.favorites: 'Lo que más comes'},
                onChanged: (v) => setState(() => _view = v),
              ),
            if (view == _View.compliance) ...[
              _Segmented<_Period>(
                value: _period,
                options: const {_Period.week: 'Semana', _Period.month: 'Mes'},
                onChanged: (p) => setState(() => _period = p),
                small: true,
              ),
              _ComplianceCard(
                stats: state.weeklyAdherence,
                period: _period,
                weekOffset: _weekOffset,
                monthOffset: _monthOffset,
                onWeek: (o) => setState(() => _weekOffset = o),
                onMonth: (o) => setState(() => _monthOffset = o),
              ),
              _WeeksChart(stats: state.weeklyAdherence, selected: _period == _Period.week ? _weekOffset : null),
            ] else
              ..._favorites(state),
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

  List<Widget> _favorites(NutritionState state) {
    if (state.optionFrequencies.isEmpty) {
      return [
        const _EmptyCard(
          icon: IconsaxPlusLinear.chart_2,
          text: 'Todavía no hay comidas del plan registradas para ver tus favoritas.',
        ),
      ];
    }
    final options = {for (final list in state.planOptions.values) for (final o in list) o.id: o};
    final grouped = groupBy(state.optionFrequencies, (OptionFrequencyStat f) => f.mealType);
    return [
      for (final entry in grouped.entries)
        _FavoritesCard(mealType: entry.key, stats: entry.value, options: options),
    ];
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
              Text('Nutrición', style: theme.textTheme.displayMedium?.copyWith(fontSize: 26)),
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

class _EmptyCard extends StatelessWidget {
  const _EmptyCard({required this.icon, required this.text});

  final IconData icon;
  final String text;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return _Card(
      child: Row(
        children: [
          Icon(icon, color: theme.colorScheme.onSurfaceVariant),
          const SizedBox(width: 12),
          Expanded(child: Text(text, style: theme.textTheme.bodyMedium)),
        ],
      ),
    );
  }
}

/// Píldora con opciones: la elegida lleva el degradado del ícono.
class _Segmented<T> extends StatelessWidget {
  const _Segmented({required this.value, required this.options, required this.onChanged, this.small = false});

  final T value;
  final Map<T, String> options;
  final ValueChanged<T> onChanged;
  final bool small;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;
    return Container(
      padding: const EdgeInsets.all(4),
      decoration: ShapeDecoration(
        color: small ? cs.surfaceContainerHigh : cs.surfaceContainerLowest,
        shape: const StadiumBorder(),
        shadows: small ? null : [context.kc.shadow],
      ),
      child: Row(
        children: [
          for (final entry in options.entries)
            Expanded(
              child: GestureDetector(
                onTap: () => onChanged(entry.key),
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 250),
                  curve: Curves.easeOutCubic,
                  padding: EdgeInsets.symmetric(vertical: small ? 9 : 12),
                  decoration: ShapeDecoration(
                    gradient: entry.key == value ? context.kc.brandGradient : null,
                    shape: const StadiumBorder(),
                  ),
                  child: Text(
                    entry.value,
                    textAlign: TextAlign.center,
                    style: theme.textTheme.labelLarge?.copyWith(
                      fontWeight: FontWeight.w800,
                      color: entry.key == value ? Colors.white : cs.onSurfaceVariant,
                    ),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

// ── Plan que se mira ────────────────────────────────────────────────────────

String _planDates(MealPlan plan) {
  final f = DateFormat('d MMM yyyy', 'es');
  final start = plan.periodStart?.toLocal();
  final end = plan.periodEnd?.toLocal();
  if (start == null) return '';
  return end == null ? 'Desde el ${f.format(start)}' : '${f.format(start)} – ${f.format(end)}';
}

class _PlanCard extends StatelessWidget {
  const _PlanCard({required this.state});

  final NutritionState state;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;
    final kc = context.kc;
    final plan = state.viewingPlan ?? state.activePlan;
    return Material(
      color: cs.surfaceContainerLowest,
      borderRadius: BorderRadius.circular(24),
      child: InkWell(
        borderRadius: BorderRadius.circular(24),
        onTap: () {
          final bloc = context.read<NutritionBloc>();
          showModalBottomSheet<void>(
            context: context,
            showDragHandle: true,
            isScrollControlled: true,
            builder: (_) => BlocProvider.value(value: bloc, child: const _PlanSheet()),
          );
        },
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Row(
            children: [
              Container(
                width: 44,
                height: 44,
                alignment: Alignment.center,
                decoration: BoxDecoration(color: kc.foodWash, borderRadius: BorderRadius.circular(14)),
                child: Icon(IconsaxPlusBold.book_1, color: kc.foodInk, size: 22),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(plan?.name ?? 'Sin plan',
                        style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w800)),
                    if (plan != null)
                      Text(plan.isActive ? 'Plan activo · ${_planDates(plan)}' : _planDates(plan),
                          style: theme.textTheme.bodySmall),
                  ],
                ),
              ),
              Text('Cambiar', style: theme.textTheme.labelLarge?.copyWith(color: cs.primary)),
              Icon(IconsaxPlusLinear.arrow_down_1, size: 18, color: cs.primary),
            ],
          ),
        ),
      ),
    );
  }
}

class _PlanSheet extends StatelessWidget {
  const _PlanSheet();

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;
    final kc = context.kc;
    return BlocBuilder<NutritionBloc, NutritionState>(
      builder: (context, state) {
        final viewing = state.viewingPlanId ?? state.activePlan?.id;
        final plans = <MealPlan>[
          if (state.activePlan != null) state.activePlan!,
          ...state.allPlans.where((p) => p.id != state.activePlan?.id),
        ];
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(18, 0, 18, 16),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text('Ver el progreso de…', style: theme.textTheme.titleLarge),
                const SizedBox(height: 12),
                for (final plan in plans)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 8),
                    child: Material(
                      color: plan.id == viewing ? kc.foodWash : cs.surfaceContainerLow,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(18),
                        side: BorderSide(color: plan.id == viewing ? cs.primary : Colors.transparent, width: 1.5),
                      ),
                      child: InkWell(
                        borderRadius: BorderRadius.circular(18),
                        onTap: () {
                          context.read<NutritionBloc>().add(NutritionProgressPlanSelected(planId: plan.id));
                          Navigator.pop(context);
                        },
                        child: Padding(
                          padding: const EdgeInsets.all(14),
                          child: Row(
                            children: [
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(plan.name,
                                        style: theme.textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w800)),
                                    Text(_planDates(plan), style: theme.textTheme.bodySmall),
                                  ],
                                ),
                              ),
                              if (plan.isActive)
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                                  decoration: ShapeDecoration(gradient: kc.brandGradient, shape: const StadiumBorder()),
                                  child: Text('Activo',
                                      style: theme.textTheme.labelSmall?.copyWith(color: Colors.white, fontSize: 11)),
                                ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ),
                const SizedBox(height: 4),
                PillButton(
                  icon: IconsaxPlusLinear.add,
                  label: 'Nueva consulta: crear su plan',
                  color: cs.primary,
                  onTap: () {
                    final bloc = context.read<NutritionBloc>();
                    Navigator.pop(context);
                    Navigator.of(context).push(
                      MaterialPageRoute<void>(
                        builder: (_) => NutritionConfigPage(
                          onComplete: () => bloc.add(NutritionLoaded(date: DateTime.now())),
                        ),
                      ),
                    );
                  },
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}

// ── Cumplimiento ────────────────────────────────────────────────────────────

class _ComplianceCard extends StatelessWidget {
  const _ComplianceCard({
    required this.stats,
    required this.period,
    required this.weekOffset,
    required this.monthOffset,
    required this.onWeek,
    required this.onMonth,
  });

  final List<NutritionWeeklyStat> stats;
  final _Period period;
  final int weekOffset;
  final int monthOffset;
  final ValueChanged<int> onWeek;
  final ValueChanged<int> onMonth;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;
    final kc = context.kc;
    final now = DateTime.now();

    late final String label;
    late final String subtitle;
    late final List<NutritionWeeklyStat> weeks;
    VoidCallback? back;
    VoidCallback? forward;
    if (period == _Period.week) {
      final index = stats.length - 1 + weekOffset;
      weeks = index >= 0 && index < stats.length ? [stats[index]] : const [];
      final monday = DateTime(now.year, now.month, now.day).subtract(Duration(days: now.weekday - 1 - 7 * weekOffset));
      final sunday = monday.add(const Duration(days: 6));
      final f = DateFormat('d MMM', 'es');
      label = '${f.format(monday)} – ${f.format(sunday)}';
      subtitle = weekOffset == 0 ? 'Esta semana' : 'Hace ${-weekOffset} ${weekOffset == -1 ? 'semana' : 'semanas'}';
      back = index > 0 ? () => onWeek(weekOffset - 1) : null;
      forward = weekOffset < 0 ? () => onWeek(weekOffset + 1) : null;
    } else {
      final month = DateTime(now.year, now.month + monthOffset);
      weeks = stats.where((s) => s.weekStart.year == month.year && s.weekStart.month == month.month).toList();
      final m = DateFormat.yMMMM('es').format(month);
      label = m[0].toUpperCase() + m.substring(1);
      subtitle = monthOffset == 0 ? 'Este mes' : 'Hace ${-monthOffset} ${monthOffset == -1 ? 'mes' : 'meses'}';
      back = stats.any((s) => s.weekStart.isBefore(DateTime.utc(month.year, month.month))) ? () => onMonth(monthOffset - 1) : null;
      forward = monthOffset < 0 ? () => onMonth(monthOffset + 1) : null;
    }

    final fromPlan = weeks.fold(0, (s, w) => s + w.mealsLogged);
    final expected = weeks.fold(0, (s, w) => s + w.mealsExpected);
    final other = weeks.fold(0, (s, w) => s + w.offPlanMeals);
    final share = expected == 0 ? 0.0 : (fromPlan / expected).clamp(0.0, 1.0);

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
                  key: ValueKey('$period$weekOffset$monthOffset'),
                  tween: Tween(begin: 0, end: share),
                  duration: const Duration(milliseconds: 1000),
                  curve: _settle,
                  builder: (context, v, _) => CustomPaint(
                    painter: GradientRing(progress: v, gradient: kc.brandGradient, track: context.hc.ringTrack, width: 12),
                    child: Center(
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(expected == 0 ? '—' : '${(v * 100).round()}%',
                              style: theme.textTheme.displayMedium?.copyWith(fontSize: 26)),
                          Text('del plan', style: theme.textTheme.bodySmall),
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
                    _StatTile(icon: IconsaxPlusBold.tick_circle, color: cs.primary, value: '$fromPlan', label: 'del plan'),
                    const SizedBox(height: 10),
                    _StatTile(icon: IconsaxPlusBold.edit_2, color: kc.warning, value: '$other', label: 'fuera o no seguidas'),
                  ],
                ),
              ),
            ],
          ),
          if (expected > 0) ...[
            const SizedBox(height: 14),
            Text(
              'Esperadas: $expected comidas del plan en este periodo.',
              style: theme.textTheme.bodySmall,
              textAlign: TextAlign.center,
            ),
          ],
        ],
      ),
    );
  }
}

class _Round extends StatelessWidget {
  const _Round({required this.icon, required this.tooltip, required this.onTap, this.flip = false});

  final IconData icon;

  /// Voltea el ícono: la flecha izquierda de Iconsax no hace juego con la derecha.
  final bool flip;
  final String tooltip;
  final VoidCallback? onTap;

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

  final IconData icon;
  final Color color;
  final String value;
  final String label;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(color: color.withValues(alpha: 0.12), borderRadius: BorderRadius.circular(16)),
      child: Row(
        children: [
          Icon(icon, color: color, size: 20),
          const SizedBox(width: 8),
          Text(value, style: theme.textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w800)),
          const SizedBox(width: 6),
          Expanded(child: Text(label, style: theme.textTheme.bodySmall, maxLines: 2)),
        ],
      ),
    );
  }
}

/// Las últimas semanas: barra llena al 100 % del plan; la actual, a medias.
class _WeeksChart extends StatelessWidget {
  const _WeeksChart({required this.stats, required this.selected});

  final List<NutritionWeeklyStat> stats;

  /// La semana elegida (0 = la actual, -1 la anterior); null en vista de mes.
  final int? selected;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;
    final kc = context.kc;
    final hc = context.hc;
    if (stats.isEmpty) return const SizedBox.shrink();
    final f = DateFormat('d MMM', 'es');
    return _Card(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text('ÚLTIMAS ${stats.length} SEMANAS', style: theme.textTheme.labelSmall?.copyWith(fontSize: 11)),
          const SizedBox(height: 14),
          SizedBox(
            height: 130,
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                for (var i = 0; i < stats.length; i++) ...[
                  if (i > 0) const SizedBox(width: 8),
                  Expanded(
                    child: Builder(builder: (context) {
                      final s = stats[i];
                      final share = s.mealsExpected == 0 ? 0.0 : (s.mealsLogged / s.mealsExpected).clamp(0.0, 1.0);
                      final current = i == stats.length - 1;
                      final isSelected = selected != null && i == stats.length - 1 + selected!;
                      return Column(
                        mainAxisAlignment: MainAxisAlignment.end,
                        children: [
                          Text(
                            s.mealsExpected == 0 ? '' : '${(share * 100).round()}%',
                            style: theme.textTheme.labelSmall?.copyWith(
                              fontSize: 10,
                              color: isSelected ? cs.primary : cs.onSurfaceVariant,
                            ),
                          ),
                          const SizedBox(height: 4),
                          TweenAnimationBuilder<double>(
                            tween: Tween(begin: 0, end: share),
                            duration: Duration(milliseconds: 700 + i * 70),
                            curve: _settle,
                            builder: (context, v, _) => Container(
                              height: 6 + 94 * v,
                              decoration: BoxDecoration(
                                gradient: s.mealsExpected == 0
                                    ? null
                                    : LinearGradient(
                                        begin: Alignment.bottomCenter,
                                        end: Alignment.topCenter,
                                        colors: kc.brandGradient.colors
                                            .map((c) => current ? c.withValues(alpha: 0.55) : c)
                                            .toList(),
                                      ),
                                color: s.mealsExpected == 0 ? hc.ringTrack : null,
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
              Text(f.format(stats.first.weekStart.toLocal()), style: theme.textTheme.bodySmall),
              const Spacer(),
              Text('Esta semana', style: theme.textTheme.bodySmall?.copyWith(color: cs.primary)),
            ],
          ),
        ],
      ),
    );
  }
}

// ── Lo que más comes ────────────────────────────────────────────────────────

class _FavoritesCard extends StatelessWidget {
  const _FavoritesCard({required this.mealType, required this.stats, required this.options});

  final String mealType;
  final List<OptionFrequencyStat> stats;
  final Map<int, MealPlanOption> options;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;
    final kc = context.kc;
    final hc = context.hc;
    final sorted = [...stats]..sort((a, b) => b.count.compareTo(a.count));
    final max = sorted.first.count;
    final total = sorted.fold(0, (s, o) => s + o.count);
    final icon = MealIcon.resolve(options[sorted.first.planOptionId]?.mealIcon, mealType);
    return _Card(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Container(
                width: 40,
                height: 40,
                alignment: Alignment.center,
                decoration: BoxDecoration(color: kc.foodWash, borderRadius: BorderRadius.circular(13)),
                child: icon.build(color: kc.foodInk, size: 20),
              ),
              const SizedBox(width: 12),
              Expanded(child: Text(mealType, style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w800))),
              Text('$total ${total == 1 ? 'vez' : 'veces'}', style: theme.textTheme.bodySmall),
            ],
          ),
          for (var i = 0; i < sorted.length; i++)
            Builder(builder: (context) {
              final stat = sorted[i];
              final photoId = options[stat.planOptionId]?.photoId;
              return Padding(
                padding: const EdgeInsets.only(top: 12),
                child: Row(
                  children: [
                    if (photoId != null)
                      GestureDetector(
                        onTap: () => showMealPhoto(context, photoId: photoId, title: stat.description),
                        child: MealPhotoImage(photoId: photoId, width: 48, height: 48, radius: 14),
                      )
                    else
                      Container(
                        width: 48,
                        height: 48,
                        alignment: Alignment.center,
                        decoration: BoxDecoration(color: cs.surfaceContainerHigh, borderRadius: BorderRadius.circular(14)),
                        child: Text('${stat.optionNumber}',
                            style: theme.textTheme.titleMedium?.copyWith(color: cs.onSurfaceVariant)),
                      ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              if (i == 0)
                                Padding(
                                  padding: const EdgeInsets.only(right: 4),
                                  child: Icon(IconsaxPlusBold.crown_1, size: 14, color: kc.gold),
                                ),
                              Expanded(
                                child: Text(stat.description,
                                    maxLines: 2,
                                    overflow: TextOverflow.ellipsis,
                                    style: theme.textTheme.bodySmall?.copyWith(color: cs.onSurface)),
                              ),
                              const SizedBox(width: 8),
                              Text('${stat.count}×',
                                  style: theme.textTheme.labelLarge?.copyWith(fontWeight: FontWeight.w800)),
                            ],
                          ),
                          const SizedBox(height: 6),
                          ClipRRect(
                            borderRadius: BorderRadius.circular(5),
                            child: TweenAnimationBuilder<double>(
                              tween: Tween(begin: 0, end: max == 0 ? 0 : stat.count / max),
                              duration: Duration(milliseconds: 700 + i * 80),
                              curve: _settle,
                              builder: (context, v, _) => LinearProgressIndicator(
                                value: v,
                                minHeight: 6,
                                color: hc.foodOn,
                                backgroundColor: hc.ringTrack,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              );
            }),
        ],
      ),
    );
  }
}
