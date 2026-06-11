// lib/shared/widgets/vitality_progress_bar.dart
import 'package:flutter/material.dart';

class VitalityProgressBar extends StatelessWidget {
  final double value;
  final Color? color;
  final double height;

  const VitalityProgressBar({
    super.key,
    required this.value,
    this.color,
    this.height = 8,
  });

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return SizedBox(
      height: height,
      child: LinearProgressIndicator(
        value: value.clamp(0.0, 1.0),
        color: color ?? cs.primaryContainer,
        backgroundColor: cs.surfaceContainerHigh,
        borderRadius: BorderRadius.circular(100),
        minHeight: height,
      ),
    );
  }
}
