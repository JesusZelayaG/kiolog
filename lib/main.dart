// lib/main.dart
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
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

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await initializeDateFormatting('es', null);
  await NotificationService.init();
  await setupDependencies();

  final onboardingComplete =
      await getIt<UserProfileDao>().isOnboardingComplete();

  runApp(KiologApp(onboardingComplete: onboardingComplete));
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

class KiologApp extends StatelessWidget {
  final bool onboardingComplete;

  const KiologApp({super.key, required this.onboardingComplete});

  @override
  Widget build(BuildContext context) {
    return BlocProvider<ModulesCubit>.value(
      value: getIt<ModulesCubit>(),
      child: MaterialApp.router(
        title: 'Kiolog',
        theme: AppTheme.light,
        routerConfig: createRouter(
          initialLocation: onboardingComplete ? '/' : '/onboarding',
        ),
        debugShowCheckedModeBanner: false,
      ),
    );
  }
}
