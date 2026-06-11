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

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Agua'),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new),
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
          final pct = (progress * 100).round();

          return SafeArea(
            child: SingleChildScrollView(
              padding: const EdgeInsets.fromLTRB(24, 16, 24, 32),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  Text(
                    'HIDRATACIÓN DIARIA',
                    style: theme.textTheme.labelSmall?.copyWith(
                      color: cs.primary,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    '$liters / $goalLiters L',
                    style: theme.textTheme.displaySmall?.copyWith(
                      fontWeight: FontWeight.bold,
                      color: cs.onSurface,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    '${state.dailyTotalMl} / ${state.dailyGoalMl} ml',
                    style: theme.textTheme.bodyMedium?.copyWith(
                      color: cs.onSurfaceVariant,
                    ),
                  ),
                  const SizedBox(height: 40),
                  SizedBox(
                    height: 200,
                    width: 200,
                    child: Stack(
                      fit: StackFit.expand,
                      children: [
                        CircularProgressIndicator(
                          value: progress,
                          strokeWidth: 14,
                          strokeCap: StrokeCap.round,
                          backgroundColor:
                              cs.primaryContainer.withValues(alpha: 0.25),
                        ),
                        Center(
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(
                                Icons.water_drop,
                                size: 40,
                                color: cs.primary,
                              ),
                              const SizedBox(height: 6),
                              Text(
                                '$pct%',
                                style:
                                    theme.textTheme.headlineMedium?.copyWith(
                                  fontWeight: FontWeight.bold,
                                  color: cs.onSurface,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 48),
                  SizedBox(
                    width: double.infinity,
                    height: 52,
                    child: ElevatedButton.icon(
                      style: ElevatedButton.styleFrom(
                        shape: const StadiumBorder(),
                        backgroundColor: cs.primary,
                        foregroundColor: cs.onPrimary,
                      ),
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
                  ),
                  const SizedBox(height: 12),
                  SizedBox(
                    width: double.infinity,
                    height: 48,
                    child: OutlinedButton.icon(
                      style: OutlinedButton.styleFrom(
                        shape: const StadiumBorder(),
                        side: BorderSide(
                          color: cs.outline.withValues(alpha: 0.5),
                        ),
                      ),
                      onPressed: () => _showCustomAmountDialog(context),
                      icon: const Icon(Icons.edit_outlined, size: 18),
                      label: const Text('Cantidad personalizada'),
                    ),
                  ),
                  if (progress >= 1.0) ...[
                    const SizedBox(height: 32),
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: cs.primaryContainer.withValues(alpha: 0.15),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(
                          color: cs.primary.withValues(alpha: 0.4),
                        ),
                      ),
                      child: Row(
                        children: [
                          Icon(Icons.celebration, color: cs.primary),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  '¡Meta alcanzada!',
                                  style:
                                      theme.textTheme.labelLarge?.copyWith(
                                    color: cs.primary,
                                  ),
                                ),
                                const SizedBox(height: 2),
                                Text(
                                  'Consumiste $liters litros hoy',
                                  style:
                                      theme.textTheme.bodySmall?.copyWith(
                                    color: cs.onSurfaceVariant,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
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
        title: Text(
          'Agregar agua',
          style: TextStyle(color: Theme.of(context).colorScheme.onSurface),
        ),
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
