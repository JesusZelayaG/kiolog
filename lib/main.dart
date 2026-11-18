// lib/main.dart
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'core/dao/user_profile_dao.dart';
import 'core/database/app_database.dart';
import 'core/database/backup_service.dart';
import 'core/di/injection.dart';
import 'core/modules/cubit/modules_cubit.dart';
import 'core/notifications/consultation_reminders.dart';
import 'core/notifications/notification_service.dart';
import 'core/router/app_router.dart';
import 'core/theme/app_theme.dart';
import 'core/theme/theme_cubit.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  // Solo vertical: el diseño no está hecho para horizontal.
  await SystemChrome.setPreferredOrientations([DeviceOrientation.portraitUp]);
  await initializeDateFormatting('es', null);
  await NotificationService.init();
  await setupDependencies();

  final onboardingComplete =
      await getIt<UserProfileDao>().isOnboardingComplete();
  final themeCubit = await ThemeCubit.load();

  runApp(KiologApp(onboardingComplete: onboardingComplete, themeCubit: themeCubit));
  _scheduleAutoBackups();
  _restoreConsultationReminders();
}

/// Los avisos de la próxima consulta se reponen al abrir la app, también
/// después de restaurar un respaldo.
Future<void> _restoreConsultationReminders() async {
  try {
    final at = (await getIt<UserProfileDao>().getProfile())?.nextConsultationAt;
    if (at == null || at.isBefore(DateTime.now())) return;
    await NotificationService.requestPermission();
    await scheduleConsultationReminders(at.toLocal());
  } catch (_) {}
}

/// Un respaldo diario en Descargas/Kiolog, al abrir o al volver a la app.
void _scheduleAutoBackups() {
  Future<void> backup() async {
    if (!await getIt<UserProfileDao>().isOnboardingComplete()) return;
    await BackupService(getIt<AppDatabase>()).autoBackupIfDue();
  }

  backup();
  // WidgetsBinding retiene el listener como observador.
  AppLifecycleListener(onResume: backup);
}

class KiologApp extends StatefulWidget {
  final bool onboardingComplete;
  final ThemeCubit? themeCubit;

  const KiologApp({super.key, required this.onboardingComplete, this.themeCubit});

  @override
  State<KiologApp> createState() => _KiologAppState();
}

class _KiologAppState extends State<KiologApp> {
  late final _themeCubit = widget.themeCubit ?? ThemeCubit(KiologThemeId.fallback);
  // El router se crea una vez: cambiar de tema no debe reiniciar la navegación.
  late final _router = createRouter(
    initialLocation: widget.onboardingComplete ? '/' : '/onboarding',
  );

  @override
  Widget build(BuildContext context) {
    return MultiBlocProvider(
      providers: [
        BlocProvider<ModulesCubit>.value(value: getIt<ModulesCubit>()),
        BlocProvider<ThemeCubit>.value(value: _themeCubit),
      ],
      child: BlocBuilder<ThemeCubit, KiologThemeId>(
        builder: (context, themeId) => MaterialApp.router(
          title: 'Kiolog',
          // Calendarios, relojes y botones de Material en español.
          locale: const Locale('es'),
          supportedLocales: const [Locale('es')],
          localizationsDelegates: GlobalMaterialLocalizations.delegates,
          theme: AppTheme.of(themeId),
          routerConfig: _router,
          debugShowCheckedModeBanner: false,
        ),
      ),
    );
  }
}
