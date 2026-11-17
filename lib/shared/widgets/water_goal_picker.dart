import 'package:flutter/material.dart';
import 'package:kiolog/core/theme/app_theme.dart';
import 'package:kiolog/shared/widgets/water_widgets.dart';

/// Elige la meta diaria de agua: atajos en litros u otra cantidad.
class WaterGoalPicker extends StatelessWidget {
  const WaterGoalPicker({super.key, required this.goalMl, required this.onChanged});

  final int goalMl;
  final ValueChanged<int> onChanged;

  static const _presets = [2000, 2500, 3000, 3500];

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final kc = context.kc;
    final custom = !_presets.contains(goalMl);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Center(
          child: Row(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.baseline,
            textBaseline: TextBaseline.alphabetic,
            children: [
              Text(litersLabel(goalMl), style: theme.textTheme.displayLarge?.copyWith(color: kc.waterInk)),
              const SizedBox(width: 6),
              Text('L al día', style: theme.textTheme.titleMedium?.copyWith(color: kc.waterInk)),
            ],
          ),
        ),
        Center(child: Text('$goalMl ml', style: theme.textTheme.bodySmall)),
        const SizedBox(height: 16),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          alignment: WrapAlignment.center,
          children: [
            for (final preset in _presets)
              ChoiceChip(
                label: Text('${litersLabel(preset)} L'),
                selected: goalMl == preset,
                onSelected: (_) => onChanged(preset),
              ),
            ChoiceChip(
              label: Text(custom ? 'Otra: ${litersLabel(goalMl)} L' : 'Otra'),
              selected: custom,
              onSelected: (_) async {
                final ml = await showWaterAmountSheet(
                  context,
                  title: 'Meta diaria de agua',
                  action: 'Usar',
                  presets: const [],
                  initialMl: goalMl,
                  startInLiters: true,
                );
                if (ml != null) onChanged(ml);
              },
            ),
          ],
        ),
      ],
    );
  }
}
