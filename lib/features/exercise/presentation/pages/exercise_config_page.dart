import 'package:flutter/material.dart';
import 'package:kiolog/core/database/app_database.dart';
import 'package:kiolog/core/di/injection.dart';
import 'package:kiolog/core/domain/app_module.dart';
import 'package:kiolog/core/modules/cubit/modules_cubit.dart';
import 'package:kiolog/features/exercise/domain/repositories/exercise_repository.dart';
import 'package:kiolog/shared/widgets/exercise_reference.dart';
import 'package:kiolog/shared/widgets/vitality_card.dart';

class ExerciseConfigPage extends StatefulWidget {
  final VoidCallback onComplete;

  const ExerciseConfigPage({super.key, required this.onComplete});

  @override
  State<ExerciseConfigPage> createState() => _ExerciseConfigPageState();
}

class _ExerciseConfigPageState extends State<ExerciseConfigPage> {
  final _planNameController = TextEditingController(text: 'Mi Rutina');
  final List<_RoutineDayLocal> _routineDays = [];
  bool _saving = false;
  bool _applyingTemplate = false;
  List<ExercisePlan> _allPlans = [];
  String _weightUnit = 'kg';

  @override
  void initState() {
    super.initState();
    _loadPlans();
  }

  Future<void> _loadPlans() async {
    final plans = await getIt<ExerciseRepository>().getAllPlans();
    if (mounted) setState(() => _allPlans = plans);
  }

  @override
  void dispose() {
    _planNameController.dispose();
    for (final day in _routineDays) {
      day.nameController.dispose();
      for (final e in day.exercises) {
        e.dispose();
      }
    }
    super.dispose();
  }

  void _showTemplatePicker(BuildContext context) {
    showModalBottomSheet<void>(
      context: context,
      builder: (ctx) => Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const ListTile(
            title: Text('Selecciona un plan base'),
            subtitle: Text(
                'Los días y ejercicios se copian como punto de partida editable.'),
          ),
          const Divider(height: 1),
          ..._allPlans.map((plan) => ListTile(
                leading: const Icon(Icons.fitness_center),
                title: Text(plan.name),
                subtitle: Text(plan.isActive ? 'Plan activo' : 'Finalizado'),
                trailing: const Icon(Icons.chevron_right),
                onTap: () {
                  Navigator.pop(ctx);
                  _applyTemplate(plan.id);
                },
              )),
          const SizedBox(height: 16),
        ],
      ),
    );
  }

  Future<void> _applyTemplate(int planId) async {
    if (_applyingTemplate) return;
    setState(() => _applyingTemplate = true);
    try {
      final repo = getIt<ExerciseRepository>();
      final routines = await repo.getRoutinesForPlan(planId);

      final newDays = <_RoutineDayLocal>[];
      for (final routine in routines) {
        final items = await repo.getRoutineItemsOrdered(routine.id);
        final day = _RoutineDayLocal();
        day.nameController.text = routine.routineName;
        for (final item in items) {
          final entry = _ExerciseEntryLocal();
          entry.name.text = item.exerciseName;
          entry.sets.text = '${item.sets}';
          entry.reps.text = '${item.reps}';
          if (item.weightKg != null) entry.weight.text = '${item.weightKg}';
          entry.reference.link.text = item.referenceUrl ?? '';
          entry.reference.mediaId = item.mediaId;
          day.exercises.add(entry);
        }
        newDays.add(day);
      }

      // Dispose old day controllers before replacing
      for (final day in _routineDays) {
        day.nameController.dispose();
        for (final e in day.exercises) {
          e.dispose();
        }
      }

      if (mounted) {
        setState(() {
          _routineDays
            ..clear()
            ..addAll(newDays);
          _planNameController.clear();
        });
      }
    } finally {
      if (mounted) setState(() => _applyingTemplate = false);
    }
  }

  Future<void> _save() async {
    setState(() => _saving = true);
    final exerciseRepo = getIt<ExerciseRepository>();
    final exercisePlanId = await exerciseRepo.createPlan(
      _planNameController.text,
      weightUnit: _weightUnit,
    );
    for (int i = 0; i < _routineDays.length; i++) {
      final day = _routineDays[i];
      final routineName = day.nameController.text.trim().isEmpty
          ? 'Día ${i + 1}'
          : day.nameController.text.trim();
      final routineId = await exerciseRepo.addRoutine(
        planId: exercisePlanId,
        dayNumber: i + 1,
        routineName: routineName,
      );
      for (final ex in day.exercises) {
        final sets = int.tryParse(ex.sets.text) ?? 3;
        final reps = int.tryParse(ex.reps.text) ?? 10;
        final weight = double.tryParse(ex.weight.text);
        if (ex.name.text.isNotEmpty) {
          await exerciseRepo.addRoutineItem(
            routineId: routineId,
            exerciseName: ex.name.text,
            sets: sets,
            reps: reps,
            weightKg: weight,
            referenceUrl: ex.reference.url,
            mediaId: await ex.reference.saveMedia(),
          );
        }
      }
    }
    await getIt<ModulesCubit>().setModuleEnabled(AppModule.exercise, true);
    if (mounted) {
      Navigator.of(context).pop();
      widget.onComplete();
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(title: const Text('Plan de Ejercicio')),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Crea los días de tu rutina (Día 1, Día 2, ...). No dependen del día de la semana: al ir al gimnasio eliges qué día entrenaste.',
              style: theme.textTheme.bodyLarge,
            ),
            const SizedBox(height: 16),
            TextField(
              controller: _planNameController,
              decoration: const InputDecoration(labelText: 'Nombre del plan'),
            ),
            const SizedBox(height: 16),
            SegmentedButton<String>(
              segments: const [
                ButtonSegment(value: 'kg', label: Text('kg')),
                ButtonSegment(value: 'lbs', label: Text('lbs')),
              ],
              selected: {_weightUnit},
              onSelectionChanged: (set) =>
                  setState(() => _weightUnit = set.first),
            ),
            if (_allPlans.isNotEmpty) ...[
              const SizedBox(height: 12),
              OutlinedButton.icon(
                onPressed: () => _showTemplatePicker(context),
                icon: const Icon(Icons.copy_outlined),
                label: const Text('Partir de plan anterior'),
                style: OutlinedButton.styleFrom(
                  minimumSize: const Size.fromHeight(44),
                ),
              ),
            ],
            const SizedBox(height: 24),
            ..._routineDays.asMap().entries.map((dayEntry) {
              final index = dayEntry.key;
              final day = dayEntry.value;
              return Padding(
                padding: const EdgeInsets.only(bottom: 12),
                child: VitalityCard(
                  padding: EdgeInsets.zero,
                  child: ExpansionTile(
                    initiallyExpanded: true,
                    title: Text('Día ${index + 1}'),
                    subtitle: day.exercises.isEmpty
                        ? const Text('Sin ejercicios')
                        : Text('${day.exercises.length} ejercicio(s)'),
                    trailing: IconButton(
                      icon: const Icon(Icons.delete_outline),
                      onPressed: () {
                        setState(() {
                          final removed = _routineDays.removeAt(index);
                          removed.nameController.dispose();
                          for (final e in removed.exercises) {
                            e.dispose();
                          }
                        });
                      },
                    ),
                    children: [
                      Padding(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 16, vertical: 8),
                        child: TextField(
                          controller: day.nameController,
                          decoration: const InputDecoration(
                            labelText: 'Nombre de la rutina',
                            hintText: 'Ej: Pecho y tríceps',
                          ),
                        ),
                      ),
                      ...day.exercises.asMap().entries.map((e) {
                        return _ExerciseRowLocal(
                          entry: e.value,
                          weightUnit: _weightUnit,
                          onDelete: () {
                            setState(() {
                              final removed = day.exercises.removeAt(e.key);
                              removed.dispose();
                            });
                          },
                        );
                      }),
                      ListTile(
                        leading: const Icon(Icons.add),
                        title: const Text('Agregar ejercicio'),
                        onTap: () {
                          setState(
                              () => day.exercises.add(_ExerciseEntryLocal()));
                        },
                      ),
                    ],
                  ),
                ),
              );
            }),
            OutlinedButton.icon(
              onPressed: () {
                setState(() => _routineDays.add(_RoutineDayLocal()));
              },
              icon: const Icon(Icons.add),
              label: const Text('Agregar día de rutina'),
            ),
            const SizedBox(height: 32),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: _saving ? null : _save,
                child: const Text('Guardar'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _RoutineDayLocal {
  final nameController = TextEditingController();
  final List<_ExerciseEntryLocal> exercises = [];
}

class _ExerciseEntryLocal {
  final name = TextEditingController();
  final sets = TextEditingController(text: '3');
  final reps = TextEditingController(text: '10');
  final weight = TextEditingController();

  /// Enlace y multimedia de referencia.
  final reference = ReferenceDraft();

  void dispose() {
    name.dispose();
    sets.dispose();
    reps.dispose();
    weight.dispose();
    reference.dispose();
  }
}

class _ExerciseRowLocal extends StatelessWidget {
  final _ExerciseEntryLocal entry;
  final String weightUnit;
  final VoidCallback onDelete;

  const _ExerciseRowLocal({
    required this.entry,
    required this.weightUnit,
    required this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 8, 8, 8),
      child: Column(
        children: [
          Row(
            children: [
              Expanded(
                child: TextField(
                  controller: entry.name,
                  decoration: const InputDecoration(
                    labelText: 'Ejercicio',
                    isDense: true,
                  ),
                ),
              ),
              IconButton(
                icon: const Icon(Icons.delete_outline),
                onPressed: onDelete,
              ),
            ],
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              Expanded(
                child: TextField(
                  controller: entry.sets,
                  decoration: const InputDecoration(
                    labelText: 'Series',
                    isDense: true,
                  ),
                  keyboardType: TextInputType.number,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: TextField(
                  controller: entry.reps,
                  decoration: const InputDecoration(
                    labelText: 'Reps',
                    isDense: true,
                  ),
                  keyboardType: TextInputType.number,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: TextField(
                  controller: entry.weight,
                  decoration: InputDecoration(
                    labelText: 'Peso',
                    suffixText: weightUnit,
                    isDense: true,
                  ),
                  keyboardType: const TextInputType.numberWithOptions(
                    decimal: true,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          ReferenceEditor(draft: entry.reference, dense: true),
          const Divider(height: 24),
        ],
      ),
    );
  }
}
