// lib/shared/widgets/app_scaffold.dart
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:kiolog/core/domain/app_module.dart';
import 'package:kiolog/core/modules/cubit/modules_cubit.dart';
import 'package:kiolog/core/modules/cubit/modules_state.dart';

const _gradientColors = [
  Color(0xFF0A8F53),
  Color(0xFF4CBF4A),
  Color(0xFF9ACD32),
];

const _navGradient = LinearGradient(
  colors: _gradientColors,
  stops: [0.0, 0.5, 1.0],
);

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

  @override
  Widget build(BuildContext context) {
    final location = GoRouterState.of(context).uri.toString();
    final currentIndex = _locationToIndex(location);

    return BlocBuilder<ModulesCubit, ModulesState>(
      builder: (context, modulesState) {
        return Scaffold(
          body: child,
          bottomNavigationBar: _CustomNavBar(
            selectedIndex: currentIndex,
            modulesState: modulesState,
            onTap: (index) {
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
          ),
        );
      },
    );
  }
}

class _CustomNavBar extends StatelessWidget {
  final int selectedIndex;
  final ModulesState modulesState;
  final ValueChanged<int> onTap;

  const _CustomNavBar({
    required this.selectedIndex,
    required this.modulesState,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final items = [
      _NavItem(
        icon: selectedIndex == 0 ? Icons.home : Icons.home_outlined,
        label: 'Inicio',
        index: 0,
      ),
      _NavItem(
        icon: selectedIndex == 1 ? Icons.restaurant : Icons.restaurant_outlined,
        label: 'Nutrición',
        index: 1,
        locked: !modulesState.isEnabled(AppModule.nutrition),
      ),
      _NavItem(
        icon: selectedIndex == 2
            ? Icons.fitness_center
            : Icons.fitness_center_outlined,
        label: 'Ejercicio',
        index: 2,
        locked: !modulesState.isEnabled(AppModule.exercise),
      ),
      _NavItem(
        icon: selectedIndex == 3 ? Icons.bar_chart : Icons.bar_chart_outlined,
        label: 'Progreso',
        index: 3,
      ),
      _NavItem(
        icon: selectedIndex == 4 ? Icons.settings : Icons.settings_outlined,
        label: 'Ajustes',
        index: 4,
      ),
    ];

    return Container(
      decoration: BoxDecoration(
        color: theme.colorScheme.surface,
        border: Border(
          top: BorderSide(
            color: theme.colorScheme.outline.withValues(alpha: 0.15),
            width: 0.5,
          ),
        ),
      ),
      child: SafeArea(
        top: false,
        child: SizedBox(
          height: 64,
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: items
                .map((item) => _NavTile(
                      item: item,
                      selected: selectedIndex == item.index,
                      onTap: () => onTap(item.index),
                    ))
                .toList(),
          ),
        ),
      ),
    );
  }
}

class _NavItem {
  final IconData icon;
  final String label;
  final int index;
  final bool locked;

  const _NavItem({
    required this.icon,
    required this.label,
    required this.index,
    this.locked = false,
  });
}

class _NavTile extends StatelessWidget {
  final _NavItem item;
  final bool selected;
  final VoidCallback onTap;

  const _NavTile({
    required this.item,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    if (selected) {
      return GestureDetector(
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          decoration: BoxDecoration(
            gradient: const LinearGradient(
              colors: [Color(0xFF062B16), Color(0xFF0D3D1E)],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
            borderRadius: BorderRadius.circular(22),
            border: Border.all(
              color: const Color(0xFF1A6B35),
              width: 0.8,
            ),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              ShaderMask(
                shaderCallback: (bounds) => _navGradient.createShader(bounds),
                blendMode: BlendMode.srcIn,
                child: Icon(item.icon, size: 20),
              ),
              const SizedBox(width: 6),
              ShaderMask(
                shaderCallback: (bounds) => _navGradient.createShader(bounds),
                blendMode: BlendMode.srcIn,
                child: Text(
                  item.label,
                  style: const TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ],
          ),
        ),
      );
    }

    // Unselected
    return GestureDetector(
      onTap: onTap,
      child: SizedBox(
        width: 60,
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            if (item.locked)
              Stack(
                clipBehavior: Clip.none,
                children: [
                  Icon(item.icon,
                      size: 22,
                      color: Colors.grey.withValues(alpha: 0.4)),
                  const Positioned(
                    right: -2,
                    top: -2,
                    child: Icon(Icons.lock, size: 10, color: Colors.grey),
                  ),
                ],
              )
            else
              ShaderMask(
                shaderCallback: (bounds) => _navGradient.createShader(bounds),
                blendMode: BlendMode.srcIn,
                child: Icon(item.icon, size: 22),
              ),
            const SizedBox(height: 3),
            Text(
              item.label,
              style: TextStyle(
                fontSize: 10,
                color: Colors.white.withValues(alpha: 0.55),
                fontWeight: FontWeight.w400,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
