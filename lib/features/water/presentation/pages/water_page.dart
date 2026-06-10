import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:kiolog/core/domain/app_module.dart';
import 'package:kiolog/core/modules/cubit/modules_cubit.dart';
import 'package:kiolog/core/modules/cubit/modules_state.dart';
import 'package:kiolog/shared/widgets/inactive_module_page.dart';
import '../../../../core/di/injection.dart';
import '../../domain/repositories/water_repository.dart';
import '../bloc/water_bloc.dart';
import '../bloc/water_event.dart';
import '../bloc/water_state.dart';

class WaterPage extends StatelessWidget {
  const WaterPage({super.key});

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<ModulesCubit, ModulesState>(
      builder: (context, modulesState) {
        if (!modulesState.isEnabled(AppModule.water)) {
          return const InactiveModulePage(module: AppModule.water);
        }
        return BlocProvider(
          create: (_) => WaterBloc(getIt<WaterRepository>())
            ..add(WaterLoaded(date: DateTime.now()))
            ..add(const WaterConfigLoaded()),
          child: const _WaterView(),
        );
      },
    );
  }
}

class _WaterView extends StatelessWidget {
  const _WaterView();

  String _unitLabel(String unitType) =>
      unitType == 'bottle' ? 'botella' : 'vaso';

  String _unitLabelPlural(String unitType) =>
      unitType == 'bottle' ? 'botellas' : 'vasos';

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Agua'),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => context.go('/'),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.settings_outlined),
            onPressed: () => _showConfigDialog(context),
          ),
        ],
      ),
      body: BlocBuilder<WaterBloc, WaterState>(
        builder: (context, state) {
          if (state.status == WaterStatus.loading) {
            return const Center(child: CircularProgressIndicator());
          }
          if (state.status == WaterStatus.failure) {
            return Center(child: Text('Error: ${state.error}'));
          }

          final progress = state.progress.clamp(0.0, 1.0);
          final liters = (state.dailyTotalMl / 1000).toStringAsFixed(1);
          final goalLiters = (state.dailyGoalMl / 1000).toStringAsFixed(1);

          return SafeArea(
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: Column(
                children: [
                  const SizedBox(height: 16),
                  Text(
                    '$liters / $goalLiters L',
                    style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                          fontWeight: FontWeight.bold,
                        ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    '${state.dailyTotalMl} / ${state.dailyGoalMl} ml',
                    style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                          color: Theme.of(context).colorScheme.onSurfaceVariant,
                        ),
                  ),
                  const SizedBox(height: 32),
                  SizedBox(
                    height: 180,
                    width: 180,
                    child: Stack(
                      fit: StackFit.expand,
                      children: [
                        CircularProgressIndicator(
                          value: progress,
                          strokeWidth: 16,
                          backgroundColor: Theme.of(context)
                              .colorScheme
                              .primaryContainer
                              .withValues(alpha: 0.4),
                        ),
                        Center(
                          child: Icon(
                            Icons.water_drop,
                            size: 64,
                            color: Theme.of(context).colorScheme.primary,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 32),
                  ElevatedButton.icon(
                    onPressed: () {
                      context.read<WaterBloc>().add(
                            WaterAdded(
                              date: DateTime.now(),
                              amountMl: state.containerMl,
                            ),
                          );
                    },
                    icon: const Icon(Icons.add),
                    label: Text(
                      'Agregar ${_unitLabel(state.unitType)} (${state.containerMl} ml)',
                    ),
                  ),
                  const SizedBox(height: 12),
                  OutlinedButton.icon(
                    onPressed: () => _showCustomAmountDialog(context),
                    icon: const Icon(Icons.edit),
                    label: const Text('Cantidad personalizada'),
                  ),
                  const Spacer(),
                  if (progress >= 1.0)
                    Card(
                      color: Theme.of(context).colorScheme.primaryContainer,
                      child: const Padding(
                        padding: EdgeInsets.all(16),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(Icons.celebration),
                            SizedBox(width: 8),
                            Text('¡Meta diaria alcanzada!'),
                          ],
                        ),
                      ),
                    ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  void _showCustomAmountDialog(BuildContext context) {
    final controller = TextEditingController();
    showDialog(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Agregar agua'),
        content: TextField(
          controller: controller,
          keyboardType: TextInputType.number,
          decoration: const InputDecoration(
            labelText: 'Cantidad (ml)',
            suffixText: 'ml',
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
              final amount = int.tryParse(controller.text);
              if (amount != null && amount > 0) {
                context.read<WaterBloc>().add(
                      WaterCustomAmountAdded(
                        date: DateTime.now(),
                        amountMl: amount,
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

  void _showConfigDialog(BuildContext context) {
    final state = context.read<WaterBloc>().state;
    var unitType = state.unitType;
    var containerMl = state.containerMl;
    var dailyGoalMl = state.dailyGoalMl;

    showDialog(
      context: context,
      builder: (dialogContext) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          title: const Text('Configuración de agua'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              SegmentedButton<String>(
                segments: const [
                  ButtonSegment(value: 'bottle', label: Text('Botella')),
                  ButtonSegment(value: 'glass', label: Text('Vaso')),
                ],
                selected: {unitType},
                onSelectionChanged: (set) {
                  setDialogState(() {
                    unitType = set.first;
                    containerMl = unitType == 'bottle' ? 1000 : 250;
                  });
                },
              ),
              const SizedBox(height: 16),
              TextField(
                decoration: const InputDecoration(
                  labelText: 'Tamaño del contenedor (ml)',
                ),
                keyboardType: TextInputType.number,
                controller: TextEditingController(text: '$containerMl'),
                onChanged: (v) => containerMl = int.tryParse(v) ?? containerMl,
              ),
              const SizedBox(height: 16),
              TextField(
                decoration: const InputDecoration(
                  labelText: 'Meta diaria (ml)',
                ),
                keyboardType: TextInputType.number,
                controller: TextEditingController(text: '$dailyGoalMl'),
                onChanged: (v) => dailyGoalMl = int.tryParse(v) ?? dailyGoalMl,
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
                context.read<WaterBloc>().add(
                      WaterConfigUpdated(
                        unitType: unitType,
                        containerMl: containerMl,
                        dailyGoalMl: dailyGoalMl,
                      ),
                    );
                Navigator.pop(dialogContext);
              },
              child: const Text('Guardar'),
            ),
          ],
        ),
      ),
    );
  }
}
