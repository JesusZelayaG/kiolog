import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:iconsax_plus/iconsax_plus.dart';
import 'package:intl/intl.dart';
import 'package:kiolog/core/di/injection.dart';
import 'package:kiolog/core/theme/app_theme.dart';
import 'package:kiolog/features/reports/domain/repositories/report_repository.dart';
import 'package:kiolog/shared/widgets/entrance.dart';
import 'package:kiolog/shared/widgets/kiolog_glyphs.dart';
import 'package:kiolog/shared/widgets/progress_ring.dart';
import 'package:kiolog/shared/widgets/themed_page.dart';

import '../../domain/month_overview.dart';
import '../bloc/history_cubit.dart';

const _settle = Cubic(.3, .9, .25, 1);

class HistoryPage extends StatelessWidget {
  const HistoryPage({super.key});

  @override
  Widget build(BuildContext context) {
    return BlocProvider(
      create: (_) => HistoryCubit(getIt<ReportRepository>())..load(),
      child: const _HistoryView(),
    );
  }
}

class _HistoryView extends StatelessWidget {
  const _HistoryView();

  @override
  Widget build(BuildContext context) {
    return ThemedPage(
      child: BlocBuilder<HistoryCubit, HistoryState>(
        builder: (context, state) {
          final overview = state.overview;
          final items = <Widget>[
            const _Header(),
            if (state.error != null)
              Text('Error: ${state.error}')
            else if (overview == null)
              const Padding(
                padding: EdgeInsets.only(top: 80),
                child: Center(child: CircularProgressIndicator()),
              )
            else ...[
              _MonthCard(state: state, overview: overview),
              _CalendarCard(overview: overview),
              const _Legend(),
            ],
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
            onTap: () => context.canPop() ? context.pop() : context.go('/'),
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
              Text('HISTORIAL', style: theme.textTheme.labelSmall?.copyWith(fontSize: 11, color: cs.primary)),
              Text('Tu mes', style: theme.textTheme.displayMedium?.copyWith(fontSize: 26)),
            ],
          ),
        ),
      ],
    );
  }
}

// ── Resumen del mes ─────────────────────────────────────────────────────────

class _MonthCard extends StatelessWidget {
  const _MonthCard({required this.state, required this.overview});

  final HistoryState state;
  final MonthOverview overview;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;
    final kc = context.kc;
    final hc = context.hc;
    final cubit = context.read<HistoryCubit>();
    final now = DateTime.now();
    final isCurrent = state.month.year == now.year && state.month.month == now.month;
    final label = DateFormat.yMMMM('es').format(state.month);

    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: cs.surfaceContainerLowest,
        borderRadius: BorderRadius.circular(28),
        boxShadow: [kc.shadow],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              _RoundButton(icon: IconsaxPlusLinear.arrow_right_3, flip: true, tooltip: 'Mes anterior', onTap: cubit.previous),
              Expanded(
                child: Text(
                  label[0].toUpperCase() + label.substring(1),
                  textAlign: TextAlign.center,
                  style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w800),
                ),
              ),
              _RoundButton(
                icon: IconsaxPlusLinear.arrow_right_3,
                tooltip: 'Mes siguiente',
                onTap: isCurrent ? null : cubit.next,
              ),
            ],
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              SizedBox(
                width: 116,
                height: 116,
                child: TweenAnimationBuilder<double>(
                  tween: Tween(begin: 0, end: overview.percent / 100),
                  duration: const Duration(milliseconds: 1200),
                  curve: _settle,
                  builder: (context, v, _) => CustomPaint(
                    painter: GradientRing(progress: v, gradient: kc.brandGradient, track: hc.ringTrack, width: 12),
                    child: Center(
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text('${(v * 100).round()}%',
                              style: theme.textTheme.displayMedium?.copyWith(fontSize: 26)),
                          Text('del mes', style: theme.textTheme.bodySmall),
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
                    _Stat(
                      icon: IconsaxPlusBold.flash,
                      color: kc.warning,
                      value: '${overview.streak}',
                      label: overview.streak == 1 ? 'día seguido' : 'días seguidos',
                    ),
                    const SizedBox(height: 10),
                    _Stat(
                      icon: IconsaxPlusBold.tick_circle,
                      color: cs.primary,
                      value: '${overview.strongDays}',
                      label: '${overview.strongDays == 1 ? 'día' : 'días'} al ${(MonthOverview.strongDay * 100).round()} %',
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 18),
          _AreaBar(
            icon: Icon(IconsaxPlusBold.drop, size: 18, color: kc.waterInk),
            wash: kc.waterWash,
            label: 'Meta de agua',
            value: overview.water,
            color: kc.waterInk,
          ),
          _AreaBar(
            icon: KiologGlyph(KiologGlyphKind.bowl, size: 18, color: kc.foodInk),
            wash: kc.foodWash,
            label: 'Comidas del plan',
            value: overview.meals,
            color: kc.foodInk,
          ),
          _AreaBar(
            icon: Icon(IconsaxPlusBold.moon, size: 18, color: kc.sleepInk),
            wash: kc.sleepWash,
            label: 'Sueño registrado',
            value: overview.sleep,
            color: kc.sleepInk,
          ),
          _AreaBar(
            icon: KiologGlyph(KiologGlyphKind.dumbbell, size: 18, color: kc.gymInk),
            wash: kc.gymWash,
            label: 'Rutina semanal',
            value: overview.exercise,
            color: kc.gymInk,
          ),
        ],
      ),
    );
  }
}

class _RoundButton extends StatelessWidget {
  const _RoundButton({required this.icon, required this.tooltip, required this.onTap, this.flip = false});

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

class _Stat extends StatelessWidget {
  const _Stat({required this.icon, required this.color, required this.value, required this.label});

  final IconData icon;
  final Color color;
  final String value;
  final String label;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(16),
      ),
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

class _AreaBar extends StatelessWidget {
  const _AreaBar({
    required this.icon,
    required this.wash,
    required this.label,
    required this.value,
    required this.color,
  });

  final Widget icon;
  final Color wash;
  final String label;
  final double value;
  final Color color;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.only(top: 10),
      child: Row(
        children: [
          Container(
            width: 34,
            height: 34,
            alignment: Alignment.center,
            decoration: BoxDecoration(color: wash, borderRadius: BorderRadius.circular(11)),
            child: icon,
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(child: Text(label, style: theme.textTheme.bodyMedium?.copyWith(fontWeight: FontWeight.w600))),
                    Text('${(value * 100).round()}%',
                        style: theme.textTheme.labelLarge?.copyWith(color: color, fontWeight: FontWeight.w800)),
                  ],
                ),
                const SizedBox(height: 5),
                ClipRRect(
                  borderRadius: BorderRadius.circular(6),
                  child: TweenAnimationBuilder<double>(
                    tween: Tween(begin: 0, end: value),
                    duration: const Duration(milliseconds: 900),
                    curve: _settle,
                    builder: (context, v, _) => LinearProgressIndicator(
                      value: v,
                      minHeight: 7,
                      color: color,
                      backgroundColor: context.hc.ringTrack,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// ── Calendario ──────────────────────────────────────────────────────────────

class _CalendarCard extends StatelessWidget {
  const _CalendarCard({required this.overview});

  final MonthOverview overview;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;
    final cubit = context.read<HistoryCubit>();
    final leading = overview.days.first.date.weekday - 1;
    const weekdays = ['L', 'M', 'X', 'J', 'V', 'S', 'D'];
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);

    return GestureDetector(
      // Deslizar cambia de mes.
      onHorizontalDragEnd: (details) {
        final v = details.primaryVelocity ?? 0;
        if (v > 300) cubit.previous();
        if (v < -300 && overview.month.isBefore(DateTime(now.year, now.month))) cubit.next();
      },
      child: Container(
        padding: const EdgeInsets.fromLTRB(12, 16, 12, 12),
        decoration: BoxDecoration(
          color: cs.surfaceContainerLowest,
          borderRadius: BorderRadius.circular(28),
          boxShadow: [context.kc.shadow],
        ),
        child: Column(
          children: [
            Row(
              children: [
                for (final d in weekdays)
                  Expanded(
                    child: Center(
                      child: Text(d, style: theme.textTheme.labelMedium?.copyWith(color: cs.onSurfaceVariant)),
                    ),
                  ),
              ],
            ),
            const SizedBox(height: 8),
            AnimatedSwitcher(
              duration: const Duration(milliseconds: 300),
              transitionBuilder: (child, animation) => FadeTransition(
                opacity: animation,
                child: SlideTransition(
                  position: Tween(begin: const Offset(0, 0.04), end: Offset.zero).animate(animation),
                  child: child,
                ),
              ),
              child: GridView.count(
                key: ValueKey(overview.month),
                crossAxisCount: 7,
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                childAspectRatio: 0.82,
                children: [
                  for (var i = 0; i < leading; i++) const SizedBox.shrink(),
                  for (final day in overview.days) _DayCell(day: day, isToday: day.date == today),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _DayCell extends StatelessWidget {
  const _DayCell({required this.day, required this.isToday});

  final DayScore day;
  final bool isToday;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;
    final kc = context.kc;
    final hc = context.hc;
    final score = day.score;
    final strong = (score ?? 0) >= MonthOverview.strongDay;

    final number = Text(
      '${day.date.day}',
      style: theme.textTheme.labelLarge?.copyWith(
        fontWeight: FontWeight.w800,
        color: isToday
            ? Colors.white
            : day.future
                ? cs.outline
                : cs.onSurface,
      ),
    );

    return InkWell(
      borderRadius: BorderRadius.circular(14),
      onTap: day.future ? null : () => context.push('/history/day/${DateFormat('yyyy-MM-dd').format(day.date)}'),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          SizedBox(
            width: 38,
            height: 38,
            child: TweenAnimationBuilder<double>(
              tween: Tween(begin: 0, end: score ?? 0),
              duration: Duration(milliseconds: 600 + day.date.day * 15),
              curve: _settle,
              builder: (context, v, child) => CustomPaint(
                painter: day.future
                    ? null
                    : GradientRing(
                        progress: v,
                        gradient: strong ? kc.brandGradient : LinearGradient(colors: [hc.rings[0], hc.rings[0]]),
                        track: hc.ringTrack,
                        width: 3.5,
                      ),
                child: child,
              ),
              child: Center(
                child: isToday
                    ? Container(
                        width: 28,
                        height: 28,
                        alignment: Alignment.center,
                        decoration: BoxDecoration(gradient: kc.brandGradient, shape: BoxShape.circle),
                        child: number,
                      )
                    : number,
              ),
            ),
          ),
          const SizedBox(height: 4),
          SizedBox(
            height: 5,
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                if (day.water) _Dot(kc.waterInk),
                if (day.meals) _Dot(kc.foodAccent),
                if (day.sleep) _Dot(kc.sleepInk),
                if (day.exercise) _Dot(kc.gymInk),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _Dot extends StatelessWidget {
  const _Dot(this.color);

  final Color color;

  @override
  Widget build(BuildContext context) => Container(
        width: 5,
        height: 5,
        margin: const EdgeInsets.symmetric(horizontal: 1),
        decoration: BoxDecoration(color: color, shape: BoxShape.circle),
      );
}

class _Legend extends StatelessWidget {
  const _Legend();

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final kc = context.kc;
    Widget item(Color color, String label) => Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(width: 8, height: 8, decoration: BoxDecoration(color: color, shape: BoxShape.circle)),
            const SizedBox(width: 6),
            Text(label, style: theme.textTheme.bodySmall),
          ],
        );
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 6),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Wrap(
            spacing: 14,
            runSpacing: 6,
            children: [
              item(kc.waterInk, 'Meta de agua'),
              item(kc.foodAccent, 'Todas las comidas del plan'),
              item(kc.sleepInk, 'Sueño'),
              item(kc.gymInk, 'Ejercicio'),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            'El anillo de cada día se llena con las comidas del plan, el agua, el sueño y el peso; '
            'en verde con degradado, el día llegó al ${(MonthOverview.strongDay * 100).round()} %. '
            'Toca un día para ver el detalle.',
            style: theme.textTheme.bodySmall,
          ),
        ],
      ),
    );
  }
}
