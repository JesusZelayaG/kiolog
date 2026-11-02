import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:intl/intl.dart';
import 'package:kiolog/core/database/app_database.dart';
import 'package:kiolog/core/database/file_chooser.dart';
import 'package:kiolog/shared/widgets/vitality_card.dart';

import '../../../../core/di/injection.dart';
import '../../data/ficha_reader.dart';
import '../../domain/repositories/progress_repository.dart';
import '../bloc/consultations_cubit.dart';
import '../widgets/measurement_form.dart';

class ConsultationsPage extends StatelessWidget {
  const ConsultationsPage({super.key});

  @override
  Widget build(BuildContext context) {
    return BlocProvider(
      create: (_) => ConsultationsCubit(getIt<ProgressRepository>())..load(),
      child: const _ConsultationsView(),
    );
  }
}

class _ConsultationsView extends StatelessWidget {
  const _ConsultationsView();

  Future<void> _add(BuildContext context) async {
    final cubit = context.read<ConsultationsCubit>();
    final measurement = await showMeasurementForm(context);
    if (measurement != null) await cubit.save(measurement);
  }

  Future<void> _import(BuildContext context) async {
    final cubit = context.read<ConsultationsCubit>();
    final messenger = ScaffoldMessenger.of(context);
    final path = await chooseFile(mimeTypes: const ['application/pdf', 'image/*']);
    if (path == null) return;
    final now = DateTime.now();
    Measurement? read;
    try {
      read = await readFicha(path, DateTime.utc(now.year, now.month, now.day));
    } catch (_) {
      read = null;
    }
    if (!context.mounted) return;
    if (read == null) {
      messenger.showSnackBar(
        const SnackBar(content: Text('No se reconocieron medidas en ese archivo')),
      );
      return;
    }
    final reviewed = await showMeasurementForm(context, initial: read);
    if (reviewed != null) await cubit.save(reviewed);
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Scaffold(
      appBar: AppBar(title: const Text('Consultas')),
      body: BlocBuilder<ConsultationsCubit, ConsultationsState>(
        builder: (context, state) => switch (state.status) {
          ConsultationsStatus.loading =>
            const Center(child: CircularProgressIndicator()),
          ConsultationsStatus.failure =>
            const Center(child: Text('No se pudieron cargar las consultas.')),
          ConsultationsStatus.ready when state.consultations.isEmpty => Center(
              child: Padding(
                padding: const EdgeInsets.all(32),
                child: Text(
                  'Registra aquí las medidas de cada consulta con tu nutricionista.',
                  textAlign: TextAlign.center,
                  style: theme.textTheme.bodyLarge,
                ),
              ),
            ),
          ConsultationsStatus.ready => ListView.separated(
              padding: const EdgeInsets.all(16),
              itemCount: state.consultations.length,
              separatorBuilder: (_, __) => const SizedBox(height: 12),
              itemBuilder: (context, i) => _ConsultationCard(state.consultations[i]),
            ),
        },
      ),
      bottomNavigationBar: SafeArea(
        minimum: const EdgeInsets.fromLTRB(16, 8, 16, 16),
        child: Builder(
          builder: (context) => Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              OutlinedButton.icon(
                onPressed: () => _import(context),
                icon: const Icon(Icons.document_scanner_outlined),
                label: const Text('Importar ficha (PDF o foto)'),
              ),
              const SizedBox(height: 8),
              ElevatedButton.icon(
                onPressed: () => _add(context),
                icon: const Icon(Icons.add),
                label: const Text('Nueva consulta'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _ConsultationCard extends StatelessWidget {
  const _ConsultationCard(this.measurement);

  final Measurement measurement;

  Future<void> _edit(BuildContext context) async {
    final cubit = context.read<ConsultationsCubit>();
    final updated = await showMeasurementForm(context, initial: measurement);
    if (updated != null) await cubit.save(updated);
  }

  Future<void> _delete(BuildContext context, String date) async {
    final cubit = context.read<ConsultationsCubit>();
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Borrar consulta'),
        content: Text('Se borrarán las medidas del $date. No se puede deshacer.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: const Text('Cancelar'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(dialogContext, true),
            child: const Text('Borrar'),
          ),
        ],
      ),
    );
    if (confirmed == true) await cubit.delete(measurement.id);
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final m = measurement;
    final date = DateFormat('dd/MM/yyyy').format(m.date.toUtc());
    final waist = m.waistCm == null ? '' : ' · Cintura ${m.waistCm} cm';
    return VitalityCard(
      padding: const EdgeInsets.fromLTRB(20, 12, 8, 12),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(date, style: theme.textTheme.titleMedium),
                Text('${m.weightKg} kg$waist', style: theme.textTheme.bodySmall),
              ],
            ),
          ),
          IconButton(
            tooltip: 'Editar',
            icon: const Icon(Icons.edit_outlined),
            onPressed: () => _edit(context),
          ),
          IconButton(
            tooltip: 'Borrar',
            icon: const Icon(Icons.delete_outline),
            onPressed: () => _delete(context, date),
          ),
        ],
      ),
    );
  }
}
