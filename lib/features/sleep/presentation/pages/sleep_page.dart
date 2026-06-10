import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:kiolog/shared/widgets/vitality_card.dart';
import '../../../../core/di/injection.dart';
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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Sueño'),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
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

          return SafeArea(
            child: ListView(
              padding: const EdgeInsets.all(16),
              children: [
                _buildTodayCard(context, state),
                const SizedBox(height: 16),
                _buildWeeklyCard(context, state),
                const SizedBox(height: 16),
                ElevatedButton.icon(
                  onPressed: () => _showAddSleepDialog(context),
                  icon: const Icon(Icons.bedtime_outlined),
                  label: const Text('Registrar sueño'),
                ),
              ],
            ),
          );
        },
      ),
    );
  }

  Widget _buildTodayCard(BuildContext context, SleepState state) {
    final log = state.todayLog;
    final hours = log?.hoursCalculated.toStringAsFixed(1) ?? '--';
    final theme = Theme.of(context);

    return VitalityCard(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Hoy', style: theme.textTheme.titleMedium),
          const SizedBox(height: 12),
          Row(
            children: [
              Icon(
                Icons.nightlight_round,
                size: 40,
                color: theme.colorScheme.primary,
              ),
              const SizedBox(width: 16),
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    '$hours h',
                    style: theme.textTheme.headlineSmall?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  if (log != null)
                    Text(
                      '${DateFormat.Hm().format(log.sleepTime)} – ${DateFormat.Hm().format(log.wakeTime)}',
                      style: theme.textTheme.bodyMedium?.copyWith(
                        color: theme.colorScheme.onSurfaceVariant,
                      ),
                    )
                  else
                    Text(
                      'No registrado',
                      style: theme.textTheme.bodyMedium?.copyWith(
                        color: theme.colorScheme.onSurfaceVariant,
                      ),
                    ),
                ],
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildWeeklyCard(BuildContext context, SleepState state) {
    final theme = Theme.of(context);
    final avg = state.weeklyAverage?.toStringAsFixed(1) ?? '--';

    return VitalityCard(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Últimos 7 días', style: theme.textTheme.titleMedium),
          const SizedBox(height: 8),
          Text('Promedio: $avg h/noche', style: theme.textTheme.bodyLarge),
          const SizedBox(height: 12),
          if (state.weeklyLogs.isEmpty)
            const Text('Sin registros esta semana')
          else
            ...state.weeklyLogs.map((log) {
              final day = DateFormat.E('es').format(log.date);
              return ListTile(
                dense: true,
                contentPadding: EdgeInsets.zero,
                leading: Text(day),
                title: Text('${log.hoursCalculated.toStringAsFixed(1)} h'),
                trailing: Text(
                  '${DateFormat.Hm().format(log.sleepTime)} – ${DateFormat.Hm().format(log.wakeTime)}',
                ),
              );
            }),
        ],
      ),
    );
  }

  void _showAddSleepDialog(BuildContext context) {
    DateTime? sleepTime;
    DateTime? wakeTime;

    showDialog(
      context: context,
      builder: (dialogContext) => StatefulBuilder(
        builder: (context, setDialogState) {
          return AlertDialog(
            title: const Text('Registrar sueño'),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                ListTile(
                  leading: const Icon(Icons.bedtime_outlined),
                  title: const Text('Hora de dormir'),
                  subtitle: Text(
                    sleepTime != null
                        ? DateFormat('dd/MM HH:mm').format(sleepTime!)
                        : 'Seleccionar',
                  ),
                  onTap: () async {
                    final now = DateTime.now();
                    final time = await showTimePicker(
                      context: dialogContext,
                      initialTime: TimeOfDay.fromDateTime(
                        now.subtract(const Duration(hours: 8)),
                      ),
                    );
                    if (time != null) {
                      setDialogState(() {
                        sleepTime = DateTime(
                          now.year,
                          now.month,
                          now.day,
                          time.hour,
                          time.minute,
                        );
                      });
                    }
                  },
                ),
                ListTile(
                  leading: const Icon(Icons.wb_sunny_outlined),
                  title: const Text('Hora de despertar'),
                  subtitle: Text(
                    wakeTime != null
                        ? DateFormat('dd/MM HH:mm').format(wakeTime!)
                        : 'Seleccionar',
                  ),
                  onTap: () async {
                    final now = DateTime.now();
                    final time = await showTimePicker(
                      context: dialogContext,
                      initialTime: TimeOfDay.fromDateTime(now),
                    );
                    if (time != null) {
                      setDialogState(() {
                        wakeTime = DateTime(
                          now.year,
                          now.month,
                          now.day,
                          time.hour,
                          time.minute,
                        );
                      });
                    }
                  },
                ),
              ],
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(dialogContext),
                child: const Text('Cancelar'),
              ),
              ElevatedButton(
                onPressed: (sleepTime != null && wakeTime != null)
                    ? () {
                        // Adjust if wakeTime is before sleepTime (next day)
                        var adjustedWake = wakeTime!;
                        if (adjustedWake.isBefore(sleepTime!)) {
                          adjustedWake =
                              adjustedWake.add(const Duration(days: 1));
                        }
                        context.read<SleepBloc>().add(
                              SleepLogAdded(
                                date: DateTime.now(),
                                sleepTime: sleepTime!,
                                wakeTime: adjustedWake,
                              ),
                            );
                        Navigator.pop(dialogContext);
                      }
                    : null,
                child: const Text('Guardar'),
              ),
            ],
          );
        },
      ),
    );
  }
}
