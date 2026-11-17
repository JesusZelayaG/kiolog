import 'package:flutter/material.dart';
import 'package:iconsax_plus/iconsax_plus.dart';
import 'package:kiolog/core/theme/app_theme.dart';
import 'package:kiolog/shared/widgets/kiolog_glyphs.dart';

/// Los íconos que se pueden elegir para un tiempo de comida. [name] es lo que
/// se guarda en la base: no cambiarlo.
enum MealIcon {
  sunrise('Amanecer', IconsaxPlusBold.sun_fog),
  sun('Sol', IconsaxPlusBold.sun_1),
  coffee('Café', IconsaxPlusBold.coffee),
  drink('Bebida', IconsaxPlusBold.drop),
  milk('Leche', IconsaxPlusBold.milk),
  bowl('Plato', null),
  dish('Servicio', IconsaxPlusBold.reserve),
  cake('Pastel', IconsaxPlusBold.cake),
  moon('Luna', IconsaxPlusBold.moon),
  energy('Energía', IconsaxPlusBold.flash),
  healthy('Saludable', IconsaxPlusBold.heart),
  star('Estrella', IconsaxPlusBold.star_1);

  const MealIcon(this.label, this._icon);

  final String label;
  final IconData? _icon;

  static MealIcon? fromName(String? name) => values.where((i) => i.name == name).firstOrNull;

  /// Sugerencia por el nombre del tiempo de comida, cuando no se eligió uno.
  static MealIcon suggest(String mealType) {
    final name = mealType.toLowerCase();
    if (name.contains('desayuno')) return sunrise;
    if (name.contains('cena')) return moon;
    if (name.contains('refacci') || name.contains('merienda') || name.contains('snack') || name.contains('colaci')) {
      return coffee;
    }
    if (name.contains('entreno')) return energy;
    return bowl;
  }

  /// El elegido, o el sugerido por el nombre.
  static MealIcon resolve(String? chosen, String mealType) => fromName(chosen) ?? suggest(mealType);

  Widget build({required Color color, double size = 22}) {
    final icon = _icon;
    return icon == null
        ? KiologGlyph(KiologGlyphKind.bowl, color: color, size: size)
        : Icon(icon, color: color, size: size);
  }
}

/// Cuadrícula para elegir el ícono de [mealType]. Devuelve null si se canceló.
Future<MealIcon?> pickMealIcon(BuildContext context, {required String mealType, required MealIcon current}) =>
    showModalBottomSheet<MealIcon>(
      context: context,
      showDragHandle: true,
      builder: (sheetContext) {
        final theme = Theme.of(sheetContext);
        final kc = sheetContext.kc;
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(20, 0, 20, 16),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  mealType.trim().isEmpty ? 'Ícono' : 'Ícono de ${mealType.trim()}',
                  style: theme.textTheme.titleLarge,
                ),
                const SizedBox(height: 16),
                GridView.count(
                  crossAxisCount: 4,
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  mainAxisSpacing: 12,
                  crossAxisSpacing: 12,
                  childAspectRatio: 0.85,
                  children: [
                    for (final icon in MealIcon.values)
                      Semantics(
                        button: true,
                        selected: icon == current,
                        label: icon.label,
                        child: InkWell(
                          borderRadius: BorderRadius.circular(18),
                          onTap: () => Navigator.pop(sheetContext, icon),
                          child: Column(
                            children: [
                              AnimatedContainer(
                                duration: const Duration(milliseconds: 200),
                                width: 58,
                                height: 58,
                                alignment: Alignment.center,
                                decoration: BoxDecoration(
                                  color: kc.foodWash,
                                  borderRadius: BorderRadius.circular(18),
                                  border: Border.all(
                                    color: icon == current ? theme.colorScheme.primary : Colors.transparent,
                                    width: 2,
                                  ),
                                ),
                                child: icon.build(color: kc.foodInk, size: 26),
                              ),
                              const SizedBox(height: 4),
                              Text(icon.label, style: theme.textTheme.labelSmall, maxLines: 1),
                            ],
                          ),
                        ),
                      ),
                  ],
                ),
              ],
            ),
          ),
        );
      },
    );
