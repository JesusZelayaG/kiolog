import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:kiolog/core/database/app_database.dart';
import 'package:kiolog/shared/widgets/vitality_card.dart';
import 'package:kiolog/shared/widgets/vitality_progress_bar.dart';
import '../bloc/exercise_bloc.dart';
import '../bloc/exercise_event.dart';
import '../bloc/exercise_state.dart';
import '../cubit/exercise_weight_unit_cubit.dart';

class ExerciseSessionPage extends StatefulWidget {
  final int sessionId;
  const ExerciseSessionPage({super.key, required this.sessionId});

  @override
  State<ExerciseSessionPage> createState() => _ExerciseSessionPageState();
}

class _ExerciseSessionPageState extends State<ExerciseSessionPage> {
  // ID del ítem actualmente expandido; null = ninguno
  int? _expandedItemId;

  // Filas de series por item.id. Se inicializan la primera vez que se expande.
  final Map<int, List<_SetRowData>> _itemRows = {};

  @override
  void initState() {
    super.initState();
    context
        .read<ExerciseBloc>()
        .add(ExerciseSessionResumed(sessionId: widget.sessionId));
  }

  @override
  void dispose() {
    for (final rows in _itemRows.values) {
      for (final row in rows) {
        row.repsCtrl.dispose();
        row.weightCtrl.dispose();
      }
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return BlocConsumer<ExerciseBloc, ExerciseState>(
      listenWhen: (prev, curr) =>
          prev.sessionSets.length != curr.sessionSets.length,
      listener: (context, state) => _syncSavedRows(state),
      builder: (context, state) {
        final session = state.activeSession;
        if (session == null) {
          return const Scaffold(
            body: Center(child: CircularProgressIndicator()),
          );
        }
        final routine = state.routineById(session.routineId);
        final items = state.activeRoutineItems;
        final completed = state.completedRoutineItemIds;
        final total = items.length;
        final doneCount = completed.length;

        return Scaffold(
          appBar: AppBar(
            title: Text(routine?.routineName ?? 'Sesión activa'),
            leading: const BackButton(),
          ),
          body: Column(
            children: [
              _buildHeader(context, session, doneCount, total),
              Expanded(
                child: ListView.builder(
                  padding: const EdgeInsets.symmetric(vertical: 8),
                  itemCount: items.length,
                  itemBuilder: (ctx, i) => _buildItemTile(ctx, state, items[i]),
                ),
              ),
            ],
          ),
          bottomNavigationBar: _buildFinishBar(context),
        );
      },
    );
  }

  Widget _buildHeader(
    BuildContext context,
    ExerciseSessionLog session,
    int doneCount,
    int total,
  ) {
    final startTime = TimeOfDay.fromDateTime(session.gymArrivedAt);
    final startStr =
        '${startTime.hour}:${startTime.minute.toString().padLeft(2, '0')}';
    final progress = total == 0 ? 0.0 : doneCount / total;

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Iniciada a las $startStr',
              style: Theme.of(context).textTheme.bodySmall),
          const SizedBox(height: 6),
          VitalityProgressBar(value: progress),
          const SizedBox(height: 4),
          Text('$doneCount / $total ejercicios',
              style: Theme.of(context).textTheme.labelSmall),
        ],
      ),
    );
  }

  Widget _buildItemTile(
    BuildContext context,
    ExerciseState state,
    ExerciseRoutineItem item,
  ) {
    final isCompleted = state.completedRoutineItemIds.contains(item.id);
    final isExpanded = _expandedItemId == item.id && !isCompleted;

    IconData icon;
    if (isCompleted) {
      icon = Icons.check_circle;
    } else if (isExpanded) {
      icon = Icons.radio_button_checked;
    } else {
      icon = Icons.radio_button_unchecked;
    }

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
      child: VitalityCard(
        padding: EdgeInsets.zero,
        child: Column(
          children: [
            ListTile(
              leading: Icon(
                icon,
                color: isCompleted
                    ? Theme.of(context).colorScheme.tertiary
                    : isExpanded
                        ? Theme.of(context).colorScheme.primary
                        : null,
              ),
              title: Text(
                item.exerciseName,
                style: isCompleted
                    ? const TextStyle(decoration: TextDecoration.lineThrough)
                    : null,
              ),
              subtitle: BlocBuilder<ExerciseWeightUnitCubit, String>(
                builder: (ctx, unit) => Text(
                  '${item.sets} series × ${item.repsLabel ?? item.reps} reps'
                  '${item.weightKg != null ? ' @ ${item.weightKg}$unit' : ''}'
                  '${item.notes == null ? '' : '\n${item.notes}'}',
                ),
              ),
              onTap: isCompleted
                  ? null
                  : () {
                      if (!isExpanded) {
                        _initRowsIfNeeded(item, state);
                      }
                      setState(() {
                        _expandedItemId = isExpanded ? null : item.id;
                      });
                    },
            ),
            if (isExpanded) _buildExpandedPanel(context, state, item),
          ],
        ),
      ),
    );
  }

  Widget _buildFinishBar(BuildContext context) {
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: ElevatedButton.icon(
          onPressed: () {
            context
                .read<ExerciseBloc>()
                .add(ExerciseSessionEnded(sessionId: widget.sessionId));
            Navigator.of(context).pop();
          },
          icon: const Icon(Icons.flag),
          label: const Text('Finalizar sesión'),
          style: ElevatedButton.styleFrom(
            minimumSize: const Size.fromHeight(48),
          ),
        ),
      ),
    );
  }

  // ── Lógica de filas ────────────────────────────────────────────────────────

  void _initRowsIfNeeded(ExerciseRoutineItem item, ExerciseState state) {
    if (_itemRows.containsKey(item.id)) return;

    final defs = state.sessionSetDefs[item.id] ?? [];
    final savedSets = state.sessionSets
        .where((s) => s.exerciseName == item.exerciseName)
        .toList()
      ..sort((a, b) => a.setNumber.compareTo(b.setNumber));

    final rows = <_SetRowData>[];

    if (defs.isNotEmpty) {
      for (final def in defs) {
        final saved = savedSets.length >= def.setNumber
            ? savedSets[def.setNumber - 1]
            : null;
        rows.add(_SetRowData(
          displayNumber: def.setNumber,
          setType: def.dropOfSetNumber != null ? 'drop' : 'normal',
          parentSetNumber: def.dropOfSetNumber,
          repsCtrl: TextEditingController(
            text: saved != null
                ? '${saved.reps}'
                : def.reps > 0
                    ? '${def.reps}'
                    : '',
          ),
          weightCtrl: TextEditingController(
            text: saved != null
                ? (saved.weightKg?.toString() ?? '')
                : (def.weightKg?.toString() ?? ''),
          ),
          saved: saved != null,
          savedSetLogId: saved?.id,
        ));
      }
    } else {
      for (var i = 1; i <= item.sets; i++) {
        final saved = savedSets.length >= i ? savedSets[i - 1] : null;
        rows.add(_SetRowData(
          displayNumber: i,
          setType: saved?.setType ?? 'normal',
          repsCtrl: TextEditingController(
            text: saved != null ? '${saved.reps}' : '',
          ),
          weightCtrl: TextEditingController(
            text: saved?.weightKg?.toString() ?? '',
          ),
          saved: saved != null,
          savedSetLogId: saved?.id,
        ));
      }
    }

    _itemRows[item.id] = rows;
  }

  void _syncSavedRows(ExerciseState state) {
    for (final entry in _itemRows.entries) {
      final itemId = entry.key;
      final rows = entry.value;

      final routineId = state.activeSession?.routineId;
      if (routineId == null) continue;
      final items = state.routineItemsByRoutine[routineId] ?? [];
      final item = items
          .cast<ExerciseRoutineItem?>()
          .firstWhere((i) => i?.id == itemId, orElse: () => null);
      if (item == null) continue;

      final savedSets = state.sessionSets
          .where((s) => s.exerciseName == item.exerciseName)
          .toList();

      for (final row in rows) {
        if (row.saved) continue;
        final match = savedSets.cast<ExerciseSetLog?>().firstWhere(
              (s) => s?.setNumber == row.displayNumber,
              orElse: () => null,
            );
        if (match != null) {
          WidgetsBinding.instance.addPostFrameCallback((_) {
            if (mounted) {
              setState(() {
                row.saved = true;
                row.savedSetLogId = match.id;
              });
            }
          });
        }
      }
    }
  }

  // ── Acciones ───────────────────────────────────────────────────────────────

  void _addRow(ExerciseRoutineItem item, String setType) {
    final rows = _itemRows[item.id] ??= [];
    final nextNumber = rows.isEmpty ? 1 : rows.last.displayNumber + 1;
    setState(() {
      rows.add(_SetRowData(
        displayNumber: nextNumber,
        setType: setType,
        repsCtrl: TextEditingController(),
        weightCtrl: TextEditingController(),
      ));
    });
  }

  void _addDropRow(ExerciseRoutineItem item, List<_SetRowData> rows) {
    final savedRows = rows.where((r) => r.saved).toList();
    if (savedRows.isEmpty) return; // guard — botón debería estar deshabilitado
    final lastSaved = savedRows.last;
    final nextNumber = rows.last.displayNumber + 1;
    setState(() {
      rows.add(_SetRowData(
        displayNumber: nextNumber,
        setType: 'drop',
        parentSetNumber: lastSaved.displayNumber,
        repsCtrl: TextEditingController(),
        weightCtrl: TextEditingController(),
      ));
    });
  }

  void _saveRow(
    BuildContext context,
    ExerciseState state,
    ExerciseRoutineItem item,
    _SetRowData row,
    List<_SetRowData> allRows,
  ) {
    final reps = int.tryParse(row.repsCtrl.text);
    if (reps == null) return;
    final weightKg = double.tryParse(row.weightCtrl.text);

    int? dropOfSetId;
    if (row.setType == 'drop') {
      dropOfSetId = _parentSavedId(state, item, row, allRows);
      if (dropOfSetId == null) return;
    }

    context.read<ExerciseBloc>().add(ExerciseSetLogged(
          sessionId: widget.sessionId,
          exerciseName: item.exerciseName,
          setNumber: row.displayNumber,
          reps: reps,
          weightKg: weightKg,
          setType: row.setType,
          dropOfSetId: dropOfSetId,
        ));
  }

  int? _parentSavedId(
    ExerciseState state,
    ExerciseRoutineItem item,
    _SetRowData row,
    List<_SetRowData> allRows,
  ) {
    final parentNum = row.parentSetNumber;
    if (parentNum == null) return null;

    final parentRow = allRows.cast<_SetRowData?>().firstWhere(
          (r) => r?.displayNumber == parentNum,
          orElse: () => null,
        );
    if (parentRow?.savedSetLogId != null) return parentRow!.savedSetLogId;

    final saved = state.sessionSets.cast<ExerciseSetLog?>().firstWhere(
          (s) =>
              s?.exerciseName == item.exerciseName && s?.setNumber == parentNum,
          orElse: () => null,
        );
    return saved?.id;
  }

  void _markItemCompleted(BuildContext context, ExerciseRoutineItem item) {
    context
        .read<ExerciseBloc>()
        .add(ExerciseItemCompleted(routineItemId: item.id));
    setState(() => _expandedItemId = null);
  }

  // ── Fila de tabla ──────────────────────────────────────────────────────────

  TableRow _buildSetRow(
    BuildContext context,
    ExerciseState state,
    ExerciseRoutineItem item,
    _SetRowData row,
    List<_SetRowData> allRows,
  ) {
    final theme = Theme.of(context);
    final isReadonly = row.saved;
    final repsOk = int.tryParse(row.repsCtrl.text) != null;
    final canSave = !row.saved &&
        repsOk &&
        (row.setType != 'drop' ||
            _parentSavedId(state, item, row, allRows) != null);

    final typeLabel = switch (row.setType) {
      'pyramid' => 'Pirámide',
      'drop' => 'Drop',
      _ => 'Normal',
    };

    return TableRow(children: [
      // # de serie
      Padding(
        padding: const EdgeInsets.symmetric(vertical: 8),
        child: Text(
          '${row.displayNumber}',
          textAlign: TextAlign.center,
          style: row.setType == 'drop'
              ? theme.textTheme.bodySmall
                  ?.copyWith(color: theme.colorScheme.secondary)
              : null,
        ),
      ),

      // Tipo
      Padding(
        padding: const EdgeInsets.symmetric(vertical: 8),
        child: Text(typeLabel, style: theme.textTheme.bodySmall),
      ),

      // Reps
      Padding(
        padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 4),
        child: TextField(
          controller: row.repsCtrl,
          keyboardType: TextInputType.number,
          readOnly: isReadonly,
          style: theme.textTheme.bodyMedium?.copyWith(
            color: theme.colorScheme.onSurface,
          ),
          decoration: const InputDecoration(
            isDense: true,
            contentPadding: EdgeInsets.symmetric(horizontal: 6, vertical: 6),
          ),
          onChanged: (_) => setState(() {}),
        ),
      ),

      // Peso
      Padding(
        padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 4),
        child: TextField(
          controller: row.weightCtrl,
          keyboardType: const TextInputType.numberWithOptions(decimal: true),
          readOnly: isReadonly,
          style: theme.textTheme.bodyMedium?.copyWith(
            color: theme.colorScheme.onSurface,
          ),
          decoration: const InputDecoration(
            isDense: true,
            contentPadding: EdgeInsets.symmetric(horizontal: 6, vertical: 6),
          ),
          onChanged: (_) => setState(() {}),
        ),
      ),

      // Guardar / check
      isReadonly
          ? const Center(
              child: Icon(Icons.check_circle, color: Colors.green, size: 20),
            )
          : TextButton(
              onPressed: canSave
                  ? () => _saveRow(context, state, item, row, allRows)
                  : null,
              child: const Text('Guardar'),
            ),
    ]);
  }

  // ── Panel expandido ────────────────────────────────────────────────────────

  Widget _buildExpandedPanel(
    BuildContext context,
    ExerciseState state,
    ExerciseRoutineItem item,
  ) {
    final rows = _itemRows[item.id] ?? [];
    final historical = state.sessionHistorical[item.exerciseName] ?? [];
    final theme = Theme.of(context);

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // ── Referencia histórica ──────────────────────────────────────
          BlocBuilder<ExerciseWeightUnitCubit, String>(
            builder: (ctx, unit) => Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (historical.isNotEmpty) ...[
                  const Divider(),
                  Text('Última sesión', style: theme.textTheme.labelLarge),
                  const SizedBox(height: 4),
                  ...historical.map(
                    (s) => Text(
                      '  Serie ${s.setNumber}: ${s.reps} reps'
                      '${s.weightKg != null ? ' @ ${s.weightKg}$unit' : ''}',
                      style: theme.textTheme.bodySmall,
                    ),
                  ),
                ] else ...[
                  const Divider(),
                  Text(
                    'Primera vez con este ejercicio',
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                  ),
                ],
                // ── Tabla de series ──────────────────────────────────────────
                const SizedBox(height: 8),
                if (rows.isEmpty)
                  Text('Sin series configuradas',
                      style: theme.textTheme.bodySmall)
                else
                  Table(
                    columnWidths: const {
                      0: FixedColumnWidth(28),
                      1: FixedColumnWidth(90),
                      2: FlexColumnWidth(),
                      3: FlexColumnWidth(),
                      4: FixedColumnWidth(72),
                    },
                    children: [
                      TableRow(
                        decoration: BoxDecoration(
                          border: Border(
                            bottom: BorderSide(
                                color: theme.colorScheme.outlineVariant),
                          ),
                        ),
                        children: [
                          const _TableHeader('#'),
                          const _TableHeader('Tipo'),
                          const _TableHeader('Reps'),
                          _TableHeader('Peso $unit'),
                          const _TableHeader(''),
                        ],
                      ),
                      ...rows.map(
                          (row) => _buildSetRow(context, state, item, row, rows)),
                    ],
                  ),
              ],
            ),
          ),

          // ── Botones de acción ─────────────────────────────────────────
          const SizedBox(height: 12),
          Row(
            children: [
              OutlinedButton.icon(
                onPressed: () => _addRow(item, 'normal'),
                icon: const Icon(Icons.add, size: 16),
                label: const Text('+ Serie'),
              ),
              const SizedBox(width: 8),
              OutlinedButton.icon(
                onPressed: rows.any((r) => r.saved)
                    ? () => _addDropRow(item, rows)
                    : null,
                icon: const Icon(Icons.arrow_downward, size: 16),
                label: const Text('+ Drop'),
              ),
              const Spacer(),
              ElevatedButton.icon(
                onPressed: () => _markItemCompleted(context, item),
                icon: const Icon(Icons.flag, size: 16),
                label: const Text('Listo'),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

// ── Modelo local de fila ────────────────────────────────────────────────────

class _SetRowData {
  final int displayNumber;
  String setType;
  int? parentSetNumber;
  final TextEditingController repsCtrl;
  final TextEditingController weightCtrl;
  bool saved;
  int? savedSetLogId;

  _SetRowData({
    required this.displayNumber,
    required this.setType,
    this.parentSetNumber,
    required this.repsCtrl,
    required this.weightCtrl,
    this.saved = false,
    this.savedSetLogId,
  });
}

// ── Widgets auxiliares ──────────────────────────────────────────────────────

class _TableHeader extends StatelessWidget {
  final String text;
  const _TableHeader(this.text);

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.symmetric(vertical: 6),
        child: Text(
          text,
          style: Theme.of(context).textTheme.labelSmall,
          textAlign: TextAlign.center,
        ),
      );
}
