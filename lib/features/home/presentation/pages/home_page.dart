import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import '../../../../core/di/injection.dart';
import '../../../../features/exercise/domain/repositories/exercise_repository.dart';
import '../../../../features/nutrition/domain/repositories/nutrition_repository.dart';
import '../../../../features/sleep/domain/repositories/sleep_repository.dart';
import '../../../../features/water/domain/repositories/water_repository.dart';
import '../../../../shared/widgets/vitality_card.dart';
import '../../../../shared/widgets/vitality_progress_bar.dart';
import '../../../../shared/widgets/module_icon_badge.dart';
import '../bloc/home_bloc.dart';
import '../bloc/home_event.dart';
import '../bloc/home_state.dart';

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
    final now = DateTime.now();
    final dateLabel = DateFormat('EEEE, d MMM', 'es').format(now);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Kiolog'),
        actions: [
          IconButton(
            icon: const Icon(Icons.emoji_events_outlined),
            onPressed: () => context.push('/achievements'),
          ),
          IconButton(
            icon: const Icon(Icons.calendar_month_outlined),
            onPressed: () => context.push('/history'),
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

          return CustomScrollView(
            slivers: [
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(24, 24, 24, 8),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Buenos días',
                        style: theme.textTheme.displayLarge,
                      ),
                      const SizedBox(height: 4),
                      Text(
                        dateLabel,
                        style: theme.textTheme.bodyMedium?.copyWith(
                          color: cs.onSurfaceVariant,
                        ),
                      ),
                      const SizedBox(height: 32),
                    ],
                  ),
                ),
              ),
              SliverPadding(
                padding: const EdgeInsets.symmetric(horizontal: 24),
                sliver: SliverList(
                  delegate: SliverChildListDelegate([
                    _ModuleCard(
                      icon: Icons.water_drop,
                      label: 'Agua',
                      color: cs.tertiary,
                      progress: state.waterProgress,
                      subtitle:
                          '${state.dailyWaterTotalMl} / ${state.dailyWaterGoalMl} ml',
                      onTap: () => context.push('/water'),
                    ),
                    const SizedBox(height: 16),
                    _ModuleCard(
                      icon: Icons.nightlight_round,
                      label: 'Sueño',
                      color: const Color(0xFFAFC7FF),
                      progress: state.sleepHours != null
                          ? (state.sleepHours! / 8).clamp(0.0, 1.0)
                          : 0.0,
                      subtitle: state.sleepHours != null
                          ? '${state.sleepHours!.toStringAsFixed(1)} h'
                          : 'No registrado',
                      onTap: () => context.push('/sleep'),
                    ),
                    const SizedBox(height: 16),
                    _ModuleCard(
                      icon: Icons.restaurant,
                      label: 'Nutrición',
                      color: cs.secondary,
                      progress: state.totalMeals > 0
                          ? state.mealsLogged / state.totalMeals
                          : 0.0,
                      subtitle:
                          '${state.mealsLogged} / ${state.totalMeals} comidas',
                      onTap: () => context.go('/nutrition'),
                    ),
                    const SizedBox(height: 16),
                    _ModuleCard(
                      icon: Icons.fitness_center,
                      label: 'Ejercicio',
                      color: cs.primary,
                      progress: state.exerciseRoutineDone ? 1.0 : 0.0,
                      subtitle: state.exerciseRoutineDone
                          ? 'Rutina completada'
                          : state.hasGymSession
                              ? 'Sesión en progreso'
                              : 'Pendiente',
                      onTap: () => context.go('/exercise'),
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

class _ModuleCard extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color color;
  final double progress;
  final String subtitle;
  final VoidCallback onTap;

  const _ModuleCard({
    required this.icon,
    required this.label,
    required this.color,
    required this.progress,
    required this.subtitle,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;

    return VitalityCard(
      onTap: onTap,
      child: Row(
        children: [
          ModuleIconBadge(icon: icon, color: color),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(label, style: theme.textTheme.labelLarge),
                const SizedBox(height: 2),
                Text(
                  subtitle,
                  style: theme.textTheme.bodyMedium?.copyWith(
                    color: cs.onSurfaceVariant,
                  ),
                ),
                const SizedBox(height: 10),
                VitalityProgressBar(value: progress, color: color),
              ],
            ),
          ),
          const SizedBox(width: 12),
          Icon(Icons.chevron_right, color: cs.onSurfaceVariant, size: 20),
        ],
      ),
    );
  }
}
