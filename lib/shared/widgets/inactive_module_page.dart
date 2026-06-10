import 'package:flutter/material.dart';
import 'package:kiolog/core/domain/app_module.dart';
import 'package:kiolog/features/exercise/presentation/pages/exercise_config_page.dart';
import 'package:kiolog/features/nutrition/presentation/pages/nutrition_config_page.dart';
import 'package:kiolog/features/water/presentation/pages/water_config_page.dart';

class InactiveModulePage extends StatelessWidget {
  final AppModule module;

  const InactiveModulePage({super.key, required this.module});

  String get _moduleName {
    switch (module) {
      case AppModule.nutrition:
        return 'Nutrición';
      case AppModule.water:
        return 'Hidratación';
      case AppModule.exercise:
        return 'Ejercicio';
    }
  }

  IconData get _moduleIcon {
    switch (module) {
      case AppModule.nutrition:
        return Icons.restaurant_menu;
      case AppModule.water:
        return Icons.water_drop;
      case AppModule.exercise:
        return Icons.fitness_center;
    }
  }

  String get _description {
    switch (module) {
      case AppModule.nutrition:
        return 'Activa el módulo de nutrición para registrar tus comidas y hacer seguimiento de tu alimentación.';
      case AppModule.water:
        return 'Activa el módulo de hidratación para registrar tu consumo diario de agua.';
      case AppModule.exercise:
        return 'Activa el módulo de ejercicio para registrar tus rutinas y sesiones de entrenamiento.';
    }
  }

  void _openConfigPage(BuildContext context) {
    final Widget page;
    switch (module) {
      case AppModule.nutrition:
        page = NutritionConfigPage(onComplete: () {});
      case AppModule.water:
        page = WaterConfigPage(onComplete: () {});
      case AppModule.exercise:
        page = ExerciseConfigPage(onComplete: () {});
    }
    Navigator.of(context).push(MaterialPageRoute<void>(builder: (_) => page));
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Scaffold(
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                _moduleIcon,
                size: 80,
                color: theme.colorScheme.onSurface.withValues(alpha: 0.3),
              ),
              const SizedBox(height: 24),
              Text(
                '$_moduleName no activado',
                style: theme.textTheme.headlineSmall?.copyWith(
                  fontWeight: FontWeight.bold,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 12),
              Text(
                _description,
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 32),
              FilledButton(
                onPressed: () => _openConfigPage(context),
                child: const Text('Activar y configurar'),
              ),
              const SizedBox(height: 24),
              Text(
                'Puedes cambiar esta configuración en cualquier momento desde ajustes.',
                style: theme.textTheme.bodySmall?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                ),
                textAlign: TextAlign.center,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
