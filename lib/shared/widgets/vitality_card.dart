// lib/shared/widgets/vitality_card.dart
import 'package:flutter/material.dart';

class VitalityCard extends StatelessWidget {
  final Widget child;
  final EdgeInsetsGeometry? padding;
  final VoidCallback? onTap;

  const VitalityCard({
    super.key,
    required this.child,
    this.padding,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Card(
      color: cs.surfaceContainer,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(color: cs.outlineVariant, width: 0.5),
      ),
      elevation: 0,
      clipBehavior: Clip.antiAlias,
      child: onTap != null
          ? InkWell(
              onTap: onTap,
              child: Padding(
                padding: padding ?? const EdgeInsets.all(16),
                child: child,
              ),
            )
          : Padding(
              padding: padding ?? const EdgeInsets.all(16),
              child: child,
            ),
    );
  }
}
