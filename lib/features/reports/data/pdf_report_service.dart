import 'dart:io';
import 'package:intl/intl.dart';
import 'package:path_provider/path_provider.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import '../domain/repositories/report_repository.dart';

class PdfReportService {
  static final _green = PdfColor.fromHex('#22C55E');
  static final _teal = PdfColor.fromHex('#4EDEA3');
  static final _blue = PdfColor.fromHex('#AFC7FF');
  static final _track = PdfColor.fromHex('#E5E7EB');
  static final _heading = PdfColor.fromHex('#111827');
  static final _body = PdfColor.fromHex('#374151');
  static final _muted = PdfColor.fromHex('#6B7280');

  static Future<File> generate(ReportData data) async {
    final now = DateTime.now();
    final dateFmt = DateFormat.yMMMd('es');
    final doc = pw.Document();

    doc.addPage(
      pw.MultiPage(
        pageFormat: PdfPageFormat.a4,
        margin: const pw.EdgeInsets.all(32),
        build: (ctx) => [
          _header(data, dateFmt),
          pw.SizedBox(height: 16),
          _sectionHeading('RESUMEN'),
          pw.SizedBox(height: 6),
          ..._summaryRows(data),
          if (data.nutritionDetail != null) ...[
            pw.SizedBox(height: 16),
            _sectionHeading('NUTRICIÓN'),
            pw.SizedBox(height: 6),
            ..._nutritionRows(data.nutritionDetail!),
          ],
          if (data.exerciseDetail != null) ...[
            pw.SizedBox(height: 16),
            _sectionHeading('EJERCICIO'),
            pw.SizedBox(height: 6),
            ..._exerciseRows(data.exerciseDetail!),
          ],
          if (data.weightLogs.isNotEmpty ||
              data.latestMeasurement != null) ...[
            pw.SizedBox(height: 16),
            _sectionHeading('MEDIDAS'),
            pw.SizedBox(height: 6),
            ..._measuresRows(data, dateFmt),
          ],
          pw.SizedBox(height: 24),
          _footer(dateFmt, now),
        ],
      ),
    );

    final dir = await getTemporaryDirectory();
    final dateStr = DateFormat('yyyyMMdd').format(now);
    final file = File('${dir.path}/kiolog_reporte_$dateStr.pdf');
    await file.writeAsBytes(await doc.save());
    return file;
  }

  // ── Header ────────────────────────────────────────────────────────────────

  static pw.Widget _header(ReportData data, DateFormat fmt) {
    return pw.Column(
      crossAxisAlignment: pw.CrossAxisAlignment.start,
      children: [
        pw.Text(
          'Kiolog — Reporte de Salud',
          style: pw.TextStyle(
            fontSize: 20,
            fontWeight: pw.FontWeight.bold,
            color: _heading,
          ),
        ),
        pw.SizedBox(height: 4),
        pw.Text(
          '${fmt.format(data.start)} – ${fmt.format(data.end)}',
          style: pw.TextStyle(fontSize: 11, color: _muted),
        ),
      ],
    );
  }

  // ── Section heading ───────────────────────────────────────────────────────

  static pw.Widget _sectionHeading(String text) {
    return pw.Container(
      margin: const pw.EdgeInsets.only(bottom: 4),
      padding: const pw.EdgeInsets.only(bottom: 4),
      decoration: const pw.BoxDecoration(
        border: pw.Border(
          bottom: pw.BorderSide(color: PdfColors.grey300, width: 0.5),
        ),
      ),
      child: pw.Text(
        text,
        style: pw.TextStyle(
          fontSize: 13,
          fontWeight: pw.FontWeight.bold,
          color: _heading,
        ),
      ),
    );
  }

  // ── Bar row ───────────────────────────────────────────────────────────────

  static pw.Widget _barRow({
    required String label,
    required double fraction,
    required String valueText,
    required PdfColor color,
    double labelWidth = 130,
    double barWidth = 200,
  }) {
    final filled = barWidth * fraction.clamp(0.0, 1.0);
    return pw.Padding(
      padding: const pw.EdgeInsets.symmetric(vertical: 3),
      child: pw.Row(
        crossAxisAlignment: pw.CrossAxisAlignment.center,
        children: [
          pw.SizedBox(
            width: labelWidth,
            child: pw.Text(label,
                style: pw.TextStyle(fontSize: 10, color: _body)),
          ),
          pw.SizedBox(width: 8),
          pw.Stack(
            children: [
              pw.Container(
                width: barWidth,
                height: 10,
                decoration: pw.BoxDecoration(
                  color: _track,
                  borderRadius: pw.BorderRadius.circular(5),
                ),
              ),
              pw.Container(
                width: filled,
                height: 10,
                decoration: pw.BoxDecoration(
                  color: color,
                  borderRadius: pw.BorderRadius.circular(5),
                ),
              ),
            ],
          ),
          pw.SizedBox(width: 8),
          pw.Text(
            valueText,
            style: pw.TextStyle(
              fontSize: 10,
              color: _body,
              fontWeight: pw.FontWeight.bold,
            ),
          ),
        ],
      ),
    );
  }

  // ── Summary rows ──────────────────────────────────────────────────────────

  static List<pw.Widget> _summaryRows(ReportData data) {
    return [
      _barRow(
        label: 'Agua',
        fraction: data.waterCompliance,
        valueText:
            '${(data.waterCompliance * 100).round()}%  ${data.waterGoalDays}/${data.waterTotalDays} días',
        color: _green,
      ),
      _barRow(
        label: 'Nutrición',
        fraction: data.nutritionCompliance,
        valueText:
            '${(data.nutritionCompliance * 100).round()}%  ${data.mealsLogged}/${data.mealsTotal} comidas',
        color: _teal,
      ),
      _barRow(
        label: 'Ejercicio',
        fraction: data.exerciseCompliance,
        valueText:
            '${(data.exerciseCompliance * 100).round()}%  ${data.exerciseDays}/${data.exerciseTotalDays} días',
        color: _blue,
      ),
      if (data.sleepAverage != null)
        _barRow(
          label: 'Sueño promedio',
          fraction: (data.sleepAverage! / 9.0).clamp(0.0, 1.0),
          valueText: '${data.sleepAverage!.toStringAsFixed(1)} h/noche',
          color: _teal,
        ),
    ];
  }

  // ── Nutrition rows ────────────────────────────────────────────────────────

  static List<pw.Widget> _nutritionRows(NutritionReportData detail) {
    final widgets = <pw.Widget>[];

    if (detail.planName != null) {
      widgets.add(pw.Text(
        'Plan: ${detail.planName}',
        style: pw.TextStyle(fontSize: 11, color: _muted),
      ));
      widgets.add(pw.SizedBox(height: 8));
    }

    if (detail.mealFrequencies.isEmpty) {
      widgets.add(pw.Text(
        'Sin datos en este período',
        style: pw.TextStyle(fontSize: 10, color: _muted),
      ));
      return widgets;
    }

    // Group by mealType (already sorted by the repository)
    final grouped = <String, List<MealFrequencyEntry>>{};
    for (final e in detail.mealFrequencies) {
      grouped.putIfAbsent(e.mealType, () => []).add(e);
    }

    const order = ['desayuno', 'almuerzo', 'cena', 'snack'];
    final types = order.where(grouped.containsKey).toList()
      ..addAll(grouped.keys.where((t) => !order.contains(t)));

    for (final type in types) {
      final entries = grouped[type]!;
      final maxCount =
          entries.map((e) => e.count).reduce((a, b) => a > b ? a : b);

      widgets.add(pw.Padding(
        padding: const pw.EdgeInsets.only(top: 8, bottom: 2),
        child: pw.Text(
          type.toUpperCase(),
          style: pw.TextStyle(
            fontSize: 9,
            fontWeight: pw.FontWeight.bold,
            color: _muted,
          ),
        ),
      ));

      for (final entry in entries) {
        widgets.add(_barRow(
          label: entry.description,
          fraction: maxCount > 0 ? entry.count / maxCount : 0,
          valueText: '${entry.count}×',
          color: _teal,
          labelWidth: 150,
          barWidth: 160,
        ));
      }
    }

    return widgets;
  }

  // ── Exercise rows ─────────────────────────────────────────────────────────

  static List<pw.Widget> _exerciseRows(ExerciseReportData detail) {
    final widgets = <pw.Widget>[];

    if (detail.planName != null) {
      widgets.add(pw.Text(
        'Plan: ${detail.planName}',
        style: pw.TextStyle(fontSize: 11, color: _muted),
      ));
      widgets.add(pw.SizedBox(height: 8));
    }

    if (detail.weeklyCompliance.isEmpty) {
      widgets.add(pw.Text(
        'Sin datos en este período',
        style: pw.TextStyle(fontSize: 10, color: _muted),
      ));
    } else {
      widgets.add(pw.Text(
        'Cumplimiento semanal',
        style: pw.TextStyle(
          fontSize: 11,
          fontWeight: pw.FontWeight.bold,
          color: _body,
        ),
      ));
      widgets.add(pw.SizedBox(height: 4));

      for (final week in detail.weeklyCompliance) {
        widgets.add(_barRow(
          label: week.weekLabel,
          fraction: week.daysGoal > 0 ? week.daysDone / week.daysGoal : 0,
          valueText: '${week.daysDone}/${week.daysGoal} días',
          color: _blue,
          labelWidth: 50,
          barWidth: 220,
        ));
      }
    }

    widgets.add(pw.SizedBox(height: 8));
    widgets.add(pw.Text(
      'Rutina: ${detail.totalRoutineSessions} sesiones  ·  '
      'Cardio: ${detail.cardioSessionsCount}  ·  '
      'Ejercicio libre: ${detail.freeExerciseCount}',
      style: pw.TextStyle(fontSize: 10, color: _body),
    ));

    return widgets;
  }

  // ── Measures rows ─────────────────────────────────────────────────────────

  static List<pw.Widget> _measuresRows(ReportData data, DateFormat fmt) {
    final widgets = <pw.Widget>[];

    if (data.weightLogs.isNotEmpty) {
      widgets.add(pw.Text(
        'Evolución de peso',
        style: pw.TextStyle(
          fontSize: 11,
          fontWeight: pw.FontWeight.bold,
          color: _body,
        ),
      ));
      widgets.add(pw.SizedBox(height: 4));
      for (final log in data.weightLogs) {
        widgets.add(pw.Padding(
          padding: const pw.EdgeInsets.symmetric(vertical: 2),
          child: pw.Row(
            children: [
              pw.SizedBox(
                width: 130,
                child: pw.Text(
                  fmt.format(log.date),
                  style: pw.TextStyle(fontSize: 10, color: _muted),
                ),
              ),
              pw.Text(
                '${log.weightKg} kg',
                style: pw.TextStyle(
                  fontSize: 10,
                  color: _body,
                  fontWeight: pw.FontWeight.bold,
                ),
              ),
            ],
          ),
        ));
      }
    }

    if (data.latestMeasurement != null) {
      final m = data.latestMeasurement!;
      widgets.add(pw.SizedBox(height: 8));
      widgets.add(pw.Text(
        'Última medición (${fmt.format(m.date)})',
        style: pw.TextStyle(
          fontSize: 11,
          fontWeight: pw.FontWeight.bold,
          color: _body,
        ),
      ));
      if (m.waistCm != null) {
        widgets.add(pw.Text(
          'Cintura: ${m.waistCm} cm',
          style: pw.TextStyle(fontSize: 10, color: _body),
        ));
      }
      if (m.hipCm != null) {
        widgets.add(pw.Text(
          'Cadera: ${m.hipCm} cm',
          style: pw.TextStyle(fontSize: 10, color: _body),
        ));
      }
    }

    return widgets;
  }

  // ── Footer ────────────────────────────────────────────────────────────────

  static pw.Widget _footer(DateFormat fmt, DateTime now) {
    return pw.Text(
      'Generado por Kiolog · ${fmt.format(now)}',
      style: pw.TextStyle(fontSize: 9, color: _muted),
    );
  }
}
