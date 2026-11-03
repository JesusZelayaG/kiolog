import 'package:flutter/material.dart';
import 'package:kiolog/shared/widgets/vitality_card.dart';
import 'package:kiolog/shared/widgets/vitality_progress_bar.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:share_plus/share_plus.dart';
import '../../../../core/di/injection.dart';
import '../../domain/repositories/report_repository.dart';
import '../../data/pdf_report_service.dart';
import '../bloc/report_bloc.dart';
import '../bloc/report_event.dart';
import '../bloc/report_state.dart';

class ReportPage extends StatelessWidget {
  const ReportPage({super.key});

  @override
  Widget build(BuildContext context) {
    return BlocProvider(
      create: (_) => ReportBloc(getIt<ReportRepository>()),
      child: const _ReportView(),
    );
  }
}

class _ReportView extends StatefulWidget {
  const _ReportView();

  @override
  State<_ReportView> createState() => _ReportViewState();
}

class _ReportViewState extends State<_ReportView> {
  DateTimeRange _range = _thisMonth();

  static DateTimeRange _thisMonth() {
    final now = DateTime.now();
    return DateTimeRange(
      start: DateTime(now.year, now.month),
      end: DateTime(now.year, now.month, now.day),
    );
  }

  bool _exporting = false;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Reporte'),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => context.go('/settings'),
        ),
      ),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            _buildDateRangeSelector(context),
            const SizedBox(height: 16),
            ElevatedButton.icon(
              onPressed: () {
                context.read<ReportBloc>().add(
                      ReportGenerated(start: _range.start, end: _range.end),
                    );
              },
              icon: const Icon(Icons.assessment),
              label: const Text('Generar reporte'),
            ),
            const SizedBox(height: 24),
            BlocBuilder<ReportBloc, ReportState>(
              builder: (context, state) {
                if (state.status == ReportStatus.loading) {
                  return const Center(child: CircularProgressIndicator());
                }
                if (state.status == ReportStatus.failure) {
                  return Text('Error: ${state.error}');
                }
                if (state.status == ReportStatus.success &&
                    state.data != null) {
                  return _buildReportContent(context, state.data!);
                }
                return const SizedBox.shrink();
              },
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildDateRangeSelector(BuildContext context) {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final presets = <(String, DateTimeRange)>[
      ('Este mes', DateTimeRange(start: DateTime(now.year, now.month), end: today)),
      ('Últimos 7 días',
          DateTimeRange(start: today.subtract(const Duration(days: 6)), end: today)),
      ('Últimos 30 días',
          DateTimeRange(start: today.subtract(const Duration(days: 29)), end: today)),
    ];
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Wrap(
          spacing: 8,
          children: [
            for (final (label, range) in presets)
              ChoiceChip(
                label: Text(label),
                selected: DateUtils.isSameDay(_range.start, range.start) &&
                    DateUtils.isSameDay(_range.end, range.end),
                onSelected: (_) => setState(() => _range = range),
              ),
          ],
        ),
        const SizedBox(height: 8),
        _buildRangeCard(context),
      ],
    );
  }

  Widget _buildRangeCard(BuildContext context) {
    return VitalityCard(
      padding: EdgeInsets.zero,
      child: ListTile(
        leading: const Icon(Icons.date_range),
        title: const Text('Período'),
        subtitle: Text(
          '${DateFormat.yMMMd('es').format(_range.start)} – ${DateFormat.yMMMd('es').format(_range.end)}',
        ),
        trailing: const Icon(Icons.edit),
        onTap: () async {
          final picked = await showDateRangePicker(
            context: context,
            firstDate: DateTime(2024),
            lastDate: DateTime.now(),
            initialDateRange: _range,
          );
          if (picked != null) {
            setState(() => _range = picked);
          }
        },
      ),
    );
  }

  Widget _buildReportContent(BuildContext context, ReportData data) {
    final theme = Theme.of(context);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // ── Resumen ─────────────────────────────────────────────────────────
        Text('Resumen', style: theme.textTheme.headlineSmall),
        const SizedBox(height: 12),
        _MetricCard(
          label: 'Agua',
          value: '${(data.waterCompliance * 100).toStringAsFixed(0)}%',
          subtitle: '${data.waterGoalDays} / ${data.waterTotalDays} días meta',
        ),
        _MetricCard(
          label: 'Nutrición',
          value: '${(data.nutritionCompliance * 100).toStringAsFixed(0)}%',
          subtitle: '${data.mealsLogged} / ${data.mealsTotal} comidas',
        ),
        _MetricCard(
          label: 'Ejercicio',
          value: '${(data.exerciseCompliance * 100).toStringAsFixed(0)}%',
          subtitle: '${data.exerciseDays} / ${data.exerciseTotalDays} días',
        ),
        if (data.sleepAverage != null)
          _MetricCard(
            label: 'Sueño promedio',
            value: '${data.sleepAverage!.toStringAsFixed(1)} h',
            subtitle: 'Por noche',
          ),

        // ── Nutrición detalle ────────────────────────────────────────────────
        if (data.nutritionDetail != null &&
            data.nutritionDetail!.mealFrequencies.isNotEmpty) ...[
          const SizedBox(height: 24),
          Text('Nutrición', style: theme.textTheme.headlineSmall),
          if (data.nutritionDetail!.planName != null)
            Text(
              'Plan: ${data.nutritionDetail!.planName}',
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
          const SizedBox(height: 12),
          ..._buildFrequencySection(context, data.nutritionDetail!),
        ],

        // ── Ejercicio detalle ────────────────────────────────────────────────
        if (data.exerciseDetail != null) ...[
          const SizedBox(height: 24),
          Text('Ejercicio', style: theme.textTheme.headlineSmall),
          if (data.exerciseDetail!.planName != null)
            Text(
              'Plan: ${data.exerciseDetail!.planName}',
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
          const SizedBox(height: 12),
          ..._buildExerciseSection(context, data.exerciseDetail!),
        ],

        // ── Export button ────────────────────────────────────────────────────
        const SizedBox(height: 24),
        ElevatedButton.icon(
          onPressed: _exporting ? null : () => _exportPdf(context, data),
          icon: _exporting
              ? const SizedBox(
                  width: 16,
                  height: 16,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : const Icon(Icons.picture_as_pdf),
          label:
              Text(_exporting ? 'Generando PDF...' : 'Exportar y compartir'),
        ),
      ],
    );
  }

  List<Widget> _buildFrequencySection(
      BuildContext context, NutritionReportData detail) {
    final theme = Theme.of(context);
    final grouped = <String, List<MealFrequencyEntry>>{};
    for (final e in detail.mealFrequencies) {
      grouped.putIfAbsent(e.mealType, () => []).add(e);
    }
    const order = ['desayuno', 'almuerzo', 'cena', 'snack'];
    final types = order.where(grouped.containsKey).toList()
      ..addAll(grouped.keys.where((t) => !order.contains(t)));

    final widgets = <Widget>[];
    for (final type in types) {
      final entries = grouped[type]!;
      final maxCount =
          entries.map((e) => e.count).reduce((a, b) => a > b ? a : b);
      widgets.add(Padding(
        padding: const EdgeInsets.only(top: 12, bottom: 4),
        child: Text(
          type.toUpperCase(),
          style: theme.textTheme.labelSmall,
        ),
      ));
      for (final entry in entries) {
        widgets.add(_FrequencyBar(
          entry: entry,
          maxCount: maxCount,
          color: theme.colorScheme.secondary,
        ));
      }
    }
    return widgets;
  }

  List<Widget> _buildExerciseSection(
      BuildContext context, ExerciseReportData detail) {
    final theme = Theme.of(context);
    final widgets = <Widget>[];

    if (detail.weeklyCompliance.isEmpty) {
      widgets.add(Text(
        'Sin datos de ejercicio en este período',
        style: theme.textTheme.bodySmall?.copyWith(
          color: theme.colorScheme.onSurfaceVariant,
        ),
      ));
    } else {
      widgets.add(Text(
        'Cumplimiento semanal',
        style: theme.textTheme.titleSmall,
      ));
      widgets.add(const SizedBox(height: 8));
      for (final week in detail.weeklyCompliance) {
        widgets.add(_WeekComplianceBar(
          entry: week,
          color: theme.colorScheme.tertiary,
        ));
      }
    }

    widgets.add(const SizedBox(height: 12));
    widgets.add(VitalityCard(
      padding: const EdgeInsets.all(12),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceAround,
        children: [
          _StatChip(label: 'Rutina', value: '${detail.totalRoutineSessions}'),
          _StatChip(label: 'Cardio', value: '${detail.cardioSessionsCount}'),
          _StatChip(label: 'Libre', value: '${detail.freeExerciseCount}'),
        ],
      ),
    ));

    return widgets;
  }

  Future<void> _exportPdf(BuildContext context, ReportData data) async {
    setState(() => _exporting = true);
    final messenger = ScaffoldMessenger.of(context);
    try {
      final file = await PdfReportService.generate(data);
      if (!mounted) return;
      await SharePlus.instance.share(
        ShareParams(
          files: [XFile(file.path)],
          subject: 'Reporte Kiolog',
        ),
      );
    } catch (e) {
      if (!mounted) return;
      messenger.showSnackBar(
        SnackBar(content: Text('Error al generar PDF: $e')),
      );
    } finally {
      if (mounted) setState(() => _exporting = false);
    }
  }
}

// ── Reusable widgets ─────────────────────────────────────────────────────────

class _MetricCard extends StatelessWidget {
  final String label;
  final String value;
  final String subtitle;

  const _MetricCard({
    required this.label,
    required this.value,
    required this.subtitle,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: VitalityCard(
        padding: EdgeInsets.zero,
        child: ListTile(
          title: Text(label),
          subtitle: Text(subtitle),
          trailing: Text(
            value,
            style: Theme.of(context).textTheme.titleLarge?.copyWith(
                  color: Theme.of(context).colorScheme.primary,
                ),
          ),
        ),
      ),
    );
  }
}

class _FrequencyBar extends StatelessWidget {
  final MealFrequencyEntry entry;
  final int maxCount;
  final Color color;

  const _FrequencyBar({
    required this.entry,
    required this.maxCount,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final fraction = maxCount > 0 ? entry.count / maxCount : 0.0;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: [
          SizedBox(
            width: 140,
            child: Text(
              entry.description,
              style: theme.textTheme.bodySmall,
              overflow: TextOverflow.ellipsis,
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: VitalityProgressBar(
              value: fraction,
              color: color,
            ),
          ),
          const SizedBox(width: 8),
          SizedBox(
            width: 32,
            child: Text(
              '${entry.count}×',
              style: theme.textTheme.labelSmall?.copyWith(
                color: color,
                fontWeight: FontWeight.bold,
              ),
              textAlign: TextAlign.right,
            ),
          ),
        ],
      ),
    );
  }
}

class _WeekComplianceBar extends StatelessWidget {
  final WeeklyComplianceEntry entry;
  final Color color;

  const _WeekComplianceBar({required this.entry, required this.color});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final fraction =
        entry.daysGoal > 0 ? entry.daysDone / entry.daysGoal : 0.0;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: [
          SizedBox(
            width: 48,
            child: Text(entry.weekLabel, style: theme.textTheme.bodySmall),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: VitalityProgressBar(
              value: fraction.clamp(0.0, 1.0),
              color: color,
            ),
          ),
          const SizedBox(width: 8),
          SizedBox(
            width: 56,
            child: Text(
              '${entry.daysDone}/${entry.daysGoal} días',
              style: theme.textTheme.labelSmall?.copyWith(
                color: color,
                fontWeight: FontWeight.bold,
              ),
              textAlign: TextAlign.right,
            ),
          ),
        ],
      ),
    );
  }
}

class _StatChip extends StatelessWidget {
  final String label;
  final String value;

  const _StatChip({required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Column(
      children: [
        Text(
          value,
          style: theme.textTheme.titleMedium?.copyWith(
            color: theme.colorScheme.primary,
            fontWeight: FontWeight.bold,
          ),
        ),
        Text(label, style: theme.textTheme.labelSmall),
      ],
    );
  }
}
