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
      meals: skipped ? 3 : 4,
      mealsFromPlan: skipped ? 1 : 4 - d % 4 % 2,
      mealsOffPlan: skipped ? 1 : d % 4 % 2,
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
      mealsPerDay: 4,
      routineDaysPerWeek: 6,
      cardioDaysPerWeek: 3,
      cardioMinutes: 30,
    ),
    personName: 'Jesús',
    nutritionDetail: NutritionReportData(
      planName: 'Pérdida de grasa',
      mealFrequencies: const [],
      mealTimes: const [
        MealTimeBreakdown(mealType: 'Desayuno', options: [
          OptionCount(1, '2 rebanadas de pan francés pequeño, 1/2 taza de frijoles o casamiento, medio plátano sancochado, 2 huevos revueltos', 9),
          OptionCount(2, '2 tortillas de maíz, 1/2 taza de frijoles, 2 huevos revueltos con jamón de pavo, 1/2 aguacate', 14),
          OptionCount(3, 'Dobladitas: 3 tortillas de harina, 2 huevos revueltos con jamón de pavo', 3),
        ], offPlan: 1, skipped: 1, offPlanTop: [('Pan dulce con café', 1)]),
        MealTimeBreakdown(mealType: 'Almuerzo', options: [
          OptionCount(1, '1 taza de arroz, 150 g de pollo o carne guisada o a la plancha, ensalada', 11),
          OptionCount(2, '1 tortilla de maíz, 2/3 taza de arroz o casamiento, 150 g de pollo tipo fajita', 8),
          OptionCount(3, 'Tacos: 4 tortillas de maíz, 150 g de pollo o carne molida, chimol', 4),
          OptionCount(4, 'Sopa de frijoles', 2),
          OptionCount(5, 'Sopa de pollo', 0),
        ], offPlan: 3, offPlanTop: [('Pupusas', 2), ('Pizza', 1)]),
        MealTimeBreakdown(mealType: 'Refacción', options: [
          OptionCount(1, '2 galletas Tosh María o 1 Vita Lido', 6),
          OptionCount(2, '1 yogur griego + fruta', 17),
          OptionCount(3, 'Sándwich de jamón de pavo', 2),
        ], skipped: 3),
        MealTimeBreakdown(mealType: 'Cena', options: [
          OptionCount(1, '1 tortilla, 1/2 taza de frijoles, 2 huevos con jamón, 1/2 aguacate', 12),
          OptionCount(2, '1 tortilla, medio plátano, casamiento, 2 huevos, cuajada', 7),
          OptionCount(3, 'Pan de caja, frijoles, omelet con mozzarella', 6),
        ], offPlan: 2, offPlanTop: [('Hamburguesa', 1), ('Pupusas', 1)]),
      ],
      offPlanMeals: [
        OffPlanMeal(DateTime.utc(2026, 11, 7), 'Almuerzo', 'Pupusas'),
        OffPlanMeal(DateTime.utc(2026, 11, 14), 'Cena', 'Hamburguesa'),
        OffPlanMeal(DateTime.utc(2026, 11, 21), 'Almuerzo', 'Pizza'),
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
