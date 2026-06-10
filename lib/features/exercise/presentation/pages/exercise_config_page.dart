import 'package:flutter/material.dart';
import 'package:kiolog/core/di/injection.dart';
import 'package:kiolog/core/domain/app_module.dart';
import 'package:kiolog/core/modules/cubit/modules_cubit.dart';
import 'package:kiolog/features/exercise/domain/repositories/exercise_repository.dart';
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

  @override
  void dispose() {
    _planNameController.dispose();
    for (final day in _routineDays) {
      day.nameController.dispose();
      for (final e in day.exercises) {
        e.name.dispose();
        e.sets.dispose();
        e.reps.dispose();
        e.weight.dispose();
      }
    }
    super.dispose();
  }

  Future<void> _save() async {
    setState(() => _saving = true);
    final exerciseRepo = getIt<ExerciseRepository>();
    final exercisePlanId =
        await exerciseRepo.createPlan(_planNameController.text);
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
                            e.name.dispose();
                            e.sets.dispose();
                            e.reps.dispose();
                            e.weight.dispose();
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
                          onDelete: () {
                            setState(() => day.exercises.removeAt(e.key));
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
}

class _ExerciseRowLocal extends StatelessWidget {
  final _ExerciseEntryLocal entry;
  final VoidCallback onDelete;

  const _ExerciseRowLocal({required this.entry, required this.onDelete});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Row(
        children: [
          Expanded(
            flex: 3,
            child: TextField(
              controller: entry.name,
              decoration: const InputDecoration(labelText: 'Ejercicio'),
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: TextField(
              controller: entry.sets,
              decoration: const InputDecoration(labelText: 'Sets'),
              keyboardType: TextInputType.number,
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: TextField(
              controller: entry.reps,
              decoration: const InputDecoration(labelText: 'Reps'),
              keyboardType: TextInputType.number,
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: TextField(
              controller: entry.weight,
              decoration: const InputDecoration(
                labelText: 'Peso',
                suffixText: 'kg',
              ),
              keyboardType: TextInputType.number,
            ),
          ),
          IconButton(
            icon: const Icon(Icons.delete_outline),
            onPressed: onDelete,
          ),
        ],
      ),
    );
  }
}
