// lib/shared/widgets/app_scaffold.dart
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:kiolog/core/di/injection.dart';
import 'package:kiolog/core/domain/app_module.dart';
import 'package:kiolog/core/modules/cubit/modules_cubit.dart';
import 'package:kiolog/core/modules/cubit/modules_state.dart';

class AppScaffold extends StatelessWidget {
  final Widget child;

  const AppScaffold({super.key, required this.child});

  int _locationToIndex(String location) {
    if (location.startsWith('/nutrition')) return 1;
    if (location.startsWith('/exercise')) return 2;
    if (location.startsWith('/progress')) return 3;
    if (location.startsWith('/settings')) return 4;
    return 0;
  }

  Widget _moduleIcon({
    required IconData activeIcon,
    required IconData inactiveIcon,
    required AppModule module,
    required ModulesState state,
    bool selected = false,
  }) {
    final isActive = state.isEnabled(module);
    if (isActive) return Icon(selected ? activeIcon : inactiveIcon);
    return Stack(
      clipBehavior: Clip.none,
      children: [
        Icon(selected ? activeIcon : inactiveIcon,
            color: Colors.grey.withValues(alpha: 0.4)),
        const Positioned(
          right: -4,
          top: -4,
          child: Icon(Icons.lock, size: 10, color: Colors.grey),
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final location = GoRouterState.of(context).uri.toString();
    final currentIndex = _locationToIndex(location);

    return BlocProvider<ModulesCubit>.value(
      value: getIt<ModulesCubit>(),
      child: BlocBuilder<ModulesCubit, ModulesState>(
        builder: (context, modulesState) {
          return Scaffold(
            body: child,
            bottomNavigationBar: NavigationBar(
              selectedIndex: currentIndex,
              onDestinationSelected: (index) {
                switch (index) {
                  case 0:
                    context.go('/');
                  case 1:
                    context.go('/nutrition');
                  case 2:
                    context.go('/exercise');
                  case 3:
                    context.go('/progress');
                  case 4:
                    context.go('/settings');
                }
              },
              destinations: [
                const NavigationDestination(
                  icon: Icon(Icons.home_outlined),
                  selectedIcon: Icon(Icons.home),
                  label: 'Inicio',
                ),
                NavigationDestination(
                  icon: _moduleIcon(
                    activeIcon: Icons.restaurant_outlined,
                    inactiveIcon: Icons.restaurant_outlined,
                    module: AppModule.nutrition,
                    state: modulesState,
                  ),
                  selectedIcon: _moduleIcon(
                    activeIcon: Icons.restaurant,
                    inactiveIcon: Icons.restaurant,
                    module: AppModule.nutrition,
                    state: modulesState,
                    selected: true,
                  ),
                  label: 'Nutrición',
                ),
                NavigationDestination(
                  icon: _moduleIcon(
                    activeIcon: Icons.fitness_center_outlined,
                    inactiveIcon: Icons.fitness_center_outlined,
                    module: AppModule.exercise,
                    state: modulesState,
                  ),
                  selectedIcon: _moduleIcon(
                    activeIcon: Icons.fitness_center,
                    inactiveIcon: Icons.fitness_center,
                    module: AppModule.exercise,
                    state: modulesState,
                    selected: true,
                  ),
                  label: 'Ejercicio',
                ),
                const NavigationDestination(
                  icon: Icon(Icons.bar_chart_outlined),
                  selectedIcon: Icon(Icons.bar_chart),
                  label: 'Progreso',
                ),
                const NavigationDestination(
                  icon: Icon(Icons.settings_outlined),
                  selectedIcon: Icon(Icons.settings),
                  label: 'Ajustes',
                ),
              ],
            ),
          );
        },
      ),
    );
  }
}
