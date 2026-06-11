import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import '../../../../core/di/injection.dart';
import '../../../../core/database/app_database.dart';
import '../../domain/repositories/sleep_repository.dart';
import '../bloc/sleep_bloc.dart';
import '../bloc/sleep_event.dart';
import '../bloc/sleep_state.dart';

class SleepPage extends StatelessWidget {
  const SleepPage({super.key});

  @override
  Widget build(BuildContext context) {
    return BlocProvider(
      create: (_) => SleepBloc(getIt<SleepRepository>())
        ..add(SleepLoaded(date: DateTime.now()))
        ..add(SleepWeeklyLoaded(endDate: DateTime.now())),
      child: const _SleepView(),
    );
  }
}

class _SleepView extends StatelessWidget {
  const _SleepView();

  static bool _isSameDay(DateTime a, DateTime b) =>
      a.year == b.year && a.month == b.month && a.day == b.day;

  SleepLog? _logForDay(List<SleepLog> logs, DateTime day) {
    final matches = logs.where((l) => _isSameDay(l.date, day));
    return matches.isEmpty ? null : matches.first;
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Sueño'),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new),
          onPressed: () => context.go('/'),
        ),
      ),
      body: BlocBuilder<SleepBloc, SleepState>(
        builder: (context, state) {
          if (state.status == SleepStatus.loading && state.weeklyLogs.isEmpty) {
            return const Center(child: CircularProgressIndicator());
          }
          if (state.status == SleepStatus.failure) {
            return Center(child: Text('Error: ${state.error}'));
          }

          final log = state.todayLog;
          final hours = log?.hoursCalculated ?? 0.0;
          final progress = (hours / 8.0).clamp(0.0, 1.0);
          final hoursLabel = log != null
              ? log.hoursCalculated.toStringAsFixed(1)
              : '--';

          return SafeArea(
            child: SingleChildScrollView(
              padding: const EdgeInsets.fromLTRB(24, 16, 24, 32),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  Text(
                    'SEGUIMIENTO DE SUEÑO',
                    style: theme.textTheme.labelSmall?.copyWith(
                      color: cs.primary,
                    ),
                  ),
                  const SizedBox(height: 32),

                  // Circular progress
                  SizedBox(
                    height: 200,
                    width: 200,
                    child: Stack(
                      fit: StackFit.expand,
                      children: [
                        CircularProgressIndicator(
                          value: progress,
                          strokeWidth: 14,
                          strokeCap: StrokeCap.round,
                          backgroundColor:
                              cs.primaryContainer.withValues(alpha: 0.25),
                        ),
                        Center(
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(
                                Icons.nightlight_round,
                                size: 40,
                                color: cs.primary,
                              ),
                              const SizedBox(height: 6),
                              Text(
                                '$hoursLabel h',
                                style: theme.textTheme.headlineMedium?.copyWith(
                                  fontWeight: FontWeight.bold,
                                  color: cs.onSurface,
                                ),
                              ),
                              if (log != null)
                                Text(
                                  '${DateFormat.Hm().format(log.sleepTime)} – ${DateFormat.Hm().format(log.wakeTime)}',
                                  style: theme.textTheme.bodySmall?.copyWith(
                                    color: cs.onSurfaceVariant,
                                  ),
                                )
                              else
                                Text(
                                  'No registrado',
                                  style: theme.textTheme.bodySmall?.copyWith(
                                    color: cs.onSurfaceVariant,
                                  ),
                                ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 12),

                  Text(
                    'OBJETIVO: 8H',
                    style: theme.textTheme.labelSmall?.copyWith(
                      color: cs.primary,
                    ),
                  ),

                  if (log == null) ...[
                    const SizedBox(height: 16),
                    Text(
                      '"El descanso es la base de la vitalidad.\nComienza tu registro hoy."',
                      textAlign: TextAlign.center,
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: cs.onSurfaceVariant,
                        fontStyle: FontStyle.italic,
                      ),
                    ),
                  ],

                  const SizedBox(height: 32),

                  // Weekly chart card
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(20),
                    decoration: BoxDecoration(
                      color: cs.surfaceContainerHigh,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Text(
                              'Últimos 7 días',
                              style: theme.textTheme.labelLarge?.copyWith(
                                color: cs.onSurface,
                              ),
                            ),
                            const Spacer(),
                            if (state.weeklyAverage != null)
                              Text(
                                'Prom: ${state.weeklyAverage!.toStringAsFixed(1)} h',
                                style: theme.textTheme.bodySmall?.copyWith(
                                  color: cs.primary,
                                ),
                              ),
                          ],
                        ),
                        const SizedBox(height: 20),
                        _WeeklyChart(
                          weeklyLogs: state.weeklyLogs,
                          logForDay: _logForDay,
                        ),
                        if (state.weeklyLogs.isEmpty) ...[
                          const SizedBox(height: 12),
                          Center(
                            child: Text(
                              'Sin registros esta semana',
                              style: theme.textTheme.bodySmall?.copyWith(
                                color: cs.onSurfaceVariant,
                              ),
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),

                  const SizedBox(height: 32),

                  // Register button
                  SizedBox(
                    width: double.infinity,
                    height: 52,
                    child: ElevatedButton.icon(
                      style: ElevatedButton.styleFrom(
                        shape: const StadiumBorder(),
                        backgroundColor: cs.primary,
                        foregroundColor: cs.onPrimary,
                      ),
                      onPressed: () => _showAddSleepDialog(context),
                      icon: const Icon(Icons.bedtime_outlined),
                      label: const Text('Registrar sueño'),
                    ),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  void _showAddSleepDialog(BuildContext context) {
    final controller = TextEditingController();
    final theme = Theme.of(context);
    final today = DateTime.now();

    showDialog(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text(
          'Registrar sueño',
          style: TextStyle(color: theme.colorScheme.onSurface),
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Fecha: ${DateFormat('dd/MM/yyyy').format(today)}',
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: controller,
              keyboardType: const TextInputType.numberWithOptions(decimal: true),
              autofocus: true,
              decoration: const InputDecoration(
                labelText: 'Horas dormidas',
                suffixText: 'h',
                hintText: 'Ej: 7.5',
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: const Text('Cancelar'),
          ),
          ElevatedButton(
            onPressed: () {
              final hours = double.tryParse(controller.text.replaceAll(',', '.'));
              if (hours != null && hours > 0 && hours <= 24) {
                final wakeTime = today;
                final sleepTime = wakeTime.subtract(
                  Duration(minutes: (hours * 60).round()),
                );
                context.read<SleepBloc>().add(
                      SleepLogAdded(
                        date: today,
                        sleepTime: sleepTime,
                        wakeTime: wakeTime,
                        type: 'main',
                      ),
                    );
                Navigator.pop(dialogContext);
              }
            },
            child: const Text('Guardar'),
          ),
        ],
      ),
    );
  }
}

class _WeeklyChart extends StatelessWidget {
  final List<SleepLog> weeklyLogs;
  final SleepLog? Function(List<SleepLog>, DateTime) logForDay;

  const _WeeklyChart({
    required this.weeklyLogs,
    required this.logForDay,
  });

  Color _barColor(BuildContext context, double hours) {
    final cs = Theme.of(context).colorScheme;
    if (hours >= 7) return cs.primary;
    if (hours >= 5) return Colors.amber;
    return cs.error;
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;
    final days = List.generate(
      7,
      (i) => DateTime.now().subtract(Duration(days: 6 - i)),
    );
    const maxH = 10.0;
    const chartHeight = 80.0;

    return SizedBox(
      height: chartHeight + 36,
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.end,
        children: days.map((day) {
          final log = logForDay(weeklyLogs, day);
          final h = log?.hoursCalculated ?? 0.0;
          final barH = log != null
              ? ((h / maxH).clamp(0.0, 1.0) * chartHeight).clamp(4.0, chartHeight)
              : 4.0;
          final dayLabel =
              DateFormat.E('es').format(day).substring(0, 2).toUpperCase();
          final isToday = _SleepView._isSameDay(day, DateTime.now());

          return Expanded(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                if (log != null)
                  Text(
                    '${h.toStringAsFixed(0)}h',
                    style: theme.textTheme.labelSmall?.copyWith(
                      color: _barColor(context, h),
                      fontSize: 9,
                    ),
                  )
                else
                  const SizedBox(height: 14),
                const SizedBox(height: 2),
                Container(
                  height: barH,
                  margin: const EdgeInsets.symmetric(horizontal: 3),
                  decoration: BoxDecoration(
                    color: log != null
                        ? _barColor(context, h)
                        : cs.surfaceContainerHighest,
                    borderRadius: const BorderRadius.vertical(
                      top: Radius.circular(4),
                    ),
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  dayLabel,
                  style: theme.textTheme.labelSmall?.copyWith(
                    color: isToday ? cs.primary : cs.onSurfaceVariant,
                    fontWeight:
                        isToday ? FontWeight.bold : FontWeight.normal,
                    fontSize: 10,
                  ),
                ),
              ],
            ),
          );
        }).toList(),
      ),
    );
  }
}
