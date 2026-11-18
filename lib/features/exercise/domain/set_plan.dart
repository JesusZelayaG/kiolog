import 'package:kiolog/core/database/app_database.dart';

/// Una serie del plan: principal, o un drop que sigue a la principal anterior.
class PlannedSet {
  const PlannedSet({required this.reps, this.weight, this.isDrop = false});

  final int reps;
  final double? weight;
  final bool isDrop;

  @override
  bool operator ==(Object other) =>
      other is PlannedSet && other.reps == reps && other.weight == weight && other.isDrop == isDrop;

  @override
  int get hashCode => Object.hash(reps, weight, isDrop);

  @override
  String toString() => '${isDrop ? 'drop ' : ''}$reps@$weight';
}

typedef SetDef = ({int setNumber, int? dropOfSetNumber, int reps, double? weightKg});

/// normal | pyramid | drop | pyramid_drop, según cómo quedaron las series.
String setTypeFor(List<PlannedSet> sets) {
  final mains = sets.where((s) => !s.isDrop).toList();
  final pyramid = mains.length > 1 && mains.any((s) => s.reps != mains.first.reps || s.weight != mains.first.weight);
  final drops = sets.any((s) => s.isDrop);
  return switch ((pyramid, drops)) {
    (true, true) => 'pyramid_drop',
    (true, false) => 'pyramid',
    (false, true) => 'drop',
    _ => 'normal',
  };
}

/// Las series como se guardan: cada una con su número y, los drops, con el
/// número de la serie de la que salen. Un drop sin serie antes se ignora.
List<SetDef> toSetDefs(List<PlannedSet> sets) {
  final defs = <SetDef>[];
  int? parent;
  var number = 0;
  for (final s in sets) {
    if (s.isDrop && parent == null) continue;
    number++;
    if (!s.isDrop) parent = number;
    defs.add((setNumber: number, dropOfSetNumber: s.isDrop ? parent : null, reps: s.reps, weightKg: s.weight));
  }
  return defs;
}

List<PlannedSet> fromSetDefs(List<ExerciseRoutineSetDef> defs) => [
      for (final d in [...defs]..sort((a, b) => a.setNumber.compareTo(b.setNumber)))
        PlannedSet(reps: d.reps, weight: d.weightKg, isDrop: d.dropOfSetNumber != null),
    ];

/// Las series de un ejercicio guardado sin series por separado.
List<PlannedSet> uniformSets(ExerciseRoutineItem item) =>
    [for (var i = 0; i < item.sets; i++) PlannedSet(reps: item.reps, weight: item.weightKg)];

String _weight(double? w) {
  if (w == null) return '';
  return w == w.roundToDouble() ? w.toStringAsFixed(0) : w.toString();
}

String _one(PlannedSet s) => s.weight == null ? '${s.reps}' : '${s.reps} × ${_weight(s.weight)}';

/// "3 × 10 @ 20 kg + drop 12 → 15" o "12 × 20 → 10 × 22.5 → 8 × 25 kg".
/// [repsLabel] reemplaza las reps cuando todas las series son iguales
/// ("6-8", "Las que salgan").
String setPlanSummary(List<PlannedSet> sets, String unit, {String? repsLabel}) {
  final mains = sets.where((s) => !s.isDrop).toList();
  if (mains.isEmpty) return 'Sin series';
  final uniform = mains.every((s) => s.reps == mains.first.reps && s.weight == mains.first.weight);
  final first = mains.first;
  final String base;
  if (uniform) {
    final reps = repsLabel ?? '${first.reps}';
    base = '${mains.length} × $reps${first.weight != null ? ' @ ${_weight(first.weight)} $unit' : ''}';
  } else {
    final anyWeight = mains.any((s) => s.weight != null);
    base = '${mains.map(_one).join(' → ')}${anyWeight ? ' $unit' : ''}';
  }

  // Drops que siguen a la última serie, en una sola línea.
  final lastMain = sets.lastIndexWhere((s) => !s.isDrop);
  final tailDrops = sets.sublist(lastMain + 1);
  final otherDrops = sets.take(lastMain).where((s) => s.isDrop).length;
  final parts = [base];
  if (tailDrops.isNotEmpty) {
    parts.add('drop ${tailDrops.map(_one).join(' → ')}');
  }
  if (otherDrops > 0) parts.add('$otherDrops ${otherDrops == 1 ? 'drop' : 'drops'} más');
  return parts.join(' + ');
}
