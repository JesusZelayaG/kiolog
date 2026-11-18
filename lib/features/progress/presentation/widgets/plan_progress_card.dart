import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:kiolog/core/theme/app_theme.dart';
import 'package:kiolog/shared/widgets/vitality_card.dart';

import '../../domain/plan_progress.dart';

/// Apego y cambios de medidas durante un plan de nutrición.
class PlanProgressCard extends StatelessWidget {
  const PlanProgressCard({super.key, required this.progress});

  final PlanProgress progress;

  String _signed(double change) {
    if (change.abs() < 0.05) return 'sin cambio';
    final sign = change > 0 ? '+' : '−';
    return '$sign${change.abs().toStringAsFixed(1)}';
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final dates = DateFormat('dd/MM/yy');
    final plan = progress.plan;
    // Inicio y fin del plan son instantes reales: se muestran en hora local.
    final start = dates.format((plan.periodStart ?? plan.createdAt).toLocal());
    final end = plan.periodEnd == null ? 'hoy' : dates.format(plan.periodEnd!.toLocal());
    final percent = progress.adherencePercent;
    final baseline = progress.baseline;
    final latest = progress.latest;
    return VitalityCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            plan.isActive ? 'PLAN ACTUAL' : 'PLAN ANTERIOR',
            style: theme.textTheme.labelSmall?.copyWith(color: theme.colorScheme.primary),
          ),
          Text(plan.name, style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w800)),
          Text('Del $start al $end', style: theme.textTheme.bodySmall),
          const SizedBox(height: 14),
          if (percent == null)
            Text('Comidas cumplidas: aún sin días completos', style: theme.textTheme.bodyMedium)
          else ...[
            Row(
              crossAxisAlignment: CrossAxisAlignment.baseline,
              textBaseline: TextBaseline.alphabetic,
              children: [
                Text('$percent %',
                    style: theme.textTheme.headlineSmall
                        ?.copyWith(fontWeight: FontWeight.w800, color: theme.colorScheme.primary)),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    'comidas cumplidas (${progress.mealsLogged} de ${progress.mealsExpected})',
                    style: theme.textTheme.bodySmall,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            ClipRRect(
              borderRadius: BorderRadius.circular(4),
              child: TweenAnimationBuilder<double>(
                tween: Tween(begin: 0, end: (percent / 100).clamp(0.0, 1.0)),
                duration: const Duration(milliseconds: 900),
                curve: Curves.easeOutCubic,
                builder: (context, v, _) => Stack(
                  children: [
                    Container(height: 8, color: theme.colorScheme.surfaceContainerHighest),
                    FractionallySizedBox(
                      widthFactor: v,
                      child: Container(height: 8, decoration: BoxDecoration(gradient: context.kc.brandGradient)),
                    ),
                  ],
                ),
              ),
            ),
          ],
          const SizedBox(height: 12),
          if (baseline == null)
            Text(
              'Registra una consulta para medir los cambios de este plan.',
              style: theme.textTheme.bodySmall,
            )
          else if (latest == null)
            Text(
              'Base: consulta del ${dates.format(baseline.date.toUtc())}. '
              'Los cambios aparecen con tu siguiente consulta.',
              style: theme.textTheme.bodySmall,
            )
          else ...[
            Text(
              'Cambios del ${dates.format(baseline.date.toUtc())} '
              'al ${dates.format(latest.date.toUtc())}',
              style: theme.textTheme.labelMedium,
            ),
            const SizedBox(height: 4),
            for (final item in progress.changes)
              Padding(
                padding: const EdgeInsets.only(top: 4),
                child: Row(
                  children: [
                    Expanded(child: Text(item.label, style: theme.textTheme.bodyMedium)),
                    Text(
                      '${item.before} → ${item.after} ${item.unit}',
                      style: theme.textTheme.bodySmall,
                    ),
                    SizedBox(
                      width: 84,
                      child: Text(
                        _signed(item.change),
                        textAlign: TextAlign.end,
                        style: theme.textTheme.labelLarge,
                      ),
                    ),
                  ],
                ),
              ),
          ],
        ],
      ),
    );
  }
}
