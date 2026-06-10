// lib/shared/widgets/module_icon_badge.dart
import 'package:flutter/material.dart';

class ModuleIconBadge extends StatelessWidget {
  final IconData icon;
  final Color color;
  final double size;

  const ModuleIconBadge({
    super.key,
    required this.icon,
    required this.color,
    this.size = 40,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(size / 2),
      ),
      child: Icon(icon, color: color, size: size * 0.5),
    );
  }
}
