import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:kiolog/core/database/app_database.dart';
import 'package:kiolog/core/database/backup_service.dart';
import 'package:kiolog/core/di/injection.dart';
import 'package:kiolog/core/domain/app_module.dart';
import 'package:kiolog/core/modules/cubit/modules_cubit.dart';
import 'package:kiolog/core/modules/cubit/modules_state.dart';
import 'package:kiolog/core/theme/app_theme.dart';
import 'package:iconsax_plus/iconsax_plus.dart';
import 'package:kiolog/shared/widgets/theme_picker.dart';
import 'package:kiolog/features/exercise/presentation/pages/exercise_config_page.dart';
import 'package:kiolog/features/nutrition/presentation/pages/nutrition_config_page.dart';
import 'package:kiolog/features/water/presentation/pages/water_config_page.dart';
import 'package:kiolog/core/dao/user_profile_dao.dart';
import 'package:kiolog/shared/widgets/entrance.dart';
import 'package:kiolog/shared/widgets/kiolog_glyphs.dart';
import 'package:kiolog/shared/widgets/themed_page.dart';
import 'package:kiolog/shared/widgets/restore_backup.dart';
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
    return ThemedPage(
      child: BlocBuilder<ModulesCubit, ModulesState>(
        builder: (context, modulesState) {
          final cubit = context.read<ModulesCubit>();
          final activeModules = AppModule.values.where((m) => modulesState.isEnabled(m)).toList();
          // El último módulo encendido no se puede apagar.
          final isLastActive = activeModules.length == 1;
          final total = AppModule.values.length;

          final items = <Widget>[
            const _Header(),
            const _ProfileCard(),
            _SectionLabel('MÓDULOS', trailing: '${activeModules.length} de $total encendidos'),
            _Card(
              padding: const EdgeInsets.symmetric(vertical: 6),
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
            const _SectionLabel('APARIENCIA'),
            const _Card(child: ThemePicker()),
            const _SectionLabel('TUS DATOS'),
            _Card(
              padding: const EdgeInsets.symmetric(vertical: 6),
              child: Column(
                children: [
                  _ToolTile(
                    icon: IconsaxPlusLinear.document_text,
                    tint: context.kc.foodWash,
                    ink: context.kc.foodInk,
                    title: 'Reporte de salud',
                    subtitle: 'PDF del período para tu nutricionista',
                    onTap: () => context.push('/report'),
                  ),
                  _ToolTile(
                    icon: IconsaxPlusLinear.export_1,
                    tint: context.kc.waterWash,
                    ink: context.kc.waterInk,
                    title: 'Crear respaldo',
                    subtitle: 'En el teléfono o en Drive, correo…',
                    onTap: () => _exportBackup(context),
                  ),
                  const _AutoBackupTile(),
                  _ToolTile(
                    icon: IconsaxPlusLinear.refresh_2,
                    tint: Theme.of(context).colorScheme.error.withValues(alpha: 0.12),
                    ink: Theme.of(context).colorScheme.error,
                    title: 'Restaurar respaldo',
                    subtitle: 'Reemplaza los datos de este teléfono',
                    onTap: () => _restoreBackup(context),
                  ),
                ],
              ),
            ),
            const _SectionLabel('NOTIFICACIONES'),
            _Card(
              padding: const EdgeInsets.symmetric(vertical: 6),
              child: _ToolTile(
                icon: IconsaxPlusLinear.notification,
                tint: context.kc.sleepWash,
                ink: context.kc.sleepInk,
                title: 'Recordatorios',
                subtitle: 'Agua, peso y sueño',
                badge: 'Pronto',
              ),
            ),
            const _AboutCard(),
          ];
          return ListView.separated(
            padding: const EdgeInsets.fromLTRB(18, 14, 18, 120),
            itemCount: items.length,
            separatorBuilder: (_, i) => SizedBox(height: items[i] is _SectionLabel ? 0 : 14),
            itemBuilder: (context, i) => Entrance(index: i, child: items[i]),
          );
        },
      ),
    );
  }
}

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
            leading: const Icon(IconsaxPlusLinear.mobile),
            title: const Text('Guardar en el teléfono'),
            subtitle: const Text('Descargas/Kiolog. Sigue ahí aunque borres la app.'),
            onTap: () => Navigator.pop(sheetContext, _BackupTarget.phone),
          ),
          ListTile(
            leading: const Icon(IconsaxPlusLinear.send_2),
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
          icon: IconsaxPlusLinear.timer_1,
          tint: context.kc.gymWash,
          ink: context.kc.gymInk,
          title: 'Respaldo automático diario',
          subtitle: 'Descargas/Kiolog, guarda $autoBackupsKept días · $when',
        );
      },
    );
  }
}

class _Header extends StatelessWidget {
  const _Header();

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('KIOLOG', style: theme.textTheme.labelSmall?.copyWith(fontSize: 11, color: theme.colorScheme.primary)),
        Text('Ajustes', style: theme.textTheme.displayMedium?.copyWith(fontSize: 28)),
      ],
    );
  }
}

class _Card extends StatelessWidget {
  const _Card({required this.child, this.padding = const EdgeInsets.all(14)});

  final Widget child;
  final EdgeInsets padding;

  @override
  Widget build(BuildContext context) => DecoratedBox(
        decoration: BoxDecoration(borderRadius: BorderRadius.circular(28), boxShadow: [context.kc.shadow]),
        // Material para que las filas muestren el efecto al tocarlas.
        child: Material(
          color: Theme.of(context).colorScheme.surfaceContainerLowest,
          borderRadius: BorderRadius.circular(28),
          clipBehavior: Clip.antiAlias,
          child: Padding(padding: padding, child: child),
        ),
      );
}

/// El nombre de la persona y desde cuándo usa Kiolog; el nombre se edita aquí.
class _ProfileCard extends StatefulWidget {
  const _ProfileCard();

  @override
  State<_ProfileCard> createState() => _ProfileCardState();
}

class _ProfileCardState extends State<_ProfileCard> {
  UserProfile? _profile;

  // En las pruebas de widgets no hay base de datos.
  UserProfileDao? get _dao => getIt.isRegistered<UserProfileDao>() ? getIt<UserProfileDao>() : null;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final profile = await _dao?.getProfile();
    if (mounted) setState(() => _profile = profile);
  }

  Future<void> _editName() async {
    final controller = TextEditingController(text: _profile?.name ?? '');
    final name = await showDialog<String>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Tu nombre'),
        content: TextField(
          controller: controller,
          autofocus: true,
          textCapitalization: TextCapitalization.words,
          decoration: const InputDecoration(labelText: 'Nombre'),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(dialogContext), child: const Text('Cancelar')),
          ElevatedButton(
            onPressed: () => Navigator.pop(dialogContext, controller.text.trim()),
            child: const Text('Guardar'),
          ),
        ],
      ),
    );
    if (name == null || name.isEmpty) return;
    await _dao?.updateProfileName(name);
    await _load();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final name = _profile?.name?.trim();
    final since = _profile?.registrationDate;
    final initial = name == null || name.isEmpty ? 'K' : name.characters.first.toUpperCase();
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        gradient: context.kc.brandGradient,
        borderRadius: BorderRadius.circular(28),
        boxShadow: [context.kc.shadow],
      ),
      child: Row(
        children: [
          Container(
            width: 58,
            height: 58,
            alignment: Alignment.center,
            decoration: BoxDecoration(color: Colors.white.withValues(alpha: 0.22), shape: BoxShape.circle),
            child: Text(initial,
                style: theme.textTheme.headlineSmall?.copyWith(color: Colors.white, fontWeight: FontWeight.w800)),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  name == null || name.isEmpty ? 'Tu perfil' : name,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: theme.textTheme.titleLarge?.copyWith(color: Colors.white, fontWeight: FontWeight.w800),
                ),
                Text(
                  since == null
                      ? 'Agrega tu nombre'
                      : 'En Kiolog desde ${DateFormat("MMMM 'de' yyyy", 'es').format(since.toLocal())}',
                  style: theme.textTheme.bodySmall?.copyWith(color: Colors.white.withValues(alpha: 0.85)),
                ),
              ],
            ),
          ),
          Material(
            color: Colors.white.withValues(alpha: 0.22),
            shape: const CircleBorder(),
            child: IconButton(
              tooltip: 'Editar nombre',
              onPressed: _editName,
              icon: const Icon(IconsaxPlusLinear.edit_2, color: Colors.white, size: 20),
            ),
          ),
        ],
      ),
    );
  }
}

class _SectionLabel extends StatelessWidget {
  const _SectionLabel(this.text, {this.trailing});

  final String text;
  final String? trailing;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.fromLTRB(6, 6, 6, 8),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(text, style: theme.textTheme.labelSmall?.copyWith(fontSize: 11)),
          if (trailing != null) Text(trailing!, style: theme.textTheme.bodySmall),
        ],
      ),
    );
  }
}

class _TileIcon extends StatelessWidget {
  const _TileIcon({required this.child, required this.background});

  final Widget child;
  final Color background;

  @override
  Widget build(BuildContext context) => Container(
        width: 44,
        height: 44,
        alignment: Alignment.center,
        decoration: BoxDecoration(color: background, borderRadius: BorderRadius.circular(15)),
        child: child,
      );
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
    final kc = context.kc;
    final cs = Theme.of(context).colorScheme;
    final (wash, ink) = switch (module) {
      AppModule.nutrition => (kc.foodWash, kc.foodInk),
      AppModule.water => (kc.waterWash, kc.waterInk),
      AppModule.exercise => (kc.gymWash, kc.gymInk),
    };
    return SwitchListTile(
      secondary: _TileIcon(
        background: value ? wash : cs.surfaceContainerHigh,
        child: switch (module) {
          AppModule.nutrition => KiologGlyph(KiologGlyphKind.bowl, size: 22, color: value ? ink : cs.outline),
          AppModule.water => Icon(IconsaxPlusBold.drop, size: 22, color: value ? ink : cs.outline),
          AppModule.exercise => KiologGlyph(KiologGlyphKind.dumbbell, size: 22, color: value ? ink : cs.outline),
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
    required this.tint,
    required this.ink,
    required this.title,
    required this.subtitle,
    this.onTap,
    this.badge,
  });

  final IconData icon;
  final Color tint;
  final Color ink;
  final String title;
  final String subtitle;
  final VoidCallback? onTap;

  /// Una etiqueta en lugar de la flecha, como "Pronto".
  final String? badge;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return ListTile(
      leading: _TileIcon(background: tint, child: Icon(icon, size: 22, color: ink)),
      title: Text(title, style: theme.textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w700)),
      subtitle: Text(subtitle),
      trailing: badge != null
          ? Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
              decoration: ShapeDecoration(color: theme.colorScheme.surfaceContainerHigh, shape: const StadiumBorder()),
              child: Text(badge!, style: theme.textTheme.labelSmall),
            )
          : onTap == null
              ? null
              : Icon(IconsaxPlusLinear.arrow_right_3, size: 18, color: theme.colorScheme.onSurfaceVariant),
      onTap: onTap,
    );
  }
}

/// Versión de la app; se mantiene a mano con la de pubspec.yaml.
const _appVersion = '1.0.1';

class _AboutCard extends StatelessWidget {
  const _AboutCard();

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.only(top: 6),
      child: Column(
        children: [
          Image.asset(
            'assets/img/splash_logo.png',
            width: 44,
            height: 44,
            errorBuilder: (_, __, ___) => const SizedBox(width: 44, height: 44),
          ),
          const SizedBox(height: 6),
          Text('Kiolog $_appVersion', style: theme.textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w800)),
          const SizedBox(height: 2),
          Text(
            'Tus datos se quedan en tu teléfono.',
            textAlign: TextAlign.center,
            style: theme.textTheme.bodySmall,
          ),
        ],
      ),
    );
  }
}
