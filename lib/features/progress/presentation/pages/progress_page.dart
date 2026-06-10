import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:intl/intl.dart';
import 'package:kiolog/core/database/app_database.dart';
import 'package:kiolog/shared/widgets/vitality_card.dart';
import '../../../../core/di/injection.dart';
import '../../domain/repositories/progress_repository.dart';
import '../bloc/progress_bloc.dart';
import '../bloc/progress_event.dart';
import '../bloc/progress_state.dart';

class ProgressPage extends StatelessWidget {
  const ProgressPage({super.key});

  @override
  Widget build(BuildContext context) {
    return BlocProvider(
      create: (_) => ProgressBloc(getIt<ProgressRepository>())
        ..add(const ProgressLoaded()),
      child: const _ProgressView(),
    );
  }
}

class _ProgressView extends StatelessWidget {
  const _ProgressView();

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Progreso')),
      body: BlocBuilder<ProgressBloc, ProgressState>(
        builder: (context, state) {
          if (state.status == ProgressStatus.loading) {
            return const Center(child: CircularProgressIndicator());
          }
          if (state.status == ProgressStatus.failure) {
            return Center(child: Text('Error: ${state.error}'));
          }

          return SafeArea(
            child: ListView(
              padding: const EdgeInsets.all(16),
              children: [
                _buildWeightCard(context, state),
                const SizedBox(height: 16),
                if (state.latestMeasurement != null)
                  _buildMeasurementsCard(context, state),
                const SizedBox(height: 16),
                if (state.weightLogs.isNotEmpty)
                  _buildWeightHistory(context, state),
              ],
            ),
          );
        },
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _showAddMeasurementDialog(context),
        icon: const Icon(Icons.straighten),
        label: const Text('Medidas'),
      ),
    );
  }

  Widget _buildWeightCard(BuildContext context, ProgressState state) {
    final theme = Theme.of(context);
    final latest = state.latestWeight;
    final change = state.weightChange;

    return VitalityCard(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Peso', style: theme.textTheme.titleMedium),
          const SizedBox(height: 12),
          if (latest != null)
            Row(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Text(
                  '${latest.toStringAsFixed(1)}',
                  style: theme.textTheme.headlineMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(width: 4),
                Text('kg', style: theme.textTheme.bodyLarge),
                const Spacer(),
                if (change != null)
                  Chip(
                    label: Text(
                      '${change >= 0 ? '+' : ''}${change.toStringAsFixed(1)} kg',
                      style: TextStyle(
                        color: change <= 0
                            ? theme.colorScheme.onPrimaryContainer
                            : theme.colorScheme.onErrorContainer,
                      ),
                    ),
                    backgroundColor: change <= 0
                        ? theme.colorScheme.primaryContainer
                        : theme.colorScheme.errorContainer,
                    side: BorderSide.none,
                  ),
              ],
            )
          else
            Text(
              'Sin registros',
              style: theme.textTheme.bodyLarge?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
          const SizedBox(height: 16),
          ElevatedButton.icon(
            onPressed: () => _showAddWeightDialog(context),
            icon: const Icon(Icons.add),
            label: const Text('Registrar peso'),
          ),
        ],
      ),
    );
  }

  Widget _buildMeasurementsCard(BuildContext context, ProgressState state) {
    final m = state.latestMeasurement!;
    final theme = Theme.of(context);

    final fields = <(String, String?)>[
      ('Talla', m.heightCm > 0 ? '${m.heightCm} cm' : null),
      ('Brazo flex', m.armFlexedCm != null ? '${m.armFlexedCm} cm' : null),
      ('Brazo relaj', m.armRelaxedCm != null ? '${m.armRelaxedCm} cm' : null),
      ('Cintura', m.waistCm != null ? '${m.waistCm} cm' : null),
      ('Cadera', m.hipCm != null ? '${m.hipCm} cm' : null),
      ('Pantorrilla', m.calfCm != null ? '${m.calfCm} cm' : null),
      (
        'Abdomen bajo',
        m.lowerAbdomenCm != null ? '${m.lowerAbdomenCm} cm' : null
      ),
      ('Muslo', m.thighCm != null ? '${m.thighCm} cm' : null),
      ('Glúteo', m.midGluteusCm != null ? '${m.midGluteusCm} cm' : null),
      ('Tórax', m.chestCm != null ? '${m.chestCm} cm' : null),
      ('% Grasa', m.bodyFatPct != null ? '${m.bodyFatPct}%' : null),
      ('Masa magra', m.leanMassKg != null ? '${m.leanMassKg} kg' : null),
      ('Masa visceral', m.visceralMass != null ? '${m.visceralMass}' : null),
    ];

    return VitalityCard(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Última consulta', style: theme.textTheme.titleMedium),
          const SizedBox(height: 4),
          Text(
            DateFormat.yMMMd('es').format(m.date),
            style: theme.textTheme.bodySmall?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
          const SizedBox(height: 12),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: fields
                .where((f) => f.$2 != null)
                .map((f) => Chip(
                      label: Text('${f.$1}: ${f.$2}'),
                      backgroundColor:
                          theme.colorScheme.surfaceContainerHighest,
                      side: BorderSide.none,
                    ))
                .toList(),
          ),
        ],
      ),
    );
  }

  Widget _buildWeightHistory(BuildContext context, ProgressState state) {
    final theme = Theme.of(context);

    return VitalityCard(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Historial de peso', style: theme.textTheme.titleMedium),
          const SizedBox(height: 12),
          ...state.weightLogs.reversed.take(10).map((log) {
            return ListTile(
              dense: true,
              contentPadding: EdgeInsets.zero,
              leading: Text(
                DateFormat.MMMd('es').format(log.date),
                style: theme.textTheme.bodyMedium,
              ),
              trailing: Text(
                '${log.weightKg.toStringAsFixed(1)} kg',
                style: theme.textTheme.bodyLarge?.copyWith(
                  fontWeight: FontWeight.bold,
                ),
              ),
            );
          }),
        ],
      ),
    );
  }

  void _showAddWeightDialog(BuildContext context) {
    final controller = TextEditingController();
    showDialog(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Registrar peso'),
        content: TextField(
          controller: controller,
          keyboardType: const TextInputType.numberWithOptions(decimal: true),
          decoration: const InputDecoration(
            labelText: 'Peso',
            suffixText: 'kg',
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
              final weight = double.tryParse(controller.text);
              if (weight != null && weight > 0) {
                context.read<ProgressBloc>().add(
                      ProgressWeightAdded(
                        date: DateTime.now(),
                        weightKg: weight,
                      ),
                    );
              }
              Navigator.pop(dialogContext);
            },
            child: const Text('Guardar'),
          ),
        ],
      ),
    );
  }

  void _showAddMeasurementDialog(BuildContext context) {
    final fields = {
      'Peso (kg)': TextEditingController(),
      'Talla (cm)': TextEditingController(),
      'Brazo flex (cm)': TextEditingController(),
      'Brazo relaj (cm)': TextEditingController(),
      'Cintura (cm)': TextEditingController(),
      'Cadera (cm)': TextEditingController(),
      'Pantorrilla (cm)': TextEditingController(),
      'Abdomen bajo (cm)': TextEditingController(),
      'Muslo (cm)': TextEditingController(),
      'Glúteo (cm)': TextEditingController(),
      'Tórax (cm)': TextEditingController(),
      '% Grasa': TextEditingController(),
      'Masa magra (kg)': TextEditingController(),
      'Masa visceral': TextEditingController(),
    };

    showDialog(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Nueva consulta'),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: fields.entries.map((e) {
              return Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: TextField(
                  controller: e.value,
                  keyboardType:
                      const TextInputType.numberWithOptions(decimal: true),
                  decoration: InputDecoration(labelText: e.key),
                ),
              );
            }).toList(),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: const Text('Cancelar'),
          ),
          ElevatedButton(
            onPressed: () {
              final weight = double.tryParse(fields['Peso (kg)']!.text);
              final height = double.tryParse(fields['Talla (cm)']!.text);
              if (weight != null && height != null) {
                context.read<ProgressBloc>().add(
                      ProgressMeasurementAdded(
                        date: DateTime.now(),
                        weightKg: weight,
                        heightCm: height,
                        armFlexedCm: _parse(fields['Brazo flex (cm)']!.text),
                        armRelaxedCm: _parse(fields['Brazo relaj (cm)']!.text),
                        waistCm: _parse(fields['Cintura (cm)']!.text),
                        hipCm: _parse(fields['Cadera (cm)']!.text),
                        calfCm: _parse(fields['Pantorrilla (cm)']!.text),
                        lowerAbdomenCm:
                            _parse(fields['Abdomen bajo (cm)']!.text),
                        thighCm: _parse(fields['Muslo (cm)']!.text),
                        midGluteusCm: _parse(fields['Glúteo (cm)']!.text),
                        chestCm: _parse(fields['Tórax (cm)']!.text),
                        bodyFatPct: _parse(fields['% Grasa']!.text),
                        leanMassKg: _parse(fields['Masa magra (kg)']!.text),
                        visceralMass: _parse(fields['Masa visceral']!.text),
                      ),
                    );
              }
              Navigator.pop(dialogContext);
            },
            child: const Text('Guardar'),
          ),
        ],
      ),
    );
  }

  double? _parse(String text) {
    final value = double.tryParse(text);
    return value != null && value > 0 ? value : null;
  }
}
