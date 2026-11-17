// lib/shared/widgets/app_scaffold.dart
import 'package:flutter/material.dart';
import 'package:iconsax_plus/iconsax_plus.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:kiolog/core/domain/app_module.dart';
import 'package:kiolog/core/modules/cubit/modules_cubit.dart';
import 'package:kiolog/core/modules/cubit/modules_state.dart';
import 'package:kiolog/core/theme/app_theme.dart';

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
        icon: selectedIndex == 0 ? IconsaxPlusBold.home_2 : IconsaxPlusLinear.home_2,
        label: 'Inicio',
        index: 0,
      ),
      _NavItem(
        icon: selectedIndex == 1 ? IconsaxPlusBold.reserve : IconsaxPlusLinear.reserve,
        label: 'Nutrición',
        index: 1,
        locked: !modulesState.isEnabled(AppModule.nutrition),
      ),
      _NavItem(
        icon: selectedIndex == 2 ? IconsaxPlusBold.flash : IconsaxPlusLinear.flash,
        label: 'Ejercicio',
        index: 2,
        locked: !modulesState.isEnabled(AppModule.exercise),
      ),
      _NavItem(
        icon: selectedIndex == 3 ? IconsaxPlusBold.status_up : IconsaxPlusLinear.status_up,
        label: 'Progreso',
        index: 3,
      ),
      _NavItem(
        icon: selectedIndex == 4 ? IconsaxPlusBold.setting_2 : IconsaxPlusLinear.setting_2,
        label: 'Ajustes',
        index: 4,
      ),
    ];

    return SafeArea(
      top: false,
      minimum: const EdgeInsets.fromLTRB(16, 4, 16, 12),
      child: Container(
        height: 68,
        padding: const EdgeInsets.symmetric(horizontal: 6),
        decoration: BoxDecoration(
          color: theme.colorScheme.surfaceContainerLowest,
          borderRadius: BorderRadius.circular(34),
          boxShadow: const [Tropical.softShadow],
        ),
        child: Row(
          children: items
              .map((item) => Expanded(
                    child: _NavTile(
                      item: item,
                      selected: selectedIndex == item.index,
                      onTap: () => onTap(item.index),
                    ),
                  ))
              .toList(),
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
    final cs = Theme.of(context).colorScheme;
    final color = selected
        ? Colors.white
        : cs.onSurfaceVariant.withValues(alpha: item.locked ? 0.4 : 1);
    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: Center(
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 180),
          padding: const EdgeInsets.symmetric(vertical: 6),
          width: double.infinity,
          margin: const EdgeInsets.symmetric(horizontal: 1),
          decoration: BoxDecoration(
            color: selected ? cs.primaryContainer : Colors.transparent,
            borderRadius: BorderRadius.circular(28),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Stack(
                clipBehavior: Clip.none,
                children: [
                  Icon(item.icon, size: 22, color: color),
                  if (item.locked)
                    Positioned(
                      right: -4,
                      top: -2,
                      child: Icon(IconsaxPlusBold.lock, size: 10, color: cs.outline),
                    ),
                ],
              ),
              const SizedBox(height: 2),
              Text(
                item.label,
                maxLines: 1,
                overflow: TextOverflow.fade,
                softWrap: false,
                style: TextStyle(fontSize: 10, fontWeight: FontWeight.w700, color: color),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
