# Exercise Phase B — Sesión Activa Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Implementar `ExerciseSessionPage` — pantalla de sesión activa con lista de ejercicios, panel expandido por ejercicio (referencia histórica + tabla de series), guardado inmediato de sets, y botón "Finalizar sesión". La sesión persiste al navegar back y puede reanudarse.

**Architecture:** El BLoC ya tiene `activeSession`, `sessionSets` y `completedRoutineItemIds`. Se agregan dos nuevos campos (`sessionSetDefs`, `sessionHistorical`) y un nuevo evento (`ExerciseSessionResumed`) para cargar el estado completo de la sesión. `ExercisePage` usa un `BlocListener` para hacer push de `ExerciseSessionPage` compartiendo el mismo BLoC via `BlocProvider.value`. La sesión page es `StatefulWidget` con estado local para filas editables.

**Tech Stack:** Flutter, flutter_bloc, Drift (SQLite), mocktail (tests).

---

## Mapa de archivos

| Archivo | Acción |
|---------|--------|
| `lib/features/exercise/presentation/bloc/exercise_event.dart` | Modificar — agregar `ExerciseSessionResumed` |
| `lib/features/exercise/presentation/bloc/exercise_state.dart` | Modificar — agregar `sessionSetDefs`, `sessionHistorical` |
| `lib/features/exercise/presentation/bloc/exercise_bloc.dart` | Modificar — agregar handler `_onSessionResumed` |
| `lib/features/exercise/presentation/pages/exercise_page.dart` | Modificar — `BlocListener` + push de sesión, banner de reanudación |
| `lib/features/exercise/presentation/pages/exercise_session_page.dart` | Crear — pantalla completa de sesión |
| `test/features/exercise/presentation/exercise_bloc_test.dart` | Modificar — agregar test de `ExerciseSessionResumed` |

---

## Task 1: ExerciseSessionResumed — evento, estado y handler BLoC

**Files:**
- Modify: `lib/features/exercise/presentation/bloc/exercise_event.dart`
- Modify: `lib/features/exercise/presentation/bloc/exercise_state.dart`
- Modify: `lib/features/exercise/presentation/bloc/exercise_bloc.dart`

- [ ] **Step 1: Escribir el test que falla (ExerciseSessionResumed carga setDefs + historical + sets)**

En `test/features/exercise/presentation/exercise_bloc_test.dart`, dentro del `group('ExerciseBloc', ...)`, agregar después del test de `ExerciseItemCompleted`:

```dart
blocTest<ExerciseBloc, ExerciseState>(
  'ExerciseSessionResumed carga sessionSetDefs, sessionHistorical y sessionSets',
  build: () {
    const setDef = ExerciseRoutineSetDef(
      id: 1, routineItemId: 1, setNumber: 1,
      dropOfSetNumber: null, reps: 12, weightKg: 75.0,
    );
    final histSet = ExerciseSetLog(
      id: 10, sessionId: 99, exerciseName: 'Press banca',
      setNumber: 1, reps: 12, weightKg: 75.0,
      setType: 'normal', dropOfSetId: null,
    );
    when(() => repository.getRoutineSetDefs(1))
        .thenAnswer((_) async => [setDef]);
    when(() => repository.getLastSessionSetsForExercise('Press banca'))
        .thenAnswer((_) async => [histSet]);
    when(() => repository.getSessionSets(5)).thenAnswer((_) async => []);

    const item = ExerciseRoutineItem(
      id: 1, routineId: 1, exerciseName: 'Press banca',
      sets: 3, reps: 12, weightKg: 60.0,
      setType: 'normal', orderIndex: 0,
    );
    final session = ExerciseSessionLog(
      id: 5, date: DateTime(2026, 6, 9),
      gymArrivedAt: DateTime(2026, 6, 9, 7, 0),
      routineId: 1,
    );
    return ExerciseBloc(repository)
      ..emit(ExerciseState(
        status: ExerciseStatus.success,
        activeSession: session,
        routineItemsByRoutine: const {1: [item]},
      ));
  },
  act: (bloc) => bloc.add(const ExerciseSessionResumed(sessionId: 5)),
  expect: () => [
    isA<ExerciseState>()
        .having((s) => s.sessionSetDefs[1]?.length, 'setDefs item 1', 1)
        .having(
          (s) => s.sessionHistorical['Press banca']?.length,
          'historical Press banca',
          1,
        )
        .having((s) => s.sessionSets.length, 'sessionSets', 0),
  ],
);
```

- [ ] **Step 2: Correr el test para verificar que falla**

```bash
flutter test test/features/exercise/presentation/exercise_bloc_test.dart --name "ExerciseSessionResumed"
```

Esperado: FAIL — `ExerciseSessionResumed` no existe aún.

- [ ] **Step 3: Agregar ExerciseSessionResumed a exercise_event.dart**

Al final de la sección `// ── Sesión ─────`, después de `ExerciseItemCompleted`, agregar:

```dart
class ExerciseSessionResumed extends ExerciseEvent {
  final int sessionId;
  const ExerciseSessionResumed({required this.sessionId});
  @override
  List<Object?> get props => [sessionId];
}
```

- [ ] **Step 4: Agregar sessionSetDefs y sessionHistorical a exercise_state.dart**

En los campos del constructor (después de `completedRoutineItemIds`):

```dart
final Map<int, List<ExerciseRoutineSetDef>> sessionSetDefs;
final Map<String, List<ExerciseSetLog>> sessionHistorical;
```

En el constructor `const ExerciseState({...})`, agregar los defaults:

```dart
this.sessionSetDefs = const {},
this.sessionHistorical = const {},
```

En `copyWith`, agregar los parámetros y propagarlos:

```dart
Map<int, List<ExerciseRoutineSetDef>>? sessionSetDefs,
Map<String, List<ExerciseSetLog>>? sessionHistorical,
```

```dart
sessionSetDefs: sessionSetDefs ?? this.sessionSetDefs,
sessionHistorical: sessionHistorical ?? this.sessionHistorical,
```

En `props`, agregar al final de la lista:

```dart
sessionSetDefs,
sessionHistorical,
```

- [ ] **Step 5: Agregar handler _onSessionResumed a exercise_bloc.dart**

En el constructor del BLoC, registrar el handler después de `on<ExerciseItemCompleted>`:

```dart
on<ExerciseSessionResumed>(_onSessionResumed);
```

Al final del archivo, agregar el método:

```dart
Future<void> _onSessionResumed(
    ExerciseSessionResumed event, Emitter<ExerciseState> emit) async {
  try {
    final routineId = state.activeSession?.routineId;
    final items = routineId != null
        ? (state.routineItemsByRoutine[routineId] ?? <ExerciseRoutineItem>[])
        : <ExerciseRoutineItem>[];

    final setDefs = <int, List<ExerciseRoutineSetDef>>{};
    final historical = <String, List<ExerciseSetLog>>{};

    for (final item in items) {
      setDefs[item.id] = await _repository.getRoutineSetDefs(item.id);
      historical[item.exerciseName] =
          await _repository.getLastSessionSetsForExercise(item.exerciseName);
    }

    final sets = await _repository.getSessionSets(event.sessionId);

    emit(state.copyWith(
      sessionSetDefs: setDefs,
      sessionHistorical: historical,
      sessionSets: sets,
    ));
  } catch (e) {
    emit(state.copyWith(status: ExerciseStatus.failure, error: e.toString()));
  }
}
```

- [ ] **Step 6: Correr el test para verificar que pasa**

```bash
flutter test test/features/exercise/presentation/exercise_bloc_test.dart --name "ExerciseSessionResumed"
```

Esperado: PASS

- [ ] **Step 7: Correr todos los tests**

```bash
flutter test
```

Esperado: todos los tests anteriores siguen pasando.

- [ ] **Step 8: Commit**

```bash
git add lib/features/exercise/presentation/bloc/exercise_event.dart \
        lib/features/exercise/presentation/bloc/exercise_state.dart \
        lib/features/exercise/presentation/bloc/exercise_bloc.dart \
        test/features/exercise/presentation/exercise_bloc_test.dart
git commit -m "feat(exercise-bloc): ExerciseSessionResumed event, sessionSetDefs y sessionHistorical en state"
```

---

## Task 2: ExercisePage — navegación hacia ExerciseSessionPage

**Files:**
- Modify: `lib/features/exercise/presentation/pages/exercise_page.dart`

Este task actualiza ExercisePage para:
1. Usar `BlocConsumer` que escucha cuando `activeSession` pasa de nulo a no-nulo y hace push de la sesión.
2. Reemplazar `_buildActiveSessionCard` por un banner de "Reanudar sesión" cuando hay sesión activa pero todavía no se navegó (ej: al abrir la app con sesión en progreso y tap en banner).

- [ ] **Step 1: Envolver _ExerciseView en BlocConsumer**

En `_ExerciseView.build(...)`, reemplaza el `BlocBuilder<ExerciseBloc, ExerciseState>` del body con un `BlocConsumer`:

```dart
body: BlocConsumer<ExerciseBloc, ExerciseState>(
  listenWhen: (prev, curr) =>
      !prev.hasActiveSession && curr.hasActiveSession,
  listener: (context, state) {
    Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => BlocProvider.value(
          value: context.read<ExerciseBloc>(),
          child: ExerciseSessionPage(
            sessionId: state.activeSession!.id,
          ),
        ),
      ),
    );
  },
  builder: (context, state) {
    // mismo contenido que tenía el BlocBuilder anterior
  },
),
```

Agregar el import de `ExerciseSessionPage` en el archivo:
```dart
import 'exercise_session_page.dart';
```

- [ ] **Step 2: Reemplazar _buildActiveSessionCard por banner de reanudación**

El método `_buildActiveSessionCard` ya existe pero no navega. Reemplazar su contenido para que sea un banner tapable que empuja la página de sesión:

```dart
Widget _buildResumeSessionBanner(BuildContext context, ExerciseState state) {
  final theme = Theme.of(context);
  final session = state.activeSession!;
  final routine = state.routineById(session.routineId);
  return Card(
    color: theme.colorScheme.primaryContainer,
    child: ListTile(
      leading: const Icon(Icons.fitness_center),
      title: Text(
        routine != null
            ? 'Sesión en curso — ${routine.routineName}'
            : 'Sesión en curso',
      ),
      subtitle: const Text('Toca para reanudar'),
      trailing: const Icon(Icons.chevron_right),
      onTap: () {
        Navigator.of(context).push(
          MaterialPageRoute<void>(
            builder: (_) => BlocProvider.value(
              value: context.read<ExerciseBloc>(),
              child: ExerciseSessionPage(sessionId: session.id),
            ),
          ),
        );
      },
    ),
  );
}
```

En el builder del body, cambiar la referencia a `_buildActiveSessionCard` por `_buildResumeSessionBanner`:

```dart
if (state.hasActiveSession)
  _buildResumeSessionBanner(context, state)
else
  _buildRoutinePicker(context, state),
```

Eliminar el método `_buildActiveSessionCard` (ya no se usa).

- [ ] **Step 3: Compilar para verificar que no hay errores**

```bash
flutter analyze lib/features/exercise/presentation/pages/exercise_page.dart
```

Esperado: sin errores (puede haber warning del import de exercise_session_page si el archivo no existe aún — ignorar).

- [ ] **Step 4: Commit**

```bash
git add lib/features/exercise/presentation/pages/exercise_page.dart
git commit -m "feat(exercise-page): BlocConsumer navega a sesión, banner de reanudación"
```

---

## Task 3: ExerciseSessionPage — scaffold, header y lista de ejercicios

**Files:**
- Create: `lib/features/exercise/presentation/pages/exercise_session_page.dart`

- [ ] **Step 1: Crear el archivo con el scaffold base**

Crear `lib/features/exercise/presentation/pages/exercise_session_page.dart`:

```dart
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
          bottomNavigationBar: _buildFinishBar(context, state),
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
                  ? Colors.green
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
                : () => setState(() {
                      _expandedItemId =
                          isExpanded ? null : item.id;
                      if (!isExpanded) {
                        _initRowsIfNeeded(item, state);
                      }
                    }),
          ),
          if (isExpanded)
            _buildExpandedPanel(context, state, item),
        ],
      ),
    );
  }

  Widget _buildFinishBar(BuildContext context, ExerciseState state) {
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
    // Cuando llegan nuevos sessionSets, marcar las filas guardadas
    for (final entry in _itemRows.entries) {
      final itemId = entry.key;
      final rows = entry.value;

      // Encontrar el exerciseName para este itemId
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
          setState(() {
            row.saved = true;
            row.savedSetLogId = match.id;
          });
        }
      }
    }
  }

  Widget _buildExpandedPanel(
    BuildContext context,
    ExerciseState state,
    ExerciseRoutineItem item,
  ) {
    // Implementado en Task 4
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
```

- [ ] **Step 2: Compilar**

```bash
flutter analyze lib/features/exercise/presentation/pages/exercise_session_page.dart
```

Esperado: sin errores.

- [ ] **Step 3: Correr todos los tests**

```bash
flutter test
```

Esperado: todos pasan.

- [ ] **Step 4: Commit**

```bash
git add lib/features/exercise/presentation/pages/exercise_session_page.dart
git commit -m "feat(exercise-session): scaffold, header, lista de ejercicios e inicialización de filas"
```

---

## Task 4: ExerciseSessionPage — panel expandido (historial + tabla de series)

**Files:**
- Modify: `lib/features/exercise/presentation/pages/exercise_session_page.dart`

Reemplaza el `_buildExpandedPanel` stub con la implementación real.

- [ ] **Step 1: Implementar _buildExpandedPanel**

Reemplazar el método stub en `_ExerciseSessionPageState`:

```dart
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
        // ── Referencia histórica ────────────────────────────────────────
        if (historical.isNotEmpty) ...[
          const Divider(),
          Text('Última sesión', style: theme.textTheme.labelLarge),
          const SizedBox(height: 4),
          ...historical.map(
            (s) => Text(
              '  Serie ${s.setNumber}: ${s.reps} reps'
              '${s.weightKg != null ? ' @ ${s.weightKg}kg' : ''}',
              style: theme.textTheme.bodySmall,
            ),
          ),
        ] else ...[
          const Divider(),
          Text('Primera vez con este ejercicio',
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              )),
        ],

        // ── Tabla de series ─────────────────────────────────────────────
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
                children: const [
                  _TableHeader('#'),
                  _TableHeader('Tipo'),
                  _TableHeader('Reps'),
                  _TableHeader('Peso kg'),
                  _TableHeader(''),
                ],
              ),
              ...rows.map((row) => _buildSetRow(
                    context, state, item, row, rows)),
            ],
          ),

        // ── Botones de acción ───────────────────────────────────────────
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
            FilledButton.icon(
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

TableRow _buildSetRow(
  BuildContext context,
  ExerciseState state,
  ExerciseRoutineItem item,
  _SetRowData row,
  List<_SetRowData> allRows,
) {
  final theme = Theme.of(context);
  final isReadonly = row.saved;
  final canSave = !row.saved &&
      row.repsCtrl.text.isNotEmpty &&
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
    isReadonly
        ? Padding(
            padding: const EdgeInsets.symmetric(vertical: 8),
            child: Text(typeLabel, style: theme.textTheme.bodySmall),
          )
        : DropdownButtonHideUnderline(
            child: DropdownButton<String>(
              value: row.setType,
              isDense: true,
              items: const [
                DropdownMenuItem(value: 'normal', child: Text('Normal')),
                DropdownMenuItem(
                    value: 'pyramid', child: Text('Pirámide')),
                DropdownMenuItem(value: 'drop', child: Text('Drop')),
              ],
              onChanged: (v) {
                if (v != null) setState(() => row.setType = v);
              },
            ),
          ),

    // Reps
    Padding(
      padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 4),
      child: TextField(
        controller: row.repsCtrl,
        keyboardType: TextInputType.number,
        readOnly: isReadonly,
        decoration: const InputDecoration(
          isDense: true,
          contentPadding:
              EdgeInsets.symmetric(horizontal: 6, vertical: 6),
          border: OutlineInputBorder(),
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
        decoration: const InputDecoration(
          isDense: true,
          contentPadding:
              EdgeInsets.symmetric(horizontal: 6, vertical: 6),
          border: OutlineInputBorder(),
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
```

Agregar también este widget helper estático al final del archivo (fuera de la clase state):

```dart
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
```

- [ ] **Step 2: Agregar métodos de acción (addRow, addDropRow, saveRow, markCompleted)**

Agregar en `_ExerciseSessionPageState` antes del método `_buildExpandedPanel`:

```dart
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
  // El drop se asocia a la última serie guardada
  final lastSaved = rows.lastWhere((r) => r.saved, orElse: () => rows.last);
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
    if (dropOfSetId == null) return; // padre no guardado aún
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

  // Buscar en las filas locales si el padre está guardado
  final parentRow = allRows.cast<_SetRowData?>()
      .firstWhere((r) => r?.displayNumber == parentNum, orElse: () => null);
  if (parentRow?.savedSetLogId != null) return parentRow!.savedSetLogId;

  // Buscar en sessionSets como fallback
  final saved = state.sessionSets.cast<ExerciseSetLog?>().firstWhere(
        (s) =>
            s?.exerciseName == item.exerciseName &&
            s?.setNumber == parentNum,
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
```

- [ ] **Step 3: Compilar**

```bash
flutter analyze lib/features/exercise/presentation/pages/exercise_session_page.dart
```

Esperado: sin errores de compilación.

- [ ] **Step 4: Correr todos los tests**

```bash
flutter test
```

Esperado: todos pasan.

- [ ] **Step 5: Commit**

```bash
git add lib/features/exercise/presentation/pages/exercise_session_page.dart
git commit -m "feat(exercise-session): panel expandido con historial, tabla de series y acciones"
```

---

## Task 5: Integración final — compile, analyze y smoke test manual

**Files:**
- Modify: `lib/features/exercise/presentation/pages/exercise_page.dart` (eliminar referencia a _buildActiveSessionCard si quedó alguna)

- [ ] **Step 1: Análisis estático completo del feature**

```bash
flutter analyze lib/features/exercise/
```

Esperado: 0 errores. Si hay warnings de unused import o unused variable, corregirlos.

- [ ] **Step 2: Correr todos los tests**

```bash
flutter test
```

Esperado: todos los tests pasan (deben ser ≥91 incluyendo el nuevo).

- [ ] **Step 3: Compilar APK de debug**

```bash
flutter build apk --debug 2>&1 | tail -20
```

Esperado: `Built build/app/outputs/flutter-apk/app-debug.apk` sin errores.

- [ ] **Step 4: Smoke test manual (si hay dispositivo/emulador)**

Flujo a verificar:
1. Abrir la app → pantalla de ejercicio.
2. Tocar "Entrené este día" en una rutina → debe navegar a `ExerciseSessionPage`.
3. La sesión muestra los ejercicios de la rutina con estado pendiente.
4. Tap en un ejercicio → se expande el panel con historial y filas de series.
5. Llenar reps y peso → tap "Guardar" → fila se marca con ✓.
6. Tap "Listo" → ejercicio se marca como completado (icono verde, tachado), barra de progreso avanza.
7. Tap en back → vuelve a `ExercisePage` con banner "Sesión en curso".
8. Tap en banner → vuelve a `ExerciseSessionPage` con la sesión reanudada.
9. Tap "Finalizar sesión" → vuelve a `ExercisePage`, sin banner.

- [ ] **Step 5: Commit final**

```bash
git add -p  # revisar que solo van cambios del feature
git commit -m "feat(exercise): Fase B completa — ExerciseSessionPage con sesión activa, panel expandido y reanudación"
```

---

## Notas técnicas

- `ExerciseRoutineSetDef.dropOfSetNumber` es un ordinal (número de serie padre), no un FK a `ExerciseSetLog`. El FK real es `ExerciseSetLog.dropOfSetId` que referencia otro `ExerciseSetLog.id`.
- `_syncSavedRows` se ejecuta cada vez que cambia `sessionSets.length`; marca filas como saved buscando por `exerciseName + setNumber`. Esto cubre tanto el guardado normal como la reanudación de sesión.
- El BLoC ya tiene `_onSessionEnded` que escribe `gymLeftAt` y limpia `activeSession` y `completedRoutineItemIds`. No se necesitan cambios ahí.
- El `BlocListener` en `ExercisePage` dispara push cuando `prev.hasActiveSession == false && curr.hasActiveSession == true`. Esto cubre tanto el inicio de sesión nueva como el inicio de la app con sesión en progreso (el estado pasa de `initial/loading` a `success`).
