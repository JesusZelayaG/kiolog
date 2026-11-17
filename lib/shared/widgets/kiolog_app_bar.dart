import 'package:flutter/material.dart';
import 'package:iconsax_plus/iconsax_plus.dart';
import 'package:go_router/go_router.dart';

import 'gradient_icon_button.dart';

/// Encabezado de las pestañas: logo, sección y acceso al calendario.
class KiologAppBar extends StatelessWidget implements PreferredSizeWidget {
  final String title;
  final List<Widget> actions;

  const KiologAppBar({super.key, required this.title, this.actions = const []});

  @override
  Size get preferredSize => const Size.fromHeight(72);

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return AppBar(
      toolbarHeight: 72,
      titleSpacing: 16,
      title: Row(
        children: [
          ClipRRect(
            borderRadius: BorderRadius.circular(12),
            child: Image.asset(
              'assets/img/kiolog_without_background_icon.png',
              width: 44,
              height: 44,
              errorBuilder: (_, __, ___) => const SizedBox(width: 44, height: 44),
            ),
          ),
          const SizedBox(width: 10),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                'KIOLOG',
                style: theme.textTheme.labelMedium?.copyWith(color: theme.colorScheme.primary),
              ),
              Text(title, style: theme.textTheme.titleLarge),
            ],
          ),
        ],
      ),
      actions: [
        ...actions,
        GradientIconButton(
          icon: IconsaxPlusLinear.calendar_1,
          onPressed: () => context.push('/history'),
        ),
        const SizedBox(width: 12),
      ],
    );
  }
}
