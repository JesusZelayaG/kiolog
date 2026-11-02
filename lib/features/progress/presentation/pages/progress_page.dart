import 'dart:math' show min, max;
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:kiolog/core/database/app_database.dart';
import 'package:kiolog/shared/widgets/gradient_icon_button.dart';
import 'package:kiolog/shared/widgets/kiolog_app_bar.dart';
import 'package:kiolog/shared/widgets/stat_chip.dart';
import 'package:kiolog/shared/widgets/vitality_card.dart';
import '../../../../core/di/injection.dart';
import '../../domain/repositories/progress_repository.dart';
import '../bloc/progress_bloc.dart';
import '../bloc/progress_event.dart';
import '../bloc/progress_state.dart';

class ProgressPage extends StatelessWidget {
  const ProgressPage({super.key});

  @override
  Widget build(BuildContext context) {
    return BlocProvider(
      create: (_) => ProgressBloc(getIt<ProgressRepository>())
        ..add(const ProgressLoaded()),
      child: const _ProgressView(),
    );
  }
}

class _ProgressView extends StatelessWidget {
  const _ProgressView();

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;

    return Scaffold(
      appBar: KiologAppBar(
        title: 'Progreso',
        actions: [
          GradientIconButton(
            icon: Icons.straighten,
            onPressed: () => _showAddMeasurementDialog(context),
          ),
        ],
      ),
      body: BlocBuilder<ProgressBloc, ProgressState>(
        builder: (context, state) {
          if (state.status == ProgressStatus.loading) {
            return const Center(child: CircularProgressIndicator());
          }
          if (state.status == ProgressStatus.failure) {
            return Center(child: Text('Error: ${state.error}'));
          }

          final last7 = state.weightLogs.length > 7
              ? state.weightLogs.sublist(state.weightLogs.length - 7)
              : state.weightLogs;
          final latest = state.latestWeight;
          final change = state.weightChange;

          return ListView(
            padding: const EdgeInsets.all(16),
            children: [
              // Stats + chart card
              VitalityCard(
                padding: const EdgeInsets.all(16),
                child: Column(
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: StatChip(
                            value: latest != null
                                ? '${latest.toStringAsFixed(1)} kg'
                                : '—',
                            label: 'peso actual',
                            color: cs.primary,
                          ),
                        ),
                        Expanded(
                          child: StatChip(
                            value: change != null
                                ? '${change >= 0 ? '+' : ''}${change.toStringAsFixed(1)} kg'
                                : '—',
                            label: 'cambio total',
                            color: change != null
                                ? (change <= 0 ? cs.primary : cs.error)
                                : cs.onSurfaceVariant,
                          ),
                        ),
                        Expanded(
                          child: StatChip(
                            value: '${state.weightLogs.length}',
                            label: 'registros',
                            color: cs.secondary,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 20),
                    SizedBox(
                      height: 150,
                      child: last7.length >= 2
                          ? _WeightLineChart(
                              logs: last7,
                              lineColor: cs.primary,
                            )
                          : Center(
                              child: Text(
                                'Registra al menos 2 pesos para ver la gráfica',
                                style: theme.textTheme.bodySmall?.copyWith(
                                  color: cs.onSurfaceVariant,
                                ),
                                textAlign: TextAlign.center,
                              ),
                            ),
                    ),
                    const SizedBox(height: 12),
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton.icon(
                        onPressed: () => _showAddWeightDialog(context),
                        icon: const Icon(Icons.add),
                        label: const Text('Registrar peso'),
                        style: ElevatedButton.styleFrom(
                          shape: const StadiumBorder(),
                          backgroundColor: cs.primary,
                          foregroundColor: cs.onPrimary,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),

              VitalityCard(
                onTap: () => context.push('/body'),
                child: Row(
                  children: [
                    Icon(Icons.accessibility_new, color: cs.primary, size: 28),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('Tu cuerpo en 3D', style: theme.textTheme.titleMedium),
                          Text(
                            'Con las medidas de tu última consulta',
                            style: theme.textTheme.bodySmall?.copyWith(
                              color: cs.onSurfaceVariant,
                            ),
                          ),
                        ],
                      ),
                    ),
                    Icon(Icons.chevron_right, color: cs.onSurfaceVariant),
                  ],
                ),
              ),
              const SizedBox(height: 16),

              if (state.latestMeasurement != null) ...[
                _buildMeasurementsCard(context, state),
                const SizedBox(height: 16),
              ],

              if (state.weightLogs.isNotEmpty)
                _buildWeightHistory(context, state),
            ],
          );
        },
      ),
    );
  }

  Widget _buildMeasurementsCard(BuildContext context, ProgressState state) {
    final m = state.latestMeasurement!;
    final theme = Theme.of(context);

    final fields = <(String, String?)>[
      ('Talla', m.heightCm > 0 ? '${m.heightCm} cm' : null),
      ('Brazo flex', m.armFlexedCm != null ? '${m.armFlexedCm} cm' : null),
      ('Brazo relaj', m.armRelaxedCm != null ? '${m.armRelaxedCm} cm' : null),
      ('Cintura', m.waistCm != null ? '${m.waistCm} cm' : null),
      ('Cadera', m.hipCm != null ? '${m.hipCm} cm' : null),
      ('Pantorrilla', m.calfCm != null ? '${m.calfCm} cm' : null),
      ('Abdomen bajo',
          m.lowerAbdomenCm != null ? '${m.lowerAbdomenCm} cm' : null),
      ('Muslo', m.thighCm != null ? '${m.thighCm} cm' : null),
      ('Glúteo', m.midGluteusCm != null ? '${m.midGluteusCm} cm' : null),
      ('Tórax', m.chestCm != null ? '${m.chestCm} cm' : null),
      ('% Grasa', m.bodyFatPct != null ? '${m.bodyFatPct}%' : null),
      ('Masa magra', m.leanMassKg != null ? '${m.leanMassKg} kg' : null),
      ('Masa visceral',
          m.visceralMass != null ? '${m.visceralMass}' : null),
    ];

    return VitalityCard(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Última consulta', style: theme.textTheme.titleMedium),
          const SizedBox(height: 4),
          Text(
            DateFormat.yMMMd('es').format(m.date.toUtc()),
            style: theme.textTheme.bodySmall?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
          const SizedBox(height: 12),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: fields
                .where((f) => f.$2 != null)
                .map((f) => Chip(
                      label: Text('${f.$1}: ${f.$2}'),
                      backgroundColor:
                          theme.colorScheme.surfaceContainerHighest,
                      side: BorderSide.none,
                    ))
                .toList(),
          ),
        ],
      ),
    );
  }

  Widget _buildWeightHistory(BuildContext context, ProgressState state) {
    final theme = Theme.of(context);

    return VitalityCard(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Historial de peso', style: theme.textTheme.titleMedium),
          const SizedBox(height: 12),
          ...state.weightLogs.reversed.take(10).map((log) => ListTile(
                dense: true,
                contentPadding: EdgeInsets.zero,
                leading: Text(
                  DateFormat.MMMd('es').format(log.date.toUtc()),
                  style: theme.textTheme.bodyMedium,
                ),
                trailing: Text(
                  '${log.weightKg.toStringAsFixed(1)} kg',
                  style: theme.textTheme.bodyLarge
                      ?.copyWith(fontWeight: FontWeight.bold),
                ),
              )),
        ],
      ),
    );
  }

  void _showAddWeightDialog(BuildContext context) {
    final bloc = context.read<ProgressBloc>();
    final controller = TextEditingController();
    showDialog(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Registrar peso'),
        content: TextField(
          controller: controller,
          keyboardType:
              const TextInputType.numberWithOptions(decimal: true),
          decoration: const InputDecoration(
            labelText: 'Peso',
            suffixText: 'kg',
          ),
          autofocus: true,
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: const Text('Cancelar'),
          ),
          ElevatedButton(
            onPressed: () {
              final weight = double.tryParse(controller.text);
              if (weight != null && weight > 0) {
                bloc.add(ProgressWeightAdded(
                    date: DateTime.now(), weightKg: weight));
              }
              Navigator.pop(dialogContext);
            },
            child: const Text('Guardar'),
          ),
        ],
      ),
    );
  }

  void _showAddMeasurementDialog(BuildContext context) {
    final bloc = context.read<ProgressBloc>();
    final fields = {
      'Peso (kg)': TextEditingController(),
      'Talla (cm)': TextEditingController(),
      'Brazo flex (cm)': TextEditingController(),
      'Brazo relaj (cm)': TextEditingController(),
      'Cintura (cm)': TextEditingController(),
      'Cadera (cm)': TextEditingController(),
      'Pantorrilla (cm)': TextEditingController(),
      'Abdomen bajo (cm)': TextEditingController(),
      'Muslo (cm)': TextEditingController(),
      'Glúteo (cm)': TextEditingController(),
      'Tórax (cm)': TextEditingController(),
      '% Grasa': TextEditingController(),
      'Masa magra (kg)': TextEditingController(),
      'Masa visceral': TextEditingController(),
    };

    showDialog(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Nueva consulta'),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: fields.entries
                .map((e) => Padding(
                      padding: const EdgeInsets.only(bottom: 8),
                      child: TextField(
                        controller: e.value,
                        keyboardType: const TextInputType.numberWithOptions(
                            decimal: true),
                        decoration: InputDecoration(labelText: e.key),
                      ),
                    ))
                .toList(),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: const Text('Cancelar'),
          ),
          ElevatedButton(
            onPressed: () {
              final weight = double.tryParse(fields['Peso (kg)']!.text);
              final height = double.tryParse(fields['Talla (cm)']!.text);
              if (weight != null && height != null) {
                bloc.add(ProgressMeasurementAdded(
                  date: DateTime.now(),
                  weightKg: weight,
                  heightCm: height,
                  armFlexedCm: _parse(fields['Brazo flex (cm)']!.text),
                  armRelaxedCm: _parse(fields['Brazo relaj (cm)']!.text),
                  waistCm: _parse(fields['Cintura (cm)']!.text),
                  hipCm: _parse(fields['Cadera (cm)']!.text),
                  calfCm: _parse(fields['Pantorrilla (cm)']!.text),
                  lowerAbdomenCm:
                      _parse(fields['Abdomen bajo (cm)']!.text),
                  thighCm: _parse(fields['Muslo (cm)']!.text),
                  midGluteusCm: _parse(fields['Glúteo (cm)']!.text),
                  chestCm: _parse(fields['Tórax (cm)']!.text),
                  bodyFatPct: _parse(fields['% Grasa']!.text),
                  leanMassKg: _parse(fields['Masa magra (kg)']!.text),
                  visceralMass: _parse(fields['Masa visceral']!.text),
                ));
              }
              Navigator.pop(dialogContext);
            },
            child: const Text('Guardar'),
          ),
        ],
      ),
    );
  }

  double? _parse(String text) {
    final value = double.tryParse(text);
    return value != null && value > 0 ? value : null;
  }
}

// ── Weight line chart ─────────────────────────────────────────────────────────

class _WeightLineChart extends StatelessWidget {
  final List<WeightLog> logs;
  final Color lineColor;

  const _WeightLineChart({required this.logs, required this.lineColor});

  @override
  Widget build(BuildContext context) {
    return CustomPaint(
      size: Size.infinite,
      painter: _LineChartPainter(logs: logs, lineColor: lineColor),
    );
  }
}

class _LineChartPainter extends CustomPainter {
  final List<WeightLog> logs;
  final Color lineColor;

  _LineChartPainter({required this.logs, required this.lineColor});

  static const _padLeft = 44.0;
  static const _padRight = 8.0;
  static const _padTop = 8.0;
  static const _padBottom = 24.0;

  @override
  void paint(Canvas canvas, Size size) {
    if (logs.length < 2) return;

    final chartW = size.width - _padLeft - _padRight;
    final chartH = size.height - _padTop - _padBottom;

    final weights = logs.map((l) => l.weightKg).toList();
    var minW = weights.reduce(min);
    var maxW = weights.reduce(max);
    if (minW == maxW) {
      minW -= 1;
      maxW += 1;
    }
    final wRange = maxW - minW;

    final epochMs = logs.map((l) => l.date.millisecondsSinceEpoch.toDouble()).toList();
    final minD = epochMs.reduce(min);
    final maxD = epochMs.reduce(max);
    final dRange = maxD == minD ? 1.0 : maxD - minD;

    Offset toPoint(WeightLog log) => Offset(
          _padLeft + (log.date.millisecondsSinceEpoch - minD) / dRange * chartW,
          _padTop + (1 - (log.weightKg - minW) / wRange) * chartH,
        );

    // Grid lines
    final gridPaint = Paint()
      ..color = lineColor.withValues(alpha: 0.12)
      ..strokeWidth = 1;
    for (int i = 0; i <= 3; i++) {
      final y = _padTop + chartH * i / 3;
      canvas.drawLine(Offset(_padLeft, y), Offset(_padLeft + chartW, y), gridPaint);
    }

    // Fill under the line
    final firstP = toPoint(logs.first);
    final lastP = toPoint(logs.last);
    final bottomY = _padTop + chartH;

    final fillPath = Path()..moveTo(firstP.dx, bottomY)..lineTo(firstP.dx, firstP.dy);
    for (int i = 1; i < logs.length; i++) {
      final p = toPoint(logs[i]);
      fillPath.lineTo(p.dx, p.dy);
    }
    fillPath.lineTo(lastP.dx, bottomY);
    fillPath.close();

    canvas.drawPath(
      fillPath,
      Paint()
        ..shader = LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [
            lineColor.withValues(alpha: 0.25),
            lineColor.withValues(alpha: 0.0),
          ],
        ).createShader(Rect.fromLTWH(_padLeft, _padTop, chartW, chartH)),
    );

    // Line
    final linePath = Path()..moveTo(firstP.dx, firstP.dy);
    for (int i = 1; i < logs.length; i++) {
      linePath.lineTo(toPoint(logs[i]).dx, toPoint(logs[i]).dy);
    }
    canvas.drawPath(
      linePath,
      Paint()
        ..color = lineColor.withValues(alpha: 0.9)
        ..strokeWidth = 2
        ..style = PaintingStyle.stroke
        ..strokeCap = StrokeCap.round
        ..strokeJoin = StrokeJoin.round,
    );

    // Dots
    final dotFill = Paint()..color = lineColor;
    final dotBg = Paint()..color = Colors.black.withValues(alpha: 0.6);
    for (final log in logs) {
      final p = toPoint(log);
      canvas.drawCircle(p, 4.5, dotBg);
      canvas.drawCircle(p, 3, dotFill);
    }

    // Y axis labels
    final labelColor = lineColor.withValues(alpha: 0.7);
    _paintText(canvas, maxW.toStringAsFixed(1), const Offset(0, _padTop - 2), labelColor);
    _paintText(canvas, minW.toStringAsFixed(1), Offset(0, _padTop + chartH - 14), labelColor);

    // X axis labels
    final dateColor = lineColor.withValues(alpha: 0.5);
    _paintText(canvas, _fmt(logs.first.date), Offset(_padLeft, size.height - _padBottom + 6), dateColor);
    _paintTextRight(canvas, _fmt(logs.last.date), size.width - _padRight, size.height - _padBottom + 6, dateColor);
  }

  String _fmt(DateTime d) => DateFormat.MMMd('es').format(d.toUtc());

  void _paintText(Canvas canvas, String text, Offset offset, Color color) {
    final tp = TextPainter(
      text: TextSpan(text: text, style: TextStyle(color: color, fontSize: 9)),
      textDirection: ui.TextDirection.ltr,
    )..layout();
    tp.paint(canvas, offset);
  }

  void _paintTextRight(Canvas canvas, String text, double rightX, double y, Color color) {
    final tp = TextPainter(
      text: TextSpan(text: text, style: TextStyle(color: color, fontSize: 9)),
      textDirection: ui.TextDirection.ltr,
    )..layout();
    tp.paint(canvas, Offset(rightX - tp.width, y));
  }

  @override
  bool shouldRepaint(_LineChartPainter old) =>
      old.logs != logs || old.lineColor != lineColor;
}
