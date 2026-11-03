import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:kiolog/core/database/app_database.dart';
import 'package:kiolog/features/reports/data/pdf_report_service.dart';
import 'package:kiolog/features/reports/domain/repositories/report_repository.dart';

/// Un mes con días cumplidos, días a medias y días sin registro.
ReportData _month() {
  final days = <ReportDay>[];
  for (var d = 3; d <= 30; d++) {
    final date = DateTime.utc(2026, 11, d);
    final skipped = d % 9 == 0;
    days.add(ReportDay(
      date: date,
      waterMl: skipped ? 0 : 2000 + (d * 137) % 1500,
      meals: skipped ? 2 : 5 - d % 3 % 2,
      mealsFromPlan: skipped ? 1 : 4 - d % 4 % 2,
      exercised: !skipped && date.weekday != DateTime.sunday,
      cardioMinutes: d % 2 == 0 ? 25 + d % 3 * 10 : 0,
      sleepHours: d % 5 == 0 ? null : 6 + (d * 7) % 25 / 10,
      weightKg: skipped ? null : 84 - d * 0.08 + (d % 3) * 0.2,
    ));
  }
  return ReportData(
    start: DateTime(2026, 11, 3),
    end: DateTime(2026, 11, 30),
    waterGoalDays: 0,
    waterTotalDays: days.length,
    mealsLogged: 0,
    mealsTotal: 0,
    exerciseDays: 0,
    exerciseTotalDays: 0,
    weightLogs: const [],
    days: days,
    goals: const ReportGoals(
      waterMl: 3000,
      mealsPerDay: 5,
      routineDaysPerWeek: 6,
      cardioDaysPerWeek: 3,
      cardioMinutes: 30,
    ),
    personName: 'Jesús',
    nutritionDetail: const NutritionReportData(
      planName: 'Plan noviembre',
      mealFrequencies: [
        MealFrequencyEntry(mealType: 'desayuno', description: 'Avena con frutas', count: 14),
        MealFrequencyEntry(mealType: 'almuerzo', description: 'Pollo con arroz y ensalada', count: 11),
      ],
    ),
    exerciseDetail: const ExerciseReportData(
      planName: 'Mi Rutina',
      weeklyCompliance: [],
      totalRoutineSessions: 20,
      cardioSessionsCount: 14,
      freeExerciseCount: 2,
    ),
    cardioLogs: [
      for (final day in days.where((d) => d.cardioMinutes > 0))
        CardioLog(
          id: day.date.day,
          date: day.date,
          cardioType: 'caminadora',
          durationMinutes: day.cardioMinutes,
        ),
    ],
    consultations: [
      Measurement(id: 1, date: DateTime.utc(2026, 11, 3), weightKg: 84, heightCm: 172, waistCm: 98),
      Measurement(id: 2, date: DateTime.utc(2026, 11, 30), weightKg: 81.9, heightCm: 172, waistCm: 95),
    ],
  );
}

void main() {
  setUpAll(() => initializeDateFormatting('es'));

  test('builds a multi-page PDF from a month of records', () async {
    final bytes = await PdfReportService.build(_month(), now: DateTime(2026, 11, 30));

    expect(String.fromCharCodes(bytes.take(5)), '%PDF-');
    expect(bytes.length, greaterThan(10000));

    // Para revisar el diseño a ojo: KIOLOG_PDF_OUT=/ruta/reporte.pdf
    final out = Platform.environment['KIOLOG_PDF_OUT'];
    if (out != null) await File(out).writeAsBytes(bytes);
  });

  test('handles a period without records', () async {
    final empty = ReportData(
      start: DateTime(2026, 11, 3),
      end: DateTime(2026, 11, 3),
      waterGoalDays: 0,
      waterTotalDays: 0,
      mealsLogged: 0,
      mealsTotal: 0,
      exerciseDays: 0,
      exerciseTotalDays: 0,
      weightLogs: const [],
    );

    final bytes = await PdfReportService.build(empty);

    expect(String.fromCharCodes(bytes.take(5)), '%PDF-');
  });
}
