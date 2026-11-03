import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
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
          Text(plan.name, style: theme.textTheme.titleMedium),
          Text('Del $start al $end', style: theme.textTheme.bodySmall),
          const SizedBox(height: 12),
          Text(
            percent == null
                ? 'Comidas cumplidas: aún sin días completos'
                : 'Comidas cumplidas: $percent % '
                    '(${progress.mealsLogged} de ${progress.mealsExpected})',
            style: theme.textTheme.bodyMedium,
          ),
          const SizedBox(height: 8),
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
