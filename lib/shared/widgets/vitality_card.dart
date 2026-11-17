// lib/shared/widgets/vitality_card.dart
import 'package:flutter/material.dart';
import 'package:kiolog/core/theme/app_theme.dart';

/// Tarjeta "pebble" de Luminous Tropical.
class VitalityCard extends StatelessWidget {
  final Widget child;
  final EdgeInsetsGeometry? padding;
  final VoidCallback? onTap;
  final Color? color;

  const VitalityCard({
    super.key,
    required this.child,
    this.padding,
    this.onTap,
    this.color,
  });

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final radius = BorderRadius.circular(Tropical.cardRadius);
    return DecoratedBox(
      decoration: BoxDecoration(
        borderRadius: radius,
        boxShadow: [context.kc.shadow],
      ),
      child: Material(
        color: color ?? cs.surfaceContainerLowest,
        borderRadius: radius,
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: onTap,
          child: Padding(
            padding: padding ?? const EdgeInsets.all(20),
            child: child,
          ),
        ),
      ),
    );
  }
}
