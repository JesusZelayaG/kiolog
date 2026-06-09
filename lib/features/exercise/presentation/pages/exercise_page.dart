import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../../../../core/di/injection.dart';
import '../../domain/repositories/exercise_repository.dart';
import '../bloc/exercise_bloc.dart';
import '../bloc/exercise_event.dart';
import '../bloc/exercise_state.dart';
import 'exercise_session_page.dart';

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
                if (state.hasActiveSession)
                  _buildResumeSessionBanner(context, state)
                else
                  _buildRoutinePicker(context, state),
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
          '${state.routines.length} día(s) de rutina',
          style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                color: Theme.of(context).colorScheme.onSurfaceVariant,
              ),
        ),
      ],
    );
  }

  Widget _buildRoutinePicker(BuildContext context, ExerciseState state) {
    final theme = Theme.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Text('¿Qué entrenaste hoy?', style: theme.textTheme.titleMedium),
            const Spacer(),
            TextButton.icon(
              onPressed: () => _showAddRoutineDialog(context, state),
              icon: const Icon(Icons.add, size: 18),
              label: const Text('Día'),
            ),
          ],
        ),
        const SizedBox(height: 8),
        if (state.routines.isEmpty)
          Card(
            child: Padding(
              padding: const EdgeInsets.all(20),
              child: Column(
                children: [
                  const Text(
                    'Aún no tienes días de rutina configurados.',
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 12),
                  FilledButton.icon(
                    onPressed: () => _showAddRoutineDialog(context, state),
                    icon: const Icon(Icons.add),
                    label: const Text('Agregar día de rutina'),
                  ),
                ],
              ),
            ),
          )
        else
          ...state.routines.map((routine) {
            final items = state.routineItemsByRoutine[routine.id] ?? const [];
            return Card(
              margin: const EdgeInsets.only(bottom: 12),
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        CircleAvatar(
                          backgroundColor: theme.colorScheme.primaryContainer,
                          child: Text('${routine.dayNumber}'),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Text(
                            routine.routineName,
                            style: theme.textTheme.titleMedium,
                          ),
                        ),
                      ],
                    ),
                    if (items.isNotEmpty) ...[
                      const SizedBox(height: 8),
                      ...items.map((item) => Padding(
                            padding: const EdgeInsets.symmetric(vertical: 2),
                            child: Text(
                              '• ${item.exerciseName} — ${item.sets}x${item.reps}'
                              '${item.weightKg != null ? ' @ ${item.weightKg}kg' : ''}',
                              style: theme.textTheme.bodyMedium,
                            ),
                          )),
                    ],
                    const SizedBox(height: 12),
                    FilledButton.icon(
                      onPressed: () {
                        context.read<ExerciseBloc>().add(
                              ExerciseSessionStarted(
                                date: DateTime.now(),
                                routineId: routine.id,
                              ),
                            );
                      },
                      icon: const Icon(Icons.play_arrow),
                      label: const Text('Entrené este día'),
                    ),
                  ],
                ),
              ),
            );
          }),
      ],
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

  Widget _buildRecentSessions(BuildContext context, ExerciseState state) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Sesiones recientes',
                style: Theme.of(context).textTheme.titleMedium),
            const SizedBox(height: 8),
            ...state.recentSessions.take(3).map((session) {
              final start = TimeOfDay.fromDateTime(session.gymArrivedAt);
              final end = session.gymLeftAt != null
                  ? TimeOfDay.fromDateTime(session.gymLeftAt!)
                  : null;
              final duration = end != null
                  ? session.gymLeftAt!.difference(session.gymArrivedAt).inMinutes
                  : null;
              final routine = state.routineById(session.routineId);

              return ListTile(
                dense: true,
                contentPadding: EdgeInsets.zero,
                leading: const Icon(Icons.fitness_center),
                title: Text(routine?.routineName ??
                    '${start.hour}:${start.minute.toString().padLeft(2, '0')}'),
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
          FilledButton(
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
