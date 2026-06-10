import 'package:flutter/material.dart';
import 'package:kiolog/core/di/injection.dart';
import 'package:kiolog/core/domain/app_module.dart';
import 'package:kiolog/core/modules/cubit/modules_cubit.dart';
import 'package:kiolog/features/nutrition/domain/repositories/nutrition_repository.dart';

class NutritionConfigPage extends StatefulWidget {
  final VoidCallback onComplete;

  const NutritionConfigPage({super.key, required this.onComplete});

  @override
  State<NutritionConfigPage> createState() => _NutritionConfigPageState();
}

class _NutritionConfigPageState extends State<NutritionConfigPage> {
  final _planNameController = TextEditingController(text: 'Mi Plan');
  final List<_MealTimeEntry> _mealTimes = [_MealTimeEntry()];
  bool _saving = false;

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
    setState(() => _saving = true);
    final nutritionRepo = getIt<NutritionRepository>();
    final planId = await nutritionRepo.createPlan(
      _planNameController.text,
      dailyMealGoal: _mealTimes.length,
    );
    for (final mealTime in _mealTimes) {
      final typeName = mealTime.nameController.text.trim();
      if (typeName.isEmpty) continue;
      for (int i = 0; i < mealTime.options.length; i++) {
        final text = mealTime.options[i].text.trim();
        if (text.isNotEmpty) {
          await nutritionRepo.addPlanOption(
            planId: planId,
            mealType: typeName,
            optionNumber: i + 1,
            description: text,
          );
        }
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
      appBar: AppBar(title: const Text('Plan de Alimentación')),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Define tus tiempos de comida y las opciones para cada uno.',
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
              return Card(
                margin: const EdgeInsets.only(bottom: 12),
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
              child: FilledButton(
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
