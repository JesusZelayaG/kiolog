import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:intl/intl.dart';
import 'package:kiolog/core/dao/user_profile_dao.dart';
import 'package:kiolog/core/theme/app_theme.dart';
import 'package:kiolog/shared/widgets/stat_chip.dart';
import 'package:kiolog/shared/widgets/vitality_card.dart';

import '../../../../core/di/injection.dart';
import '../../domain/repositories/progress_repository.dart';
import '../bloc/body_cubit.dart';
import '../widgets/body_viewer.dart';

const _visibleSessions = 2;

String _signed(double change) {
  if (change.abs() < 0.05) return '=';
  final sign = change > 0 ? '+' : '−';
  return '$sign${change.abs().toStringAsFixed(1)}';
}

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
                _SessionSelector(state: state),
                const SizedBox(height: 8),
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

class _SessionSelector extends StatelessWidget {
  const _SessionSelector({required this.state});

  final BodyState state;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final sessions = state.sessions;
    if (sessions.length < 2) {
      return Text(
        'Registra otra consulta para comparar tu cuerpo entre fechas.',
        style: theme.textTheme.bodySmall,
      );
    }
    final format = DateFormat('dd/MM/yy');
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      // Starts at the newest consultation, which is the one selected on entry.
      reverse: sessions.length > _visibleSessions,
      child: Row(
        children: [
          for (var i = 0; i < sessions.length; i++)
            Padding(
              padding: const EdgeInsets.only(right: 8),
              child: ChoiceChip(
                label: Text('${i + 1} · ${format.format(sessions[i].date.toUtc())}'),
                selected: state.selected == i,
                onSelected: (_) => context.read<BodyCubit>().selectSession(i),
              ),
            ),
        ],
      ),
    );
  }
}

class _Controls extends StatelessWidget {
  const _Controls();

  @override
  Widget build(BuildContext context) {
    final cubit = context.read<BodyCubit>();
    final state = context.watch<BodyCubit>().state;
    return Align(
      alignment: Alignment.centerRight,
      child: FilterChip(
        label: const Text('Grasa'),
        selected: state.showFat,
        onSelected: (_) => cubit.toggleFat(),
      ),
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
    final dates = DateFormat('dd/MM/yyyy');
    final date = dates.format(measurement.date.toUtc());
    final previous = state.previous;
    final fatChange = state.fatChange;
    return VitalityCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Medición del $date · ${measurement.heightCm.toStringAsFixed(0)} cm'
            '${fat != null ? ' · ${fat.toStringAsFixed(1)} % grasa' : ''}'
            '${fatChange != null ? ' (${_signed(fatChange)})' : ''}',
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
                    child: Column(
                      children: [
                        StatChip(
                          value: entry.value!.toStringAsFixed(1),
                          label: _labels[entry.key]!,
                        ),
                        if (state.changeIn(entry.key) case final change?)
                          Text(_signed(change), style: theme.textTheme.labelMedium),
                      ],
                    ),
                  ),
              ],
            ),
          ),
          if (previous != null) ...[
            const SizedBox(height: 8),
            Text(
              'Cambios en cm frente al ${dates.format(previous.date.toUtc())}.',
              style: theme.textTheme.bodySmall,
            ),
          ],
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
