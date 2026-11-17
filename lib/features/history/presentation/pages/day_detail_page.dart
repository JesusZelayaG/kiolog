import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:iconsax_plus/iconsax_plus.dart';
import 'package:intl/intl.dart';
import 'package:kiolog/core/database/app_database.dart';
import 'package:kiolog/core/theme/app_theme.dart';
import 'package:kiolog/features/history/domain/month_overview.dart';
import 'package:kiolog/features/reports/domain/repositories/report_repository.dart';
import 'package:kiolog/shared/widgets/entrance.dart';
import 'package:kiolog/shared/widgets/kiolog_glyphs.dart';
import 'package:kiolog/shared/widgets/meal_icons.dart';
import 'package:kiolog/shared/widgets/meal_photo.dart';
import 'package:kiolog/shared/widgets/progress_ring.dart';
import 'package:kiolog/shared/widgets/themed_page.dart';
import '../../../../core/dao/exercise_dao.dart';
import '../../../../core/dao/nutrition_dao.dart';
import '../../../../core/dao/water_sleep_dao.dart';
import '../../../../core/di/injection.dart';
import '../bloc/day_detail_bloc.dart';
import '../bloc/day_detail_event.dart';
import '../bloc/day_detail_state.dart';

class DayDetailPage extends StatelessWidget {
  final DateTime date;

  const DayDetailPage({super.key, required this.date});

  @override
  Widget build(BuildContext context) {
    return BlocProvider(
      create: (_) => DayDetailBloc(
        getIt<WaterSleepDao>(),
        getIt<NutritionDao>(),
        getIt<ExerciseDao>(),
        reports: getIt<ReportRepository>(),
      )..add(DayDetailLoaded(date: date)),
      child: _DayDetailView(date: date),
    );
  }
}

class _DayDetailView extends StatelessWidget {
  final DateTime date;

  const _DayDetailView({required this.date});

  @override
  Widget build(BuildContext context) {
    return ThemedPage(
      child: BlocBuilder<DayDetailBloc, DayDetailState>(
        builder: (context, state) {
          final ready = state.status == DayDetailStatus.success;
          final items = <Widget>[
            _Header(date: date),
            if (state.status == DayDetailStatus.failure)
              Text('Error: ${state.error}')
            else if (!ready)
              const Padding(
                padding: EdgeInsets.only(top: 80),
                child: Center(child: CircularProgressIndicator()),
              )
            else ...[
              _ScoreCard(state: state),
              _WaterCard(state: state),
              _MealsCard(state: state),
              _ExerciseCard(state: state),
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
  const _Header({required this.date});

  final DateTime date;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;
    final title = DateFormat("EEEE d 'de' MMMM", 'es').format(date);
    return Row(
      children: [
        Material(
          color: cs.surfaceContainerLowest,
          borderRadius: BorderRadius.circular(16),
          child: InkWell(
            borderRadius: BorderRadius.circular(16),
            onTap: () => context.canPop() ? context.pop() : context.go('/history'),
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
              Text('DETALLE DEL DÍA', style: theme.textTheme.labelSmall?.copyWith(fontSize: 11, color: cs.primary)),
              Text(
                title[0].toUpperCase() + title.substring(1),
                style: theme.textTheme.displayMedium?.copyWith(fontSize: 23, height: 1.15),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

/// Una tarjeta redondeada con la sombra del tema.
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

/// Ícono, título y etiqueta de estado de una tarjeta.
class _CardTitle extends StatelessWidget {
  const _CardTitle({required this.icon, required this.wash, required this.title, this.status, this.met = false});

  final Widget icon;
  final Color wash;
  final String title;
  final String? status;
  final bool met;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;
    final color = met ? cs.primary : cs.onSurfaceVariant;
    return Row(
      children: [
        Container(
          width: 40,
          height: 40,
          alignment: Alignment.center,
          decoration: BoxDecoration(color: wash, borderRadius: BorderRadius.circular(13)),
          child: icon,
        ),
        const SizedBox(width: 12),
        Expanded(child: Text(title, style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w800))),
        if (status != null)
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
            decoration: ShapeDecoration(
              color: met ? cs.primary.withValues(alpha: 0.14) : cs.surfaceContainerHigh,
              shape: const StadiumBorder(),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                if (met) ...[
                  Icon(IconsaxPlusBold.tick_circle, size: 14, color: color),
                  const SizedBox(width: 4),
                ],
                Text(status!, style: theme.textTheme.labelMedium?.copyWith(color: color, fontWeight: FontWeight.w800)),
              ],
            ),
          ),
      ],
    );
  }
}

// ── Cumplimiento del día ────────────────────────────────────────────────────

class _ScoreCard extends StatelessWidget {
  const _ScoreCard({required this.state});

  final DayDetailState state;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final kc = context.kc;
    final hc = context.hc;
    final goals = state.goals;
    final day = state.summary ?? ReportDay(date: state.date);
    final score = dayScore(day, goals);
    final planMeals = day.mealsFromPlan.clamp(0, goals.mealsPerDay);

    final checks = [
      (IconsaxPlusBold.drop, 'Agua', '${day.waterMl} / ${goals.waterMl} ml', day.waterMl >= goals.waterMl),
      (null, 'Comidas del plan', '$planMeals / ${goals.mealsPerDay}', planMeals >= goals.mealsPerDay),
      (IconsaxPlusBold.moon, 'Sueño', day.sleepHours == null ? 'Sin registro' : '${day.sleepHours!.toStringAsFixed(1)} h',
          day.sleepHours != null),
      (IconsaxPlusBold.weight, 'Peso', day.weightKg == null ? 'Sin registro' : '${day.weightKg!.toStringAsFixed(1)} kg',
          day.weightKg != null),
      (IconsaxPlusBold.flash, 'Ejercicio', day.exercised ? 'Hecho' : 'Descanso', day.exercised),
      (IconsaxPlusBold.activity, 'Cardio', day.cardioMinutes > 0 ? '${day.cardioMinutes} min' : 'Sin cardio',
          day.cardioMinutes >= goals.cardioMinutes),
    ];

    return _Card(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              SizedBox(
                width: 104,
                height: 104,
                child: TweenAnimationBuilder<double>(
                  tween: Tween(begin: 0, end: score),
                  duration: const Duration(milliseconds: 1100),
                  curve: const Cubic(.3, .9, .25, 1),
                  builder: (context, v, _) => CustomPaint(
                    painter: GradientRing(progress: v, gradient: kc.brandGradient, track: hc.ringTrack, width: 11),
                    child: Center(
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text('${(v * 100).round()}%', style: theme.textTheme.displayMedium?.copyWith(fontSize: 24)),
                          Text('del día', style: theme.textTheme.bodySmall),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Text(
                  score >= MonthOverview.strongDay
                      ? 'Buen día: llegaste a la meta del ${(MonthOverview.strongDay * 100).round()} %.'
                      : 'Cuenta las comidas del plan, el agua, el sueño y el peso. La rutina y el cardio suman extra.',
                  style: theme.textTheme.bodyMedium?.copyWith(color: theme.colorScheme.onSurfaceVariant),
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          for (final (icon, label, value, met) in checks)
            Padding(
              padding: const EdgeInsets.only(top: 8),
              child: Row(
                children: [
                  SizedBox(
                    width: 22,
                    child: icon == null
                        ? KiologGlyph(KiologGlyphKind.bowl, size: 18, color: theme.colorScheme.onSurfaceVariant)
                        : Icon(icon, size: 18, color: theme.colorScheme.onSurfaceVariant),
                  ),
                  const SizedBox(width: 10),
                  Expanded(child: Text(label, style: theme.textTheme.bodyMedium?.copyWith(fontWeight: FontWeight.w600))),
                  Text(value,
                      style: theme.textTheme.bodyMedium?.copyWith(
                        fontWeight: FontWeight.w700,
                        color: met ? theme.colorScheme.primary : theme.colorScheme.onSurfaceVariant,
                      )),
                  const SizedBox(width: 8),
                  Icon(
                    met ? IconsaxPlusBold.tick_circle : IconsaxPlusLinear.minus_cirlce,
                    size: 18,
                    color: met ? theme.colorScheme.primary : theme.colorScheme.outline,
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }
}

// ── Agua ────────────────────────────────────────────────────────────────────

class _WaterCard extends StatelessWidget {
  const _WaterCard({required this.state});

  final DayDetailState state;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final kc = context.kc;
    final goal = state.goals.waterMl;
    final total = state.totalWaterMl;
    final met = total >= goal;
    return _Card(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _CardTitle(
            icon: Icon(IconsaxPlusBold.drop, size: 20, color: kc.waterInk),
            wash: kc.waterWash,
            title: 'Agua',
            status: met ? 'Meta cumplida' : '${goal > 0 ? (total * 100 / goal).round() : 0} %',
            met: met,
          ),
          const SizedBox(height: 14),
          Row(
            crossAxisAlignment: CrossAxisAlignment.baseline,
            textBaseline: TextBaseline.alphabetic,
            children: [
              Text('$total', style: theme.textTheme.displayMedium?.copyWith(fontSize: 28, color: kc.waterInk)),
              const SizedBox(width: 6),
              Text('/ $goal ml', style: theme.textTheme.bodyMedium?.copyWith(color: theme.colorScheme.onSurfaceVariant)),
            ],
          ),
          const SizedBox(height: 8),
          ClipRRect(
            borderRadius: BorderRadius.circular(6),
            child: TweenAnimationBuilder<double>(
              tween: Tween(begin: 0, end: goal > 0 ? (total / goal).clamp(0.0, 1.0) : 0),
              duration: const Duration(milliseconds: 900),
              curve: const Cubic(.3, .9, .25, 1),
              builder: (context, v, _) =>
                  LinearProgressIndicator(value: v, minHeight: 8, color: kc.waterInk, backgroundColor: context.hc.ringTrack),
            ),
          ),
          const SizedBox(height: 12),
          if (state.waterLogs.isEmpty)
            Text('No hay tomas registradas', style: theme.textTheme.bodySmall)
          else
            Wrap(
              spacing: 6,
              runSpacing: 6,
              children: [
                for (final log in state.waterLogs)
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                    decoration: ShapeDecoration(color: kc.waterWash, shape: const StadiumBorder()),
                    child: Text(
                      '${DateFormat('HH:mm').format(log.timestamp.toLocal())} · ${log.amountMl} ml',
                      style: theme.textTheme.labelMedium?.copyWith(color: kc.waterInk),
                    ),
                  ),
              ],
            ),
        ],
      ),
    );
  }
}

// ── Comidas ─────────────────────────────────────────────────────────────────

class _MealsCard extends StatelessWidget {
  const _MealsCard({required this.state});

  final DayDetailState state;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final kc = context.kc;
    final goal = state.goals.mealsPerDay;
    final fromPlan = state.mealLogs.where((l) => l.planOptionId != null).length;
    return _Card(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _CardTitle(
            icon: KiologGlyph(KiologGlyphKind.bowl, size: 20, color: kc.foodInk),
            wash: kc.foodWash,
            title: 'Comidas',
            status: '$fromPlan / $goal del plan',
            met: fromPlan >= goal,
          ),
          const SizedBox(height: 6),
          if (state.mealLogs.isEmpty)
            Padding(
              padding: const EdgeInsets.only(top: 8),
              child: Text('No hay comidas registradas', style: theme.textTheme.bodySmall),
            )
          else
            for (final log in state.mealLogs) _MealRow(log: log, option: state.mealOptions[log.planOptionId]),
        ],
      ),
    );
  }
}

class _MealRow extends StatelessWidget {
  const _MealRow({required this.log, required this.option});

  final DailyMealLog log;
  final MealPlanOption? option;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;
    final kc = context.kc;
    final (text, label, color) = switch (log) {
      _ when log.planOptionId != null => (option?.description ?? 'Opción del plan', 'Del plan', cs.primary),
      _ when log.freeDescription != null => (log.freeDescription!, 'Fuera de plan', kc.warning),
      _ => ('No seguí el plan', 'No seguido', cs.error),
    };
    final photoId = log.photoId;
    return Padding(
      padding: const EdgeInsets.only(top: 10),
      child: Container(
        padding: const EdgeInsets.all(10),
        decoration: BoxDecoration(color: cs.surfaceContainerLow, borderRadius: BorderRadius.circular(20)),
        child: Row(
          children: [
            Container(
              width: 40,
              height: 40,
              alignment: Alignment.center,
              decoration: BoxDecoration(color: kc.foodWash, borderRadius: BorderRadius.circular(13)),
              child: MealIcon.resolve(option?.mealIcon, log.mealType).build(color: kc.foodInk, size: 20),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Flexible(
                        child: Text(log.mealType,
                            style: theme.textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w800),
                            overflow: TextOverflow.ellipsis),
                      ),
                      const SizedBox(width: 6),
                      Text(label, style: theme.textTheme.labelSmall?.copyWith(color: color, fontSize: 10)),
                    ],
                  ),
                  const SizedBox(height: 2),
                  Text(text, style: theme.textTheme.bodySmall?.copyWith(color: cs.onSurface)),
                ],
              ),
            ),
            if (photoId != null) ...[
              const SizedBox(width: 10),
              GestureDetector(
                onTap: () => showMealPhoto(context, photoId: photoId, title: log.mealType),
                child: MealPhotoImage(photoId: photoId, width: 56, height: 56),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

// ── Ejercicio ───────────────────────────────────────────────────────────────

class _ExerciseCard extends StatelessWidget {
  const _ExerciseCard({required this.state});

  final DayDetailState state;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;
    final kc = context.kc;
    final time = DateFormat('HH:mm');
    final sessions = state.exerciseSessions;
    return _Card(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _CardTitle(
            icon: KiologGlyph(KiologGlyphKind.dumbbell, size: 20, color: kc.gymInk),
            wash: kc.gymWash,
            title: 'Ejercicio',
            status: state.hasExercise ? 'Hecho' : 'Descanso',
            met: state.hasExercise,
          ),
          const SizedBox(height: 6),
          if (sessions.isEmpty && !(state.exerciseLog?.completed ?? false))
            Padding(
              padding: const EdgeInsets.only(top: 8),
              child: Text('Sin ejercicio registrado', style: theme.textTheme.bodySmall),
            ),
          if (sessions.isEmpty && (state.exerciseLog?.completed ?? false))
            Padding(
              padding: const EdgeInsets.only(top: 8),
              child: Text('Rutina marcada como hecha', style: theme.textTheme.bodyMedium),
            ),
          for (var i = 0; i < sessions.length; i++)
            Builder(builder: (context) {
              final s = sessions[i];
              final start = s.gymArrivedAt.toLocal();
              final end = s.gymLeftAt?.toLocal();
              final minutes = end?.difference(start).inMinutes;
              return Padding(
                padding: const EdgeInsets.only(top: 10),
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                  decoration: BoxDecoration(color: cs.surfaceContainerLow, borderRadius: BorderRadius.circular(18)),
                  child: Row(
                    children: [
                      Icon(IconsaxPlusLinear.timer_1, size: 18, color: kc.gymInk),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Text(
                          s.routineId == null ? 'Ejercicio libre ${i + 1}' : 'Sesión ${i + 1}',
                          style: theme.textTheme.bodyMedium?.copyWith(fontWeight: FontWeight.w600),
                        ),
                      ),
                      Text(
                        end == null
                            ? 'Desde ${time.format(start)}'
                            : '${time.format(start)} – ${time.format(end)}${minutes != null ? ' · $minutes min' : ''}',
                        style: theme.textTheme.labelLarge?.copyWith(color: kc.gymInk),
                      ),
                    ],
                  ),
                ),
              );
            }),
        ],
      ),
    );
  }
}
