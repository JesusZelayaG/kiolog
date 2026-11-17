import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:kiolog/core/theme/app_theme.dart';
import 'package:kiolog/core/theme/theme_cubit.dart';

/// Los temas con una vista previa en miniatura; el cambio se aplica al tocar.
class ThemePicker extends StatelessWidget {
  const ThemePicker({super.key});

  @override
  Widget build(BuildContext context) {
    final current = context.watch<ThemeCubit>().state;
    return Column(
      children: [
        for (final id in KiologThemeId.values)
          Padding(
            padding: const EdgeInsets.only(bottom: 10),
            child: _ThemeOption(
              id: id,
              selected: id == current,
              onTap: () => context.read<ThemeCubit>().select(id),
            ),
          ),
      ],
    );
  }
}

class _ThemeOption extends StatelessWidget {
  const _ThemeOption({required this.id, required this.selected, required this.onTap});

  final KiologThemeId id;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final current = Theme.of(context);
    // La miniatura se pinta con el tema que representa, no con el actual.
    final preview = AppTheme.of(id);
    final pcs = preview.colorScheme;
    final pkc = preview.extension<KiologColors>()!;
    return Material(
      color: current.colorScheme.surfaceContainerLowest,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(20),
        side: BorderSide(
          color: selected ? current.colorScheme.primary : current.colorScheme.outlineVariant,
          width: selected ? 2 : 1,
        ),
      ),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Row(
            children: [
              Container(
                width: 72,
                height: 56,
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: pcs.surface,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: pcs.outlineVariant),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Container(
                      height: 14,
                      decoration: BoxDecoration(
                        gradient: pkc.brandGradient,
                        borderRadius: BorderRadius.circular(7),
                      ),
                    ),
                    const SizedBox(height: 6),
                    Row(
                      children: [
                        _Swatch(pkc.waterWash),
                        const SizedBox(width: 4),
                        _Swatch(pkc.foodWash),
                        const SizedBox(width: 4),
                        _Swatch(pcs.surfaceContainerLowest),
                      ],
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(id.label, style: current.textTheme.titleSmall),
                    const SizedBox(height: 2),
                    Text(id.description, style: current.textTheme.bodySmall),
                  ],
                ),
              ),
              Icon(
                selected ? Icons.radio_button_checked : Icons.radio_button_unchecked,
                color: selected ? current.colorScheme.primary : current.colorScheme.outline,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _Swatch extends StatelessWidget {
  const _Swatch(this.color);

  final Color color;

  @override
  Widget build(BuildContext context) => Expanded(
        child: Container(
          height: 18,
          decoration: BoxDecoration(color: color, borderRadius: BorderRadius.circular(5)),
        ),
      );
}
