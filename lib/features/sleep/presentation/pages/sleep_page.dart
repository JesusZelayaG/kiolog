import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import '../../../../core/dao/user_profile_dao.dart';
import '../../../../core/database/app_database.dart';
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

  static bool _isSameDay(DateTime a, DateTime b) =>
      a.year == b.year && a.month == b.month && a.day == b.day;

  double _totalHoursForDay(List<SleepLog> weeklyLogs, DateTime day) =>
      weeklyLogs
          .where((l) => _isSameDay(l.date, day))
          .fold(0.0, (s, l) => s + l.hoursCalculated);

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

          final progress = (state.totalHours / 8.0).clamp(0.0, 1.0);
          final hoursLabel = state.totalHours > 0
              ? state.totalHours.toStringAsFixed(1)
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
                              Icon(Icons.nightlight_round,
                                  size: 40, color: cs.primary),
                              const SizedBox(height: 6),
                              Text(
                                '$hoursLabel h',
                                style: theme.textTheme.headlineMedium?.copyWith(
                                  fontWeight: FontWeight.bold,
                                  color: cs.onSurface,
                                ),
                              ),
                              if (state.totalHours > 0)
                                Text(
                                  'Sueño ${state.mainSleepHours.toStringAsFixed(1)}h · Siestas ${state.napHours.toStringAsFixed(1)}h',
                                  style: theme.textTheme.bodySmall?.copyWith(
                                    color: cs.onSurfaceVariant,
                                    fontSize: 10,
                                  ),
                                  textAlign: TextAlign.center,
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

                  if (state.todayLogs.isEmpty) ...[
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

                  if (state.todayLogs.isNotEmpty) ...[
                    const SizedBox(height: 16),
                    ...state.todayLogs.map((log) => _SleepLogTile(log: log)),
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
                          totalHoursForDay: _totalHoursForDay,
                          isSameDay: _isSameDay,
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

  Future<void> _showAddSleepDialog(BuildContext context) async {
    final profile = await getIt<UserProfileDao>().getProfile();
    final firstDate = profile?.registrationDate ?? DateTime(2020, 1, 1);
    if (!context.mounted) return;
    showDialog(
      context: context,
      builder: (_) => _SleepLogDialog(
        firstDate: firstDate,
        onSave: (date, sleepTime, wakeTime, type) {
          if (!context.mounted) return;
          context.read<SleepBloc>().add(SleepLogAdded(
                date: date,
                sleepTime: sleepTime,
                wakeTime: wakeTime,
                type: type,
              ));
        },
      ),
    );
  }
}

// ── Log tile ─────────────────────────────────────────────────────────────────

class _SleepLogTile extends StatelessWidget {
  final SleepLog log;
  const _SleepLogTile({required this.log});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;
    final isMain = log.type == 'main';

    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        decoration: BoxDecoration(
          color: cs.surfaceContainerHigh,
          borderRadius: BorderRadius.circular(10),
        ),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
              decoration: BoxDecoration(
                color: isMain
                    ? const Color(0xFF2E7D68).withValues(alpha: 0.2)
                    : Colors.amber.withValues(alpha: 0.2),
                borderRadius: BorderRadius.circular(4),
              ),
              child: Text(
                isMain ? 'PRINCIPAL' : 'SIESTA',
                style: TextStyle(
                  fontSize: 10,
                  fontWeight: FontWeight.bold,
                  color: isMain ? const Color(0xFF2E7D68) : Colors.amber,
                ),
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                '${DateFormat.Hm().format(log.sleepTime)} – ${DateFormat.Hm().format(log.wakeTime)}  ·  ${log.hoursCalculated.toStringAsFixed(1)}h',
                style: theme.textTheme.bodySmall?.copyWith(color: cs.onSurface),
              ),
            ),
            IconButton(
              icon: Icon(Icons.delete_outline,
                  size: 18, color: cs.onSurfaceVariant),
              onPressed: () => context.read<SleepBloc>().add(
                    SleepLogDeleted(id: log.id, date: log.date),
                  ),
              visualDensity: VisualDensity.compact,
              padding: EdgeInsets.zero,
            ),
          ],
        ),
      ),
    );
  }
}

// ── Add dialog ────────────────────────────────────────────────────────────────

class _SleepLogDialog extends StatefulWidget {
  final DateTime firstDate;
  final void Function(
      DateTime date, DateTime sleepTime, DateTime wakeTime, String type) onSave;

  const _SleepLogDialog({required this.firstDate, required this.onSave});

  @override
  State<_SleepLogDialog> createState() => _SleepLogDialogState();
}

class _SleepLogDialogState extends State<_SleepLogDialog> {
  String _type = 'main';
  DateTime? _date;
  TimeOfDay? _sleepTime;
  TimeOfDay? _wakeTime;

  bool get _canSave =>
      _date != null && _sleepTime != null && _wakeTime != null;

  bool get _isNextDay =>
      _sleepTime != null &&
      _wakeTime != null &&
      (_wakeTime!.hour < _sleepTime!.hour ||
          (_wakeTime!.hour == _sleepTime!.hour &&
              _wakeTime!.minute < _sleepTime!.minute));

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;

    return AlertDialog(
      title: Text(
        'Registrar sueño',
        style: TextStyle(color: cs.onSurface),
      ),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            SegmentedButton<String>(
              segments: const [
                ButtonSegment(
                    value: 'main',
                    label: Text('Principal'),
                    icon: Icon(Icons.nightlight_round, size: 16)),
                ButtonSegment(
                    value: 'nap',
                    label: Text('Siesta'),
                    icon: Icon(Icons.wb_twilight, size: 16)),
              ],
              selected: {_type},
              onSelectionChanged: (s) => setState(() => _type = s.first),
            ),
            const SizedBox(height: 8),
            ListTile(
              contentPadding: EdgeInsets.zero,
              leading: const Icon(Icons.calendar_today_outlined),
              title: const Text('Fecha'),
              subtitle: Text(
                _date != null
                    ? DateFormat('dd/MM/yyyy').format(_date!)
                    : 'Seleccionar',
              ),
              onTap: () async {
                final now = DateTime.now();
                final picked = await showDatePicker(
                  context: context,
                  initialDate: now,
                  firstDate: widget.firstDate,
                  lastDate: now,
                );
                if (picked != null) setState(() => _date = picked);
              },
            ),
            ListTile(
              contentPadding: EdgeInsets.zero,
              leading: const Icon(Icons.bedtime_outlined),
              title: const Text('Hora de dormir'),
              subtitle: Text(_sleepTime?.format(context) ?? 'Seleccionar'),
              onTap: () async {
                final t = await showTimePicker(
                  context: context,
                  initialTime: const TimeOfDay(hour: 22, minute: 0),
                );
                if (t != null) setState(() => _sleepTime = t);
              },
            ),
            ListTile(
              contentPadding: EdgeInsets.zero,
              leading: const Icon(Icons.wb_sunny_outlined),
              title: const Text('Hora de despertar'),
              subtitle: Row(
                children: [
                  Text(_wakeTime?.format(context) ?? 'Seleccionar'),
                  if (_isNextDay) ...[
                    const SizedBox(width: 6),
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 6, vertical: 2),
                      decoration: BoxDecoration(
                        color: cs.primaryContainer,
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: Text(
                        '+1d',
                        style: TextStyle(
                            fontSize: 11, color: cs.onPrimaryContainer),
                      ),
                    ),
                  ],
                ],
              ),
              onTap: () async {
                final t = await showTimePicker(
                  context: context,
                  initialTime: const TimeOfDay(hour: 7, minute: 0),
                );
                if (t != null) setState(() => _wakeTime = t);
              },
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Cancelar'),
        ),
        ElevatedButton(
          onPressed: _canSave
              ? () {
                  final sleepDt = DateTime(
                    _date!.year,
                    _date!.month,
                    _date!.day,
                    _sleepTime!.hour,
                    _sleepTime!.minute,
                  );
                  final rawWake = DateTime(
                    _date!.year,
                    _date!.month,
                    _date!.day,
                    _wakeTime!.hour,
                    _wakeTime!.minute,
                  );
                  final wakeDt = rawWake.isBefore(sleepDt)
                      ? rawWake.add(const Duration(days: 1))
                      : rawWake;
                  if (!wakeDt.isAfter(sleepDt)) return;
                  widget.onSave(_date!, sleepDt, wakeDt, _type);
                  Navigator.pop(context);
                }
              : null,
          child: const Text('Guardar'),
        ),
      ],
    );
  }
}

// ── Weekly chart ──────────────────────────────────────────────────────────────

class _WeeklyChart extends StatelessWidget {
  final List<SleepLog> weeklyLogs;
  final double Function(List<SleepLog>, DateTime) totalHoursForDay;
  final bool Function(DateTime, DateTime) isSameDay;

  const _WeeklyChart({
    required this.weeklyLogs,
    required this.totalHoursForDay,
    required this.isSameDay,
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
          final h = totalHoursForDay(weeklyLogs, day);
          final hasLog = h > 0;
          final barH = hasLog
              ? ((h / maxH).clamp(0.0, 1.0) * chartHeight)
                  .clamp(4.0, chartHeight)
              : 4.0;
          final dayLabel = DateFormat.E('es')
              .format(day)
              .substring(0, 2)
              .toUpperCase();
          final isToday = isSameDay(day, DateTime.now());

          return Expanded(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                if (hasLog)
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
                    color: hasLog
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
