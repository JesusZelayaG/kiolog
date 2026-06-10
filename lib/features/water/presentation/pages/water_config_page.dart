import 'package:flutter/material.dart';
import 'package:kiolog/core/di/injection.dart';
import 'package:kiolog/core/domain/app_module.dart';
import 'package:kiolog/core/modules/cubit/modules_cubit.dart';
import 'package:kiolog/features/water/domain/repositories/water_repository.dart';

class WaterConfigPage extends StatefulWidget {
  final VoidCallback onComplete;

  const WaterConfigPage({super.key, required this.onComplete});

  @override
  State<WaterConfigPage> createState() => _WaterConfigPageState();
}

class _WaterConfigPageState extends State<WaterConfigPage> {
  String _waterUnit = 'bottle';
  int _containerMl = 1000;
  int _dailyGoalMl = 3000;

  late final TextEditingController _containerMlController;
  late final TextEditingController _dailyGoalMlController;

  @override
  void initState() {
    super.initState();
    _containerMlController = TextEditingController(text: '$_containerMl');
    _dailyGoalMlController = TextEditingController(text: '$_dailyGoalMl');
  }

  @override
  void dispose() {
    _containerMlController.dispose();
    _dailyGoalMlController.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    await getIt<WaterRepository>().saveConfig(
      unitType: _waterUnit,
      containerMl: _containerMl,
      dailyGoalMl: _dailyGoalMl,
    );
    await getIt<ModulesCubit>().setModuleEnabled(AppModule.water, true);
    if (mounted) {
      Navigator.of(context).pop();
    }
    widget.onComplete();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(title: const Text('Configuración de Agua')),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              '¿Cómo vas a medir tu ingesta de agua?',
              style: theme.textTheme.bodyLarge,
            ),
            const SizedBox(height: 24),
            SegmentedButton<String>(
              segments: const [
                ButtonSegment(value: 'bottle', label: Text('Botella')),
                ButtonSegment(value: 'glass', label: Text('Vaso')),
              ],
              selected: {_waterUnit},
              onSelectionChanged: (set) {
                setState(() {
                  _waterUnit = set.first;
                  _containerMl = _waterUnit == 'bottle' ? 1000 : 250;
                  _containerMlController.text = '$_containerMl';
                });
              },
            ),
            const SizedBox(height: 24),
            TextField(
              decoration: const InputDecoration(
                labelText: 'Tamaño del contenedor (ml)',
                suffixText: 'ml',
              ),
              keyboardType: TextInputType.number,
              controller: _containerMlController,
              onChanged: (v) => _containerMl = int.tryParse(v) ?? _containerMl,
            ),
            const SizedBox(height: 16),
            TextField(
              decoration: const InputDecoration(
                labelText: 'Meta diaria de agua (ml)',
                suffixText: 'ml',
              ),
              keyboardType: TextInputType.number,
              controller: _dailyGoalMlController,
              onChanged: (v) => _dailyGoalMl = int.tryParse(v) ?? _dailyGoalMl,
            ),
            const SizedBox(height: 16),
            Text(
              'Eso equivale a aproximadamente ${_dailyGoalMl ~/ _containerMl} ${_waterUnit == 'bottle' ? 'botellas' : 'vasos'} al día.',
              style: theme.textTheme.bodyMedium?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
            const SizedBox(height: 32),
            SizedBox(
              width: double.infinity,
              child: FilledButton(
                onPressed: _save,
                child: const Text('Guardar'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
