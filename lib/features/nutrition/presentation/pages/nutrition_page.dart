import 'package:collection/collection.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:intl/intl.dart';
import 'package:kiolog/core/database/app_database.dart';
import 'package:kiolog/core/domain/app_module.dart';
import 'package:kiolog/core/modules/cubit/modules_cubit.dart';
import 'package:kiolog/core/modules/cubit/modules_state.dart';
import 'package:kiolog/shared/widgets/inactive_module_page.dart';
import 'package:kiolog/shared/widgets/gradient_icon_button.dart';
import 'package:kiolog/shared/widgets/vitality_card.dart';
import '../../../../core/di/injection.dart';
import '../../domain/repositories/nutrition_repository.dart';
import '../bloc/nutrition_bloc.dart';
import '../bloc/nutrition_event.dart';
import '../bloc/nutrition_state.dart';
import 'package:kiolog/shared/widgets/kiolog_app_bar.dart';
import 'nutrition_config_page.dart';
import 'nutrition_progress_page.dart';

class NutritionPage extends StatelessWidget {
  const NutritionPage({super.key});

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<ModulesCubit, ModulesState>(
      builder: (context, modulesState) {
        if (!modulesState.isEnabled(AppModule.nutrition)) {
          return const InactiveModulePage(module: AppModule.nutrition);
        }
        return BlocProvider(
          create: (_) => NutritionBloc(getIt<NutritionRepository>())
            ..add(NutritionLoaded(date: DateTime.now())),
          child: const _NutritionView(),
        );
      },
    );
  }
}

class _NutritionView extends StatelessWidget {
  const _NutritionView();

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: KiologAppBar(
        title: 'Nutrición',
        actions: [
          GradientIconButton(
            icon: Icons.bar_chart,
            onPressed: () {
              final bloc = context.read<NutritionBloc>();
              Navigator.of(context).push(
                MaterialPageRoute<void>(
                  builder: (_) => BlocProvider.value(
                    value: bloc,
                    child: const NutritionProgressPage(),
                  ),
                ),
              );
            },
          ),
          GradientIconButton(
            icon: Icons.history,
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

          return Column(
            children: [
              Expanded(
                child: ListView(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
                  children: [
                    Text(
                      state.activePlan!.name,
                      style: Theme.of(context).textTheme.titleLarge?.copyWith(
                            color: Theme.of(context).colorScheme.onSurface,
                          ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'Plan activo',
                      style:
                          Theme.of(context).textTheme.bodyMedium?.copyWith(
                                color: Theme.of(context)
                                    .colorScheme
                                    .onSurfaceVariant,
                              ),
                    ),
                    const SizedBox(height: 16),
                    if (state.planOptions.isEmpty)
                      _EmptyPlanCard(plan: state.activePlan!),
                    ...state.planOptions.keys.map(
                      (type) => _MealSection(
                        mealType: type,
                        label: type,
                        options: state.planOptions[type] ?? [],
                        log: state.getLogForMeal(type),
                      ),
                    ),
                    const SizedBox(height: 8),
                    OutlinedButton.icon(
                      onPressed: () => _openPlanForm(context),
                      icon: const Icon(Icons.add),
                      label: const Text('Nuevo plan'),
                    ),
                  ],
                ),
              ),
            ],
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
            Icon(Icons.restaurant_menu,
                size: 64,
                color: Theme.of(context).colorScheme.onSurfaceVariant),
            const SizedBox(height: 16),
            Text(
              'Sin plan activo',
              style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                    color: Theme.of(context).colorScheme.onSurface,
                  ),
            ),
            const SizedBox(height: 8),
            Text(
              'Crea un plan alimenticio para empezar a registrar tus comidas.',
              textAlign: TextAlign.center,
              style: TextStyle(
                  color: Theme.of(context).colorScheme.onSurfaceVariant),
            ),
            const SizedBox(height: 24),
            ElevatedButton.icon(
              onPressed: () => _openPlanForm(context),
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
    showDialog<void>(
      context: context,
      builder: (dialogContext) => BlocProvider.value(
        value: context.read<NutritionBloc>(),
        child: const _PlansDialog(),
      ),
    );
  }
}

// ── Formulario y acciones de plan ────────────────────────────────────────────

enum _PlanAction { activate, edit, delete }

void _pushPlanForm(BuildContext context, NutritionBloc bloc, {MealPlan? plan}) {
  Navigator.of(context).push(
    MaterialPageRoute<void>(
      builder: (_) => NutritionConfigPage(
        plan: plan,
        onComplete: () => bloc.add(NutritionLoaded(date: DateTime.now())),
      ),
    ),
  );
}

void _openPlanForm(BuildContext context, {MealPlan? plan}) =>
    _pushPlanForm(context, context.read<NutritionBloc>(), plan: plan);

Future<void> _onPlanAction(
  BuildContext context,
  _PlanAction action,
  MealPlan plan,
) async {
  final bloc = context.read<NutritionBloc>();
  final navigator = Navigator.of(context);
  switch (action) {
    case _PlanAction.activate:
      bloc.add(NutritionPlanActivated(planId: plan.id));
      navigator.pop();
    case _PlanAction.edit:
      navigator.pop();
      _pushPlanForm(context, bloc, plan: plan);
    case _PlanAction.delete:
      final confirmed = await showDialog<bool>(
        context: context,
        builder: (dialogContext) => AlertDialog(
          title: const Text('Borrar plan'),
          content: Text(
            'Se borrará "${plan.name}" con las comidas registradas en él. '
            'No se puede deshacer.',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext, false),
              child: const Text('Cancelar'),
            ),
            ElevatedButton(
              onPressed: () => Navigator.pop(dialogContext, true),
              child: const Text('Borrar'),
            ),
          ],
        ),
      );
      if (confirmed == true) {
        bloc.add(NutritionPlanDeleted(planId: plan.id));
        navigator.pop();
      }
  }
}

class _EmptyPlanCard extends StatelessWidget {
  const _EmptyPlanCard({required this.plan});

  final MealPlan plan;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return VitalityCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text('Este plan no tiene comidas', style: theme.textTheme.titleMedium),
          const SizedBox(height: 4),
          Text(
            'Agrégalas para registrar lo que comes cada día.',
            style: theme.textTheme.bodySmall,
          ),
          const SizedBox(height: 12),
          ElevatedButton.icon(
            onPressed: () => _openPlanForm(context, plan: plan),
            icon: const Icon(Icons.restaurant_menu),
            label: const Text('Agregar comidas'),
          ),
        ],
      ),
    );
  }
}

// ── Diálogo de planes ────────────────────────────────────────────────────────

class _PlansDialog extends StatelessWidget {
  const _PlansDialog();

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return AlertDialog(
      backgroundColor: cs.surface,
      titleTextStyle: Theme.of(context)
          .textTheme
          .titleLarge
          ?.copyWith(color: cs.onSurface),
      title: const Text('Planes alimenticios'),
      content: SizedBox(
        width: double.maxFinite,
        child: BlocBuilder<NutritionBloc, NutritionState>(
          builder: (context, state) {
            return Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                if (state.allPlans.isEmpty)
                  Text('No hay planes registrados.',
                      style: TextStyle(color: cs.onSurface))
                else
                  Flexible(
                    child: ListView.builder(
                      shrinkWrap: true,
                      itemCount: state.allPlans.length,
                      itemBuilder: (context, index) {
                        final plan = state.allPlans[index];
                        final isActive = plan.id == state.activePlan?.id;
                        return ListTile(
                          title: Text(plan.name,
                              style: TextStyle(color: cs.onSurface)),
                          subtitle: Text(
                              '${plan.isActive ? 'Plan actual' : 'Plan anterior'}'
                              ' · ${DateFormat('dd/MM/yy').format((plan.periodStart ?? plan.createdAt).toUtc())}',
                              style:
                                  TextStyle(color: cs.onSurfaceVariant)),
                          trailing: PopupMenuButton<_PlanAction>(
                            onSelected: (action) =>
                                _onPlanAction(context, action, plan),
                            itemBuilder: (_) => [
                              if (!isActive)
                                const PopupMenuItem(
                                  value: _PlanAction.activate,
                                  child: Text('Activar'),
                                ),
                              const PopupMenuItem(
                                value: _PlanAction.edit,
                                child: Text('Editar'),
                              ),
                              const PopupMenuItem(
                                value: _PlanAction.delete,
                                child: Text('Borrar'),
                              ),
                            ],
                          ),
                        );
                      },
                    ),
                  ),
                const SizedBox(height: 8),
                TextButton.icon(
                  onPressed: () {
                    final bloc = context.read<NutritionBloc>();
                    Navigator.pop(context);
                    _pushPlanForm(context, bloc);
                  },
                  icon: const Icon(Icons.add),
                  label: const Text('Nuevo plan'),
                ),
              ],
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

// ── Sección de comida ────────────────────────────────────────────────────────

class _MealSection extends StatelessWidget {
  final String mealType;
  final String label;
  final List<MealPlanOption> options;
  final DailyMealLog? log;

  const _MealSection({
    required this.mealType,
    required this.label,
    required this.options,
    this.log,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isLogged = log != null;

    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: VitalityCard(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Icon(Icons.restaurant_menu),
                const SizedBox(width: 8),
                Text(label,
                    style: theme.textTheme.titleMedium
                        ?.copyWith(color: theme.colorScheme.onSurface)),
                const Spacer(),
                if (isLogged)
                  Builder(builder: (_) {
                    final l = log!;
                    final String chipLabel;
                    final Color chipColor;
                    if (l.planOptionId != null) {
                      chipLabel = 'Registrado';
                      chipColor = theme.colorScheme.primaryContainer;
                    } else if (l.freeDescription != null) {
                      chipLabel = 'Fuera de plan';
                      chipColor =
                          theme.colorScheme.surfaceContainerHighest;
                    } else {
                      chipLabel = 'No seguido';
                      chipColor = theme.colorScheme.errorContainer;
                    }
                    return Chip(
                      label: Text(chipLabel),
                      backgroundColor: chipColor,
                      side: BorderSide.none,
                    );
                  }),
              ],
            ),
            const SizedBox(height: 12),
            if (log?.planOptionId != null)
              _buildSelectedOption(context)
            else if (log?.freeDescription != null)
              _buildOffPlanText(context, log!.freeDescription!)
            else if (log != null)
              _buildNotFollowed(context)
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
                    isSelected: false,
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
            const Divider(height: 24),
            if (!isLogged) ...[
              Row(
                children: [
                  Expanded(
                    child: TextButton.icon(
                      onPressed: () {
                        context.read<NutritionBloc>().add(
                              NutritionOffPlanMealLogged(
                                date: DateTime.now(),
                                mealType: mealType,
                                description: null,
                              ),
                            );
                      },
                      icon: const Icon(Icons.close),
                      label: const Text('No seguí el plan'),
                    ),
                  ),
                  Expanded(
                    child: TextButton.icon(
                      onPressed: () => _showOffPlanDialog(context),
                      icon: const Icon(Icons.edit_note),
                      label: const Text('Fuera de plan'),
                    ),
                  ),
                ],
              ),
            ] else ...[
              TextButton.icon(
                onPressed: () {
                  context.read<NutritionBloc>().add(
                        NutritionMealLogRemoved(
                          date: DateTime.now(),
                          mealType: mealType,
                        ),
                      );
                },
                icon: const Icon(Icons.undo),
                label: const Text('Cambiar selección'),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildSelectedOption(BuildContext context) {
    final opt = options.firstWhereOrNull((o) => o.id == log!.planOptionId);
    if (opt == null) return const SizedBox.shrink();
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Theme.of(context)
            .colorScheme
            .primaryContainer
            .withValues(alpha: 0.4),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        children: [
          Icon(Icons.check_circle,
              color: Theme.of(context).colorScheme.primary),
          const SizedBox(width: 8),
          Expanded(
              child: Text(
                'Opción ${opt.optionNumber}: ${opt.description}',
                style: TextStyle(
                    color: Theme.of(context).colorScheme.onSurface),
              )),
        ],
      ),
    );
  }

  Widget _buildOffPlanText(BuildContext context, String text) {
    final cs = Theme.of(context).colorScheme;
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: cs.errorContainer.withValues(alpha: 0.3),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        children: [
          Icon(Icons.edit_note, color: cs.error),
          const SizedBox(width: 8),
          Expanded(
            child: Text(text,
                style: TextStyle(color: cs.onErrorContainer)),
          ),
        ],
      ),
    );
  }

  Widget _buildNotFollowed(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Theme.of(context)
            .colorScheme
            .errorContainer
            .withValues(alpha: 0.3),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        children: [
          Icon(Icons.close,
              color: Theme.of(context).colorScheme.error),
          const SizedBox(width: 8),
          Text(
            'No seguí el plan',
            style: TextStyle(
                color: Theme.of(context).colorScheme.error),
          ),
        ],
      ),
    );
  }

  void _showOffPlanDialog(BuildContext context) {
    final controller = TextEditingController();
    showDialog<void>(
      context: context,
      builder: (dialogContext) {
        final cs = Theme.of(dialogContext).colorScheme;
        return AlertDialog(
          backgroundColor: cs.surface,
          titleTextStyle: Theme.of(dialogContext)
              .textTheme
              .titleLarge
              ?.copyWith(color: cs.onSurface),
          title: const Text('Comida fuera de plan'),
          content: TextField(
            controller: controller,
            style: TextStyle(color: cs.onSurface),
            decoration: InputDecoration(
              labelText: '¿Qué comiste?',
              hintText: 'Ej: Pizza con amigos',
              labelStyle: TextStyle(color: cs.onSurfaceVariant),
              hintStyle: TextStyle(color: cs.onSurfaceVariant),
            ),
          maxLines: 2,
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
        );
      },
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
        child: Text('${option.optionNumber}',
            style: TextStyle(color: Theme.of(context).colorScheme.onSurface)),
      ),
      title: Text(option.description,
          style: TextStyle(color: Theme.of(context).colorScheme.onSurface)),
      trailing: isSelected
          ? Icon(Icons.check_circle,
              color: Theme.of(context).colorScheme.primary)
          : const Icon(Icons.radio_button_unchecked),
      onTap: onTap,
    );
  }
}
