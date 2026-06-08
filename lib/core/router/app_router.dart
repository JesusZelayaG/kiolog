// lib/core/router/app_router.dart
import 'package:go_router/go_router.dart';
import '../../features/home/presentation/pages/home_page.dart';
import '../../features/nutrition/presentation/pages/nutrition_page.dart';
import '../../features/exercise/presentation/pages/exercise_page.dart';
import '../../features/progress/presentation/pages/progress_page.dart';
import '../../features/settings/presentation/pages/settings_page.dart';
import '../../features/sleep/presentation/pages/sleep_page.dart';
import '../../features/water/presentation/pages/water_page.dart';
import '../../shared/widgets/app_scaffold.dart';

final appRouter = GoRouter(
  initialLocation: '/',
  routes: [
    ShellRoute(
      builder: (context, state, child) => AppScaffold(child: child),
      routes: [
        GoRoute(
          path: '/',
          builder: (context, state) => const HomePage(),
        ),
        GoRoute(
          path: '/nutrition',
          builder: (context, state) => const NutritionPage(),
        ),
        GoRoute(
          path: '/exercise',
          builder: (context, state) => const ExercisePage(),
        ),
        GoRoute(
          path: '/progress',
          builder: (context, state) => const ProgressPage(),
        ),
        GoRoute(
          path: '/settings',
          builder: (context, state) => const SettingsPage(),
        ),
      ],
    ),
    GoRoute(
      path: '/water',
      builder: (context, state) => const WaterPage(),
    ),
    GoRoute(
      path: '/sleep',
      builder: (context, state) => const SleepPage(),
    ),
  ],
);
