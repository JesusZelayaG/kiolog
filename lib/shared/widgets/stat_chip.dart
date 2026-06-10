// lib/shared/widgets/stat_chip.dart
import 'package:flutter/material.dart';

class StatChip extends StatelessWidget {
  final String value;
  final String label;
  final Color? color;

  const StatChip({
    super.key,
    required this.value,
    required this.label,
    this.color,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          value,
          style: theme.textTheme.headlineMedium?.copyWith(
            color: color ?? cs.primary,
            fontWeight: FontWeight.w700,
          ),
        ),
        const SizedBox(height: 2),
        Text(
          label,
          style: theme.textTheme.labelSmall?.copyWith(
            color: cs.onSurfaceVariant,
          ),
          textAlign: TextAlign.center,
        ),
      ],
    );
  }
}
