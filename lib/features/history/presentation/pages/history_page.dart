import 'package:flutter/material.dart';
import 'package:kiolog/core/theme/app_theme.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import '../../../../core/di/injection.dart';
import '../../domain/repositories/history_repository.dart';
import '../bloc/history_bloc.dart';
import '../bloc/history_event.dart';
import '../bloc/history_state.dart';

class HistoryPage extends StatelessWidget {
  const HistoryPage({super.key});

  @override
  Widget build(BuildContext context) {
    return BlocProvider(
      create: (_) => HistoryBloc(getIt<HistoryRepository>())
        ..add(HistoryMonthLoaded(month: DateTime.now())),
      child: const _HistoryView(),
    );
  }
}

class _HistoryView extends StatelessWidget {
  const _HistoryView();

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Historial'),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => context.canPop() ? context.pop() : context.go('/'),
        ),
      ),
      body: BlocBuilder<HistoryBloc, HistoryState>(
        builder: (context, state) {
          if (state.status == HistoryStatus.loading && state.days.isEmpty) {
            return const Center(child: CircularProgressIndicator());
          }
          if (state.status == HistoryStatus.failure) {
            return Center(child: Text('Error: ${state.error}'));
          }

          return SafeArea(
            child: Column(
              children: [
                Padding(
                  padding: const EdgeInsets.all(16),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      IconButton(
                        icon: const Icon(Icons.chevron_left),
                        onPressed: () => context
                            .read<HistoryBloc>()
                            .add(const HistoryPreviousMonth()),
                      ),
                      Text(
                        DateFormat.yMMMM('es').format(state.currentMonth),
                        style: Theme.of(context).textTheme.titleLarge,
                      ),
                      IconButton(
                        icon: const Icon(Icons.chevron_right),
                        onPressed: () => context
                            .read<HistoryBloc>()
                            .add(const HistoryNextMonth()),
                      ),
                    ],
                  ),
                ),
                Expanded(
                  child: GridView.builder(
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    gridDelegate:
                        const SliverGridDelegateWithFixedCrossAxisCount(
                      crossAxisCount: 7,
                      childAspectRatio: 0.85,
                    ),
                    itemCount: state.days.length,
                    itemBuilder: (context, index) {
                      final day = state.days[index];
                      return _DayCell(day: day);
                    },
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
                  child: _ComplianceSection(compliance: state.compliance),
                ),
              ],
            ),
          );
        },
      ),
    );
  }
}

class _DayCell extends StatelessWidget {
  final DaySummary day;

  const _DayCell({required this.day});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return GestureDetector(
      onTap: () {
        final dateStr = DateFormat('yyyy-MM-dd').format(day.date);
        context.push('/history/day/$dateStr');
      },
      child: Card(
        margin: const EdgeInsets.all(2),
        color: day.shownCompletedCount == 3
            ? theme.colorScheme.primaryContainer
            : theme.colorScheme.surfaceContainerHighest.withValues(alpha: 0.3),
        child: Padding(
          padding: const EdgeInsets.all(4),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text(
                '${day.date.day}',
                style: theme.textTheme.bodySmall?.copyWith(
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 4),
              Wrap(
                spacing: 2,
                runSpacing: 2,
                alignment: WrapAlignment.center,
                children: [
                  if (day.hasWater) _MiniDot(color: context.kc.waterInk),
                  if (day.hasMeals) _MiniDot(color: context.kc.foodAccent),
                  if (day.hasExercise) _MiniDot(color: context.kc.gymInk),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _MiniDot extends StatelessWidget {
  final Color color;

  const _MiniDot({required this.color});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 6,
      height: 6,
      decoration: BoxDecoration(
        color: color,
        shape: BoxShape.circle,
      ),
    );
  }
}

class _ComplianceSection extends StatelessWidget {
  final MonthCompliance compliance;

  const _ComplianceSection({required this.compliance});

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Cumplimiento del mes',
              style: Theme.of(context).textTheme.labelSmall?.copyWith(
                    color: Theme.of(context).colorScheme.onSurfaceVariant,
                    letterSpacing: 0.5,
                  ),
            ),
            const SizedBox(height: 10),
            _SegmentRow(
              icon: '💧',
              iconBackground: context.kc.waterWash,
              label: 'Agua',
              value: compliance.water,
              barColor: context.kc.waterInk,
              valueColor: context.kc.waterInk,
            ),
            const SizedBox(height: 8),
            _SegmentRow(
              icon: '🍽️',
              iconBackground: context.kc.foodWash,
              label: 'Comida',
              value: compliance.meals,
              barColor: context.kc.foodAccent,
              valueColor: context.kc.foodInk,
            ),
            const SizedBox(height: 8),
            _SegmentRow(
              icon: '🏋️',
              iconBackground: context.kc.gymWash,
              label: 'Ejercicio',
              value: compliance.exercise,
              barColor: context.kc.gymInk,
              valueColor: context.kc.gymInk,
            ),
          ],
        ),
      ),
    );
  }
}

class _SegmentRow extends StatelessWidget {
  final String icon;
  final Color iconBackground;
  final String label;
  final double value;
  final Color barColor;
  final Color valueColor;

  const _SegmentRow({
    required this.icon,
    required this.iconBackground,
    required this.label,
    required this.value,
    required this.barColor,
    required this.valueColor,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final pct = (value * 100).round();

    return Row(
      children: [
        Container(
          width: 24,
          height: 24,
          decoration: BoxDecoration(
            color: iconBackground,
            borderRadius: BorderRadius.circular(6),
          ),
          child: Center(
            child: Text(icon, style: const TextStyle(fontSize: 13)),
          ),
        ),
        const SizedBox(width: 8),
        SizedBox(
          width: 60,
          child: Text(label, style: theme.textTheme.bodySmall),
        ),
        Expanded(
          child: ClipRRect(
            borderRadius: BorderRadius.circular(100),
            child: LinearProgressIndicator(
              value: value,
              minHeight: 6,
              backgroundColor: theme.colorScheme.surfaceContainerHighest,
              valueColor: AlwaysStoppedAnimation<Color>(barColor),
            ),
          ),
        ),
        const SizedBox(width: 8),
        SizedBox(
          width: 32,
          child: Text(
            '$pct%',
            textAlign: TextAlign.right,
            style: theme.textTheme.bodySmall?.copyWith(
              fontWeight: FontWeight.w700,
              color: valueColor,
            ),
          ),
        ),
      ],
    );
  }
}
