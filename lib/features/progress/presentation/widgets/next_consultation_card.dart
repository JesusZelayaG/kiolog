import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:kiolog/core/dao/user_profile_dao.dart';
import 'package:kiolog/core/di/injection.dart';
import 'package:kiolog/core/notifications/consultation_reminders.dart';
import 'package:kiolog/core/notifications/notification_service.dart';
import 'package:kiolog/shared/widgets/vitality_card.dart';

/// Cuántos días faltan, contando días de calendario.
String daysUntilLabel(DateTime at, DateTime now) {
  final days = DateTime(at.year, at.month, at.day)
      .difference(DateTime(now.year, now.month, now.day))
      .inDays;
  return switch (days) {
    < 0 => 'ya pasó',
    0 => 'hoy',
    1 => 'mañana',
    _ => 'faltan $days días',
  };
}

/// Muestra y edita la próxima cita con la nutricionista.
class NextConsultationCard extends StatefulWidget {
  const NextConsultationCard({
    super.key,
    this.hideWhenEmpty = false,
    this.margin = EdgeInsets.zero,
  });

  /// En Inicio no se muestra nada si no hay cita.
  final bool hideWhenEmpty;

  /// Solo se aplica si la tarjeta se muestra.
  final EdgeInsets margin;

  @override
  State<NextConsultationCard> createState() => _NextConsultationCardState();
}

class _NextConsultationCardState extends State<NextConsultationCard> {
  final _dao = getIt<UserProfileDao>();
  DateTime? _at;
  bool _loaded = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final at = (await _dao.getProfile())?.nextConsultationAt?.toLocal();
    if (!mounted) return;
    setState(() {
      _at = at;
      _loaded = true;
    });
  }

  Future<void> _edit() async {
    final now = DateTime.now();
    final initial = _at != null && _at!.isAfter(now)
        ? _at!
        : now.add(const Duration(days: 7));
    final date = await showDatePicker(
      context: context,
      initialDate: initial,
      firstDate: DateTime(now.year, now.month, now.day),
      lastDate: now.add(const Duration(days: 365)),
      helpText: 'Fecha de la consulta',
    );
    if (date == null || !mounted) return;
    final time = await showTimePicker(
      context: context,
      initialTime: TimeOfDay.fromDateTime(initial),
      helpText: 'Hora de la consulta',
    );
    if (time == null) return;
    await _save(
        DateTime(date.year, date.month, date.day, time.hour, time.minute));
  }

  Future<void> _save(DateTime? at) async {
    await _dao.setNextConsultation(at);
    if (at != null) await NotificationService.requestPermission();
    await scheduleConsultationReminders(at);
    if (mounted) setState(() => _at = at);
  }

  @override
  Widget build(BuildContext context) {
    if (!_loaded) return const SizedBox.shrink();
    final at = _at;
    final upcoming = at != null && at.isAfter(DateTime.now());
    if (widget.hideWhenEmpty && !upcoming) return const SizedBox.shrink();
    final theme = Theme.of(context);

    return Padding(
      padding: widget.margin,
      child: VitalityCard(
        padding: EdgeInsets.zero,
        child: ListTile(
          contentPadding:
              const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
          leading: const Icon(Icons.event_available),
          title: const Text('Próxima consulta'),
          subtitle: Text(
            at == null
                ? 'Toca para agendarla y recibir un aviso'
                : '${_capitalize(DateFormat("EEEE d 'de' MMMM, h:mm a", 'es').format(at))}'
                    ' · ${daysUntilLabel(at, DateTime.now())}',
            style: theme.textTheme.bodyMedium,
          ),
          trailing: at == null
              ? const Icon(Icons.edit_calendar)
              : IconButton(
                  tooltip: 'Quitar',
                  icon: const Icon(Icons.close),
                  onPressed: () => _save(null),
                ),
          onTap: _edit,
        ),
      ),
    );
  }
}

String _capitalize(String text) =>
    text.isEmpty ? text : text[0].toUpperCase() + text.substring(1);
