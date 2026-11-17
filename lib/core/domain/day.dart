/// Los registros diarios se guardan como medianoche UTC del día local.
///
/// `DateTime.now().toUtc()` no sirve para eso: a partir de las 18:00 en
/// UTC-6 ya es el día siguiente en UTC.
DateTime utcDayOf(DateTime local) =>
    DateTime.utc(local.year, local.month, local.day);

DateTime todayUtcDay() => utcDayOf(DateTime.now());

/// El día local que representa una fecha guardada con [utcDayOf].
///
/// Drift devuelve las fechas en hora local: la medianoche UTC del lunes
/// llega como domingo 18:00 en UTC-6, así que leer `.day` o `.weekday`
/// directamente da el día anterior.
DateTime storedDay(DateTime stored) {
  final u = stored.toUtc();
  return DateTime(u.year, u.month, u.day);
}
