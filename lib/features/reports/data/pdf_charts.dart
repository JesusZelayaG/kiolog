import 'dart:math' as math;

import 'package:intl/intl.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;

/// Colores de las gráficas. El par pasa el validador de daltonismo sobre
/// fondo claro; el texto nunca usa el color de una serie.
abstract final class ChartColors {
  static final primary = PdfColor.fromHex('#00785A');
  static final secondary = PdfColor.fromHex('#D97B1E');
  static final ink = PdfColor.fromHex('#1F2937');
  static final muted = PdfColor.fromHex('#6B7280');
  static final grid = PdfColor.fromHex('#E7E5E4');
  static final goal = PdfColor.fromHex('#78716C');
}

class ChartSeries {
  const ChartSeries(this.label, this.color, this.values);

  final String label;
  final PdfColor color;

  /// Un valor por fecha; null es un día sin registro.
  final List<double?> values;
}

const _axisWidth = 30.0;
const _xLabelHeight = 14.0;
const _topPad = 8.0;
const _gap = 2.0;
const _radius = 2.0;

/// Barras por día. Con dos series se apilan (la primera abajo).
pw.Widget barChart({
  required List<DateTime> dates,
  required List<ChartSeries> series,
  double? goal,
  String? goalLabel,
  String Function(double)? yFormat,
  double height = 120,
}) {
  final totals = [
    for (var i = 0; i < dates.length; i++)
      series.fold<double>(0, (sum, s) => sum + (s.values[i] ?? 0)),
  ];
  final top = _niceMax(math.max(totals.fold(0.0, math.max), goal ?? 0));
  return _frame(
    dates: dates,
    series: series,
    min: 0,
    max: top,
    goal: goal,
    goalLabel: goalLabel,
    yFormat: yFormat,
    height: height,
    plot: (canvas, w, h) {
      final slot = w / dates.length;
      final barWidth = math.max(1.0, slot - _gap);
      for (var i = 0; i < dates.length; i++) {
        var base = 0.0;
        final x = i * slot + (slot - barWidth) / 2;
        for (final (index, s) in series.indexed) {
          final value = s.values[i] ?? 0;
          if (value <= 0) continue;
          final y0 = base / top * h;
          final y1 = (base + value) / top * h;
          final isTop = index == series.length - 1 ||
              series.skip(index + 1).every((o) => (o.values[i] ?? 0) <= 0);
          // Hueco de superficie entre segmentos apilados.
          final bottom = base > 0 ? y0 + _gap / 2 : y0;
          _bar(canvas, x, bottom, barWidth, y1 - bottom, s.color, roundTop: isTop);
          base += value;
        }
      }
    },
  );
}

/// Línea por día; une los días con registro saltando los vacíos.
pw.Widget lineChart({
  required List<DateTime> dates,
  required ChartSeries series,
  String Function(double)? yFormat,
  double height = 130,
}) {
  final present = series.values.whereType<double>().toList();
  if (present.isEmpty) return pw.SizedBox();
  final low = present.reduce(math.min);
  final high = present.reduce(math.max);
  final span = math.max(high - low, 1.0);
  final step = _niceStep(span / 3);
  final min = (low / step).floor() * step;
  final ceiling = (high / step).ceil() * step;
  final max = ceiling > min ? ceiling : min + step;
  return _frame(
    dates: dates,
    series: [series],
    min: min,
    max: max,
    step: step,
    yFormat: yFormat,
    height: height,
    plot: (canvas, w, h) {
      final slot = w / dates.length;
      final points = <PdfPoint>[
        for (var i = 0; i < dates.length; i++)
          if (series.values[i] != null)
            PdfPoint(i * slot + slot / 2, (series.values[i]! - min) / (max - min) * h),
      ];
      canvas
        ..setStrokeColor(series.color)
        ..setLineWidth(1.5)
        ..setLineJoin(PdfLineJoin.round)
        ..setLineCap(PdfLineCap.round);
      for (final (i, p) in points.indexed) {
        i == 0 ? canvas.moveTo(p.x, p.y) : canvas.lineTo(p.x, p.y);
      }
      if (points.length > 1) canvas.strokePath();
      for (final p in points) {
        // Anillo de superficie para que el punto se lea sobre la línea.
        canvas
          ..setFillColor(PdfColors.white)
          ..drawEllipse(p.x, p.y, 3.4, 3.4)
          ..fillPath()
          ..setFillColor(series.color)
          ..drawEllipse(p.x, p.y, 2.4, 2.4)
          ..fillPath();
      }
    },
  );
}

/// Leyenda para gráficas con más de una serie.
pw.Widget chartLegend(List<ChartSeries> series) => pw.Wrap(
      spacing: 12,
      children: [
        for (final s in series)
          pw.Row(mainAxisSize: pw.MainAxisSize.min, children: [
            pw.Container(
              width: 8,
              height: 8,
              decoration: pw.BoxDecoration(
                color: s.color,
                borderRadius: pw.BorderRadius.circular(2),
              ),
            ),
            pw.SizedBox(width: 4),
            pw.Text(s.label, style: pw.TextStyle(fontSize: 8, color: ChartColors.ink)),
          ]),
      ],
    );

pw.Widget _frame({
  required List<DateTime> dates,
  required List<ChartSeries> series,
  required double min,
  required double max,
  required double height,
  required void Function(PdfGraphics canvas, double w, double h) plot,
  double? step,
  double? goal,
  String? goalLabel,
  String Function(double)? yFormat,
}) {
  final tickStep = step ?? _niceStep((max - min) / 4);
  final ticks = <double>[
    for (var v = min; v <= max + tickStep / 1000; v += tickStep) v,
  ];
  final format = yFormat ?? _plain;
  final topPad = goalLabel != null ? _topPad + 10 : _topPad;
  final plotHeight = height - _xLabelHeight - topPad;
  double yOf(double v) => topPad + plotHeight - (v - min) / (max - min) * plotHeight;

  return pw.LayoutBuilder(builder: (context, constraints) {
    final width = constraints!.maxWidth;
    final plotWidth = width - _axisWidth;
    final slot = plotWidth / dates.length;
    final every = math.max(1, (dates.length / 10).ceil());
    final dayFormat = DateFormat('d MMM', 'es');

    return pw.SizedBox(
      width: width,
      height: height,
      child: pw.Stack(children: [
        pw.Positioned(
          left: _axisWidth,
          top: topPad,
          child: pw.CustomPaint(
            size: PdfPoint(plotWidth, plotHeight),
            painter: (canvas, size) {
              // Cuadrícula tenue, detrás de los datos.
              canvas
                ..setStrokeColor(ChartColors.grid)
                ..setLineWidth(0.5);
              for (final t in ticks) {
                final y = (t - min) / (max - min) * size.y;
                canvas
                  ..moveTo(0, y)
                  ..lineTo(size.x, y)
                  ..strokePath();
              }
              plot(canvas, size.x, size.y);
              if (goal != null && goal > min && goal <= max) {
                final y = (goal - min) / (max - min) * size.y;
                canvas
                  ..saveContext()
                  ..setStrokeColor(ChartColors.goal)
                  ..setLineWidth(1)
                  ..setLineDashPattern([3, 2])
                  ..moveTo(0, y)
                  ..lineTo(size.x, y)
                  ..strokePath()
                  ..restoreContext();
              }
            },
          ),
        ),
        for (final t in ticks)
          pw.Positioned(
            left: 0,
            top: yOf(t) - 4,
            child: pw.SizedBox(
              width: _axisWidth - 4,
              child: pw.Text(format(t),
                  textAlign: pw.TextAlign.right,
                  style: pw.TextStyle(fontSize: 7, color: ChartColors.muted)),
            ),
          ),
        if (goal != null && goalLabel != null && goal <= max)
          pw.Positioned(
            right: 0,
            top: 0,
            child: pw.Row(mainAxisSize: pw.MainAxisSize.min, children: [
              pw.CustomPaint(
                size: const PdfPoint(14, 6),
                painter: (canvas, size) => canvas
                  ..setStrokeColor(ChartColors.goal)
                  ..setLineWidth(1)
                  ..setLineDashPattern([3, 2])
                  ..moveTo(0, size.y / 2)
                  ..lineTo(size.x, size.y / 2)
                  ..strokePath(),
              ),
              pw.SizedBox(width: 3),
              pw.Text(goalLabel,
                  style: pw.TextStyle(fontSize: 7, color: ChartColors.ink)),
            ]),
          ),
        for (var i = 0; i < dates.length; i += every)
          pw.Positioned(
            // Sin salirse del borde derecho.
            left: math.min(_axisWidth + i * slot + slot / 2 - 16, width - 32),
            top: height - _xLabelHeight + 3,
            child: pw.SizedBox(
              width: 32,
              child: pw.Text(dayFormat.format(dates[i]),
                  textAlign: pw.TextAlign.center,
                  style: pw.TextStyle(fontSize: 7, color: ChartColors.muted)),
            ),
          ),
      ]),
    );
  });
}

/// Barra anclada a la base con el extremo de datos redondeado.
void _bar(PdfGraphics canvas, double x, double y, double w, double h, PdfColor color,
    {required bool roundTop}) {
  if (h <= 0) return;
  final r = roundTop ? math.min(_radius, math.min(w / 2, h)) : 0.0;
  canvas.setFillColor(color);
  if (r == 0) {
    canvas.drawRect(x, y, w, h);
  } else {
    canvas
      ..drawRRect(x, y, w, h, r, r)
      ..fillPath()
      ..drawRect(x, y, w, h - r);
  }
  canvas.fillPath();
}

double _niceStep(double raw) {
  if (raw <= 0) return 1;
  final magnitude = math.pow(10, (math.log(raw) / math.ln10).floor()).toDouble();
  for (final m in const [1, 2, 2.5, 5, 10]) {
    if (m * magnitude >= raw) return m * magnitude;
  }
  return 10 * magnitude;
}

double _niceMax(double value) {
  if (value <= 0) return 1;
  final step = _niceStep(value / 4);
  return (value / step).ceil() * step;
}

/// Sin ceros de sobra: 2, 2.5, 0.25.
String _plain(double v) => v
    .toStringAsFixed(2)
    .replaceFirst(RegExp(r'0+$'), '')
    .replaceFirst(RegExp(r'\.$'), '');
