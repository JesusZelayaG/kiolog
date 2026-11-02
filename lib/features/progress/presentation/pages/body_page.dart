import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:intl/intl.dart';
import 'package:kiolog/core/dao/user_profile_dao.dart';
import 'package:kiolog/core/theme/app_theme.dart';
import 'package:kiolog/shared/widgets/stat_chip.dart';
import 'package:kiolog/shared/widgets/vitality_card.dart';

import '../../../../core/di/injection.dart';
import '../../domain/body_calibration.dart';
import '../../domain/repositories/progress_repository.dart';
import '../bloc/body_cubit.dart';
import '../widgets/body_viewer.dart';

const _labels = {
  'pecho': 'Tórax',
  'cintura': 'Cintura',
  'abdomen': 'Abdomen',
  'cadera': 'Cadera',
  'brazo': 'Brazo',
  'muslo': 'Muslo',
  'pantorrilla': 'Pantorrilla',
};

class BodyPage extends StatelessWidget {
  const BodyPage({super.key});

  @override
  Widget build(BuildContext context) {
    return BlocProvider(
      create: (_) => BodyCubit(getIt<ProgressRepository>(), getIt<UserProfileDao>())..load(),
      child: const _BodyView(),
    );
  }
}

class _BodyView extends StatelessWidget {
  const _BodyView();

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Tu cuerpo')),
      body: BlocBuilder<BodyCubit, BodyState>(
        builder: (context, state) => switch (state.status) {
          BodyStatus.loading => const Center(child: CircularProgressIndicator()),
          BodyStatus.failure => const _Message('No se pudo cargar tu medición.'),
          BodyStatus.empty => const _Message(
              'Registra una medición con tu estatura en Progreso para ver tu cuerpo.',
            ),
          BodyStatus.ready => _BodyContent(state: state),
        },
      ),
    );
  }
}

class _Message extends StatelessWidget {
  const _Message(this.text);

  final String text;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Text(
          text,
          textAlign: TextAlign.center,
          style: theme.textTheme.bodyLarge?.copyWith(color: theme.colorScheme.onSurfaceVariant),
        ),
      ),
    );
  }
}

class _BodyContent extends StatelessWidget {
  const _BodyContent({required this.state});

  final BodyState state;

  @override
  Widget build(BuildContext context) {
    final measurement = state.measurement!;
    final perimeters = state.perimeters;
    return Column(
      children: [
        Expanded(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(Tropical.cardRadius),
              child: BodyViewer(
                sex: state.sex,
                perimetersCm: perimeters,
                heightCm: measurement.heightCm,
                fatPercent: measurement.bodyFatPct,
                showFat: state.showFat,
              ),
            ),
          ),
        ),
        SafeArea(
          top: false,
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const _Controls(),
                const SizedBox(height: 12),
                _MeasuresCard(state: state),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

class _Controls extends StatelessWidget {
  const _Controls();

  @override
  Widget build(BuildContext context) {
    final cubit = context.read<BodyCubit>();
    final state = context.watch<BodyCubit>().state;
    return Row(
      children: [
        Expanded(
          child: SegmentedButton<BodySex>(
            segments: const [
              ButtonSegment(value: BodySex.male, label: Text('Hombre')),
              ButtonSegment(value: BodySex.female, label: Text('Mujer')),
            ],
            selected: {state.sex},
            showSelectedIcon: false,
            onSelectionChanged: (selection) => cubit.setSex(selection.first),
          ),
        ),
        const SizedBox(width: 8),
        FilterChip(
          label: const Text('Grasa'),
          selected: state.showFat,
          onSelected: (_) => cubit.toggleFat(),
        ),
      ],
    );
  }
}

class _MeasuresCard extends StatelessWidget {
  const _MeasuresCard({required this.state});

  final BodyState state;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;
    final measurement = state.measurement!;
    final fat = measurement.bodyFatPct;
    final entries = state.perimeters.entries;
    final known = entries.where((e) => e.value != null);
    final missing = entries.where((e) => e.value == null).map((e) => _labels[e.key]);
    final date = DateFormat('dd/MM/yyyy').format(measurement.date.toUtc());
    return VitalityCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Medición del $date · ${measurement.heightCm.toStringAsFixed(0)} cm'
            '${fat != null ? ' · ${fat.toStringAsFixed(1)} % grasa' : ''}',
            style: theme.textTheme.bodySmall?.copyWith(color: cs.onSurfaceVariant),
          ),
          const SizedBox(height: 8),
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: [
                for (final entry in known)
                  Padding(
                    padding: const EdgeInsets.only(right: 16),
                    child: StatChip(
                      value: entry.value!.toStringAsFixed(1),
                      label: _labels[entry.key]!,
                    ),
                  ),
              ],
            ),
          ),
          if (missing.isNotEmpty) ...[
            const SizedBox(height: 8),
            Text(
              'Sin dato: ${missing.join(', ')}. Esa zona usa el tamaño base del modelo.',
              style: theme.textTheme.bodySmall?.copyWith(color: cs.onSurfaceVariant),
            ),
          ],
        ],
      ),
    );
  }
}
