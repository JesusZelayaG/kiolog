import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:kiolog/core/database/app_database.dart';
import '../../../../core/di/injection.dart';
import '../../domain/repositories/exercise_repository.dart';
import '../bloc/exercise_bloc.dart';
import '../bloc/exercise_event.dart';
import '../bloc/exercise_state.dart';

class ExercisePage extends StatelessWidget {
  const ExercisePage({super.key});

  @override
  Widget build(BuildContext context) {
    return BlocProvider(
      create: (_) => ExerciseBloc(getIt<ExerciseRepository>())
        ..add(ExerciseLoaded(date: DateTime.now())),
      child: const _ExerciseView(),
    );
  }
}

class _ExerciseView extends StatelessWidget {
  const _ExerciseView();

  String _dayName(int weekday) {
    return switch (weekday) {
      1 => 'Lunes',
      2 => 'Martes',
      3 => 'Miércoles',
      4 => 'Jueves',
      5 => 'Viernes',
      6 => 'Sábado',
      7 => 'Domingo',
      _ => '',
    };
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Ejercicio'),
        actions: [
          IconButton(
            icon: const Icon(Icons.history),
            onPressed: () => _showPlansDialog(context),
          ),
        ],
      ),
      body: BlocBuilder<ExerciseBloc, ExerciseState>(
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
                _buildPlanHeader(context, state),
                const SizedBox(height: 16),
                if (state.todayRoutine != null) ...[
                  _buildRoutineCard(context, state),
                  const SizedBox(height: 16),
                ] else
                  _buildRestDayCard(context),
                _buildSessionCard(context, state),
                const SizedBox(height: 16),
                if (state.recentSessions.isNotEmpty)
                  _buildRecentSessions(context, state),
              ],
            ),
          );
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
            const Icon(Icons.fitness_center, size: 64, color: Colors.grey),
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
            FilledButton.icon(
              onPressed: () => _showCreatePlanDialog(context),
              icon: const Icon(Icons.add),
              label: const Text('Crear plan'),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildPlanHeader(BuildContext context, ExerciseState state) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          state.activePlan!.name,
          style: Theme.of(context).textTheme.titleLarge,
        ),
        Text(
          '${_dayName(DateTime.now().weekday)} — ${state.todayRoutine?.routineName ?? 'Día de descanso'}',
          style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                color: Theme.of(context).colorScheme.onSurfaceVariant,
              ),
        ),
      ],
    );
  }

  Widget _buildRoutineCard(BuildContext context, ExerciseState state) {
    final theme = Theme.of(context);
    final isDone = state.dailyLog?.completed ?? false;

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Text('Rutina de hoy', style: theme.textTheme.titleMedium),
                const Spacer(),
                if (isDone)
                  Chip(
                    label: const Text('Completada'),
                    backgroundColor: theme.colorScheme.primaryContainer,
                    side: BorderSide.none,
                  ),
              ],
            ),
            const SizedBox(height: 12),
            ...state.routineItems.map((item) => ListTile(
                  dense: true,
                  contentPadding: EdgeInsets.zero,
                  leading: CircleAvatar(
                    backgroundColor: theme.colorScheme.surfaceContainerHighest,
                    child: Text('${item.sets}x'),
                  ),
                  title: Text(item.exerciseName),
                  subtitle: Text(
                    '${item.reps} reps${item.weightKg != null ? ' @ ${item.weightKg} kg' : ''}',
                  ),
                )),
            if (!isDone) ...[
              const SizedBox(height: 12),
              FilledButton.icon(
                onPressed: () {
                  context.read<ExerciseBloc>().add(
                        ExerciseRoutineMarkedDone(
                          date: DateTime.now(),
                          routineId: state.todayRoutine!.id,
                        ),
                      );
                },
                icon: const Icon(Icons.check),
                label: const Text('Marcar como completada'),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildRestDayCard(BuildContext context) {
    return Card(
      color: Theme.of(context).colorScheme.secondaryContainer.withOpacity(0.4),
      child: const Padding(
        padding: EdgeInsets.all(24),
        child: Row(
          children: [
            Icon(Icons.beach_access),
            SizedBox(width: 16),
            Text('Hoy es día de descanso'),
          ],
        ),
      ),
    );
  }

  Widget _buildSessionCard(BuildContext context, ExerciseState state) {
    if (state.hasActiveSession) {
      return _buildActiveSessionCard(context, state);
    }

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Sesión de gym', style: Theme.of(context).textTheme.titleMedium),
            const SizedBox(height: 12),
            FilledButton.icon(
              onPressed: () {
                context.read<ExerciseBloc>().add(
                      ExerciseSessionStarted(date: DateTime.now()),
                    );
              },
              icon: const Icon(Icons.play_arrow),
              label: const Text('Iniciar sesión'),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildActiveSessionCard(BuildContext context, ExerciseState state) {
    final theme = Theme.of(context);
    final session = state.activeSession!;
    final startTime = TimeOfDay.fromDateTime(session.gymArrivedAt);

    return Card(
      color: theme.colorScheme.primaryContainer.withOpacity(0.3),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Text('Sesión activa', style: theme.textTheme.titleMedium),
                const Spacer(),
                Text('${startTime.hour}:${startTime.minute.toString().padLeft(2, '0')}'),
              ],
            ),
            const SizedBox(height: 12),
            if (state.sessionSets.isNotEmpty)
              Text('${state.sessionSets.length} serie(s) registradas'),
            const SizedBox(height: 12),
            FilledButton.icon(
              onPressed: () => _showLogSetDialog(context, state),
              icon: const Icon(Icons.add),
              label: const Text('Registrar serie'),
            ),
            const SizedBox(height: 8),
            OutlinedButton.icon(
              onPressed: () {
                context.read<ExerciseBloc>().add(
                      ExerciseSessionEnded(sessionId: session.id),
                    );
              },
              icon: const Icon(Icons.stop),
              label: const Text('Finalizar sesión'),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildRecentSessions(BuildContext context, ExerciseState state) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Sesiones recientes', style: Theme.of(context).textTheme.titleMedium),
            const SizedBox(height: 8),
            ...state.recentSessions.take(3).map((session) {
              final start = TimeOfDay.fromDateTime(session.gymArrivedAt);
              final end = session.gymLeftAt != null
                  ? TimeOfDay.fromDateTime(session.gymLeftAt!)
                  : null;
              final duration = end != null
                  ? session.gymLeftAt!.difference(session.gymArrivedAt).inMinutes
                  : null;

              return ListTile(
                dense: true,
                contentPadding: EdgeInsets.zero,
                leading: const Icon(Icons.fitness_center),
                title: Text('${start.hour}:${start.minute.toString().padLeft(2, '0')}'),
                subtitle: end != null
                    ? Text('Duración: ${duration! ~/ 60}h ${duration % 60}m')
                    : const Text('En progreso'),
              );
            }),
          ],
        ),
      ),
    );
  }

  void _showLogSetDialog(BuildContext context, ExerciseState state) {
    final exerciseNameController = TextEditingController();
    final repsController = TextEditingController();
    final weightController = TextEditingController();
    int setNumber = state.sessionSets.length + 1;

    // Pre-fill with last exercise if available
    if (state.sessionSets.isNotEmpty) {
      exerciseNameController.text = state.sessionSets.last.exerciseName;
    } else if (state.routineItems.isNotEmpty) {
      exerciseNameController.text = state.routineItems.first.exerciseName;
    }

    showDialog(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text('Serie $setNumber'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: exerciseNameController,
              decoration: const InputDecoration(labelText: 'Ejercicio'),
              autofocus: true,
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: repsController,
                    decoration: const InputDecoration(labelText: 'Reps'),
                    keyboardType: TextInputType.number,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: TextField(
                    controller: weightController,
                    decoration: const InputDecoration(
                      labelText: 'Peso',
                      suffixText: 'kg',
                    ),
                    keyboardType: TextInputType.number,
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
          FilledButton(
            onPressed: () {
              final reps = int.tryParse(repsController.text);
              final weight = double.tryParse(weightController.text);
              if (exerciseNameController.text.isNotEmpty &&
                  reps != null &&
                  weight != null) {
                context.read<ExerciseBloc>().add(
                      ExerciseSetLogged(
                        sessionId: state.activeSession!.id,
                        exerciseName: exerciseNameController.text,
                        setNumber: setNumber,
                        reps: reps,
                        weightKg: weight,
                      ),
                    );
              }
              Navigator.pop(dialogContext);
            },
            child: const Text('Guardar'),
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
          FilledButton(
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
