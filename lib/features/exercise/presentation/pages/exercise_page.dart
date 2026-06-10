import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:kiolog/core/database/app_database.dart';
import 'package:kiolog/core/domain/app_module.dart';
import 'package:kiolog/core/modules/cubit/modules_cubit.dart';
import 'package:kiolog/core/modules/cubit/modules_state.dart';
import 'package:kiolog/shared/widgets/inactive_module_page.dart';
import 'package:kiolog/shared/widgets/vitality_card.dart';
import 'package:kiolog/shared/widgets/vitality_progress_bar.dart';
import '../../../../core/di/injection.dart';
import '../../domain/models/independent_exercise_log.dart';
import '../../domain/repositories/exercise_repository.dart';
import '../bloc/exercise_bloc.dart';
import '../bloc/exercise_event.dart';
import '../bloc/exercise_state.dart';
import 'exercise_session_page.dart';
import 'exercise_progress_page.dart';

class ExercisePage extends StatelessWidget {
  const ExercisePage({super.key});

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<ModulesCubit, ModulesState>(
      builder: (context, modulesState) {
        if (!modulesState.isEnabled(AppModule.exercise)) {
          return const InactiveModulePage(module: AppModule.exercise);
        }
        return BlocProvider(
          create: (_) => ExerciseBloc(getIt<ExerciseRepository>())
            ..add(ExerciseLoaded(date: DateTime.now())),
          child: const _ExerciseView(),
        );
      },
    );
  }
}

class _ExerciseView extends StatefulWidget {
  const _ExerciseView();

  @override
  State<_ExerciseView> createState() => _ExerciseViewState();
}

class _ExerciseViewState extends State<_ExerciseView> {
  int? _expandedRoutineId;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Ejercicio'),
        actions: [
          IconButton(
            icon: const Icon(Icons.bar_chart),
            onPressed: () {
              final bloc = context.read<ExerciseBloc>();
              Navigator.of(context).push(
                MaterialPageRoute<void>(
                  builder: (_) => BlocProvider.value(
                    value: bloc,
                    child: const ExerciseProgressPage(),
                  ),
                ),
              );
            },
          ),
          IconButton(
            icon: const Icon(Icons.history),
            onPressed: () => _showPlansDialog(context),
          ),
        ],
      ),
      body: BlocConsumer<ExerciseBloc, ExerciseState>(
        listenWhen: (prev, curr) =>
            prev.status == ExerciseStatus.success &&
            !prev.hasActiveSession &&
            curr.hasActiveSession,
        listener: (context, state) {
          final bloc = context.read<ExerciseBloc>();
          Navigator.of(context).push(
            MaterialPageRoute<void>(
              builder: (_) => BlocProvider.value(
                value: bloc,
                child: ExerciseSessionPage(
                  sessionId: state.activeSession!.id,
                ),
              ),
            ),
          );
        },
        builder: (context, state) {
          if (state.status == ExerciseStatus.loading &&
              state.activePlan == null) {
            return const Center(child: CircularProgressIndicator());
          }
          if (state.status == ExerciseStatus.failure) {
            return Center(child: Text('Error: ${state.error}'));
          }
          if (state.activePlan == null) {
            return _buildNoPlanView(context);
          }
          return SafeArea(
            child: ListView(
              padding: const EdgeInsets.all(16),
              children: [
                if (state.hasActiveSession)
                  _buildResumeSessionBanner(context, state),
                const SizedBox(height: 12),
                _buildRutinaSection(context, state),
                const SizedBox(height: 16),
                _buildCardioSection(context, state),
                const SizedBox(height: 16),
                _buildIndependentSection(context, state),
                const SizedBox(height: 80),
              ],
            ),
          );
        },
      ),
      bottomNavigationBar: BlocBuilder<ExerciseBloc, ExerciseState>(
        builder: (context, state) {
          if (state.activePlan == null) return const SizedBox.shrink();
          return _buildStartRoutineBar(context, state);
        },
      ),
    );
  }

  Widget _buildNoPlanView(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.fitness_center,
                size: 64,
                color: Theme.of(context).colorScheme.onSurfaceVariant),
            const SizedBox(height: 16),
            Text(
              'Sin plan de ejercicio',
              style: Theme.of(context).textTheme.headlineSmall,
            ),
            const SizedBox(height: 8),
            const Text(
              'Crea un plan para empezar a registrar tus rutinas.',
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 24),
            ElevatedButton.icon(
              onPressed: () => _showCreatePlanDialog(context),
              icon: const Icon(Icons.add),
              label: const Text('Crear plan'),
            ),
          ],
        ),
      ),
    );
  }

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
          final bloc = context.read<ExerciseBloc>();
          Navigator.of(context).push(
            MaterialPageRoute<void>(
              builder: (_) => BlocProvider.value(
                value: bloc,
                child: ExerciseSessionPage(sessionId: session.id),
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _buildRutinaSection(BuildContext context, ExerciseState state) {
    final theme = Theme.of(context);
    final completedIds = state.completedRoutineSessionsThisWeek
        .map((s) => s.routineId)
        .whereType<int>()
        .toSet();
    final done = completedIds.length;
    final goal = state.routineDaysGoal;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Text('🏋️ Rutina semanal',
                style: theme.textTheme.titleMedium
                    ?.copyWith(fontWeight: FontWeight.bold)),
            const Spacer(),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 2),
              decoration: BoxDecoration(
                color: done >= goal
                    ? theme.colorScheme.tertiaryContainer
                    : theme.colorScheme.surfaceContainerHighest,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Text(
                '$done / $goal días',
                style: theme.textTheme.labelSmall?.copyWith(
                  color: done >= goal
                      ? theme.colorScheme.onTertiaryContainer
                      : theme.colorScheme.onSurfaceVariant,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 6),
        VitalityProgressBar(
          value: goal > 0 ? (done / goal).clamp(0.0, 1.0) : 0,
          color: theme.colorScheme.tertiary,
        ),
        const SizedBox(height: 10),
        if (state.routines.isEmpty)
          VitalityCard(
            padding: const EdgeInsets.all(16),
            child: Column(
              children: [
                const Text('Sin días de rutina configurados.',
                    textAlign: TextAlign.center),
                const SizedBox(height: 12),
                ElevatedButton.icon(
                  onPressed: () => _showAddRoutineDialog(context, state),
                  icon: const Icon(Icons.add),
                  label: const Text('Agregar día de rutina'),
                ),
              ],
            ),
          )
        else
          ...state.routines.map((routine) {
            final isCompleted = completedIds.contains(routine.id);
            final isExpanded = _expandedRoutineId == routine.id;
            final items = state.routineItemsByRoutine[routine.id] ?? const [];

            return _buildRoutineDayCard(
              context: context,
              state: state,
              routine: routine,
              items: items,
              isCompleted: isCompleted,
              isExpanded: isExpanded,
            );
          }),
      ],
    );
  }

  Widget _buildRoutineDayCard({
    required BuildContext context,
    required ExerciseState state,
    required ExerciseRoutine routine,
    required List<ExerciseRoutineItem> items,
    required bool isCompleted,
    required bool isExpanded,
  }) {
    final theme = Theme.of(context);
    final Color borderColor = isCompleted
        ? theme.colorScheme.tertiary
        : isExpanded
            ? theme.colorScheme.primary
            : theme.colorScheme.outline;
    final Color bgColor = isCompleted
        ? theme.colorScheme.tertiaryContainer.withValues(alpha: 0.3)
        : isExpanded
            ? theme.colorScheme.primaryContainer.withValues(alpha: 0.2)
            : Colors.transparent;

    return Card(
      margin: const EdgeInsets.only(bottom: 6),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(8),
        side: BorderSide(color: borderColor, width: isExpanded ? 1.5 : 1),
      ),
      color: bgColor,
      child: Column(
        children: [
          InkWell(
            borderRadius: BorderRadius.circular(8),
            onTap: () => setState(() {
              _expandedRoutineId = isExpanded ? null : routine.id;
            }),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
              child: Row(
                children: [
                  CircleAvatar(
                    radius: 14,
                    backgroundColor: isCompleted
                        ? theme.colorScheme.tertiary
                        : theme.colorScheme.surfaceContainerHighest,
                    child: isCompleted
                        ? Icon(Icons.check,
                            size: 14, color: theme.colorScheme.onTertiary)
                        : Text(
                            '${routine.dayNumber}',
                            style: theme.textTheme.labelSmall,
                          ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(routine.routineName,
                            style: theme.textTheme.titleSmall?.copyWith(
                              color: isCompleted
                                  ? theme.colorScheme.tertiary
                                  : null,
                            )),
                        if (isCompleted)
                          Text(
                            'Completado esta semana',
                            style: theme.textTheme.bodySmall?.copyWith(
                              color: theme.colorScheme.tertiary,
                            ),
                          )
                        else
                          Text(
                            '${items.length} ejercicio(s)',
                            style: theme.textTheme.bodySmall?.copyWith(
                              color: theme.colorScheme.onSurfaceVariant,
                            ),
                          ),
                      ],
                    ),
                  ),
                  Icon(
                    isExpanded
                        ? Icons.keyboard_arrow_up
                        : Icons.keyboard_arrow_down,
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                ],
              ),
            ),
          ),
          if (isExpanded) ...[
            const Divider(height: 1),
            ...items.map((item) => _buildItemRow(context, item, routine.id)),
            Padding(
              padding: const EdgeInsets.fromLTRB(12, 4, 12, 8),
              child: Align(
                alignment: Alignment.centerRight,
                child: OutlinedButton.icon(
                  onPressed: () => _showExerciseDialog(context, state,
                      routineId: routine.id),
                  icon: const Icon(Icons.add, size: 16),
                  label: const Text('Ejercicio'),
                  style: OutlinedButton.styleFrom(
                    visualDensity: VisualDensity.compact,
                  ),
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildItemRow(
      BuildContext context, ExerciseRoutineItem item, int routineId) {
    final theme = Theme.of(context);
    final weightStr = item.weightKg != null ? ' @ ${item.weightKg}kg' : '';
    return ListTile(
      dense: true,
      contentPadding: const EdgeInsets.only(left: 16, right: 4),
      title: Text(item.exerciseName, style: theme.textTheme.bodyMedium),
      subtitle: Text(
        '${item.sets}×${item.reps}$weightStr · ${item.setType}',
        style: theme.textTheme.bodySmall
            ?.copyWith(color: theme.colorScheme.onSurfaceVariant),
      ),
      trailing: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          IconButton(
            icon: const Icon(Icons.edit_outlined, size: 18),
            onPressed: () => _showExerciseDialog(
                context, context.read<ExerciseBloc>().state,
                item: item, routineId: routineId),
            visualDensity: VisualDensity.compact,
          ),
          IconButton(
            icon: const Icon(Icons.delete_outline, size: 18),
            color: theme.colorScheme.error,
            onPressed: () => _confirmDeleteItem(context, item),
            visualDensity: VisualDensity.compact,
          ),
        ],
      ),
    );
  }

  void _showExerciseDialog(
    BuildContext context,
    ExerciseState state, {
    ExerciseRoutineItem? item,
    required int routineId,
  }) {
    final nameCtrl = TextEditingController(text: item?.exerciseName ?? '');
    final setsCtrl =
        TextEditingController(text: item != null ? '${item.sets}' : '');
    final repsCtrl =
        TextEditingController(text: item != null ? '${item.reps}' : '');
    final weightCtrl = TextEditingController(
        text: item?.weightKg != null ? '${item!.weightKg}' : '');
    String selectedType = item?.setType ?? 'normal';

    List<(TextEditingController, TextEditingController)> setRows = [];

    void rebuildRows(int count, StateSetter setInner) {
      setInner(() {
        while (setRows.length < count) {
          setRows.add((TextEditingController(), TextEditingController()));
        }
        while (setRows.length > count) {
          setRows.last.$1.dispose();
          setRows.last.$2.dispose();
          setRows.removeLast();
        }
      });
    }

    showDialog(
      context: context,
      builder: (dialogContext) => StatefulBuilder(
        builder: (ctx, setInner) {
          final isNormal = selectedType == 'normal';
          final setsCount = int.tryParse(setsCtrl.text) ?? 0;

          return AlertDialog(
            title:
                Text(item == null ? 'Agregar ejercicio' : 'Editar ejercicio'),
            content: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  TextField(
                    controller: nameCtrl,
                    decoration: const InputDecoration(labelText: 'Nombre *'),
                    autofocus: item == null,
                  ),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      Expanded(
                        child: TextField(
                          controller: setsCtrl,
                          decoration:
                              const InputDecoration(labelText: 'Series *'),
                          keyboardType: TextInputType.number,
                          onChanged: (v) {
                            if (!isNormal) {
                              rebuildRows(int.tryParse(v) ?? 0, setInner);
                            }
                          },
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: TextField(
                          controller: repsCtrl,
                          decoration:
                              const InputDecoration(labelText: 'Reps *'),
                          keyboardType: TextInputType.number,
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: TextField(
                          controller: weightCtrl,
                          decoration: const InputDecoration(labelText: 'kg'),
                          keyboardType: const TextInputType.numberWithOptions(
                              decimal: true),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  DropdownButtonFormField<String>(
                    value: selectedType,
                    decoration:
                        const InputDecoration(labelText: 'Tipo de serie'),
                    items: const [
                      DropdownMenuItem(value: 'normal', child: Text('Normal')),
                      DropdownMenuItem(
                          value: 'pyramid', child: Text('Pirámide')),
                      DropdownMenuItem(
                          value: 'pyramid_drop',
                          child: Text('Pirámide + Drop')),
                    ],
                    onChanged: (v) {
                      if (v == null) return;
                      setInner(() => selectedType = v);
                      if (v != 'normal') {
                        rebuildRows(setsCount, setInner);
                      } else {
                        setInner(() {
                          for (final r in setRows) {
                            r.$1.dispose();
                            r.$2.dispose();
                          }
                          setRows = [];
                        });
                      }
                    },
                  ),
                  if (!isNormal && setRows.isNotEmpty) ...[
                    const SizedBox(height: 12),
                    Text('Detalle por serie',
                        style: Theme.of(ctx).textTheme.labelSmall),
                    const SizedBox(height: 4),
                    ...List.generate(setRows.length, (i) {
                      final (rCtrl, wCtrl) = setRows[i];
                      return Padding(
                        padding: const EdgeInsets.only(bottom: 4),
                        child: Row(
                          children: [
                            SizedBox(
                                width: 24,
                                child: Text('${i + 1}',
                                    style: Theme.of(ctx).textTheme.bodySmall)),
                            const SizedBox(width: 8),
                            Expanded(
                              child: TextField(
                                controller: rCtrl,
                                decoration: const InputDecoration(
                                    labelText: 'Reps', isDense: true),
                                keyboardType: TextInputType.number,
                              ),
                            ),
                            const SizedBox(width: 8),
                            Expanded(
                              child: TextField(
                                controller: wCtrl,
                                decoration: const InputDecoration(
                                    labelText: 'kg', isDense: true),
                                keyboardType:
                                    const TextInputType.numberWithOptions(
                                        decimal: true),
                              ),
                            ),
                          ],
                        ),
                      );
                    }),
                  ],
                ],
              ),
            ),
            actions: [
              TextButton(
                onPressed: () {
                  for (final r in setRows) {
                    r.$1.dispose();
                    r.$2.dispose();
                  }
                  Navigator.pop(dialogContext);
                },
                child: const Text('Cancelar'),
              ),
              ElevatedButton(
                onPressed: () {
                  final name = nameCtrl.text.trim();
                  final sets = int.tryParse(setsCtrl.text);
                  final reps = int.tryParse(repsCtrl.text);
                  if (name.isEmpty || sets == null || reps == null) return;
                  final weight =
                      double.tryParse(weightCtrl.text.replaceAll(',', '.'));

                  final defs = setRows.isNotEmpty
                      ? List.generate(setRows.length, (i) {
                          final (rCtrl, wCtrl) = setRows[i];
                          return (
                            setNumber: i + 1,
                            dropOfSetNumber: null as int?,
                            reps: int.tryParse(rCtrl.text) ?? reps,
                            weightKg: double.tryParse(
                                wCtrl.text.replaceAll(',', '.')),
                          );
                        })
                      : <({
                          int setNumber,
                          int? dropOfSetNumber,
                          int reps,
                          double? weightKg
                        })>[];

                  if (item == null) {
                    context.read<ExerciseBloc>().add(
                          ExerciseRoutineItemAdded(
                            routineId: routineId,
                            exerciseName: name,
                            sets: sets,
                            reps: reps,
                            weightKg: weight,
                            setType: selectedType,
                            setDefs: defs,
                          ),
                        );
                  } else {
                    context.read<ExerciseBloc>().add(
                          ExerciseRoutineItemUpdated(
                            itemId: item.id,
                            exerciseName: name,
                            sets: sets,
                            reps: reps,
                            weightKg: weight,
                            setType: selectedType,
                            setDefs: defs.isEmpty ? null : defs,
                          ),
                        );
                  }
                  for (final r in setRows) {
                    r.$1.dispose();
                    r.$2.dispose();
                  }
                  Navigator.pop(dialogContext);
                },
                child: const Text('Guardar'),
              ),
            ],
          );
        },
      ),
    );
  }

  void _confirmDeleteItem(BuildContext context, ExerciseRoutineItem item) {
    showDialog<void>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('¿Eliminar ejercicio?'),
        content: Text('Se eliminará "${item.exerciseName}" de la rutina.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: const Text('Cancelar'),
          ),
          ElevatedButton(
            onPressed: () {
              context.read<ExerciseBloc>().add(ExerciseRoutineItemDeleted(
                    itemId: item.id,
                    routineId: item.routineId,
                  ));
              Navigator.pop(dialogContext);
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: Theme.of(context).colorScheme.error,
              foregroundColor: Theme.of(context).colorScheme.onError,
            ),
            child: const Text('Eliminar'),
          ),
        ],
      ),
    );
  }

  // ── Cardio ───────────────────────────────────────────────────────────────────

  Widget _buildCardioSection(BuildContext context, ExerciseState state) {
    final theme = Theme.of(context);
    final done = state.weeklyCardioLogs.length;
    final goal = state.cardioDaysGoal;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Text('🏃 Cardio semanal',
                style: theme.textTheme.titleMedium
                    ?.copyWith(fontWeight: FontWeight.bold)),
            const Spacer(),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 2),
              decoration: BoxDecoration(
                color: done >= goal
                    ? theme.colorScheme.tertiaryContainer
                    : theme.colorScheme.surfaceContainerHighest,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Text(
                '$done / $goal días',
                style: theme.textTheme.labelSmall?.copyWith(
                  fontWeight: FontWeight.bold,
                  color: done >= goal
                      ? theme.colorScheme.onTertiaryContainer
                      : theme.colorScheme.onSurfaceVariant,
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 6),
        VitalityProgressBar(
          value: goal > 0 ? (done / goal).clamp(0.0, 1.0) : 0,
          color: theme.colorScheme.primary,
        ),
        const SizedBox(height: 10),
        ...state.weeklyCardioLogs.map((log) => _buildCardioItem(context, log)),
        _buildDashedAddButton(
          context: context,
          label: '＋ Registrar cardio',
          color: theme.colorScheme.primary,
          onTap: () => _showCardioDialog(context),
        ),
      ],
    );
  }

  Widget _buildCardioItem(BuildContext context, CardioLog log) {
    final theme = Theme.of(context);
    final weekday = _weekdayName(log.date.weekday);
    final icon = _cardioIcon(log.cardioType);
    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: VitalityCard(
        padding: EdgeInsets.zero,
        child: ListTile(
          leading: Text(icon, style: const TextStyle(fontSize: 20)),
          title: Text(log.cardioType),
          subtitle: Text('${log.durationMinutes} min · $weekday'),
          trailing: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              IconButton(
                icon: const Icon(Icons.edit_outlined, size: 18),
                onPressed: () => _showCardioDialog(context, log: log),
                visualDensity: VisualDensity.compact,
              ),
              IconButton(
                icon: const Icon(Icons.delete_outline, size: 18),
                color: theme.colorScheme.error,
                onPressed: () => context
                    .read<ExerciseBloc>()
                    .add(CardioDeleted(cardioId: log.id)),
                visualDensity: VisualDensity.compact,
              ),
            ],
          ),
        ),
      ),
    );
  }

  String _cardioIcon(String type) {
    switch (type.toLowerCase()) {
      case 'correr':
        return '🏃';
      case 'bici':
        return '🚴';
      case 'elíptica':
      case 'eliptica':
        return '⬡';
      case 'nadar':
        return '🏊';
      default:
        return '💧';
    }
  }

  void _showCardioDialog(BuildContext context, {CardioLog? log}) {
    const types = ['Correr', 'Bici', 'Elíptica', 'Nadar', 'Otro'];
    String selectedType = log?.cardioType ?? types.first;
    final durationCtrl = TextEditingController(
        text: log != null ? '${log.durationMinutes}' : '');

    showDialog<void>(
      context: context,
      builder: (dialogContext) => StatefulBuilder(
        builder: (ctx, setInner) => AlertDialog(
          title: Text(log == null ? 'Registrar cardio' : 'Editar cardio'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              DropdownButtonFormField<String>(
                value: selectedType,
                decoration: const InputDecoration(labelText: 'Tipo'),
                items: types
                    .map((t) => DropdownMenuItem(value: t, child: Text(t)))
                    .toList(),
                onChanged: (v) {
                  if (v != null) setInner(() => selectedType = v);
                },
              ),
              const SizedBox(height: 8),
              TextField(
                controller: durationCtrl,
                decoration:
                    const InputDecoration(labelText: 'Duración (minutos) *'),
                keyboardType: TextInputType.number,
                autofocus: log == null,
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext),
              child: const Text('Cancelar'),
            ),
            ElevatedButton(
              onPressed: () {
                final duration = int.tryParse(durationCtrl.text);
                if (duration == null || duration <= 0) return;
                if (log == null) {
                  context.read<ExerciseBloc>().add(CardioLogged(
                        date: DateTime.now(),
                        cardioType: selectedType,
                        durationMinutes: duration,
                      ));
                } else {
                  context.read<ExerciseBloc>().add(CardioUpdated(
                        cardioId: log.id,
                        cardioType: selectedType,
                        durationMinutes: duration,
                      ));
                }
                Navigator.pop(dialogContext);
              },
              child: const Text('Guardar'),
            ),
          ],
        ),
      ),
    );
  }

  // ── Ejercicio libre ──────────────────────────────────────────────────────

  Widget _buildIndependentSection(BuildContext context, ExerciseState state) {
    final theme = Theme.of(context);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Text('💪 Ejercicio libre',
                style: theme.textTheme.titleMedium
                    ?.copyWith(fontWeight: FontWeight.bold)),
            const Spacer(),
            Text('esta semana',
                style: theme.textTheme.bodySmall
                    ?.copyWith(color: theme.colorScheme.onSurfaceVariant)),
          ],
        ),
        const SizedBox(height: 10),
        ...state.weeklyIndependentLogs
            .map((log) => _buildIndependentItem(context, log)),
        _buildDashedAddButton(
          context: context,
          label: '＋ Registrar ejercicio libre',
          color: theme.colorScheme.secondary,
          onTap: () => _showIndependentExerciseDialog(context),
        ),
      ],
    );
  }

  Widget _buildIndependentItem(
      BuildContext context, IndependentExerciseLog log) {
    final theme = Theme.of(context);
    final weightStr = log.weightKg != null ? ' @ ${log.weightKg}kg' : '';
    final weekday = _weekdayName(log.date.weekday);
    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: VitalityCard(
        padding: EdgeInsets.zero,
        child: ListTile(
          title: Text(log.exerciseName),
          subtitle: Text('${log.sets}×${log.reps}$weightStr · $weekday'),
          trailing: IconButton(
            icon: const Icon(Icons.delete_outline, size: 18),
            color: theme.colorScheme.error,
            onPressed: () => context
                .read<ExerciseBloc>()
                .add(IndependentExerciseDeleted(sessionId: log.sessionId)),
            visualDensity: VisualDensity.compact,
          ),
        ),
      ),
    );
  }

  void _showIndependentExerciseDialog(BuildContext context) {
    final nameCtrl = TextEditingController();
    final setsCtrl = TextEditingController();
    final repsCtrl = TextEditingController();
    final weightCtrl = TextEditingController();

    showDialog<void>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Registrar ejercicio libre'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: nameCtrl,
              decoration: const InputDecoration(labelText: 'Nombre *'),
              autofocus: true,
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: setsCtrl,
                    decoration: const InputDecoration(labelText: 'Series *'),
                    keyboardType: TextInputType.number,
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: TextField(
                    controller: repsCtrl,
                    decoration: const InputDecoration(labelText: 'Reps *'),
                    keyboardType: TextInputType.number,
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: TextField(
                    controller: weightCtrl,
                    decoration: const InputDecoration(labelText: 'kg'),
                    keyboardType:
                        const TextInputType.numberWithOptions(decimal: true),
                  ),
                ),
              ],
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: const Text('Cancelar'),
          ),
          ElevatedButton(
            onPressed: () {
              final name = nameCtrl.text.trim();
              final sets = int.tryParse(setsCtrl.text);
              final reps = int.tryParse(repsCtrl.text);
              if (name.isEmpty || sets == null || reps == null) return;
              final weight =
                  double.tryParse(weightCtrl.text.replaceAll(',', '.'));
              context.read<ExerciseBloc>().add(IndependentExerciseLogged(
                    date: DateTime.now(),
                    exerciseName: name,
                    sets: sets,
                    reps: reps,
                    weightKg: weight,
                  ));
              Navigator.pop(dialogContext);
            },
            child: const Text('Guardar'),
          ),
        ],
      ),
    );
  }

  // ── Sticky start-routine button ───────────────────────────────────────────

  Widget _buildStartRoutineBar(BuildContext context, ExerciseState state) {
    final completedIds = state.completedRoutineSessionsThisWeek
        .map((s) => s.routineId)
        .whereType<int>()
        .toSet();

    final nextRoutine = state.routines.isEmpty
        ? null
        : state.routines.firstWhere(
            (r) => !completedIds.contains(r.id),
            orElse: () => state.routines.first,
          );

    final enabled = nextRoutine != null && !state.hasActiveSession;

    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
        child: ElevatedButton.icon(
          onPressed: enabled
              ? () => context.read<ExerciseBloc>().add(
                    ExerciseSessionStarted(
                      date: DateTime.now(),
                      routineId: nextRoutine.id,
                    ),
                  )
              : null,
          icon: const Icon(Icons.play_arrow),
          label: Text(state.hasActiveSession
              ? 'Sesión en curso'
              : state.routines.isEmpty
                  ? 'Sin rutinas configuradas'
                  : 'Iniciar rutina del día'),
          style: ElevatedButton.styleFrom(
            minimumSize: const Size.fromHeight(48),
          ),
        ),
      ),
    );
  }

  // ── Shared helpers ────────────────────────────────────────────────────────

  Widget _buildDashedAddButton({
    required BuildContext context,
    required String label,
    required Color color,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(vertical: 10),
        decoration: BoxDecoration(
          border: Border.all(color: color.withValues(alpha: 0.5), width: 1),
          borderRadius: BorderRadius.circular(8),
        ),
        child: Center(
          child: Text(label,
              style: TextStyle(color: color, fontWeight: FontWeight.w500)),
        ),
      ),
    );
  }

  String _weekdayName(int weekday) {
    const names = [
      '',
      'lunes',
      'martes',
      'miércoles',
      'jueves',
      'viernes',
      'sábado',
      'domingo'
    ];
    return names[weekday.clamp(1, 7)];
  }

  void _showAddRoutineDialog(BuildContext context, ExerciseState state) {
    final nameController = TextEditingController();
    final nextDay = state.routines.isEmpty
        ? 1
        : (state.routines
                .map((r) => r.dayNumber)
                .reduce((a, b) => a > b ? a : b) +
            1);

    showDialog(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text('Día $nextDay de rutina'),
        content: TextField(
          controller: nameController,
          decoration: const InputDecoration(
            labelText: 'Nombre de la rutina',
            hintText: 'Ej: Pecho y tríceps',
          ),
          autofocus: true,
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: const Text('Cancelar'),
          ),
          ElevatedButton(
            onPressed: () {
              if (nameController.text.isNotEmpty) {
                context.read<ExerciseBloc>().add(
                      ExerciseRoutineAdded(
                        planId: state.activePlan!.id,
                        dayNumber: nextDay,
                        routineName: nameController.text,
                      ),
                    );
              }
              Navigator.pop(dialogContext);
            },
            child: const Text('Agregar'),
          ),
        ],
      ),
    );
  }

  void _showPlansDialog(BuildContext context) {
    context.read<ExerciseBloc>().add(const ExercisePlanLoaded());
    showDialog(
      context: context,
      builder: (dialogContext) => BlocProvider.value(
        value: context.read<ExerciseBloc>(),
        child: const _PlansDialog(),
      ),
    );
  }

  void _showCreatePlanDialog(BuildContext context) {
    final controller = TextEditingController();
    showDialog(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Nuevo plan de ejercicio'),
        content: TextField(
          controller: controller,
          decoration: const InputDecoration(labelText: 'Nombre del plan'),
          autofocus: true,
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: const Text('Cancelar'),
          ),
          ElevatedButton(
            onPressed: () {
              if (controller.text.isNotEmpty) {
                context.read<ExerciseBloc>().add(
                      ExercisePlanCreated(name: controller.text),
                    );
              }
              Navigator.pop(dialogContext);
            },
            child: const Text('Crear'),
          ),
        ],
      ),
    );
  }
}

class _PlansDialog extends StatelessWidget {
  const _PlansDialog();

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Planes de ejercicio'),
      content: SizedBox(
        width: double.maxFinite,
        child: BlocBuilder<ExerciseBloc, ExerciseState>(
          builder: (context, state) {
            if (state.allPlans.isEmpty) {
              return const Text('No hay planes registrados.');
            }
            return ListView.builder(
              shrinkWrap: true,
              itemCount: state.allPlans.length,
              itemBuilder: (context, index) {
                final plan = state.allPlans[index];
                final isActive = plan.id == state.activePlan?.id;
                return ListTile(
                  title: Text(plan.name),
                  subtitle: Text(plan.isActive ? 'Activo' : 'Inactivo'),
                  trailing: isActive
                      ? Icon(Icons.check_circle,
                          color: Theme.of(context).colorScheme.primary)
                      : TextButton(
                          onPressed: () {
                            context.read<ExerciseBloc>().add(
                                  ExercisePlanActivated(planId: plan.id),
                                );
                            Navigator.pop(context);
                          },
                          child: const Text('Activar'),
                        ),
                );
              },
            );
          },
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Cerrar'),
        ),
      ],
    );
  }
}
