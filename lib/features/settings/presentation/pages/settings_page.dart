import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:kiolog/core/domain/app_module.dart';
import 'package:kiolog/core/modules/cubit/modules_cubit.dart';
import 'package:kiolog/core/modules/cubit/modules_state.dart';
import 'package:kiolog/features/exercise/presentation/pages/exercise_config_page.dart';
import 'package:kiolog/features/nutrition/presentation/pages/nutrition_config_page.dart';
import 'package:kiolog/features/water/presentation/pages/water_config_page.dart';

class SettingsPage extends StatelessWidget {
  const SettingsPage({super.key});

  String _moduleTitle(AppModule module) {
    switch (module) {
      case AppModule.nutrition:
        return 'Nutrición';
      case AppModule.water:
        return 'Hidratación';
      case AppModule.exercise:
        return 'Ejercicio';
    }
  }

  String _moduleSubtitle(AppModule module, bool enabled) {
    if (!enabled) return 'Inactivo';
    switch (module) {
      case AppModule.nutrition:
        return 'Plan activo';
      case AppModule.water:
        return 'Meta de agua activa';
      case AppModule.exercise:
        return 'Rutina activa';
    }
  }

  Widget _configPage(AppModule module, VoidCallback onComplete) {
    switch (module) {
      case AppModule.nutrition:
        return NutritionConfigPage(onComplete: onComplete);
      case AppModule.water:
        return WaterConfigPage(onComplete: onComplete);
      case AppModule.exercise:
        return ExerciseConfigPage(onComplete: onComplete);
    }
  }

  Future<void> _onToggle(
    BuildContext context,
    AppModule module,
    bool newValue,
    ModulesCubit cubit,
  ) async {
    if (!newValue) {
      // Deactivating — show confirm dialog
      final confirmed = await showDialog<bool>(
        context: context,
        builder: (ctx) => AlertDialog(
          title: Text('Desactivar ${_moduleTitle(module)}'),
          content: const Text(
            'Tu historial será conservado. Puedes volver a activar este módulo en cualquier momento.',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(ctx).pop(false),
              child: const Text('Cancelar'),
            ),
            TextButton(
              onPressed: () => Navigator.of(ctx).pop(true),
              child: const Text('Desactivar'),
            ),
          ],
        ),
      );
      if (confirmed == true) {
        await cubit.setModuleEnabled(module, false);
      }
    } else {
      // Activating — push config page
      Navigator.of(context).push(
        MaterialPageRoute(
          builder: (ctx) => _configPage(
            module,
            () => Navigator.of(ctx).pop(),
          ),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Ajustes')),
      body: SafeArea(
        child: BlocBuilder<ModulesCubit, ModulesState>(
          builder: (context, modulesState) {
            final cubit = context.read<ModulesCubit>();

            // Determine if a module's switch should be disabled (last active)
            final activeModules = AppModule.values
                .where((m) => modulesState.isEnabled(m))
                .toList();
            final isLastActive = activeModules.length == 1;

            return ListView(
              children: [
                // ── Módulos activos section ──────────────────────────────
                const Padding(
                  padding: EdgeInsets.fromLTRB(16, 12, 16, 4),
                  child: Text(
                    'Módulos activos',
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 14,
                    ),
                  ),
                ),
                ...AppModule.values.map((module) {
                  final enabled = modulesState.isEnabled(module);
                  final disabled = enabled && isLastActive;
                  return SwitchListTile(
                    title: Text(_moduleTitle(module)),
                    subtitle: Text(_moduleSubtitle(module, enabled)),
                    value: enabled,
                    onChanged: disabled
                        ? null
                        : (newValue) =>
                            _onToggle(context, module, newValue, cubit),
                  );
                }),
                const Divider(),
                // ── Existing settings ────────────────────────────────────
                ListTile(
                  leading: const Icon(Icons.picture_as_pdf),
                  title: const Text('Reporte de salud'),
                  subtitle: const Text('Generar PDF del período'),
                  trailing: const Icon(Icons.chevron_right),
                  onTap: () => context.push('/report'),
                ),
                const Divider(),
                ListTile(
                  leading: const Icon(Icons.notifications_outlined),
                  title: const Text('Notificaciones'),
                  subtitle: const Text('Próximamente'),
                  trailing: const Icon(Icons.chevron_right),
                  onTap: () {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('Próximamente')),
                    );
                  },
                ),
                ListTile(
                  leading: const Icon(Icons.smart_toy_outlined),
                  title: const Text('Integración IA'),
                  subtitle: const Text('Próximamente'),
                  trailing: const Icon(Icons.chevron_right),
                  onTap: () {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('Próximamente')),
                    );
                  },
                ),
                const Divider(),
                ListTile(
                  leading: const Icon(Icons.info_outline),
                  title: const Text('Acerca de Kiolog'),
                  subtitle: const Text('v1.0.0'),
                ),
              ],
            );
          },
        ),
      ),
    );
  }
}
