// lib/shared/widgets/app_scaffold.dart
import 'dart:ui' show ImageFilter;

import 'package:flutter/material.dart';
import 'package:iconsax_plus/iconsax_plus.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:kiolog/core/domain/app_module.dart';
import 'package:kiolog/core/modules/cubit/modules_cubit.dart';
import 'package:kiolog/core/modules/cubit/modules_state.dart';
import 'package:kiolog/core/theme/app_theme.dart';
import 'package:kiolog/shared/widgets/kiolog_glyphs.dart';

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
    _NavIcon iconax(IconData idle, IconData active) =>
        _NavIcon((color, selected) => Icon(selected ? active : idle, size: 22, color: color));
    _NavIcon glyph(KiologGlyphKind kind) =>
        _NavIcon((color, selected) => KiologGlyph(kind, size: 22, color: color, filled: selected));
    final items = [
      _NavItem(icon: iconax(IconsaxPlusLinear.home_2, IconsaxPlusBold.home_2), label: 'Inicio', index: 0),
      _NavItem(
        icon: glyph(KiologGlyphKind.bowl),
        label: 'Nutrición',
        index: 1,
        locked: !modulesState.isEnabled(AppModule.nutrition),
      ),
      _NavItem(
        icon: glyph(KiologGlyphKind.dumbbell),
        label: 'Ejercicio',
        index: 2,
        locked: !modulesState.isEnabled(AppModule.exercise),
      ),
      _NavItem(icon: iconax(IconsaxPlusLinear.status_up, IconsaxPlusBold.status_up), label: 'Progreso', index: 3),
      _NavItem(icon: iconax(IconsaxPlusLinear.setting_2, IconsaxPlusBold.setting_2), label: 'Ajustes', index: 4),
    ];

    return SafeArea(
      top: false,
      minimum: const EdgeInsets.fromLTRB(14, 4, 14, 14),
      child: DecoratedBox(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(26),
          boxShadow: [context.kc.shadow],
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(26),
          child: BackdropFilter(
            filter: ImageFilter.blur(sigmaX: 16, sigmaY: 16),
            child: Container(
              height: 68,
              padding: const EdgeInsets.symmetric(horizontal: 6),
              color: theme.colorScheme.surfaceContainerLowest.withValues(alpha: 0.88),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceAround,
                children: [
                  for (final item in items)
                    _NavTile(
                      item: item,
                      selected: selectedIndex == item.index,
                      onTap: () => onTap(item.index),
                    ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// Dibuja el ícono con el color y el estado que le da la pestaña.
class _NavIcon {
  const _NavIcon(this.build);

  final Widget Function(Color color, bool selected) build;
}

class _NavItem {
  final _NavIcon icon;
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
    final color = selected ? Colors.white : cs.onSurfaceVariant.withValues(alpha: item.locked ? 0.4 : 1);
    return Semantics(
      button: true,
      selected: selected,
      label: item.label,
      child: GestureDetector(
        onTap: onTap,
        behavior: HitTestBehavior.opaque,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 350),
          curve: const Cubic(.3, 1.3, .5, 1),
          height: 48,
          padding: EdgeInsets.symmetric(horizontal: selected ? 16 : 12),
          decoration: BoxDecoration(
            gradient: selected ? context.kc.brandGradient : null,
            borderRadius: BorderRadius.circular(18),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Stack(
                clipBehavior: Clip.none,
                children: [
                  item.icon.build(color, selected),
                  if (item.locked)
                    Positioned(
                      right: -4,
                      top: -2,
                      child: Icon(IconsaxPlusBold.lock, size: 10, color: cs.outline),
                    ),
                ],
              ),
              AnimatedSize(
                duration: const Duration(milliseconds: 300),
                curve: Curves.easeOutCubic,
                child: selected
                    ? Padding(
                        padding: const EdgeInsets.only(left: 6),
                        child: Text(
                          item.label,
                          maxLines: 1,
                          style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w800, color: Colors.white),
                        ),
                      )
                    : const SizedBox.shrink(),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
