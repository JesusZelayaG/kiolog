import 'package:equatable/equatable.dart';
import 'package:kiolog/core/database/app_database.dart';

const _measures = <(String, String, double? Function(Measurement))>[
  ('Peso', 'kg', _weight),
  ('Cintura', 'cm', _waist),
  ('Abdomen', 'cm', _abdomen),
  ('Cadera', 'cm', _hip),
  ('Muslo', 'cm', _thigh),
  ('Brazo', 'cm', _arm),
  ('Grasa', '%', _fat),
];

double? _weight(Measurement m) => m.weightKg;
double? _waist(Measurement m) => m.waistCm;
double? _abdomen(Measurement m) => m.lowerAbdomenCm;
double? _hip(Measurement m) => m.hipCm;
double? _thigh(Measurement m) => m.thighCm;
double? _arm(Measurement m) => m.armRelaxedCm;
double? _fat(Measurement m) => m.bodyFatPct;

class MeasureChange extends Equatable {
  const MeasureChange(this.label, this.unit, this.before, this.after);

  final String label;
  final String unit;
  final double before;
  final double after;

  double get change => after - before;

  @override
  List<Object?> get props => [label, unit, before, after];
}

/// Lo que cambió durante un plan: desde la consulta con que empezó hasta la
/// última consulta dentro de su periodo.
class PlanProgress extends Equatable {
  const PlanProgress({
    required this.plan,
    required this.mealsLogged,
    required this.mealsExpected,
    this.baseline,
    this.latest,
  });

  final MealPlan plan;
  final int mealsLogged;
  final int mealsExpected;
  final Measurement? baseline;
  final Measurement? latest;

  int? get adherencePercent =>
      mealsExpected == 0 ? null : (100 * mealsLogged / mealsExpected).round();

  List<MeasureChange> get changes {
    final from = baseline;
    final to = latest;
    if (from == null || to == null) return const [];
    return [
      for (final (label, unit, read) in _measures)
        if ((read(from), read(to)) case (final before?, final after?))
          MeasureChange(label, unit, before, after),
    ];
  }

  @override
  List<Object?> get props => [plan, mealsLogged, mealsExpected, baseline, latest];
}

DateTime _day(DateTime date) {
  final utc = date.toUtc();
  return DateTime.utc(utc.year, utc.month, utc.day);
}

/// [consultations] puede venir en cualquier orden. Una consulta el día que
/// cambia el plan cierra el anterior y sirve de base para el nuevo.
PlanProgress planProgressFor(
  MealPlan plan,
  List<Measurement> consultations, {
  required int mealsLogged,
  required int mealsExpected,
}) {
  final start = _day(plan.periodStart ?? plan.createdAt);
  final end = plan.periodEnd == null ? null : _day(plan.periodEnd!);
  final sorted = [...consultations]..sort((a, b) {
      final byDate = a.date.compareTo(b.date);
      return byDate != 0 ? byDate : a.id.compareTo(b.id);
    });
  final before = sorted.where((m) => !_day(m.date).isAfter(start));
  final during = sorted.where((m) {
    final day = _day(m.date);
    return day.isAfter(start) && (end == null || !day.isAfter(end));
  }).toList();

  final baseline =
      before.isNotEmpty ? before.last : (during.isEmpty ? null : during.first);
  final latest = during.isEmpty || during.last == baseline ? null : during.last;
  return PlanProgress(
    plan: plan,
    mealsLogged: mealsLogged,
    mealsExpected: mealsExpected,
    baseline: baseline,
    latest: latest,
  );
}
