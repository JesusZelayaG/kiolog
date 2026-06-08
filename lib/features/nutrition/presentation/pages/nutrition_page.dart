import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:kiolog/core/database/app_database.dart';
import '../../../../core/di/injection.dart';
import '../../domain/repositories/nutrition_repository.dart';
import '../bloc/nutrition_bloc.dart';
import '../bloc/nutrition_event.dart';
import '../bloc/nutrition_state.dart';

class NutritionPage extends StatelessWidget {
  const NutritionPage({super.key});

  @override
  Widget build(BuildContext context) {
    return BlocProvider(
      create: (_) => NutritionBloc(getIt<NutritionRepository>())
        ..add(NutritionLoaded(date: DateTime.now())),
      child: const _NutritionView(),
    );
  }
}

class _NutritionView extends StatelessWidget {
  const _NutritionView();

  String _mealTypeLabel(String type) {
    return switch (type) {
      'breakfast' => 'Desayuno',
      'lunch' => 'Almuerzo',
      'dinner' => 'Cena',
      'snack' => 'Entrecomida',
      _ => type,
    };
  }

  String _mealTypeIcon(String type) {
    return switch (type) {
      'breakfast' => '🍳',
      'lunch' => '🍱',
      'dinner' => '🍽️',
      'snack' => '🍎',
      _ => '🍽️',
    };
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Nutrición'),
        actions: [
          IconButton(
            icon: const Icon(Icons.history),
            onPressed: () => _showPlansDialog(context),
          ),
        ],
      ),
      body: BlocBuilder<NutritionBloc, NutritionState>(
        builder: (context, state) {
          if (state.status == NutritionStatus.loading &&
              state.activePlan == null) {
            return const Center(child: CircularProgressIndicator());
          }
          if (state.status == NutritionStatus.failure) {
            return Center(child: Text('Error: ${state.error}'));
          }

          if (state.activePlan == null) {
            return _buildNoPlanView(context);
          }

          return SafeArea(
            child: ListView(
              padding: const EdgeInsets.all(16),
              children: [
                Text(
                  state.activePlan!.name,
                  style: Theme.of(context).textTheme.titleLarge,
                ),
                const SizedBox(height: 4),
                Text(
                  'Plan activo',
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                        color: Theme.of(context).colorScheme.onSurfaceVariant,
                      ),
                ),
                const SizedBox(height: 16),
                ...['breakfast', 'lunch', 'dinner', 'snack'].map(
                  (type) => _MealSection(
                    mealType: type,
                    label: _mealTypeLabel(type),
                    icon: _mealTypeIcon(type),
                    options: state.planOptions[type] ?? [],
                    log: state.getLogForMeal(type),
                  ),
                ),
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
            const Icon(Icons.restaurant_menu, size: 64, color: Colors.grey),
            const SizedBox(height: 16),
            Text(
              'Sin plan activo',
              style: Theme.of(context).textTheme.headlineSmall,
            ),
            const SizedBox(height: 8),
            const Text(
              'Crea un plan alimenticio para empezar a registrar tus comidas.',
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

  void _showPlansDialog(BuildContext context) {
    context.read<NutritionBloc>().add(const NutritionPlanLoaded());
    showDialog(
      context: context,
      builder: (dialogContext) => BlocProvider.value(
        value: context.read<NutritionBloc>(),
        child: const _PlansDialog(),
      ),
    );
  }

  void _showCreatePlanDialog(BuildContext context) {
    final controller = TextEditingController();
    showDialog(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Nuevo plan alimenticio'),
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
                context.read<NutritionBloc>().add(
                      NutritionPlanCreated(name: controller.text),
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

class _MealSection extends StatelessWidget {
  final String mealType;
  final String label;
  final String icon;
  final List<MealPlanOption> options;
  final DailyMealLog? log;

  const _MealSection({
    required this.mealType,
    required this.label,
    required this.icon,
    required this.options,
    this.log,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isLogged = log != null;

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Text(icon, style: const TextStyle(fontSize: 24)),
                const SizedBox(width: 8),
                Text(label, style: theme.textTheme.titleMedium),
                const Spacer(),
                if (isLogged)
                  Chip(
                    label: const Text('Registrado'),
                    backgroundColor: theme.colorScheme.primaryContainer,
                    side: BorderSide.none,
                  ),
              ],
            ),
            const SizedBox(height: 12),
            if (log?.freeDescription != null)
              Text(
                'Fuera de plan: ${log!.freeDescription}',
                style: theme.textTheme.bodyMedium?.copyWith(
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
              )
            else if (log?.planOptionId != null)
              _buildSelectedOption(context)
            else if (options.isEmpty)
              Text(
                'Sin opciones configuradas',
                style: theme.textTheme.bodyMedium?.copyWith(
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
              )
            else
              ...options.map((opt) => _OptionTile(
                    option: opt,
                    isSelected: log?.planOptionId == opt.id,
                    onTap: () {
                      context.read<NutritionBloc>().add(
                            NutritionMealLogged(
                              date: DateTime.now(),
                              mealType: mealType,
                              planOptionId: opt.id,
                            ),
                          );
                    },
                  )),
            if (!isLogged) ...[
              const Divider(height: 24),
              TextButton.icon(
                onPressed: () => _showOffPlanDialog(context),
                icon: const Icon(Icons.edit_note),
                label: const Text('Registrar fuera de plan'),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildSelectedOption(BuildContext context) {
    final opt = options.firstWhere((o) => o.id == log!.planOptionId);
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.primaryContainer.withOpacity(0.4),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        children: [
          Icon(Icons.check_circle,
              color: Theme.of(context).colorScheme.primary),
          const SizedBox(width: 8),
          Expanded(child: Text('Opción ${opt.optionNumber}: ${opt.description}')),
        ],
      ),
    );
  }

  void _showOffPlanDialog(BuildContext context) {
    final controller = TextEditingController();
    showDialog(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Comida fuera de plan'),
        content: TextField(
          controller: controller,
          decoration: const InputDecoration(
            labelText: '¿Qué comiste?',
            hintText: 'Ej: Pizza con amigos',
          ),
          maxLines: 2,
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
                context.read<NutritionBloc>().add(
                      NutritionOffPlanMealLogged(
                        date: DateTime.now(),
                        mealType: mealType,
                        description: controller.text,
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
}

class _OptionTile extends StatelessWidget {
  final MealPlanOption option;
  final bool isSelected;
  final VoidCallback onTap;

  const _OptionTile({
    required this.option,
    required this.isSelected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return ListTile(
      dense: true,
      contentPadding: EdgeInsets.zero,
      leading: CircleAvatar(
        backgroundColor: isSelected
            ? Theme.of(context).colorScheme.primaryContainer
            : Theme.of(context).colorScheme.surfaceContainerHighest,
        child: Text('${option.optionNumber}'),
      ),
      title: Text(option.description),
      trailing: isSelected
          ? Icon(Icons.check_circle,
              color: Theme.of(context).colorScheme.primary)
          : const Icon(Icons.radio_button_unchecked),
      onTap: onTap,
    );
  }
}

class _PlansDialog extends StatelessWidget {
  const _PlansDialog();

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Planes alimenticios'),
      content: SizedBox(
        width: double.maxFinite,
        child: BlocBuilder<NutritionBloc, NutritionState>(
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
                  subtitle: Text(
                    plan.isActive ? 'Activo' : 'Inactivo',
                  ),
                  trailing: isActive
                      ? Icon(Icons.check_circle,
                          color: Theme.of(context).colorScheme.primary)
                      : TextButton(
                          onPressed: () {
                            context.read<NutritionBloc>().add(
                                  NutritionPlanActivated(planId: plan.id),
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
