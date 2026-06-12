import 'package:collection/collection.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:intl/intl.dart';
import '../../../../core/di/injection.dart';
import '../../../../core/dao/exercise_dao.dart';
import '../../../../core/dao/nutrition_dao.dart';
import '../../../../core/dao/water_sleep_dao.dart';
import '../bloc/day_detail_bloc.dart';
import '../bloc/day_detail_event.dart';
import '../bloc/day_detail_state.dart';

class DayDetailPage extends StatelessWidget {
  final DateTime date;

  const DayDetailPage({super.key, required this.date});

  @override
  Widget build(BuildContext context) {
    return BlocProvider(
      create: (_) => DayDetailBloc(
        getIt<WaterSleepDao>(),
        getIt<NutritionDao>(),
        getIt<ExerciseDao>(),
      )..add(DayDetailLoaded(date: date)),
      child: _DayDetailView(date: date),
    );
  }
}

class _DayDetailView extends StatelessWidget {
  final DateTime date;

  const _DayDetailView({required this.date});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final title = DateFormat('EEEE d MMM yyyy', 'es').format(date);

    return Scaffold(
      appBar: AppBar(
        title: Text(title),
      ),
      body: BlocBuilder<DayDetailBloc, DayDetailState>(
        builder: (context, state) {
          if (state.status == DayDetailStatus.loading ||
              state.status == DayDetailStatus.initial) {
            return const Center(child: CircularProgressIndicator());
          }
          if (state.status == DayDetailStatus.failure) {
            return Center(child: Text('Error: ${state.error}'));
          }

          return ListView(
            padding: const EdgeInsets.all(16),
            children: [
              Padding(
                padding: const EdgeInsets.only(bottom: 12),
                child: Text(
                  '${state.completedSegments} de 3 segmentos con registro',
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                ),
              ),
              _SegmentCard(
                icon: '💧',
                iconBackground: const Color(0xFF1E3A5F),
                title: 'Agua',
                accentColor: const Color(0xFF60A5FA),
                hasData: state.hasWater,
                child: _WaterContent(state: state),
              ),
              const SizedBox(height: 8),
              _SegmentCard(
                icon: '🍽️',
                iconBackground: const Color(0xFF3D2000),
                title: 'Nutrición',
                accentColor: const Color(0xFFFB923C),
                hasData: state.hasMeals,
                child: _NutritionContent(state: state),
              ),
              const SizedBox(height: 8),
              _SegmentCard(
                icon: '🏋️',
                iconBackground: const Color(0xFF3D0A0A),
                title: 'Ejercicio',
                accentColor: const Color(0xFFF87171),
                hasData: state.hasExercise,
                child: _ExerciseContent(state: state),
              ),
            ],
          );
        },
      ),
    );
  }
}

class _SegmentCard extends StatelessWidget {
  final String icon;
  final Color iconBackground;
  final String title;
  final Color accentColor;
  final bool hasData;
  final Widget child;

  const _SegmentCard({
    required this.icon,
    required this.iconBackground,
    required this.title,
    required this.accentColor,
    required this.hasData,
    required this.child,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Row(
                  children: [
                    Container(
                      width: 28,
                      height: 28,
                      decoration: BoxDecoration(
                        color: iconBackground,
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Center(
                          child: Text(icon,
                              style: const TextStyle(fontSize: 14))),
                    ),
                    const SizedBox(width: 8),
                    Text(title,
                        style: theme.textTheme.bodyMedium
                            ?.copyWith(fontWeight: FontWeight.w600)),
                  ],
                ),
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                  decoration: BoxDecoration(
                    color: hasData
                        ? const Color(0xFF1A3D27)
                        : theme.colorScheme.surfaceContainerHighest,
                    borderRadius: BorderRadius.circular(99),
                  ),
                  child: Text(
                    hasData ? 'Cumplido' : 'Sin registro',
                    style: theme.textTheme.labelSmall?.copyWith(
                      color: hasData
                          ? const Color(0xFF4BE277)
                          : theme.colorScheme.onSurfaceVariant,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ],
            ),
            const Divider(height: 20),
            child,
          ],
        ),
      ),
    );
  }
}

class _WaterContent extends StatelessWidget {
  final DayDetailState state;

  const _WaterContent({required this.state});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    if (!state.hasWater) {
      return const _EmptyNote(text: 'No hay tomas registradas');
    }
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text('Total del día', style: theme.textTheme.bodySmall),
            Text(
              '${state.totalWaterMl} ml',
              style: theme.textTheme.bodySmall?.copyWith(
                fontWeight: FontWeight.w700,
                color: const Color(0xFF60A5FA),
              ),
            ),
          ],
        ),
        const SizedBox(height: 6),
        Wrap(
          spacing: 6,
          runSpacing: 4,
          children: state.waterLogs.map((log) {
            final time = DateFormat('HH:mm').format(log.timestamp.toLocal());
            return Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
              decoration: BoxDecoration(
                color: const Color(0xFF1E3A5F),
                borderRadius: BorderRadius.circular(6),
              ),
              child: Text(
                '$time · ${log.amountMl} ml',
                style: theme.textTheme.labelSmall?.copyWith(
                  color: const Color(0xFF93C5FD),
                ),
              ),
            );
          }).toList(),
        ),
      ],
    );
  }
}

class _NutritionContent extends StatelessWidget {
  final DayDetailState state;

  const _NutritionContent({required this.state});

  static const _mealOrder = ['breakfast', 'lunch', 'dinner', 'snack'];
  static const _mealLabel = {
    'breakfast': 'Desayuno',
    'lunch': 'Almuerzo',
    'dinner': 'Cena',
    'snack': 'Snack',
  };

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    if (!state.hasMeals) {
      return const _EmptyNote(text: 'No hay comidas registradas');
    }
    return Column(
      children: _mealOrder.map((type) {
        final log = state.mealLogs
            .where((l) => l.mealType == type)
            .firstOrNull;
        final label = _mealLabel[type]!;
        String value;
        if (log == null) {
          value = '—';
        } else if (log.planOptionId != null &&
            state.mealOptions.containsKey(log.planOptionId)) {
          value =
              'Opción ${state.mealOptions[log.planOptionId!]!.optionNumber}';
        } else if (log.freeDescription != null) {
          value = log.freeDescription!;
        } else {
          value = 'Registrado';
        }
        return Padding(
          padding: const EdgeInsets.symmetric(vertical: 3),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(label, style: theme.textTheme.bodySmall),
              Text(
                value,
                style: theme.textTheme.bodySmall?.copyWith(
                  fontWeight: FontWeight.w600,
                  color: log != null
                      ? const Color(0xFFFB923C)
                      : theme.colorScheme.onSurfaceVariant,
                ),
              ),
            ],
          ),
        );
      }).toList(),
    );
  }
}

class _ExerciseContent extends StatelessWidget {
  final DayDetailState state;

  const _ExerciseContent({required this.state});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    if (!state.hasExercise) {
      return const _EmptyNote(text: 'No hay sesiones registradas este día');
    }

    if (state.exerciseSessions.isEmpty &&
        (state.exerciseLog?.completed ?? false)) {
      return Text(
        'Ejercicio completado sin sesión registrada',
        style: theme.textTheme.bodySmall,
      );
    }

    return Column(
      children: state.exerciseSessions.asMap().entries.map((entry) {
        final i = entry.key;
        final session = entry.value;
        final arrived =
            DateFormat('HH:mm').format(session.gymArrivedAt.toLocal());
        final left = session.gymLeftAt != null
            ? DateFormat('HH:mm').format(session.gymLeftAt!.toLocal())
            : 'En curso';
        return Padding(
          padding: const EdgeInsets.symmetric(vertical: 3),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text('Sesión ${i + 1}', style: theme.textTheme.bodySmall),
              Text(
                '$arrived – $left',
                style: theme.textTheme.bodySmall?.copyWith(
                  fontWeight: FontWeight.w600,
                  color: const Color(0xFFF87171),
                ),
              ),
            ],
          ),
        );
      }).toList(),
    );
  }
}

class _EmptyNote extends StatelessWidget {
  final String text;

  const _EmptyNote({required this.text});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 4),
        child: Text(
          text,
          style: Theme.of(context).textTheme.bodySmall?.copyWith(
                fontStyle: FontStyle.italic,
                color: Theme.of(context).colorScheme.onSurfaceVariant,
              ),
        ),
      ),
    );
  }
}
