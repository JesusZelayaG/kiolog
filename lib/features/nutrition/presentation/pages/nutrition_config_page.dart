import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:iconsax_plus/iconsax_plus.dart';
import 'package:kiolog/core/theme/app_theme.dart';
import 'package:kiolog/shared/widgets/meal_icons.dart';
import 'package:kiolog/shared/widgets/meal_photo.dart';
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

  /// La foto de cada plato: la que ya tenía (id) o una nueva (bytes).
  final Map<TextEditingController, _PhotoDraft> _photos = {};
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
        created.icon = option.mealIcon;
        return created;
      });
      final controller = TextEditingController(text: option.description);
      entry.options.add(controller);
      _optionIds[controller] = option.id;
      if (option.photoId != null) _photos[controller] = _PhotoDraft(id: option.photoId);
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
    var drafts = <PlanOptionDraft>[];
    final draftFields = <TextEditingController>[];
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
          mealIcon: mealTime.icon,
        ));
        draftFields.add(filled[i]);
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
    // Las fotos nuevas se guardan primero; el plan solo guarda su id.
    final photoIds = <TextEditingController, int?>{};
    for (final field in draftFields) {
      final photo = _photos[field];
      if (photo == null) continue;
      final bytes = photo.bytes;
      photoIds[field] = bytes != null ? await nutritionRepo.savePhoto(bytes) : photo.id;
    }
    drafts = [
      for (var k = 0; k < drafts.length; k++)
        PlanOptionDraft(
          id: drafts[k].id,
          mealType: drafts[k].mealType,
          optionNumber: drafts[k].optionNumber,
          description: drafts[k].description,
          photoId: photoIds[draftFields[k]],
          mealIcon: drafts[k].mealIcon,
        ),
    ];
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
          photoId: draft.photoId,
          mealIcon: draft.mealIcon,
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
                          Builder(builder: (context) {
                            final current = MealIcon.resolve(mt.icon, mt.nameController.text);
                            return Tooltip(
                              message: 'Elegir ícono',
                              child: Material(
                                color: context.kc.foodWash,
                                borderRadius: BorderRadius.circular(14),
                                child: InkWell(
                                  borderRadius: BorderRadius.circular(14),
                                  onTap: () async {
                                    final chosen = await pickMealIcon(
                                      context,
                                      mealType: mt.nameController.text,
                                      current: current,
                                    );
                                    if (chosen != null) setState(() => mt.icon = chosen.name);
                                  },
                                  child: SizedBox(
                                    width: 44,
                                    height: 44,
                                    child: Center(child: current.build(color: context.kc.foodInk)),
                                  ),
                                ),
                              ),
                            );
                          }),
                          const SizedBox(width: 12),
                          Expanded(
                            child: TextField(
                              controller: mt.nameController,
                              // El ícono sugerido sigue al nombre mientras no se elija uno.
                              onChanged: (_) => setState(() {}),
                              decoration: InputDecoration(
                                labelText: 'Tiempo ${index + 1}',
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
                                  _OptionPhotoButton(
                                    draft: _photos[oe.value],
                                    onChanged: (draft) => setState(() {
                                      if (draft == null) {
                                        _photos.remove(oe.value);
                                      } else {
                                        _photos[oe.value] = draft;
                                      }
                                    }),
                                  ),
                                  const SizedBox(width: 10),
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

  /// El ícono elegido (MealIcon.name); null usa el sugerido por el nombre.
  String? icon;
  final List<TextEditingController> options = [TextEditingController()];
}

/// La foto de un plato mientras se edita el plan.
class _PhotoDraft {
  const _PhotoDraft({this.id, this.bytes});

  /// La que ya estaba guardada.
  final int? id;

  /// Una nueva, todavía sin guardar.
  final Uint8List? bytes;
}

class _OptionPhotoButton extends StatelessWidget {
  const _OptionPhotoButton({required this.draft, required this.onChanged});

  final _PhotoDraft? draft;
  final ValueChanged<_PhotoDraft?> onChanged;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final d = draft;
    final Widget image;
    if (d?.bytes != null) {
      image = ClipRRect(
        borderRadius: BorderRadius.circular(12),
        child: Image.memory(d!.bytes!, width: 48, height: 48, fit: BoxFit.cover, cacheWidth: 144),
      );
    } else if (d?.id != null) {
      image = MealPhotoImage(photoId: d!.id!, width: 48, height: 48, radius: 12);
    } else {
      image = Container(
        width: 48,
        height: 48,
        decoration: BoxDecoration(color: cs.surfaceContainerHigh, borderRadius: BorderRadius.circular(12)),
        child: Icon(IconsaxPlusLinear.gallery_add, size: 20, color: cs.onSurfaceVariant),
      );
    }
    return Tooltip(
      message: 'Foto de cómo debería verse',
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: () async {
          final choice = await pickMealPhoto(context, title: 'Cómo debería verse', canRemove: d != null);
          switch (choice) {
            case PhotoPicked(:final bytes):
              onChanged(_PhotoDraft(bytes: bytes));
            case PhotoRemoved():
              onChanged(null);
            case null:
          }
        },
        child: image,
      ),
    );
  }
}
