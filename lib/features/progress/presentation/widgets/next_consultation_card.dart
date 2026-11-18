import 'package:flutter/material.dart';
import 'package:iconsax_plus/iconsax_plus.dart';
import 'package:intl/intl.dart';
import 'package:kiolog/core/dao/user_profile_dao.dart';
import 'package:kiolog/core/di/injection.dart';
import 'package:kiolog/core/notifications/consultation_reminders.dart';
import 'package:kiolog/core/notifications/notification_service.dart';
import 'package:kiolog/core/theme/app_theme.dart';
import 'package:kiolog/shared/widgets/vitality_card.dart';

/// "9:30 a.m.": intl escribe "a. m.", que se ve cortado en una línea.
String consultationTime(DateTime at) =>
    '${DateFormat('h:mm', 'es').format(at)} ${at.hour < 12 ? 'a.m.' : 'p.m.'}';

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
    this.compact = false,
  });

  /// Una franja corta (Home): agenda si no hay consulta y, si la hay,
  /// abre una hoja para re-agendarla o cancelarla.
  final bool compact;

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

  /// Pide fecha y hora y la guarda; devuelve la nueva, o null si se canceló.
  Future<DateTime?> _edit() async {
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
    if (date == null || !mounted) return null;
    final time = await showTimePicker(
      context: context,
      initialTime: TimeOfDay.fromDateTime(initial),
      helpText: 'Hora de la consulta',
    );
    if (time == null) return null;
    final at = DateTime(date.year, date.month, date.day, time.hour, time.minute);
    await _save(at);
    return at;
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
    if (widget.compact) return _buildCompact(context, upcoming ? at : null, past: at != null && !upcoming);
    if (widget.hideWhenEmpty && !upcoming) return const SizedBox.shrink();
    final theme = Theme.of(context);

    return Padding(
      padding: widget.margin,
      child: VitalityCard(
        padding: EdgeInsets.zero,
        child: ListTile(
          contentPadding:
              const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
          leading: const Icon(IconsaxPlusBold.calendar_tick),
          title: const Text('Próxima consulta'),
          subtitle: Text(
            at == null
                ? 'Toca para agendarla y recibir un aviso'
                : '${_capitalize(DateFormat("EEEE d 'de' MMMM", 'es').format(at))}, ${consultationTime(at)}'
                    ' · ${daysUntilLabel(at, DateTime.now())}',
            style: theme.textTheme.bodyMedium,
          ),
          trailing: at == null
              ? const Icon(IconsaxPlusLinear.calendar_edit)
              : IconButton(
                  tooltip: 'Quitar',
                  icon: const Icon(IconsaxPlusLinear.close_circle),
                  onPressed: () => _save(null),
                ),
          onTap: _edit,
        ),
      ),
    );
  }
}

extension on _NextConsultationCardState {
  String _when(DateTime at) =>
      '${_capitalize(DateFormat("EEEE d 'de' MMMM", 'es').format(at))} · ${consultationTime(at)}';

  void _toast(String text) => ScaffoldMessenger.of(context)
    ..hideCurrentSnackBar()
    ..showSnackBar(SnackBar(content: Text(text)));

  Future<void> _schedule() async {
    final at = await _edit();
    if (at != null && mounted) _toast('Consulta agendada: ${_when(at)}. Te aviso antes.');
  }

  Future<void> _reschedule() async {
    final at = await _edit();
    if (at != null && mounted) _toast('Consulta re-agendada: ${_when(at)}');
  }

  Future<void> _cancel() async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Cancelar consulta'),
        content: const Text('Se quitan la fecha y sus avisos. Puedes agendarla de nuevo cuando quieras.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(dialogContext, false), child: const Text('Volver')),
          ElevatedButton(onPressed: () => Navigator.pop(dialogContext, true), child: const Text('Cancelar consulta')),
        ],
      ),
    );
    if (ok != true) return;
    await _save(null);
    if (mounted) _toast('Consulta cancelada');
  }

  /// La hoja con la consulta agendada y qué hacer con ella.
  Future<void> _openSheet(DateTime at) async {
    final action = await showModalBottomSheet<String>(
      context: context,
      showDragHandle: true,
      builder: (sheetContext) {
        final theme = Theme.of(sheetContext);
        final cs = theme.colorScheme;
        final kc = sheetContext.kc;
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(20, 0, 20, 16),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Row(
                  children: [
                    Container(
                      width: 52,
                      height: 52,
                      alignment: Alignment.center,
                      decoration: BoxDecoration(color: kc.waterWash, borderRadius: BorderRadius.circular(16)),
                      child: Icon(IconsaxPlusBold.calendar_tick, color: cs.primary, size: 26),
                    ),
                    const SizedBox(width: 14),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('Próxima consulta', style: theme.textTheme.labelSmall?.copyWith(color: cs.primary)),
                          Text(_when(at), style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w800)),
                          Text(_capitalize(daysUntilLabel(at, DateTime.now())), style: theme.textTheme.bodySmall),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                Text(
                  'Te aviso la noche anterior y 2 horas antes.',
                  style: theme.textTheme.bodySmall,
                ),
                const SizedBox(height: 18),
                ElevatedButton.icon(
                  onPressed: () => Navigator.pop(sheetContext, 'reschedule'),
                  icon: const Icon(IconsaxPlusLinear.calendar_edit),
                  label: const Text('Re-agendar'),
                ),
                const SizedBox(height: 8),
                TextButton.icon(
                  onPressed: () => Navigator.pop(sheetContext, 'cancel'),
                  style: TextButton.styleFrom(foregroundColor: cs.error),
                  icon: const Icon(IconsaxPlusLinear.calendar_remove),
                  label: const Text('Cancelar consulta'),
                ),
              ],
            ),
          ),
        );
      },
    );
    if (!mounted) return;
    if (action == 'reschedule') await _reschedule();
    if (action == 'cancel') await _cancel();
  }

  Widget _buildCompact(BuildContext context, DateTime? at, {required bool past}) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;
    final kc = context.kc;
    final scheduled = at != null;
    final title = scheduled
        ? 'Próxima consulta'
        : past
            ? '¿Ya fuiste a tu consulta?'
            : 'Agenda tu próxima consulta';
    final subtitle = scheduled
        ? '${_capitalize(DateFormat('EEE d MMM', 'es').format(at).replaceAll('.', ''))} · ${consultationTime(at)}'
        : past
            ? 'Agenda la siguiente y te aviso antes'
            : 'Te aviso la noche anterior y 2 h antes';
    return Padding(
      padding: widget.margin,
      child: Material(
        color: cs.surfaceContainerLowest,
        borderRadius: BorderRadius.circular(22),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: scheduled ? () => _openSheet(at) : _schedule,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
            child: Row(
              children: [
                Container(
                  width: 40,
                  height: 40,
                  decoration: BoxDecoration(
                    color: kc.waterWash,
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: Icon(
                    scheduled ? IconsaxPlusBold.calendar_tick : IconsaxPlusBold.calendar_add,
                    size: 22,
                    color: cs.primary,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(title, style: theme.textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w700)),
                      Text(subtitle, style: theme.textTheme.bodySmall?.copyWith(fontSize: 13)),
                    ],
                  ),
                ),
                if (scheduled)
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                    decoration: ShapeDecoration(color: kc.waterWash, shape: const StadiumBorder()),
                    child: Text(
                      daysUntilLabel(at, DateTime.now()).replaceFirst('faltan ', ''),
                      style: theme.textTheme.labelMedium?.copyWith(color: cs.primary, fontWeight: FontWeight.w800),
                    ),
                  )
                else
                  Container(
                    width: 36,
                    height: 36,
                    decoration: BoxDecoration(gradient: kc.brandGradient, shape: BoxShape.circle),
                    child: const Icon(IconsaxPlusLinear.add, color: Colors.white, size: 20),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

String _capitalize(String text) =>
    text.isEmpty ? text : text[0].toUpperCase() + text.substring(1);
