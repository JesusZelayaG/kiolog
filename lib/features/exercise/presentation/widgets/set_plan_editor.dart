import 'package:flutter/material.dart';
import 'package:iconsax_plus/iconsax_plus.dart';
import 'package:kiolog/core/database/app_database.dart';
import 'package:kiolog/core/theme/app_theme.dart';
import 'package:kiolog/features/exercise/domain/reps.dart';
import 'package:kiolog/features/exercise/domain/set_plan.dart';

/// Una fila del editor: reps y peso, principal o drop.
class _RowDraft {
  _RowDraft({String reps = '', String weight = '', this.isDrop = false})
      : reps = TextEditingController(text: reps),
        weight = TextEditingController(text: weight);

  final TextEditingController reps;
  final TextEditingController weight;
  final bool isDrop;

  void dispose() {
    reps.dispose();
    weight.dispose();
  }
}

String _w(double? w) => w == null ? '' : (w == w.roundToDouble() ? w.toStringAsFixed(0) : '$w');

double? _parseWeight(String text) => double.tryParse(text.trim().replaceAll(',', '.'));

/// Lo que sale del editor, listo para guardar el ejercicio.
typedef SetPlanResult = ({
  int sets,
  int reps,
  double? weight,
  String? repsLabel,
  String setType,
  List<SetDef> defs,
});

/// Las series de un ejercicio mientras se editan: iguales (con drops al
/// final) o una por una (pirámide, con drops donde se quiera).
class SetPlanDraft {
  SetPlanDraft({String sets = '3', String reps = '10', String weight = ''})
      : sets = TextEditingController(text: sets),
        reps = TextEditingController(text: reps),
        weight = TextEditingController(text: weight);

  /// Desde un ejercicio guardado y sus series por separado.
  factory SetPlanDraft.fromItem(ExerciseRoutineItem item, List<ExerciseRoutineSetDef> defs) {
    if (defs.isEmpty) {
      return SetPlanDraft(sets: '${item.sets}', reps: item.repsLabel ?? '${item.reps}', weight: _w(item.weightKg));
    }
    final planned = fromSetDefs(defs);
    final mains = planned.where((s) => !s.isDrop).toList();
    final lastMain = planned.lastIndexWhere((s) => !s.isDrop);
    final onlyTailDrops = planned.take(lastMain).every((s) => !s.isDrop);
    final uniform = mains.every((s) => s.reps == mains.first.reps && s.weight == mains.first.weight);
    if (uniform && onlyTailDrops && mains.isNotEmpty) {
      final draft = SetPlanDraft(
        sets: '${mains.length}',
        reps: item.repsLabel ?? '${mains.first.reps}',
        weight: _w(mains.first.weight),
      );
      for (final d in planned.sublist(lastMain + 1)) {
        draft.tailDrops.add(_RowDraft(reps: '${d.reps}', weight: _w(d.weight), isDrop: true));
      }
      return draft;
    }
    return SetPlanDraft()
      ..perSet = true
      ..rows.addAll([
        for (final s in planned) _RowDraft(reps: '${s.reps}', weight: _w(s.weight), isDrop: s.isDrop),
      ]);
  }

  /// Serie por serie (pirámide) en vez de series iguales.
  bool perSet = false;

  final TextEditingController sets;
  final TextEditingController reps;
  final TextEditingController weight;

  /// Drops después de la última serie, en el modo de series iguales.
  final List<_RowDraft> tailDrops = [];

  /// Todas las series, en el modo serie por serie.
  final List<_RowDraft> rows = [];

  List<PlannedSet>? _uniformSets() {
    final n = int.tryParse(sets.text.trim());
    final parsed = parseReps(reps.text);
    if (n == null || n <= 0 || parsed == null) return null;
    final w = _parseWeight(weight.text);
    return [
      for (var i = 0; i < n; i++) PlannedSet(reps: parsed.$1, weight: w),
      for (final d in tailDrops)
        if (int.tryParse(d.reps.text.trim()) case final r?) PlannedSet(reps: r, weight: _parseWeight(d.weight.text), isDrop: true),
    ];
  }

  List<PlannedSet>? _perSetSets() {
    final out = <PlannedSet>[];
    for (final r in rows) {
      final reps = int.tryParse(r.reps.text.trim());
      if (reps == null) return null;
      out.add(PlannedSet(reps: reps, weight: _parseWeight(r.weight.text), isDrop: r.isDrop));
    }
    return out.any((s) => !s.isDrop) ? out : null;
  }

  List<PlannedSet>? get planned => perSet ? _perSetSets() : _uniformSets();

  String? get repsLabel => perSet ? null : parseReps(reps.text)?.$2;

  /// Null si falta algo (series o reps).
  SetPlanResult? build() {
    final sets = planned;
    if (sets == null) return null;
    final mains = sets.where((s) => !s.isDrop).toList();
    final type = setTypeFor(sets);
    return (
      sets: mains.length,
      reps: mains.first.reps,
      weight: mains.first.weight,
      repsLabel: repsLabel,
      setType: type,
      // Series iguales sin drops no necesitan guardarse una por una.
      defs: type == 'normal' ? const [] : toSetDefs(sets),
    );
  }

  /// Pasa a serie por serie copiando lo que había.
  void switchToPerSet() {
    final current = _uniformSets() ?? const [PlannedSet(reps: 10)];
    for (final r in rows) {
      r.dispose();
    }
    rows
      ..clear()
      ..addAll([for (final s in current) _RowDraft(reps: '${s.reps}', weight: _w(s.weight), isDrop: s.isDrop)]);
    perSet = true;
  }

  /// Vuelve a series iguales con la primera serie como base.
  void switchToUniform() {
    final current = _perSetSets();
    if (current != null) {
      final mains = current.where((s) => !s.isDrop).toList();
      sets.text = '${mains.length}';
      reps.text = '${mains.first.reps}';
      weight.text = _w(mains.first.weight);
      final lastMain = current.lastIndexWhere((s) => !s.isDrop);
      for (final d in tailDrops) {
        d.dispose();
      }
      tailDrops
        ..clear()
        ..addAll([
          for (final s in current.sublist(lastMain + 1)) _RowDraft(reps: '${s.reps}', weight: _w(s.weight), isDrop: true),
        ]);
    }
    perSet = false;
  }

  void dispose() {
    sets.dispose();
    reps.dispose();
    weight.dispose();
    for (final r in [...tailDrops, ...rows]) {
      r.dispose();
    }
  }
}

/// Series iguales o pirámide, con drops; muestra el resumen al pie.
class SetPlanEditor extends StatefulWidget {
  const SetPlanEditor({super.key, required this.draft, required this.unit, this.dense = false});

  final SetPlanDraft draft;
  final String unit;
  final bool dense;

  @override
  State<SetPlanEditor> createState() => _SetPlanEditorState();
}

class _SetPlanEditorState extends State<SetPlanEditor> {
  SetPlanDraft get d => widget.draft;

  /// Lo que sube el peso de una serie a la siguiente en una pirámide.
  double get _step => widget.unit == 'kg' ? 2.5 : 5;

  void _addMain() {
    final mains = d.rows.where((r) => !r.isDrop).toList();
    final last = mains.isEmpty ? null : mains.last;
    final reps = int.tryParse(last?.reps.text ?? '');
    final weight = _parseWeight(last?.weight.text ?? '');
    setState(() => d.rows.add(_RowDraft(
          reps: reps == null ? '10' : '${(reps - 2).clamp(1, 100)}',
          weight: weight == null ? '' : _w(weight + _step),
        )));
  }

  void _addDrop(List<_RowDraft> list) {
    final last = list.isEmpty ? null : list.last;
    final weight = _parseWeight(last?.weight.text ?? '') ?? _parseWeight(d.weight.text);
    final lastReps = int.tryParse(last?.reps.text ?? '');
    setState(() => list.add(_RowDraft(
          // Al bajar el peso se hacen más reps.
          reps: lastReps == null ? '12' : '${lastReps + 3}',
          // Un drop baja el peso; aquí, un 25 % como sugerencia.
          weight: weight == null ? '' : _w((weight * 0.75 / _step).round() * _step),
          isDrop: true,
        )));
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;
    final planned = d.planned;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        SegmentedButton<bool>(
          segments: const [
            ButtonSegment(value: false, label: Text('Series iguales')),
            ButtonSegment(value: true, label: Text('Pirámide')),
          ],
          selected: {d.perSet},
          showSelectedIcon: false,
          onSelectionChanged: (s) => setState(() => s.first ? d.switchToPerSet() : d.switchToUniform()),
        ),
        const SizedBox(height: 10),
        if (!d.perSet) ...[
          Row(
            children: [
              Expanded(child: _field(d.sets, 'Series', number: true)),
              const SizedBox(width: 8),
              Expanded(child: _field(d.reps, 'Reps', hint: '8 o 6-8')),
              const SizedBox(width: 8),
              Expanded(child: _field(d.weight, widget.unit, decimal: true)),
            ],
          ),
          for (var i = 0; i < d.tailDrops.length; i++) _rowEditor(d.tailDrops, i, label: 'Drop ${i + 1}'),
          Align(
            alignment: Alignment.centerLeft,
            child: TextButton.icon(
              onPressed: () => _addDrop(d.tailDrops),
              icon: const Icon(IconsaxPlusLinear.arrow_down_2, size: 16),
              label: const Text('Drop en la última serie'),
            ),
          ),
        ] else ...[
          for (var i = 0; i < d.rows.length; i++)
            _rowEditor(
              d.rows,
              i,
              label: d.rows[i].isDrop
                  ? 'Drop'
                  : 'Serie ${d.rows.take(i + 1).where((r) => !r.isDrop).length}',
            ),
          Row(
            children: [
              TextButton.icon(
                onPressed: _addMain,
                icon: const Icon(IconsaxPlusLinear.add, size: 16),
                label: const Text('Serie'),
              ),
              TextButton.icon(
                onPressed: d.rows.any((r) => !r.isDrop) ? () => _addDrop(d.rows) : null,
                icon: const Icon(IconsaxPlusLinear.arrow_down_2, size: 16),
                label: const Text('Drop'),
              ),
            ],
          ),
        ],
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
          decoration: BoxDecoration(color: context.kc.gymWash, borderRadius: BorderRadius.circular(14)),
          child: Text(
            planned == null ? 'Completa series y reps' : setPlanSummary(planned, widget.unit, repsLabel: d.repsLabel),
            style: theme.textTheme.bodySmall?.copyWith(color: planned == null ? cs.error : context.kc.gymInk, fontWeight: FontWeight.w700),
          ),
        ),
      ],
    );
  }

  Widget _field(TextEditingController c, String label, {String? hint, bool number = false, bool decimal = false}) =>
      TextField(
        controller: c,
        onChanged: (_) => setState(() {}),
        keyboardType: number || decimal ? TextInputType.numberWithOptions(decimal: decimal) : TextInputType.text,
        decoration: InputDecoration(labelText: label, hintText: hint, isDense: true),
      );

  Widget _rowEditor(List<_RowDraft> list, int i, {required String label}) {
    final row = list[i];
    final theme = Theme.of(context);
    return Padding(
      padding: EdgeInsets.only(top: 8, left: row.isDrop ? 18 : 0),
      child: Row(
        children: [
          SizedBox(
            width: 62,
            child: Row(
              children: [
                if (row.isDrop) Icon(IconsaxPlusLinear.arrow_down_2, size: 14, color: context.kc.warning),
                Flexible(
                  child: Text(label,
                      style: theme.textTheme.labelMedium?.copyWith(color: row.isDrop ? context.kc.warning : null)),
                ),
              ],
            ),
          ),
          Expanded(child: _field(row.reps, 'Reps', number: true)),
          const SizedBox(width: 8),
          Expanded(child: _field(row.weight, widget.unit, decimal: true)),
          IconButton(
            tooltip: 'Quitar',
            visualDensity: VisualDensity.compact,
            icon: Icon(IconsaxPlusLinear.minus_cirlce, size: 18, color: theme.colorScheme.error),
            onPressed: () => setState(() => list.removeAt(i).dispose()),
          ),
        ],
      ),
    );
  }
}
