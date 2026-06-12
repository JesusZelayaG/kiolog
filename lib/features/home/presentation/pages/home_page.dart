import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import '../../../../core/di/injection.dart';
import '../../../../features/exercise/domain/repositories/exercise_repository.dart';
import '../../../../features/nutrition/domain/repositories/nutrition_repository.dart';
import '../../../../features/sleep/domain/repositories/sleep_repository.dart';
import '../../../../features/water/domain/repositories/water_repository.dart';
import '../../../../shared/widgets/vitality_progress_bar.dart';
import '../../../../shared/widgets/module_icon_badge.dart';
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

class _HomeView extends StatelessWidget {
  const _HomeView();

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;

    return Scaffold(
      appBar: AppBar(
        title: Image.asset(
          'assets/img/kiolog_banner.png',
          height: 88,
        ),
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: 12),
            child: GestureDetector(
              onTap: () => context.push('/history'),
              child: Container(
                width: 36,
                height: 36,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(10),
                  gradient: const LinearGradient(
                    colors: [
                      Color(0xFF0A8F53),
                      Color(0xFF4CBF4A),
                      Color(0xFF9ACD32),
                    ],
                    stops: [0.0, 0.5, 1.0],
                  ),
                ),
                child: const Icon(
                  Icons.calendar_month_outlined,
                  color: Colors.white,
                  size: 20,
                ),
              ),
            ),
          ),
        ],
      ),
      body: BlocBuilder<HomeBloc, HomeState>(
        builder: (context, state) {
          if (state.status == HomeStatus.loading) {
            return const Center(child: CircularProgressIndicator());
          }
          if (state.status == HomeStatus.failure) {
            return Center(child: Text('Error: ${state.error}'));
          }

          final overall = calcOverallProgress(state);

          return CustomScrollView(
            slivers: [
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(24, 24, 24, 0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.end,
                        children: [
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'BIENVENIDO DE NUEVO',
                                style: theme.textTheme.labelSmall?.copyWith(
                                  color: cs.primary,
                                ),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                'Resumen del día',
                                style:
                                    theme.textTheme.headlineMedium?.copyWith(
                                  fontWeight: FontWeight.bold,
                                  color: cs.onSurface,
                                ),
                              ),
                            ],
                          ),
                          const Spacer(),
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.end,
                            children: [
                              Text(
                                '${(overall * 100).round()}%',
                                style:
                                    theme.textTheme.headlineMedium?.copyWith(
                                  fontWeight: FontWeight.bold,
                                  color: cs.primary,
                                ),
                              ),
                              Text(
                                'META DIARIA',
                                style: theme.textTheme.labelSmall?.copyWith(
                                  color: cs.onSurfaceVariant,
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),
                      VitalityProgressBar(value: overall, color: cs.primary),
                      const SizedBox(height: 24),
                    ],
                  ),
                ),
              ),
              SliverPadding(
                padding: const EdgeInsets.symmetric(horizontal: 24),
                sliver: SliverList(
                  delegate: SliverChildListDelegate([
                    _WaterCard(
                      icon: Icons.water_drop,
                      label: 'Agua',
                      subtitle:
                          '${state.dailyWaterTotalMl} / ${state.dailyWaterGoalMl} ml',
                      color: cs.tertiary,
                      bgImage: 'assets/img/watter_bg2.png',
                      onTap: () => context.push('/water'),
                    ),
                    const SizedBox(height: 12),
                    Row(
                      children: [
                        Expanded(
                          child: _CompactModuleCard(
                            icon: Icons.nightlight_round,
                            label: 'Sueño',
                            subtitle: state.sleepHours != null
                                ? '${state.sleepHours!.toStringAsFixed(1)} h'
                                : 'Sin registro',
                            color: const Color(0xFFAFC7FF),
                            bgImage: 'assets/img/sleep_bg2.png',
                            onTap: () => context.push('/sleep'),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: _CompactModuleCard(
                            icon: Icons.restaurant,
                            label: 'Nutrición',
                            subtitle:
                                '${state.mealsLogged} / ${state.totalMeals} comidas',
                            color: cs.secondary,
                            bgImage: 'assets/img/nutrition_bg2.png',
                            onTap: () => context.go('/nutrition'),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    _ExerciseCard(
                      icon: Icons.fitness_center,
                      label: 'Ejercicio',
                      subtitle: state.exerciseRoutineDone
                          ? 'Rutina completada'
                          : state.hasGymSession
                              ? 'Sesión en progreso'
                              : 'Pendiente',
                      color: cs.primary,
                      bgImage: 'assets/img/exercise_bg2.png',
                      onTap: () => context.go('/exercise'),
                    ),
                    const SizedBox(height: 24),
                    Text(
                      '"La disciplina es el puente entre las metas y los logros."',
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: cs.onSurface.withValues(alpha: 0.5),
                        fontStyle: FontStyle.italic,
                      ),
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 32),
                  ]),
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}

class _WaterCard extends StatelessWidget {
  final IconData icon;
  final String label;
  final String subtitle;
  final Color color;
  final String bgImage;
  final VoidCallback onTap;

  const _WaterCard({
    required this.icon,
    required this.label,
    required this.subtitle,
    required this.color,
    required this.bgImage,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;
    return GestureDetector(
      onTap: onTap,
      child: ClipRRect(
        borderRadius: BorderRadius.circular(12),
        child: SizedBox(
          height: 120,
          child: Stack(
            fit: StackFit.expand,
            children: [
              Image.asset(
                bgImage,
                fit: BoxFit.cover,
                alignment: Alignment.centerRight,
              ),
              Container(
                decoration: const BoxDecoration(
                  gradient: LinearGradient(
                    colors: [Color(0xEE000000), Color(0x33000000)],
                    begin: Alignment.centerLeft,
                    end: Alignment.centerRight,
                  ),
                ),
              ),
              Padding(
                padding: const EdgeInsets.all(16),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    ModuleIconBadge(icon: icon, color: color),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Text(
                            label,
                            style: theme.textTheme.labelLarge?.copyWith(
                              color: cs.onSurface,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            subtitle,
                            style: theme.textTheme.bodySmall?.copyWith(
                              color: cs.onSurface.withValues(alpha: 0.7),
                            ),
                          ),
                        ],
                      ),
                    ),
                    Container(
                      width: 32,
                      height: 32,
                      decoration: BoxDecoration(
                        color: cs.primary,
                        shape: BoxShape.circle,
                      ),
                      child: Icon(Icons.add, color: cs.onPrimary, size: 18),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _ExerciseCard extends StatelessWidget {
  final IconData icon;
  final String label;
  final String subtitle;
  final Color color;
  final String bgImage;
  final VoidCallback onTap;

  const _ExerciseCard({
    required this.icon,
    required this.label,
    required this.subtitle,
    required this.color,
    required this.bgImage,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;
    return GestureDetector(
      onTap: onTap,
      child: ClipRRect(
        borderRadius: BorderRadius.circular(12),
        child: SizedBox(
          height: 160,
          child: Stack(
            fit: StackFit.expand,
            children: [
              Image.asset(bgImage, fit: BoxFit.cover),
              Container(
                decoration: const BoxDecoration(
                  gradient: RadialGradient(
                    colors: [Color(0x1A000000), Color(0xCC000000)],
                    stops: [0.0, 1.0],
                    radius: 1.1,
                  ),
                ),
              ),
              Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        ModuleIconBadge(icon: icon, color: color),
                        const SizedBox(width: 12),
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              label,
                              style: theme.textTheme.labelLarge?.copyWith(
                                color: cs.onSurface,
                              ),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              subtitle,
                              style: theme.textTheme.bodySmall?.copyWith(
                                color: cs.onSurface.withValues(alpha: 0.7),
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                    const Spacer(),
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton.icon(
                        icon: const Icon(Icons.play_arrow, size: 16),
                        label: const Text('VER AHORA'),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: cs.primary,
                          foregroundColor: cs.onPrimary,
                          shape: const StadiumBorder(),
                          padding: const EdgeInsets.symmetric(vertical: 10),
                          textStyle: const TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        onPressed: onTap,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _CompactModuleCard extends StatelessWidget {
  final IconData icon;
  final String label;
  final String subtitle;
  final Color color;
  final String bgImage;
  final VoidCallback onTap;

  const _CompactModuleCard({
    required this.icon,
    required this.label,
    required this.subtitle,
    required this.color,
    required this.bgImage,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;
    return GestureDetector(
      onTap: onTap,
      child: ClipRRect(
        borderRadius: BorderRadius.circular(12),
        child: SizedBox(
          height: 120,
          child: Stack(
            fit: StackFit.expand,
            children: [
              Image.asset(bgImage, fit: BoxFit.cover),
              Container(
                decoration: const BoxDecoration(
                  gradient: RadialGradient(
                    colors: [Color(0x1A000000), Color(0xCC000000)],
                    stops: [0.0, 1.0],
                    radius: 1.1,
                  ),
                ),
              ),
              Padding(
                padding: const EdgeInsets.all(12),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    ModuleIconBadge(icon: icon, color: color, size: 32),
                    const Spacer(),
                    Text(
                      label,
                      style: theme.textTheme.labelMedium?.copyWith(
                        color: cs.onSurface,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      subtitle,
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: cs.onSurface.withValues(alpha: 0.7),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
