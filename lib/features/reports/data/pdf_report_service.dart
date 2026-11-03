import 'dart:io';
import 'dart:typed_data';

import 'package:intl/intl.dart';
import 'package:path_provider/path_provider.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:kiolog/core/database/app_database.dart';

import '../domain/report_summary.dart';
import '../domain/repositories/report_repository.dart';
import 'pdf_charts.dart';

const _maxConsultations = 8;

// Las fuentes base del PDF solo cubren Latin-1: nada de «—» ni «–».

/// Reporte de cumplimiento para compartir con la nutricionista.
class PdfReportService {
  static final _heading = PdfColor.fromHex('#111827');
  static final _body = PdfColor.fromHex('#374151');
  static final _muted = PdfColor.fromHex('#6B7280');
  static final _line = PdfColor.fromHex('#E5E7EB');
  static final _surface = PdfColor.fromHex('#F5F5F4');

  static Future<File> generate(ReportData data) async {
    final dir = await getTemporaryDirectory();
    final dateStr = DateFormat('yyyyMMdd').format(DateTime.now());
    final file = File('${dir.path}/kiolog_reporte_$dateStr.pdf');
    await file.writeAsBytes(await build(data));
    return file;
  }

  static Future<Uint8List> build(ReportData data, {DateTime? now}) {
    final generatedAt = now ?? DateTime.now();
    final summary = ComplianceSummary(data.days, data.goals);
    final dates = [for (final d in data.days) d.date];
    final doc = pw.Document(title: 'Reporte de cumplimiento', author: 'Kiolog');

    doc.addPage(
      pw.MultiPage(
        pageFormat: PdfPageFormat.a4,
        margin: const pw.EdgeInsets.fromLTRB(32, 32, 32, 28),
        footer: (context) => pw.Row(
          mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
          children: [
            pw.Text(
              'Generado por Kiolog · ${DateFormat.yMMMd('es').format(generatedAt)}',
              style: pw.TextStyle(fontSize: 8, color: _muted),
            ),
            pw.Text(
              'Página ${context.pageNumber} de ${context.pagesCount}',
              style: pw.TextStyle(fontSize: 8, color: _muted),
            ),
          ],
        ),
        build: (context) => [
          _header(data, summary),
          pw.SizedBox(height: 14),
          _kpis(summary, data.goals),
          if (dates.isNotEmpty) ...[
            if (summary.weights.isNotEmpty) ...[
              _section('Peso'),
              _weightLine(summary),
              pw.SizedBox(height: 4),
              lineChart(
                dates: dates,
                series: ChartSeries('Peso', ChartColors.primary,
                    [for (final d in data.days) d.weightKg]),
                yFormat: (v) => v.toStringAsFixed(1),
              ),
            ],
            _section('Cumplimiento por semana'),
            _weeklyTable(data),
            _section('Alimentación'),
            _note('Comidas registradas por día. La línea marca la meta del plan '
                '(${data.goals.mealsPerDay} al día).'),
            _mealsChart(data, dates),
            ..._mealFrequencies(data.nutritionDetail),
            _section('Ejercicio y cardio'),
            _note('Días con rutina o ejercicio libre, y días con cardio. '
                'Meta: ${data.goals.routineDaysPerWeek} días de rutina y '
                '${data.goals.cardioDaysPerWeek} de cardio por semana.'),
            _activityCalendar(data.days),
            pw.SizedBox(height: 10),
            _note('Minutos de cardio por día. La línea marca la meta por sesión.'),
            barChart(
              dates: dates,
              series: [
                ChartSeries('Cardio', ChartColors.primary,
                    [for (final d in data.days) d.cardioMinutes.toDouble()]),
              ],
              goal: data.goals.cardioMinutes.toDouble(),
              goalLabel: 'Meta ${data.goals.cardioMinutes} min',
              height: 110,
            ),
            ..._cardioTable(data.cardioLogs),
            _section('Agua'),
            _note('Litros por día.'),
            barChart(
              dates: dates,
              series: [
                ChartSeries('Agua', ChartColors.primary,
                    [for (final d in data.days) d.waterMl / 1000]),
              ],
              goal: data.goals.waterMl / 1000,
              goalLabel: 'Meta ${_liters(data.goals.waterMl)} L',
              height: 110,
            ),
            _section('Sueño'),
            _note('Horas dormidas por noche.'),
            barChart(
              dates: dates,
              series: [
                ChartSeries('Sueño', ChartColors.primary,
                    [for (final d in data.days) d.sleepHours]),
              ],
              height: 110,
            ),
            _section('Bitácora diaria'),
            _dailyTable(data),
          ] else
            _note('No hay días registrados en este periodo.'),
          if (data.consultations.isNotEmpty) ...[
            _section('Evolución por consulta'),
            _consultations(data.consultations),
          ],
        ],
      ),
    );
    return doc.save();
  }

  // ── Encabezado y resumen ──────────────────────────────────────────────────

  static pw.Widget _header(ReportData data, ComplianceSummary summary) {
    final fmt = DateFormat.yMMMd('es');
    final plans = [
      if (data.nutritionDetail?.planName != null)
        'Plan de alimentación: ${data.nutritionDetail!.planName}',
      if (data.exerciseDetail?.planName != null)
        'Rutina: ${data.exerciseDetail!.planName}',
    ];
    return pw.Column(
      crossAxisAlignment: pw.CrossAxisAlignment.start,
      children: [
        pw.Text('Reporte de cumplimiento',
            style: pw.TextStyle(fontSize: 20, fontWeight: pw.FontWeight.bold, color: _heading)),
        if (data.personName?.trim().isNotEmpty == true)
          pw.Text(data.personName!.trim(),
              style: pw.TextStyle(fontSize: 13, color: _body)),
        pw.SizedBox(height: 4),
        pw.Text(
          '${fmt.format(data.start)} al ${fmt.format(data.end)}'
          ' · ${summary.dayCount} ${summary.dayCount == 1 ? 'día' : 'días'} registrables',
          style: pw.TextStyle(fontSize: 10, color: _muted),
        ),
        if (plans.isNotEmpty)
          pw.Text(plans.join('  ·  '), style: pw.TextStyle(fontSize: 10, color: _muted)),
      ],
    );
  }

  static pw.Widget _kpis(ComplianceSummary s, ReportGoals goals) {
    String pct(int done, int expected) {
      final p = ComplianceSummary.percent(done, expected);
      return p == null ? '-' : '$p %';
    }

    final change = s.weightChange;
    final weights = s.weights;
    final tiles = [
      _tile('Alimentación', pct(s.meals, s.mealsExpected),
          '${s.meals} de ${s.mealsExpected} comidas · ${s.mealsFromPlan} del plan'),
      _tile('Ejercicio', pct(s.exerciseDays, s.exerciseDaysExpected),
          '${s.exerciseDays} días · meta ${s.exerciseDaysExpected}'),
      _tile('Cardio', pct(s.cardioDays, s.cardioDaysExpected),
          '${s.cardioDays} días · ${s.cardioMinutes} min en total'),
      _tile('Agua', pct(s.waterGoalDays, s.dayCount),
          '${s.waterGoalDays} de ${s.dayCount} días con la meta'
          '${s.waterAverageLiters == null ? '' : ' · ${s.waterAverageLiters!.toStringAsFixed(1)} L/día'}'),
      _tile('Sueño',
          s.sleepAverage == null ? '-' : '${s.sleepAverage!.toStringAsFixed(1)} h',
          '${s.nightsLogged} noches registradas'),
      _tile(
          'Peso',
          change == null
              ? (weights.isEmpty ? '-' : '${weights.last.toStringAsFixed(1)} kg')
              : '${change > 0 ? '+' : ''}${change.toStringAsFixed(1)} kg',
          change == null
              ? '${weights.length} registros'
              : 'de ${weights.first.toStringAsFixed(1)} a ${weights.last.toStringAsFixed(1)} kg'
                  ' · ${weights.length} registros'),
    ];
    return pw.Column(children: [
      pw.Row(children: _spaced(tiles.sublist(0, 3))),
      pw.SizedBox(height: 8),
      pw.Row(children: _spaced(tiles.sublist(3))),
    ]);
  }

  static List<pw.Widget> _spaced(List<pw.Widget> tiles) => [
        for (final (i, t) in tiles.indexed) ...[
          if (i > 0) pw.SizedBox(width: 8),
          pw.Expanded(child: t),
        ],
      ];

  static pw.Widget _tile(String label, String value, String detail) => pw.Container(
        height: 66,
        padding: const pw.EdgeInsets.all(8),
        decoration: pw.BoxDecoration(
          color: _surface,
          borderRadius: pw.BorderRadius.circular(6),
        ),
        child: pw.Column(
          crossAxisAlignment: pw.CrossAxisAlignment.start,
          children: [
            pw.Text(label.toUpperCase(),
                style: pw.TextStyle(fontSize: 7, color: _muted, fontWeight: pw.FontWeight.bold)),
            pw.SizedBox(height: 2),
            pw.Text(value,
                style: pw.TextStyle(fontSize: 18, color: _heading, fontWeight: pw.FontWeight.bold)),
            pw.Spacer(),
            pw.Text(detail, style: pw.TextStyle(fontSize: 7.5, color: _body), maxLines: 2),
          ],
        ),
      );

  // ── Secciones ─────────────────────────────────────────────────────────────

  static pw.Widget _section(String text) => pw.Container(
        margin: const pw.EdgeInsets.only(top: 16, bottom: 6),
        padding: const pw.EdgeInsets.only(bottom: 3),
        decoration: pw.BoxDecoration(
          border: pw.Border(bottom: pw.BorderSide(color: _line, width: 0.5)),
        ),
        child: pw.Text(text,
            style: pw.TextStyle(fontSize: 12, fontWeight: pw.FontWeight.bold, color: _heading)),
      );

  static pw.Widget _note(String text) => pw.Padding(
        padding: const pw.EdgeInsets.only(bottom: 4),
        child: pw.Text(text, style: pw.TextStyle(fontSize: 8.5, color: _muted)),
      );

  static pw.Widget _weightLine(ComplianceSummary s) {
    final w = s.weights;
    final low = w.reduce((a, b) => a < b ? a : b);
    final high = w.reduce((a, b) => a > b ? a : b);
    return _note('${w.length} registros · mínimo ${low.toStringAsFixed(1)} kg · '
        'máximo ${high.toStringAsFixed(1)} kg · promedio ${s.weightAverage!.toStringAsFixed(1)} kg');
  }

  static pw.Widget _mealsChart(ReportData data, List<DateTime> dates) {
    final series = [
      ChartSeries('Del plan', ChartColors.primary,
          [for (final d in data.days) d.mealsFromPlan.toDouble()]),
      ChartSeries('Fuera del plan', ChartColors.secondary,
          [for (final d in data.days) (d.meals - d.mealsFromPlan).toDouble()]),
    ];
    return pw.Column(crossAxisAlignment: pw.CrossAxisAlignment.start, children: [
      chartLegend(series),
      pw.SizedBox(height: 4),
      barChart(
        dates: dates,
        series: series,
        goal: data.goals.mealsPerDay.toDouble(),
        goalLabel: 'Meta ${data.goals.mealsPerDay}',
        height: 110,
      ),
    ]);
  }

  static List<pw.Widget> _mealFrequencies(NutritionReportData? detail) {
    if (detail == null || detail.mealFrequencies.isEmpty) return const [];
    return [
      pw.SizedBox(height: 8),
      _note('Opciones del plan que más se eligieron.'),
      _table(
        ['Tiempo', 'Opción', 'Veces'],
        [
          for (final e in detail.mealFrequencies)
            [_capitalize(e.mealType), e.description, '${e.count}'],
        ],
        widths: const {0: 80, 2: 40},
      ),
    ];
  }

  /// Una fila por semana con un cuadro por día: hecho, no hecho o sin llegar.
  static pw.Widget _activityCalendar(List<ReportDay> days) {
    final weeks = splitByWeek(days);
    const names = ['L', 'M', 'M', 'J', 'V', 'S', 'D'];
    pw.Widget cell(ReportDay? day, bool Function(ReportDay) done, String mark) {
      final filled = day != null && done(day);
      return pw.Container(
        width: 16,
        height: 16,
        margin: const pw.EdgeInsets.all(1),
        alignment: pw.Alignment.center,
        decoration: pw.BoxDecoration(
          color: filled ? ChartColors.primary : (day == null ? null : _surface),
          borderRadius: pw.BorderRadius.circular(3),
        ),
        child: filled
            ? pw.Text(mark,
                style: pw.TextStyle(fontSize: 7, color: PdfColors.white, fontWeight: pw.FontWeight.bold))
            : null,
      );
    }

    pw.Widget block(String title, bool Function(ReportDay) done, String mark) {
      return pw.Column(crossAxisAlignment: pw.CrossAxisAlignment.start, children: [
        pw.Text(title, style: pw.TextStyle(fontSize: 8, color: _body, fontWeight: pw.FontWeight.bold)),
        pw.SizedBox(height: 2),
        pw.Row(children: [
          pw.SizedBox(width: 44),
          for (final n in names)
            pw.Container(
              width: 18,
              alignment: pw.Alignment.center,
              child: pw.Text(n, style: pw.TextStyle(fontSize: 7, color: _muted)),
            ),
        ]),
        for (final week in weeks)
          pw.Row(children: [
            pw.SizedBox(
              width: 44,
              child: pw.Text(DateFormat('d MMM', 'es').format(week.first.date),
                  style: pw.TextStyle(fontSize: 7, color: _muted)),
            ),
            for (var weekday = 1; weekday <= 7; weekday++)
              cell(
                week.where((d) => d.date.weekday == weekday).firstOrNull,
                done,
                mark,
              ),
          ]),
      ]);
    }

    return pw.Row(crossAxisAlignment: pw.CrossAxisAlignment.start, children: [
      block('Ejercicio', (d) => d.exercised, 'E'),
      pw.SizedBox(width: 32),
      block('Cardio', (d) => d.cardioMinutes > 0, 'C'),
    ]);
  }

  static List<pw.Widget> _cardioTable(List<CardioLog> logs) {
    if (logs.isEmpty) return const [];
    final fmt = DateFormat('EEE d MMM', 'es');
    return [
      pw.SizedBox(height: 8),
      _note('Sesiones de cardio.'),
      _table(
        ['Fecha', 'Tipo', 'Minutos', 'Notas'],
        [
          for (final log in logs)
            [
              _capitalize(fmt.format(log.date.toUtc())),
              _capitalize(log.cardioType),
              '${log.durationMinutes}',
              log.notes ?? '',
            ],
        ],
        widths: const {0: 80, 1: 80, 2: 50},
      ),
    ];
  }

  static pw.Widget _weeklyTable(ReportData data) {
    final fmt = DateFormat('d MMM', 'es');
    String ratio(int done, int expected) => '$done/$expected';
    final rows = <List<String>>[];
    for (final week in splitByWeek(data.days)) {
      final s = ComplianceSummary(week, data.goals);
      rows.add([
        week.length == 1
            ? fmt.format(week.first.date)
            : '${fmt.format(week.first.date)} al ${fmt.format(week.last.date)}',
        ratio(s.meals, s.mealsExpected),
        ratio(s.exerciseDays, s.exerciseDaysExpected),
        '${ratio(s.cardioDays, s.cardioDaysExpected)} · ${s.cardioMinutes} min',
        ratio(s.waterGoalDays, s.dayCount),
        s.sleepAverage == null ? '-' : '${s.sleepAverage!.toStringAsFixed(1)} h',
        s.weightAverage == null ? '-' : '${s.weightAverage!.toStringAsFixed(1)} kg',
      ]);
    }
    return pw.Column(crossAxisAlignment: pw.CrossAxisAlignment.start, children: [
      _note('Hecho / esperado. Agua: días que se llegó a la meta. Peso: promedio de la semana.'),
      _table(
        ['Semana', 'Comidas', 'Ejercicio', 'Cardio', 'Agua', 'Sueño', 'Peso'],
        rows,
      ),
    ]);
  }

  static pw.Widget _dailyTable(ReportData data) {
    final fmt = DateFormat('EEE d MMM', 'es');
    return _table(
      ['Fecha', 'Comidas', 'Agua', 'Ejercicio', 'Cardio', 'Sueño', 'Peso'],
      [
        for (final d in data.days)
          [
            _capitalize(fmt.format(d.date)),
            '${d.meals}/${data.goals.mealsPerDay}',
            d.waterMl == 0 ? '-' : '${_liters(d.waterMl)} L',
            d.exercised ? 'Sí' : '-',
            d.cardioMinutes == 0 ? '-' : '${d.cardioMinutes} min',
            d.sleepHours == null ? '-' : '${d.sleepHours!.toStringAsFixed(1)} h',
            d.weightKg == null ? '-' : '${d.weightKg!.toStringAsFixed(1)} kg',
          ],
      ],
    );
  }

  static pw.Widget _consultations(List<Measurement> consultations) {
    final table = consultationTable(consultations);
    return _table(table.first, table.sublist(1));
  }

  static pw.Widget _table(List<String> headers, List<List<String>> rows,
      {Map<int, double> widths = const {}}) {
    return pw.TableHelper.fromTextArray(
      headers: headers,
      data: rows,
      columnWidths: {
        for (final e in widths.entries) e.key: pw.FixedColumnWidth(e.value),
      },
      headerStyle: pw.TextStyle(fontSize: 8, fontWeight: pw.FontWeight.bold, color: _heading),
      headerDecoration: pw.BoxDecoration(color: _surface),
      headerAlignment: pw.Alignment.centerLeft,
      cellStyle: pw.TextStyle(fontSize: 8, color: _body),
      cellAlignment: pw.Alignment.centerLeft,
      cellPadding: const pw.EdgeInsets.symmetric(horizontal: 4, vertical: 2.5),
      border: pw.TableBorder(horizontalInside: pw.BorderSide(color: _line, width: 0.5)),
    );
  }

  static String _liters(int ml) {
    final liters = ml / 1000;
    return liters == liters.roundToDouble()
        ? liters.toStringAsFixed(0)
        : liters.toStringAsFixed(1);
  }

  static String _capitalize(String text) =>
      text.isEmpty ? text : text[0].toUpperCase() + text.substring(1);

  // ── Consultas ─────────────────────────────────────────────────────────────

  static const _columns = <(String, double? Function(Measurement))>[
    ('Peso', _weightOf),
    ('Cintura', _waistOf),
    ('Cadera', _hipOf),
    ('Muslo', _thighOf),
    ('Brazo', _armOf),
    ('% Grasa', _fatOf),
  ];

  static double? _weightOf(Measurement m) => m.weightKg;
  static double? _waistOf(Measurement m) => m.waistCm;
  static double? _hipOf(Measurement m) => m.hipCm;
  static double? _thighOf(Measurement m) => m.thighCm;
  static double? _armOf(Measurement m) => m.armRelaxedCm;
  static double? _fatOf(Measurement m) => m.bodyFatPct;

  /// Encabezado, una fila por consulta reciente y el cambio total si hay varias.
  static List<List<String>> consultationTable(List<Measurement> consultations) {
    final dates = DateFormat('dd/MM/yy');
    String cell(double? value) => value == null ? '-' : value.toStringAsFixed(1);
    final shown = consultations.length > _maxConsultations
        ? consultations.sublist(consultations.length - _maxConsultations)
        : consultations;
    return [
      ['Fecha', for (final (label, _) in _columns) label],
      for (final m in shown)
        [dates.format(m.date.toUtc()), for (final (_, read) in _columns) cell(read(m))],
      if (consultations.length > 1)
        [
          'Cambio',
          for (final (_, read) in _columns)
            _change(read(consultations.first), read(consultations.last)),
        ],
    ];
  }

  static String _change(double? first, double? last) {
    if (first == null || last == null) return '-';
    final change = last - first;
    return '${change > 0 ? '+' : ''}${change.toStringAsFixed(1)}';
  }
}
