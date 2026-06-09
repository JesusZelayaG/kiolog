import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import '../../../../core/di/injection.dart';
import '../../../../features/exercise/domain/repositories/exercise_repository.dart';
import '../../../../features/nutrition/domain/repositories/nutrition_repository.dart';
import '../../../../features/sleep/domain/repositories/sleep_repository.dart';
import '../../../../features/water/domain/repositories/water_repository.dart';
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

          return SafeArea(
            child: ListView(
              padding: const EdgeInsets.all(16),
              children: [
                Text(
                  'Resumen del día',
                  style: Theme.of(context).textTheme.headlineSmall,
                ),
                const SizedBox(height: 16),
                _SummaryCard(
                  icon: Icons.water_drop,
                  label: 'Agua',
                  color: Colors.blue,
                  progress: state.waterProgress,
                  subtitle:
                      '${state.dailyWaterTotalMl} / ${state.dailyWaterGoalMl} ml',
                  onTap: () => context.push('/water'),
                ),
                _SummaryCard(
                  icon: Icons.nightlight_round,
                  label: 'Sueño',
                  color: Colors.indigo,
                  progress: state.sleepHours != null ? (state.sleepHours! / 8).clamp(0.0, 1.0) : 0.0,
                  subtitle: state.sleepHours != null
                      ? '${state.sleepHours!.toStringAsFixed(1)} h'
                      : 'No registrado',
                  onTap: () => context.push('/sleep'),
                ),
                _SummaryCard(
                  icon: Icons.restaurant,
                  label: 'Nutrición',
                  color: Colors.orange,
                  progress: state.totalMeals > 0
                      ? state.mealsLogged / state.totalMeals
                      : 0.0,
                  subtitle: '${state.mealsLogged} / ${state.totalMeals} comidas',
                  onTap: () => context.go('/nutrition'),
                ),
                _SummaryCard(
                  icon: Icons.fitness_center,
                  label: 'Ejercicio',
                  color: Colors.red,
                  progress: state.exerciseRoutineDone ? 1.0 : 0.0,
                  subtitle: state.exerciseRoutineDone
                      ? 'Rutina completada'
                      : state.hasGymSession
                          ? 'Sesión en progreso'
                          : 'Pendiente',
                  onTap: () => context.go('/exercise'),
                ),
              ],
            ),
          );
        },
      ),
    );
  }
}

class _SummaryCard extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color color;
  final double progress;
  final String subtitle;
  final VoidCallback onTap;

  const _SummaryCard({
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
    final clampedProgress = progress.clamp(0.0, 1.0);

    return Card(
      clipBehavior: Clip.antiAlias,
      margin: const EdgeInsets.only(bottom: 12),
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              CircleAvatar(
                backgroundColor: color.withOpacity(0.15),
                child: Icon(icon, color: color),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(label, style: theme.textTheme.titleMedium),
                    const SizedBox(height: 4),
                    Text(subtitle,
                        style: theme.textTheme.bodyMedium?.copyWith(
                              color: theme.colorScheme.onSurfaceVariant,
                            )),
                    const SizedBox(height: 8),
                    LinearProgressIndicator(
                      value: clampedProgress,
                      backgroundColor:
                          theme.colorScheme.surfaceContainerHighest,
                      valueColor: AlwaysStoppedAnimation<Color>(color),
                      borderRadius: BorderRadius.circular(4),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              Icon(Icons.chevron_right,
                  color: theme.colorScheme.onSurfaceVariant),
            ],
          ),
        ),
      ),
    );
  }
}
