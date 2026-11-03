import 'package:intl/intl.dart';

import 'notification_service.dart';

const _dayBeforeId = 9101;
const _sameDayId = 9102;

/// Los avisos de una consulta: la víspera a las 19:00 y dos horas antes.
List<(int, DateTime, String)> consultationReminders(DateTime at) {
  final hour = DateFormat('h:mm a', 'es').format(at);
  final dayBefore = DateTime(at.year, at.month, at.day - 1, 19);
  return [
    (_dayBeforeId, dayBefore, 'Mañana a las $hour tienes consulta con tu nutricionista.'),
    (_sameDayId, at.subtract(const Duration(hours: 2)), 'Hoy a las $hour tienes consulta.'),
  ];
}

/// Reemplaza los avisos programados por los de [at]; null solo los borra.
Future<void> scheduleConsultationReminders(DateTime? at, {DateTime? now}) async {
  await NotificationService.cancel(_dayBeforeId);
  await NotificationService.cancel(_sameDayId);
  if (at == null) return;
  final current = now ?? DateTime.now();
  for (final (id, moment, body) in consultationReminders(at)) {
    if (!moment.isAfter(current)) continue;
    await NotificationService.scheduleOnce(
      id: id,
      title: 'Próxima consulta',
      body: body,
      at: moment,
    );
  }
}
