import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:kiolog/core/database/app_database.dart';
import '../bloc/exercise_bloc.dart';
import '../bloc/exercise_event.dart';
import '../bloc/exercise_state.dart';

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
                  itemBuilder: (ctx, i) =>
                      _buildItemTile(ctx, state, items[i]),
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
          LinearProgressIndicator(value: progress, minHeight: 6),
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

    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
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
            subtitle: Text('${item.sets} series × ${item.reps} reps'
                '${item.weightKg != null ? ' @ ${item.weightKg}kg' : ''}'),
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
          if (isExpanded)
            _buildExpandedPanel(context, state, item),
        ],
      ),
    );
  }

  Widget _buildFinishBar(BuildContext context) {
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: FilledButton.icon(
          onPressed: () {
            context
                .read<ExerciseBloc>()
                .add(ExerciseSessionEnded(sessionId: widget.sessionId));
            Navigator.of(context).pop();
          },
          icon: const Icon(Icons.flag),
          label: const Text('Finalizar sesión'),
          style: FilledButton.styleFrom(
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
      final item = items.cast<ExerciseRoutineItem?>()
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

  // ── Panel expandido (stub — Task 4 lo implementa) ─────────────────────────
  Widget _buildExpandedPanel(
    BuildContext context,
    ExerciseState state,
    ExerciseRoutineItem item,
  ) {
    return const SizedBox.shrink();
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
