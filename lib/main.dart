// lib/main.dart
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'core/dao/user_profile_dao.dart';
import 'core/di/injection.dart';
import 'core/modules/cubit/modules_cubit.dart';
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
        theme: AppTheme.dark,
        darkTheme: AppTheme.dark,
        themeMode: ThemeMode.dark,
        routerConfig: createRouter(
          initialLocation: onboardingComplete ? '/' : '/onboarding',
        ),
        debugShowCheckedModeBanner: false,
      ),
    );
  }
}
