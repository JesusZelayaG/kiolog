import 'package:flutter/material.dart';
import 'package:kiolog/core/di/injection.dart';
import 'package:kiolog/core/domain/app_module.dart';
import 'package:kiolog/core/modules/cubit/modules_cubit.dart';
import 'package:kiolog/features/water/domain/repositories/water_repository.dart';
import 'package:kiolog/shared/widgets/water_goal_picker.dart';

/// Activa el módulo de agua pidiendo solo la meta diaria.
class WaterConfigPage extends StatefulWidget {
  final VoidCallback onComplete;

  const WaterConfigPage({super.key, required this.onComplete});

  @override
  State<WaterConfigPage> createState() => _WaterConfigPageState();
}

class _WaterConfigPageState extends State<WaterConfigPage> {
  int _dailyGoalMl = 3000;
  bool _saving = false;

  Future<void> _save() async {
    setState(() => _saving = true);
    await getIt<WaterRepository>().saveGoal(_dailyGoalMl);
    await getIt<ModulesCubit>().setModuleEnabled(AppModule.water, true);
    if (mounted) {
      Navigator.of(context).pop();
      widget.onComplete();
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Scaffold(
      appBar: AppBar(title: const Text('Agua')),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text('¿Cuánta agua quieres tomar al día?', style: theme.textTheme.titleLarge),
            const SizedBox(height: 8),
            Text(
              'Cada vez que tomes agua escribes la cantidad en ml o litros.',
              style: theme.textTheme.bodyMedium?.copyWith(color: theme.colorScheme.onSurfaceVariant),
            ),
            const SizedBox(height: 24),
            WaterGoalPicker(goalMl: _dailyGoalMl, onChanged: (ml) => setState(() => _dailyGoalMl = ml)),
            const SizedBox(height: 32),
            ElevatedButton(
              onPressed: _saving ? null : _save,
              child: const Text('Guardar'),
            ),
          ],
        ),
      ),
    );
  }
}
