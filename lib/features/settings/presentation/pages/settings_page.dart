import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:kiolog/core/database/app_database.dart';
import 'package:kiolog/core/database/backup_service.dart';
import 'package:kiolog/core/di/injection.dart';
import 'package:kiolog/core/domain/app_module.dart';
import 'package:kiolog/core/modules/cubit/modules_cubit.dart';
import 'package:kiolog/core/modules/cubit/modules_state.dart';
import 'package:kiolog/core/theme/app_theme.dart';
import 'package:kiolog/core/theme/theme_cubit.dart';
import 'package:iconsax_plus/iconsax_plus.dart';
import 'package:kiolog/shared/widgets/theme_picker.dart';
import 'package:kiolog/features/exercise/presentation/pages/exercise_config_page.dart';
import 'package:kiolog/features/nutrition/presentation/pages/nutrition_config_page.dart';
import 'package:kiolog/features/water/presentation/pages/water_config_page.dart';
import 'package:kiolog/shared/widgets/kiolog_app_bar.dart';
import 'package:kiolog/shared/widgets/restore_backup.dart';
import 'package:kiolog/shared/widgets/vitality_card.dart';
import 'package:share_plus/share_plus.dart';

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
      appBar: const KiologAppBar(title: 'Ajustes'),
      body: SafeArea(
        child: BlocBuilder<ModulesCubit, ModulesState>(
          builder: (context, modulesState) {
            final cubit = context.read<ModulesCubit>();

            // Determine if a module's switch should be disabled (last active)
            final activeModules = AppModule.values
                .where((m) => modulesState.isEnabled(m))
                .toList();
            final isLastActive = activeModules.length == 1;
            final total = AppModule.values.length;

            return ListView(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
              children: [
                _SectionLabel(
                  'Módulos activos',
                  trailing: '${activeModules.length} de $total encendidos',
                ),
                VitalityCard(
                  padding: const EdgeInsets.symmetric(vertical: 8),
                  child: Column(
                    children: [
                      for (final module in AppModule.values)
                        _ModuleTile(
                          module: module,
                          title: _moduleTitle(module),
                          subtitle: _moduleSubtitle(module, modulesState.isEnabled(module)),
                          value: modulesState.isEnabled(module),
                          onChanged: modulesState.isEnabled(module) && isLastActive
                              ? null
                              : (value) => _onToggle(context, module, value, cubit),
                        ),
                    ],
                  ),
                ),
                const SizedBox(height: 24),
                const _SectionLabel('Apariencia'),
                VitalityCard(
                  padding: const EdgeInsets.symmetric(vertical: 8),
                  child: BlocBuilder<ThemeCubit, KiologThemeId>(
                    builder: (context, themeId) => _ToolTile(
                      icon: IconsaxPlusLinear.brush_2,
                      title: 'Tema',
                      subtitle: themeId.label,
                      onTap: () => _chooseTheme(context),
                    ),
                  ),
                ),
                const SizedBox(height: 24),
                const _SectionLabel('Herramientas y datos'),
                VitalityCard(
                  padding: const EdgeInsets.symmetric(vertical: 8),
                  child: Column(
                    children: [
                      _ToolTile(
                        icon: Icons.picture_as_pdf_outlined,
                        title: 'Reporte de salud',
                        subtitle: 'Generar PDF del período',
                        onTap: () => context.push('/report'),
                      ),
                      _ToolTile(
                        icon: Icons.upload_file_outlined,
                        title: 'Crear respaldo',
                        subtitle: 'En el teléfono o en Drive, correo…',
                        onTap: () => _exportBackup(context),
                      ),
                      const _AutoBackupTile(),
                      _ToolTile(
                        icon: Icons.settings_backup_restore,
                        title: 'Restaurar respaldo',
                        subtitle: 'Reemplaza los datos de este teléfono',
                        onTap: () => _restoreBackup(context),
                      ),
                      _ToolTile(
                        icon: Icons.notifications_outlined,
                        title: 'Notificaciones',
                        subtitle: 'Próximamente',
                        onTap: () => _showSoon(context),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 24),
                const _SectionLabel('Información'),
                const VitalityCard(
                  padding: EdgeInsets.symmetric(vertical: 8),
                  child: _ToolTile(
                    icon: Icons.info_outline,
                    title: 'Acerca de Kiolog',
                    subtitle: 'v1.0.0',
                  ),
                ),
              ],
            );
          },
        ),
      ),
    );
  }
}


Future<void> _chooseTheme(BuildContext context) => showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      isScrollControlled: true,
      builder: (sheetContext) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Tema', style: Theme.of(sheetContext).textTheme.titleLarge),
              const SizedBox(height: 12),
              const ThemePicker(),
            ],
          ),
        ),
      ),
    );

enum _BackupTarget { phone, share }

Future<void> _exportBackup(BuildContext context) async {
  final messenger = ScaffoldMessenger.of(context);
  final target = await showModalBottomSheet<_BackupTarget>(
    context: context,
    // Por encima de la barra de navegación.
    useRootNavigator: true,
    builder: (sheetContext) => SafeArea(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          ListTile(
            leading: const Icon(Icons.phone_android),
            title: const Text('Guardar en el teléfono'),
            subtitle: const Text('Descargas/Kiolog. Sigue ahí aunque borres la app.'),
            onTap: () => Navigator.pop(sheetContext, _BackupTarget.phone),
          ),
          ListTile(
            leading: const Icon(Icons.share),
            title: const Text('Enviar a Drive, correo…'),
            subtitle: const Text('Una copia fuera del teléfono.'),
            onTap: () => Navigator.pop(sheetContext, _BackupTarget.share),
          ),
        ],
      ),
    ),
  );
  if (target == null) return;
  final service = BackupService(getIt<AppDatabase>());
  try {
    switch (target) {
      case _BackupTarget.phone:
        final saved = await service.saveToPhone();
        messenger.showSnackBar(SnackBar(content: Text('Respaldo guardado en $saved')));
      case _BackupTarget.share:
        final file = await service.export();
        await SharePlus.instance.share(
          ShareParams(files: [XFile(file.path)], subject: 'Respaldo de Kiolog'),
        );
    }
  } catch (_) {
    messenger.showSnackBar(
      const SnackBar(content: Text('No se pudo crear el respaldo')),
    );
  }
}

Future<void> _restoreBackup(BuildContext context) => restoreBackupFlow(context);

/// Muestra cuándo se hizo el último respaldo automático.
class _AutoBackupTile extends StatelessWidget {
  const _AutoBackupTile();

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<DateTime?>(
      future: BackupService.lastAutoBackup(),
      builder: (context, snapshot) {
        final last = snapshot.data;
        final when = last == null
            ? 'todavía ninguno'
            : 'último: ${DateFormat.yMMMd('es').format(last)}';
        return _ToolTile(
          icon: Icons.history,
          title: 'Respaldo automático diario',
          subtitle: 'Descargas/Kiolog, guarda $autoBackupsKept días · $when',
        );
      },
    );
  }
}

void _showSoon(BuildContext context) {
  ScaffoldMessenger.of(context).showSnackBar(
    const SnackBar(content: Text('Próximamente')),
  );
}

class _SectionLabel extends StatelessWidget {
  const _SectionLabel(this.text, {this.trailing});

  final String text;
  final String? trailing;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.fromLTRB(8, 4, 8, 10),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            text,
            style: theme.textTheme.labelMedium?.copyWith(color: theme.colorScheme.primary),
          ),
          if (trailing != null) Text(trailing!, style: theme.textTheme.bodySmall),
        ],
      ),
    );
  }
}

class _TileIcon extends StatelessWidget {
  const _TileIcon({required this.icon, required this.background});

  final IconData icon;
  final Color background;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 44,
      height: 44,
      decoration: BoxDecoration(color: background, shape: BoxShape.circle),
      child: Icon(icon, size: 22, color: Theme.of(context).colorScheme.primary),
    );
  }
}

class _ModuleTile extends StatelessWidget {
  const _ModuleTile({
    required this.module,
    required this.title,
    required this.subtitle,
    required this.value,
    required this.onChanged,
  });

  final AppModule module;
  final String title;
  final String subtitle;
  final bool value;
  final ValueChanged<bool>? onChanged;

  @override
  Widget build(BuildContext context) {
    return SwitchListTile(
      secondary: _TileIcon(
        background: context.kc.waterWash,
        icon: switch (module) {
          AppModule.nutrition => Icons.restaurant_outlined,
          AppModule.water => Icons.water_drop_outlined,
          AppModule.exercise => Icons.fitness_center,
        },
      ),
      title: Text(title),
      subtitle: Text(subtitle),
      value: value,
      onChanged: onChanged,
    );
  }
}

class _ToolTile extends StatelessWidget {
  const _ToolTile({
    required this.icon,
    required this.title,
    required this.subtitle,
    this.onTap,
  });

  final IconData icon;
  final String title;
  final String subtitle;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return ListTile(
      leading: _TileIcon(
        icon: icon,
        background: Theme.of(context).colorScheme.surfaceContainerLow,
      ),
      title: Text(title),
      subtitle: Text(subtitle),
      trailing: onTap == null ? null : const Icon(Icons.chevron_right),
      onTap: onTap,
    );
  }
}
