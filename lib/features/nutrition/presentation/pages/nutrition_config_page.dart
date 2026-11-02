import 'package:flutter/material.dart';
import 'package:kiolog/core/database/app_database.dart';
import 'package:kiolog/shared/widgets/vitality_card.dart';
import 'package:kiolog/core/di/injection.dart';
import 'package:kiolog/core/domain/app_module.dart';
import 'package:kiolog/core/modules/cubit/modules_cubit.dart';
import 'package:kiolog/features/nutrition/domain/models/plan_option_draft.dart';
import 'package:kiolog/features/nutrition/domain/repositories/nutrition_repository.dart';

class NutritionConfigPage extends StatefulWidget {
  final VoidCallback onComplete;

  /// Plan a corregir; sin él, se crea uno nuevo que reemplaza al vigente.
  final MealPlan? plan;

  const NutritionConfigPage({super.key, required this.onComplete, this.plan});

  @override
  State<NutritionConfigPage> createState() => _NutritionConfigPageState();
}

class _NutritionConfigPageState extends State<NutritionConfigPage> {
  late final _planNameController =
      TextEditingController(text: widget.plan?.name ?? 'Mi Plan');
  final List<_MealTimeEntry> _mealTimes = [_MealTimeEntry()];
  final Map<TextEditingController, int> _optionIds = {};
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    final plan = widget.plan;
    if (plan != null) _loadPlan(plan);
  }

  Future<void> _loadPlan(MealPlan plan) async {
    final options = await getIt<NutritionRepository>().getAllPlanOptions(plan.id);
    if (!mounted || options.isEmpty) return;
    final byType = <String, _MealTimeEntry>{};
    for (final option in options) {
      final entry = byType.putIfAbsent(option.mealType, () {
        final created = _MealTimeEntry()..options.clear();
        created.nameController.text = option.mealType;
        return created;
      });
      final controller = TextEditingController(text: option.description);
      entry.options.add(controller);
      _optionIds[controller] = option.id;
    }
    setState(() {
      _mealTimes
        ..clear()
        ..addAll(byType.values);
    });
  }

  void _complain(String message) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(message)));
  }

  @override
  void dispose() {
    _planNameController.dispose();
    for (final mt in _mealTimes) {
      mt.nameController.dispose();
      for (final c in mt.options) c.dispose();
    }
    super.dispose();
  }

  Future<void> _save() async {
    final name = _planNameController.text.trim();
    final drafts = <PlanOptionDraft>[];
    var mealCount = 0;
    for (final mealTime in _mealTimes) {
      final typeName = mealTime.nameController.text.trim();
      final filled = mealTime.options.where((c) => c.text.trim().isNotEmpty).toList();
      if (filled.isEmpty) continue;
      if (typeName.isEmpty) {
        _complain('Escribe el nombre de cada tiempo de comida');
        return;
      }
      mealCount++;
      for (var i = 0; i < filled.length; i++) {
        drafts.add(PlanOptionDraft(
          id: _optionIds[filled[i]],
          mealType: typeName,
          optionNumber: i + 1,
          description: filled[i].text.trim(),
        ));
      }
    }
    if (name.isEmpty) {
      _complain('Escribe el nombre del plan');
      return;
    }
    if (drafts.isEmpty) {
      _complain('Agrega al menos una comida con una opción');
      return;
    }

    setState(() => _saving = true);
    final nutritionRepo = getIt<NutritionRepository>();
    final plan = widget.plan;
    if (plan != null) {
      await nutritionRepo.updatePlan(
        planId: plan.id,
        name: name,
        dailyMealGoal: mealCount,
        options: drafts,
      );
    } else {
      final planId = await nutritionRepo.createPlan(name, dailyMealGoal: mealCount);
      for (final draft in drafts) {
        await nutritionRepo.addPlanOption(
          planId: planId,
          mealType: draft.mealType,
          optionNumber: draft.optionNumber,
          description: draft.description,
        );
      }
    }
    await getIt<ModulesCubit>().setModuleEnabled(AppModule.nutrition, true);
    if (mounted) {
      Navigator.of(context).pop();
      widget.onComplete();
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(title: Text(widget.plan == null ? 'Nuevo plan' : 'Editar plan')),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              widget.plan == null
                  ? 'Copia el plan de tu nutricionista. Reemplazará al plan actual.'
                  : 'Corrige este plan. Lo que ya registraste se conserva.',
              style: theme.textTheme.bodyLarge,
            ),
            const SizedBox(height: 16),
            TextField(
              controller: _planNameController,
              decoration: const InputDecoration(labelText: 'Nombre del plan'),
            ),
            const SizedBox(height: 24),
            ..._mealTimes.asMap().entries.map((e) {
              final index = e.key;
              final mt = e.value;
              return Padding(
                padding: const EdgeInsets.only(bottom: 12),
                child: VitalityCard(
                  padding: EdgeInsets.zero,
                  child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Padding(
                      padding: const EdgeInsets.fromLTRB(16, 12, 8, 0),
                      child: Row(
                        children: [
                          Text(
                            'Tiempo ${index + 1}',
                            style: theme.textTheme.labelSmall?.copyWith(
                              color: theme.colorScheme.onSurfaceVariant,
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: TextField(
                              controller: mt.nameController,
                              decoration: const InputDecoration(
                                hintText: 'Ej: Desayuno',
                                isDense: true,
                              ),
                            ),
                          ),
                          if (_mealTimes.length > 1)
                            IconButton(
                              icon: const Icon(Icons.delete_outline),
                              color: theme.colorScheme.error,
                              onPressed: () {
                                setState(() {
                                  mt.nameController.dispose();
                                  for (final c in mt.options) c.dispose();
                                  _mealTimes.removeAt(index);
                                });
                              },
                            ),
                        ],
                      ),
                    ),
                    const Divider(height: 16),
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 16),
                      child: Column(
                        children: [
                          ...mt.options.asMap().entries.map((oe) {
                            return Padding(
                              padding: const EdgeInsets.only(bottom: 8),
                              child: Row(
                                children: [
                                  Expanded(
                                    child: TextField(
                                      controller: oe.value,
                                      decoration: InputDecoration(
                                        labelText: 'Opción ${oe.key + 1}',
                                        hintText: 'Ej: Avena con frutas',
                                        isDense: true,
                                      ),
                                    ),
                                  ),
                                  if (mt.options.length > 1)
                                    IconButton(
                                      icon: const Icon(Icons.close, size: 18),
                                      onPressed: () {
                                        setState(() {
                                          oe.value.dispose();
                                          mt.options.removeAt(oe.key);
                                        });
                                      },
                                    ),
                                ],
                              ),
                            );
                          }),
                          Align(
                            alignment: Alignment.centerLeft,
                            child: TextButton.icon(
                              onPressed: () {
                                setState(
                                    () => mt.options.add(TextEditingController()));
                              },
                              icon: const Icon(Icons.add, size: 16),
                              label: const Text('Agregar opción'),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                ),
              );
            }),
            OutlinedButton.icon(
              onPressed: () {
                setState(() => _mealTimes.add(_MealTimeEntry()));
              },
              icon: const Icon(Icons.add),
              label: const Text('Agregar tiempo de comida'),
            ),
            const SizedBox(height: 8),
            Text(
              'Meta diaria automática: ${_mealTimes.length} ${_mealTimes.length == 1 ? 'comida' : 'comidas'}',
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
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

class _MealTimeEntry {
  final nameController = TextEditingController();
  final List<TextEditingController> options = [TextEditingController()];
}
