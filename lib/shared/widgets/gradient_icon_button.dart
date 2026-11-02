import 'package:flutter/material.dart';
import 'package:kiolog/core/theme/app_theme.dart';

/// Botón redondo de acción secundaria, con lavado menta.
class GradientIconButton extends StatelessWidget {
  final IconData icon;
  final VoidCallback onPressed;

  const GradientIconButton({
    super.key,
    required this.icon,
    required this.onPressed,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 4),
      child: Material(
        color: Tropical.mintWash,
        shape: const CircleBorder(),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: onPressed,
          child: SizedBox(
            width: 44,
            height: 44,
            child: Icon(icon, color: Theme.of(context).colorScheme.primary, size: 22),
          ),
        ),
      ),
    );
  }
}
