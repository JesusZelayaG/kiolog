import 'package:flutter_test/flutter_test.dart';
import 'package:kiolog/core/database/app_database.dart';
import 'package:kiolog/features/progress/domain/plan_progress.dart';

MealPlan _plan({required int startDay, int? endDay, int month = 10}) => MealPlan(
      id: 1,
      name: 'Plan',
      createdAt: DateTime.utc(2026, month, startDay),
      isActive: endDay == null,
      dailyMealGoal: 3,
      periodStart: DateTime.utc(2026, month, startDay, 15),
      periodEnd: endDay == null ? null : DateTime.utc(2026, month, endDay, 15),
    );

Measurement _consultation(int id, int day, double weight, {double? waist}) => Measurement(
      id: id,
      date: DateTime.utc(2026, 10, day),
      weightKg: weight,
      heightCm: 160,
      waistCm: waist,
    );

PlanProgress _progress(MealPlan plan, List<Measurement> consultations) =>
    planProgressFor(plan, consultations, mealsLogged: 3, mealsExpected: 12);

void main() {
  test('mide desde la consulta de inicio hasta la siguiente consulta', () {
    final progress = _progress(_plan(startDay: 1), [
      _consultation(2, 15, 74, waist: 85),
      _consultation(1, 1, 76, waist: 88),
    ]);

    expect(progress.baseline?.id, 1);
    expect(progress.latest?.id, 2);
    expect(progress.changes.first, const MeasureChange('Peso', 'kg', 76, 74));
    expect(progress.changes.last.change, -3);
    expect(progress.adherencePercent, 25);
  });

  test('sin renovar el plan, una consulta más actualiza el resultado', () {
    final progress = _progress(_plan(startDay: 1), [
      _consultation(1, 1, 76),
      _consultation(2, 15, 74),
      _consultation(3, 29, 73),
    ]);
    expect(progress.latest?.id, 3);
  });

  test('la consulta del cambio cierra un plan y es base del siguiente', () {
    final consultations = [
      _consultation(1, 1, 76),
      _consultation(2, 15, 74),
      _consultation(3, 29, 73),
    ];

    final closed = _progress(_plan(startDay: 1, endDay: 15), consultations);
    final next = _progress(_plan(startDay: 15), consultations);

    expect(closed.latest?.id, 2);
    expect(next.baseline?.id, 2);
    expect(next.latest?.id, 3);
  });

  test('usa la última consulta anterior como base', () {
    final progress = _progress(_plan(startDay: 10), [
      _consultation(1, 1, 76),
      _consultation(2, 5, 75),
    ]);
    expect(progress.baseline?.id, 2);
    expect(progress.latest, isNull);
    expect(progress.changes, isEmpty);
  });

  test('sin consulta previa, la primera del periodo es la base', () {
    final progress = _progress(_plan(startDay: 1), [
      _consultation(1, 5, 76),
      _consultation(2, 20, 74),
    ]);
    expect(progress.baseline?.id, 1);
    expect(progress.latest?.id, 2);
  });

  test('sin consultas no inventa cambios', () {
    final progress = _progress(_plan(startDay: 1), []);
    expect(progress.baseline, isNull);
    expect(progress.changes, isEmpty);
  });

  test('un plan recién empezado no tiene porcentaje', () {
    final progress = planProgressFor(
      _plan(startDay: 1),
      const [],
      mealsLogged: 0,
      mealsExpected: 0,
    );
    expect(progress.adherencePercent, isNull);
  });
}
