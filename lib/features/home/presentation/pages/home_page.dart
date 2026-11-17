import 'package:flutter/material.dart';
import 'package:iconsax_plus/iconsax_plus.dart';
import 'package:kiolog/features/progress/presentation/widgets/next_consultation_card.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import '../../../../core/di/injection.dart';
import '../../../../features/exercise/domain/repositories/exercise_repository.dart';
import '../../../../features/nutrition/domain/repositories/nutrition_repository.dart';
import '../../../../features/sleep/domain/repositories/sleep_repository.dart';
import '../../../../features/water/domain/repositories/water_repository.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../shared/widgets/kiolog_app_bar.dart';
import '../../../../shared/widgets/vitality_card.dart';
import '../bloc/home_bloc.dart';
import '../bloc/home_event.dart';
import '../bloc/home_state.dart';

double calcOverallProgress(HomeState s) {
  final values = [
    s.waterProgress,
    s.sleepHours != null ? (s.sleepHours! / 8).clamp(0.0, 1.0) : 0.0,
    s.totalMeals > 0 ? s.mealsLogged / s.totalMeals : 0.0,
    s.exerciseRoutineDone ? 1.0 : (s.hasGymSession ? 0.5 : 0.0),
  ];
  return values.reduce((a, b) => a + b) / values.length;
}

class HomePage extends StatelessWidget {
  const HomePage({super.key});

  @override
  Widget build(BuildContext context) {
    return BlocProvider(
      create: (_) => HomeBloc(
        waterRepository: getIt<WaterRepository>(),
        sleepRepository: getIt<SleepRepository>(),
        nutritionRepository: getIt<NutritionRepository>(),
        exerciseRepository: getIt<ExerciseRepository>(),
      )..add(HomeLoaded(date: DateTime.now())),
      child: const _HomeView(),
    );
  }
}

const _waterSegments = 6;

/// Abre una pantalla encima del Home y recarga el resumen al volver,
/// para que el agua o el sueño recién registrados aparezcan.
Future<void> _openAndReload(BuildContext context, String route) async {
  final bloc = context.read<HomeBloc>();
  await context.push(route);
  bloc.add(HomeLoaded(date: DateTime.now()));
}

class _HomeView extends StatelessWidget {
  const _HomeView();

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: const KiologAppBar(title: 'Inicio'),
      body: BlocBuilder<HomeBloc, HomeState>(
        builder: (context, state) {
          if (state.status == HomeStatus.loading) {
            return const Center(child: CircularProgressIndicator());
          }
          if (state.status == HomeStatus.failure) {
            return Center(child: Text('Error: ${state.error}'));
          }
          return ListView(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
            children: [
              _Summary(overall: calcOverallProgress(state)),
              const SizedBox(height: 24),
              const NextConsultationCard(
                hideWhenEmpty: true,
                margin: EdgeInsets.only(bottom: 16),
              ),
              _WaterCard(state: state),
              const SizedBox(height: 16),
              IntrinsicHeight(
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Expanded(child: _SleepCard(hours: state.sleepHours)),
                    const SizedBox(width: 12),
                    Expanded(child: _NutritionCard(state: state)),
                  ],
                ),
              ),
              const SizedBox(height: 16),
              _ExerciseCard(state: state),
              const SizedBox(height: 24),
              const _QuoteCard(),
            ],
          );
        },
      ),
    );
  }
}

class _Summary extends StatelessWidget {
  const _Summary({required this.overall});

  final double overall;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    '¡HOLA DE NUEVO!',
                    style: theme.textTheme.labelMedium?.copyWith(color: cs.primary),
                  ),
                  const SizedBox(height: 2),
                  Text('Resumen de hoy', style: theme.textTheme.displayMedium),
                ],
              ),
            ),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              decoration: const ShapeDecoration(
                color: Tropical.mintWash,
                shape: StadiumBorder(),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(IconsaxPlusBold.verify, size: 18, color: cs.primary),
                  const SizedBox(width: 6),
                  Text(
                    '${(overall * 100).round()}% Meta',
                    style: theme.textTheme.labelMedium?.copyWith(color: cs.primary),
                  ),
                ],
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        ClipRRect(
          borderRadius: BorderRadius.circular(100),
          child: SizedBox(
            height: 10,
            child: Stack(
              children: [
                Positioned.fill(child: ColoredBox(color: cs.surfaceContainerHighest)),
                FractionallySizedBox(
                  widthFactor: overall.clamp(0.0, 1.0),
                  child: const DecoratedBox(
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        colors: [Color(0xFF88D5BD), Color(0xFF076450), Tropical.guava],
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

class _RoundIcon extends StatelessWidget {
  const _RoundIcon({
    required this.icon,
    required this.background,
    required this.color,
    this.size = 56,
  });

  final IconData icon;
  final Color background;
  final Color color;
  final double size;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(color: background, shape: BoxShape.circle),
      child: Icon(icon, color: color, size: size * 0.5),
    );
  }
}

class _WaterCard extends StatelessWidget {
  const _WaterCard({required this.state});

  final HomeState state;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;
    final filled = (state.waterProgress.clamp(0.0, 1.0) * _waterSegments).round();
    return VitalityCard(
      onTap: () => _openAndReload(context, '/water'),
      child: Column(
        children: [
          Row(
            children: [
              _RoundIcon(
                icon: IconsaxPlusBold.drop,
                background: Tropical.mintWash,
                color: cs.primary,
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('HIDRATACIÓN', style: theme.textTheme.labelSmall),
                    Text.rich(
                      TextSpan(
                        children: [
                          TextSpan(
                            text: '${state.dailyWaterTotalMl}',
                            style: theme.textTheme.displayMedium?.copyWith(color: cs.primary),
                          ),
                          TextSpan(
                            text: ' / ${state.dailyWaterGoalMl} ml',
                            style: theme.textTheme.bodyMedium,
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              Container(
                width: 48,
                height: 48,
                decoration: BoxDecoration(color: cs.primary, shape: BoxShape.circle),
                child: Icon(IconsaxPlusLinear.add, color: cs.onPrimary),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              for (var i = 0; i < _waterSegments; i++)
                Expanded(
                  child: Container(
                    height: 8,
                    margin: EdgeInsets.only(right: i == _waterSegments - 1 ? 0 : 6),
                    decoration: ShapeDecoration(
                      color: i < filled ? cs.primary : cs.surfaceContainerHigh,
                      shape: const StadiumBorder(),
                    ),
                  ),
                ),
            ],
          ),
        ],
      ),
    );
  }
}

class _SmallCard extends StatelessWidget {
  const _SmallCard({
    required this.icon,
    required this.iconBackground,
    required this.iconColor,
    required this.title,
    required this.value,
    required this.caption,
    required this.titleColor,
    required this.background,
    required this.onTap,
    this.badge,
  });

  final IconData icon;
  final Color iconBackground;
  final Color iconColor;
  final String title;
  final String value;
  final String caption;
  final Color titleColor;
  final Color background;
  final VoidCallback onTap;
  final String? badge;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return VitalityCard(
      color: background,
      onTap: onTap,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              _RoundIcon(
                icon: icon,
                background: iconBackground,
                color: iconColor,
                size: 48,
              ),
              if (badge != null)
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: ShapeDecoration(
                    color: Colors.white.withValues(alpha: 0.8),
                    shape: const StadiumBorder(),
                  ),
                  child: Text(badge!, style: theme.textTheme.labelMedium),
                ),
            ],
          ),
          const SizedBox(height: 20),
          Text(title, style: theme.textTheme.labelSmall?.copyWith(color: titleColor)),
          const SizedBox(height: 4),
          Text(value, style: theme.textTheme.headlineLarge),
          const SizedBox(height: 4),
          Text(caption, style: theme.textTheme.bodySmall?.copyWith(color: titleColor)),
        ],
      ),
    );
  }
}

class _SleepCard extends StatelessWidget {
  const _SleepCard({required this.hours});

  final double? hours;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final known = hours;
    return _SmallCard(
      icon: IconsaxPlusBold.moon,
      iconBackground: cs.surfaceContainerHigh,
      iconColor: cs.onSurface,
      title: 'SUEÑO',
      value: known != null ? '${known.toStringAsFixed(1)} h' : '—',
      caption: known != null ? 'Última noche' : 'Sin registro',
      titleColor: cs.onSurfaceVariant,
      background: cs.surfaceContainerLow,
      onTap: () => _openAndReload(context, '/sleep'),
    );
  }
}

class _NutritionCard extends StatelessWidget {
  const _NutritionCard({required this.state});

  final HomeState state;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final pending = state.totalMeals - state.mealsLogged;
    return _SmallCard(
      icon: IconsaxPlusBold.reserve,
      iconBackground: const Color(0xFFFFDCC1),
      iconColor: cs.tertiary,
      title: 'NUTRICIÓN',
      value: '${state.mealsLogged}',
      caption: pending > 0 ? 'Comida pendiente' : 'Comidas al día',
      titleColor: cs.tertiary,
      background: Tropical.peachWash,
      badge: '${state.mealsLogged} / ${state.totalMeals}',
      onTap: () => context.go('/nutrition'),
    );
  }
}

class _ExerciseCard extends StatelessWidget {
  const _ExerciseCard({required this.state});

  final HomeState state;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;
    final status = state.exerciseRoutineDone
        ? 'Rutina completada'
        : state.hasGymSession
            ? 'Sesión en progreso'
            : 'Listo para iniciar';
    return VitalityCard(
      onTap: () => context.go('/exercise'),
      child: Column(
        children: [
          Row(
            children: [
              _RoundIcon(
                icon: IconsaxPlusBold.flash,
                background: const Color(0xFFFFDAD2),
                color: cs.secondary,
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'RUTINA DEL DÍA',
                      style: theme.textTheme.labelSmall?.copyWith(color: cs.secondary),
                    ),
                    Text('Ejercicio', style: theme.textTheme.headlineMedium),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Estado actual', style: theme.textTheme.bodySmall),
                    Text(status, style: theme.textTheme.titleMedium),
                  ],
                ),
              ),
              ElevatedButton.icon(
                onPressed: () => context.go('/exercise'),
                icon: const Icon(IconsaxPlusBold.play),
                label: const Text('Comenzar'),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _QuoteCard extends StatelessWidget {
  const _QuoteCard();

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: theme.colorScheme.surfaceContainerLow,
        borderRadius: BorderRadius.circular(Tropical.cardRadius),
      ),
      child: Text(
        '"La disciplina es el puente entre las metas y los logros."',
        style: theme.textTheme.bodyLarge?.copyWith(fontStyle: FontStyle.italic),
        textAlign: TextAlign.center,
      ),
    );
  }
}
