import 'dart:io';
import 'dart:typed_data';

import 'package:flutter/services.dart' show rootBundle;
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
  static final _heading = PdfColor.fromHex('#0B1123');
  static final _body = PdfColor.fromHex('#1B2A22');
  static final _muted = PdfColor.fromHex('#66756C');
  static final _line = PdfColor.fromHex('#E4EBE0');
  static final _surface = PdfColor.fromHex('#F0F3EC');
  static final _zebra = PdfColor.fromHex('#F8FAF5');
  static final _deepGreen = PdfColor.fromHex('#123A28');
  static final _bandText = PdfColor.fromHex('#B9C6D2');
  static final _warn = PdfColor.fromHex('#B07A12');

  /// La franja del encabezado y la línea de abajo, en los colores del logo.
  static const _side = 30.0;
  static const _bandFirst = 82.0;
  static const _bandOther = 44.0;
  static const _stripe = 4.0;
  static final _brand = pw.LinearGradient(
    colors: [ChartColors.primary, ChartColors.lime, PdfColor.fromHex('#A8D86A')],
  );

  static Future<File> generate(ReportData data) async {
    final dir = await getTemporaryDirectory();
    final dateStr = DateFormat('yyyyMMdd').format(DateTime.now());
    final file = File('${dir.path}/kiolog_reporte_$dateStr.pdf');
    final logo = await rootBundle.load('assets/img/splash_logo.png');
    await file.writeAsBytes(await build(data, logo: logo.buffer.asUint8List()));
    return file;
  }

  /// [logo] es el PNG del logo; sin él, el encabezado va solo con texto.
  static Future<Uint8List> build(ReportData data, {DateTime? now, Uint8List? logo}) {
    final generatedAt = now ?? DateTime.now();
    final logoImage = logo == null ? null : pw.MemoryImage(logo);
    final summary = ComplianceSummary(data.days, data.goals);
    final dates = [for (final d in data.days) d.date];
    final doc = pw.Document(title: 'Reporte de cumplimiento', author: 'Kiolog');

    doc.addPage(
      pw.MultiPage(
        pageTheme: pw.PageTheme(
          pageFormat: PdfPageFormat.a4,
          margin: const pw.EdgeInsets.fromLTRB(_side, 0, _side, 24),
          // La franja azul marino llega a los bordes de la hoja.
          buildBackground: (context) => pw.FullPage(
            ignoreMargins: true,
            child: pw.Column(children: [
              pw.Container(
                height: context.pageNumber == 1 ? _bandFirst : _bandOther,
                decoration: pw.BoxDecoration(
                  gradient: pw.LinearGradient(
                    colors: [ChartColors.navy, ChartColors.navy, _deepGreen],
                    stops: const [0, 0.55, 1],
                  ),
                ),
              ),
              pw.Container(height: _stripe, decoration: pw.BoxDecoration(gradient: _brand)),
            ]),
          ),
        ),
        header: (context) => _header(data, summary, logoImage, first: context.pageNumber == 1),
        footer: (context) => pw.Container(
          padding: const pw.EdgeInsets.only(top: 6),
          decoration: pw.BoxDecoration(border: pw.Border(top: pw.BorderSide(color: _line, width: 0.5))),
          child: pw.Row(
            mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
            children: [
              pw.Text(
                'Generado por Kiolog · ${DateFormat.yMMMd('es').format(generatedAt)}',
                style: pw.TextStyle(fontSize: 7.5, color: _muted),
              ),
              pw.Text(
                'Página ${context.pageNumber} de ${context.pagesCount}',
                style: pw.TextStyle(fontSize: 7.5, color: _muted),
              ),
            ],
          ),
        ),
        build: (context) => [
          _kpis(summary, data.goals),
          if (dates.isNotEmpty) ...[
            // Cada título va con su gráfica para que no quede solo al pie.
            if (summary.weights.isNotEmpty)
              _card([
                _section('Peso'),
                _weightLine(summary),
                pw.SizedBox(height: 4),
                lineChart(
                  dates: dates,
                  series: ChartSeries('Peso', ChartColors.primary,
                      [for (final d in data.days) d.weightKg]),
                  yFormat: (v) => v.toStringAsFixed(1),
                ),
              ]),
            _card([
              _section('Cumplimiento por semana'),
              _weeklyTable(data),
            ]),
            _card([
              _section('Alimentación por día'),
              _note('Comidas registradas por día. La línea marca la meta del plan '
                  '(${data.goals.mealsPerDay} al día).'),
              _mealsChart(data, dates),
            ]),
            ..._mealChoices(data.nutritionDetail),
            _card([
              _section('Ejercicio y cardio'),
              _note('Días con rutina o ejercicio libre, y días con cardio. '
                  'Meta: ${data.goals.routineDaysPerWeek} días de rutina y '
                  '${data.goals.cardioDaysPerWeek} de cardio por semana.'),
              _activityCalendar(data.days),
            ]),
            _card([
              _section('Cardio'),
              _note('Minutos de cardio por día. La línea marca la meta por sesión.'),
              barChart(
                dates: dates,
                series: [
                  ChartSeries('Cardio', ChartColors.cardio,
                      [for (final d in data.days) d.cardioMinutes.toDouble()]),
                ],
                goal: data.goals.cardioMinutes.toDouble(),
                goalLabel: 'Meta ${data.goals.cardioMinutes} min',
                height: 110,
              ),
            ]),
            ..._cardioTable(data.cardioLogs),
            _card([
              _section('Agua'),
              _note('Litros por día.'),
              barChart(
                dates: dates,
                series: [
                  ChartSeries('Agua', ChartColors.water,
                      [for (final d in data.days) d.waterMl / 1000]),
                ],
                goal: data.goals.waterMl / 1000,
                goalLabel: 'Meta ${_liters(data.goals.waterMl)} L',
                height: 110,
              ),
            ]),
            _card([
              _section('Sueño'),
              _note('Horas dormidas por noche.'),
              barChart(
                dates: dates,
                series: [
                  ChartSeries('Sueño', ChartColors.sleep,
                      [for (final d in data.days) d.sleepHours]),
                ],
                height: 110,
              ),
            ]),
            pw.SizedBox(height: 12),
            _section('Bitácora diaria'),
            _dailyTable(data),
          ] else
            _note('No hay días registrados en este periodo.'),
          if (data.consultations.isNotEmpty)
            _card([
              _section('Evolución por consulta'),
              _consultations(data.consultations),
            ]),
        ],
      ),
    );
    return doc.save();
  }

  // ── Encabezado y resumen ──────────────────────────────────────────────────

  /// Va sobre la franja azul marino que pinta el fondo de la página.
  static pw.Widget _header(ReportData data, ComplianceSummary summary, pw.ImageProvider? logo,
      {required bool first}) {
    final fmt = DateFormat.yMMMd('es');
    final period = '${fmt.format(data.start)} al ${fmt.format(data.end)}';
    final name = data.personName?.trim();
    final hasName = name != null && name.isNotEmpty;
    final white = pw.TextStyle(color: PdfColors.white, fontWeight: pw.FontWeight.bold);
    final light = pw.TextStyle(fontSize: 8.5, color: _bandText);
    if (!first) {
      return pw.Container(
        height: _bandOther + _stripe + 12,
        padding: const pw.EdgeInsets.only(bottom: _stripe + 12),
        child: pw.Row(children: [
          if (logo != null) ...[pw.Image(logo, width: 24, height: 24), pw.SizedBox(width: 10)],
          pw.Text('Reporte de cumplimiento', style: white.copyWith(fontSize: 11)),
          pw.Spacer(),
          pw.Text([if (hasName) name, period].join(' · '), style: light),
        ]),
      );
    }
    final plans = [
      if (data.nutritionDetail?.planName != null) 'Plan: ${data.nutritionDetail!.planName}',
      if (data.exerciseDetail?.planName != null) 'Rutina: ${data.exerciseDetail!.planName}',
    ];
    return pw.Container(
      height: _bandFirst + _stripe + 14,
      padding: const pw.EdgeInsets.only(bottom: _stripe + 14),
      child: pw.Row(children: [
        if (logo != null) ...[pw.Image(logo, width: 46, height: 46), pw.SizedBox(width: 14)],
        pw.Column(
          mainAxisAlignment: pw.MainAxisAlignment.center,
          crossAxisAlignment: pw.CrossAxisAlignment.start,
          children: [
            pw.Text('Reporte de cumplimiento', style: white.copyWith(fontSize: 18)),
            pw.SizedBox(height: 3),
            pw.Text(
              '$period · ${summary.dayCount} ${summary.dayCount == 1 ? 'día' : 'días'} registrables',
              style: light,
            ),
          ],
        ),
        pw.Spacer(),
        pw.Column(
          mainAxisAlignment: pw.MainAxisAlignment.center,
          crossAxisAlignment: pw.CrossAxisAlignment.end,
          children: [
            if (hasName) pw.Text(name, style: white.copyWith(fontSize: 12)),
            for (final p in plans) pw.Text(p, style: light),
          ],
        ),
      ]),
    );
  }

  static pw.Widget _kpis(ComplianceSummary s, ReportGoals goals) {
    String pct(int done, int expected) {
      final p = ComplianceSummary.percent(done, expected);
      return p == null ? '-' : '$p %';
    }

    final change = s.weightChange;
    final weights = s.weights;
    double? share(int done, int expected) => expected <= 0 ? null : done / expected;
    final tiles = [
      _tile(_Module.food, 'Alimentación', pct(s.mealsFromPlan, s.mealsExpected),
          '${s.mealsFromPlan} de ${s.mealsExpected} del plan · ${s.mealsOffPlan} fuera'
          ' · ${s.mealsSkipped} sin seguir',
          share(s.mealsFromPlan, s.mealsExpected)),
      _tile(_Module.gym, 'Ejercicio', pct(s.exerciseDays, s.exerciseDaysExpected),
          '${s.exerciseDays} días · meta ${s.exerciseDaysExpected}',
          share(s.exerciseDays, s.exerciseDaysExpected)),
      _tile(_Module.cardio, 'Cardio', pct(s.cardioDays, s.cardioDaysExpected),
          '${s.cardioDays} días · ${s.cardioMinutes} min en total',
          share(s.cardioDays, s.cardioDaysExpected)),
      _tile(_Module.water, 'Agua', pct(s.waterGoalDays, s.dayCount),
          '${s.waterGoalDays} de ${s.dayCount} días con la meta'
          '${s.waterAverageLiters == null ? '' : ' · ${s.waterAverageLiters!.toStringAsFixed(1)} L/día'}',
          share(s.waterGoalDays, s.dayCount)),
      _tile(_Module.sleep, 'Sueño',
          s.sleepAverage == null ? '-' : '${s.sleepAverage!.toStringAsFixed(1)} h',
          '${s.nightsLogged} noches registradas · meta 8 h',
          s.sleepAverage == null ? null : s.sleepAverage! / 8),
      _tile(
          _Module.weight,
          'Peso',
          change == null
              ? (weights.isEmpty ? '-' : '${weights.last.toStringAsFixed(1)} kg')
              : '${change > 0 ? '+' : ''}${change.toStringAsFixed(1)} kg',
          change == null
              ? '${weights.length} registros'
              : 'de ${weights.first.toStringAsFixed(1)} a ${weights.last.toStringAsFixed(1)} kg'
                  ' · ${weights.length} registros',
          null),
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

  /// Fondo, color de la etiqueta y de la barra de cada módulo, como en la app.
  static (PdfColor, PdfColor, PdfColor) _moduleColors(_Module m) => switch (m) {
        _Module.food => (PdfColor.fromHex('#EEF6E2'), PdfColor.fromHex('#4F7A1E'), ChartColors.lime),
        _Module.gym => (PdfColor.fromHex('#E3F2E8'), ChartColors.primary, ChartColors.primary),
        _Module.cardio => (PdfColor.fromHex('#E6F4EE'), PdfColor.fromHex('#24725A'), ChartColors.cardio),
        _Module.water => (PdfColor.fromHex('#E4F1F4'), PdfColor.fromHex('#23697A'), ChartColors.water),
        _Module.sleep => (PdfColor.fromHex('#ECEEF6'), PdfColor.fromHex('#4A5680'), ChartColors.sleep),
        _Module.weight => (PdfColor.fromHex('#F1F4EA'), PdfColor.fromHex('#4F6A2A'), PdfColor.fromHex('#8BBF3F')),
      };

  static pw.Widget _tile(_Module module, String label, String value, String detail, double? share) {
    final (wash, ink, bar) = _moduleColors(module);
    return pw.Container(
      height: 70,
      padding: const pw.EdgeInsets.fromLTRB(10, 8, 10, 8),
      decoration: pw.BoxDecoration(color: wash, borderRadius: pw.BorderRadius.circular(10)),
      child: pw.Column(
        crossAxisAlignment: pw.CrossAxisAlignment.start,
        children: [
          pw.Text(label.toUpperCase(),
              style: pw.TextStyle(fontSize: 7, color: ink, fontWeight: pw.FontWeight.bold, letterSpacing: 0.5)),
          pw.SizedBox(height: 2),
          pw.Text(value, style: pw.TextStyle(fontSize: 18, color: _heading, fontWeight: pw.FontWeight.bold)),
          pw.Spacer(),
          pw.Text(detail, style: pw.TextStyle(fontSize: 7, color: _body), maxLines: 2),
          if (share != null) ...[
            pw.SizedBox(height: 4),
            pw.LayoutBuilder(
              builder: (context, c) => pw.Stack(children: [
                pw.Container(
                  height: 3.5,
                  width: c!.maxWidth,
                  decoration: pw.BoxDecoration(
                    color: const PdfColor(0.04, 0.07, 0.14, 0.08),
                    borderRadius: pw.BorderRadius.circular(2),
                  ),
                ),
                pw.Container(
                  height: 3.5,
                  width: c.maxWidth * share.clamp(0.0, 1.0),
                  decoration: pw.BoxDecoration(color: bar, borderRadius: pw.BorderRadius.circular(2)),
                ),
              ]),
            ),
          ],
        ],
      ),
    );
  }

  // ── Secciones ─────────────────────────────────────────────────────────────

  /// Título de sección con el cuadrito del degradado del logo.
  static pw.Widget _section(String text) => pw.Padding(
        padding: const pw.EdgeInsets.only(bottom: 3),
        child: pw.Row(children: [
          pw.Container(
            width: 8,
            height: 8,
            decoration: pw.BoxDecoration(gradient: _brand, borderRadius: pw.BorderRadius.circular(2.5)),
          ),
          pw.SizedBox(width: 6),
          pw.Text(text, style: pw.TextStyle(fontSize: 11.5, fontWeight: pw.FontWeight.bold, color: _heading)),
        ]),
      );

  /// Una sección en tarjeta, sin partirse entre páginas.
  static pw.Widget _card(List<pw.Widget> children) => pw.Inseparable(
        child: pw.Container(
          margin: const pw.EdgeInsets.only(top: 12),
          padding: const pw.EdgeInsets.fromLTRB(12, 10, 12, 10),
          decoration: pw.BoxDecoration(
            border: pw.Border.all(color: _line, width: 0.8),
            borderRadius: pw.BorderRadius.circular(12),
          ),
          child: pw.Column(crossAxisAlignment: pw.CrossAxisAlignment.start, children: children),
        ),
      );

  static pw.Widget _note(String text) => pw.Padding(
        padding: const pw.EdgeInsets.only(bottom: 4),
        child: pw.Text(text, style: pw.TextStyle(fontSize: 8, color: _muted)),
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
      ChartSeries('Fuera del plan o sin seguirlo', ChartColors.secondary,
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

  /// Qué opción del plan se eligió en cada tiempo de comida y qué se comió
  /// fuera de él.
  static List<pw.Widget> _mealChoices(NutritionReportData? detail) {
    if (detail == null || detail.mealTimes.isEmpty) return const [];
    final times = detail.mealTimes;
    // Cada título va junto a su contenido para que no quede solo al pie.
    return [
      _card([
      _section('Lo que más se repitió'),
      _note('La opción del plan más elegida en cada tiempo de comida.'),
      _table(
        ['Tiempo', 'Opción más elegida', 'Veces', 'Del plan', 'Fuera', 'Sin seguir'],
        [
          for (final t in times)
            [
              t.mealType,
              t.favorite == null
                  ? 'Ninguna'
                  : 'Opción ${t.favorite!.optionNumber}: ${t.favorite!.description}',
              t.favorite == null ? '-' : '${t.favorite!.count}',
              '${t.fromPlan}',
              '${t.offPlan}',
              '${t.skipped}',
            ],
        ],
        widths: const {0: 62, 2: 42, 3: 42, 4: 38, 5: 48},
      ),
      ]),
      for (final t in times)
        if (_mealTimeBars(t).isNotEmpty) _card(_mealTimeBars(t)),
      if (detail.offPlanMeals.isNotEmpty) ...[
        pw.SizedBox(height: 12),
        _section('Comidas fuera del plan'),
        _table(
          ['Fecha', 'Tiempo', 'Qué se comió'],
          [
            for (final m in detail.offPlanMeals)
              [
                _capitalize(DateFormat('EEE d MMM', 'es').format(m.date)),
                m.mealType,
                m.description,
              ],
          ],
          widths: const {0: 80, 1: 70},
        ),
      ],
    ];
  }

  /// Una barra por opción del plan, también las que no se eligieron.
  static List<pw.Widget> _mealTimeBars(MealTimeBreakdown t) {
    if (t.options.isEmpty && t.logged == 0) return const [];
    final top = t.options.fold(0, (m, o) => o.count > m ? o.count : m);
    final favorite = t.favorite;
    const barWidth = 150.0;
    final extras = [
      if (t.offPlan > 0)
        'Fuera del plan: ${t.offPlan}'
            '${t.offPlanTop.isEmpty ? '' : ' (${t.offPlanTop.map((e) => '${e.$1} ${e.$2}x').join(', ')})'}',
      if (t.skipped > 0) 'Sin seguir el plan: ${t.skipped}',
    ];
    return [
      pw.Padding(
        padding: const pw.EdgeInsets.only(bottom: 3),
        child: pw.Text(
          '${t.mealType} · ${t.logged} ${t.logged == 1 ? 'registro' : 'registros'}',
          style: pw.TextStyle(fontSize: 9.5, fontWeight: pw.FontWeight.bold, color: _heading),
        ),
      ),
      for (final o in t.options)
        pw.Padding(
          padding: const pw.EdgeInsets.symmetric(vertical: 2),
          child: pw.Row(
            crossAxisAlignment: pw.CrossAxisAlignment.center,
            children: [
              pw.Expanded(
                child: pw.Text('${o.optionNumber}. ${o.description}',
                    style: pw.TextStyle(fontSize: 7.5, color: _body)),
              ),
              pw.SizedBox(width: 8),
              pw.Container(
                width: barWidth,
                height: 7,
                alignment: pw.Alignment.centerLeft,
                decoration: pw.BoxDecoration(color: _surface, borderRadius: pw.BorderRadius.circular(3.5)),
                child: o.count == 0
                    ? null
                    : pw.Container(
                        width: barWidth * o.count / top,
                        height: 7,
                        decoration: pw.BoxDecoration(
                          gradient: pw.LinearGradient(colors: [ChartColors.primary, ChartColors.lime]),
                          borderRadius: pw.BorderRadius.circular(3.5),
                        ),
                      ),
              ),
              pw.SizedBox(
                width: 70,
                child: pw.Text(
                  o.count == 0
                      ? '  0'
                      : '  ${o.count}${identical(o, favorite) ? '  más elegida' : ''}',
                  style: pw.TextStyle(
                    fontSize: 7.5,
                    color: o.count == 0 ? _muted : (identical(o, favorite) ? ChartColors.primary : _heading),
                    fontWeight: identical(o, favorite) ? pw.FontWeight.bold : null,
                  ),
                ),
              ),
            ],
          ),
        ),
      if (extras.isNotEmpty)
        pw.Padding(
          padding: const pw.EdgeInsets.only(top: 2),
          child: pw.Text(extras.join('  ·  '), style: pw.TextStyle(fontSize: 7.5, color: _muted)),
        ),
    ];
  }

  /// Una fila por semana con un cuadro por día: hecho, no hecho o sin llegar.
  static pw.Widget _activityCalendar(List<ReportDay> days) {
    final weeks = splitByWeek(days);
    const names = ['L', 'M', 'M', 'J', 'V', 'S', 'D'];
    pw.Widget cell(ReportDay? day, bool Function(ReportDay) done, String mark) {
      final filled = day != null && done(day);
      // Rutina con el degradado del logo; cardio en su verde agua.
      final isCardio = mark == 'C';
      return pw.Container(
        width: 16,
        height: 16,
        margin: const pw.EdgeInsets.all(1),
        alignment: pw.Alignment.center,
        decoration: pw.BoxDecoration(
          color: filled ? (isCardio ? ChartColors.cardio : null) : (day == null ? null : _surface),
          gradient: filled && !isCardio
              ? pw.LinearGradient(
                  begin: pw.Alignment.topLeft,
                  end: pw.Alignment.bottomRight,
                  colors: [ChartColors.primary, ChartColors.lime],
                )
              : null,
          borderRadius: pw.BorderRadius.circular(5),
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
      pw.SizedBox(height: 12),
      _section('Sesiones de cardio'),
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
        ratio(s.mealsFromPlan, s.mealsExpected),
        ratio(s.exerciseDays, s.exerciseDaysExpected),
        '${ratio(s.cardioDays, s.cardioDaysExpected)} · ${s.cardioMinutes} min',
        ratio(s.waterGoalDays, s.dayCount),
        s.sleepAverage == null ? '-' : '${s.sleepAverage!.toStringAsFixed(1)} h',
        s.weightAverage == null ? '-' : '${s.weightAverage!.toStringAsFixed(1)} kg',
      ]);
    }
    return pw.Column(crossAxisAlignment: pw.CrossAxisAlignment.start, children: [
      _note('Hecho / esperado. Comidas: las del plan. Agua: días que se llegó a la meta. '
          'Peso: promedio de la semana.'),
      _table(
        ['Semana', 'Comidas', 'Ejercicio', 'Cardio', 'Agua', 'Sueño', 'Peso'],
        rows,
        // Verde si se cumplió la meta de la semana; ámbar si quedó en menos de la mitad.
        textStyle: (index, cell, rowNum) {
          if (rowNum == 0 || index < 1 || index > 4) return null;
          final m = RegExp(r'^(\d+)/(\d+)').firstMatch('$cell');
          if (m == null) return null;
          final done = int.parse(m[1]!);
          final expected = int.parse(m[2]!);
          if (expected == 0) return null;
          if (done >= expected) {
            return pw.TextStyle(fontSize: 8, color: ChartColors.primary, fontWeight: pw.FontWeight.bold);
          }
          if (done * 2 < expected) {
            return pw.TextStyle(fontSize: 8, color: _warn, fontWeight: pw.FontWeight.bold);
          }
          return null;
        },
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
            '${d.mealsFromPlan}/${data.goals.mealsPerDay}'
                '${d.meals > d.mealsFromPlan ? ' +${d.meals - d.mealsFromPlan} fuera' : ''}',
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
      {Map<int, double> widths = const {}, pw.OnCellTextStyle? textStyle}) {
    return pw.TableHelper.fromTextArray(
      headers: headers,
      data: rows,
      // Con anchos fijos, las demás columnas toman solo lo que sobra; si no,
      // un texto largo aprieta las columnas fijas.
      columnWidths: widths.isEmpty
          ? const {}
          : {
              for (var i = 0; i < headers.length; i++)
                i: widths[i] == null ? const pw.FlexColumnWidth() : pw.FixedColumnWidth(widths[i]!),
            },
      headerStyle: pw.TextStyle(fontSize: 7.5, fontWeight: pw.FontWeight.bold, color: _muted),
      headerAlignment: pw.Alignment.centerLeft,
      cellStyle: pw.TextStyle(fontSize: 8, color: _body),
      cellAlignment: pw.Alignment.centerLeft,
      cellPadding: const pw.EdgeInsets.symmetric(horizontal: 5, vertical: 3),
      textStyleBuilder: textStyle,
      // Filas alternas tenues, como en la propuesta.
      oddRowDecoration: pw.BoxDecoration(color: _zebra),
      border: pw.TableBorder(
        top: pw.BorderSide.none,
        horizontalInside: pw.BorderSide(color: _line, width: 0.5),
      ),
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

enum _Module { food, gym, cardio, water, sleep, weight }
