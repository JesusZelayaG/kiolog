/// Los registros diarios se guardan como medianoche UTC del día local.
///
/// `DateTime.now().toUtc()` no sirve para eso: a partir de las 18:00 en
/// UTC-6 ya es el día siguiente en UTC.
DateTime utcDayOf(DateTime local) =>
    DateTime.utc(local.year, local.month, local.day);

DateTime todayUtcDay() => utcDayOf(DateTime.now());
