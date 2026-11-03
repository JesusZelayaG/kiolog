import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:timezone/timezone.dart' as tz;
import 'package:timezone/data/latest.dart' as tz_data;

class NotificationService {
  static final FlutterLocalNotificationsPlugin _plugin =
      FlutterLocalNotificationsPlugin();

  static bool _initialized = false;

  static Future<void> init() async {
    if (_initialized) return;

    tz_data.initializeTimeZones();

    const androidSettings = AndroidInitializationSettings('@mipmap/ic_launcher');
    const initSettings = InitializationSettings(android: androidSettings);

    await _plugin.initialize(initSettings);
    _initialized = true;
  }

  static Future<void> scheduleDailyNotification({
    required int id,
    required String title,
    required String body,
    required int hour,
    required int minute,
  }) async {
    await _plugin.zonedSchedule(
      id,
      title,
      body,
      _nextInstanceOfTime(hour, minute),
      const NotificationDetails(
        android: AndroidNotificationDetails(
          'kiolog_channel',
          'Kiolog Notifications',
          channelDescription: 'Recordatorios de salud',
          importance: Importance.high,
          priority: Priority.high,
        ),
      ),
      androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle,
      uiLocalNotificationDateInterpretation:
          UILocalNotificationDateInterpretation.absoluteTime,
      matchDateTimeComponents: DateTimeComponents.time,
    );
  }

  static Future<void> scheduleIntervalNotification({
    required int id,
    required String title,
    required String body,
    required int intervalMinutes,
  }) async {
    await _plugin.periodicallyShow(
      id,
      title,
      body,
      RepeatInterval.everyMinute, // closest built-in option
      const NotificationDetails(
        android: AndroidNotificationDetails(
          'kiolog_interval',
          'Kiolog Interval Notifications',
          channelDescription: 'Recordatorios periódicos',
          importance: Importance.high,
          priority: Priority.high,
        ),
      ),
      androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle,
    );
  }

  /// Pide permiso para mostrar notificaciones (Android 13 o más nuevo).
  static Future<bool> requestPermission() async {
    final android = _plugin.resolvePlatformSpecificImplementation<
        AndroidFlutterLocalNotificationsPlugin>();
    return await android?.requestNotificationsPermission() ?? true;
  }

  /// Una sola notificación en el instante [at].
  static Future<void> scheduleOnce({
    required int id,
    required String title,
    required String body,
    required DateTime at,
  }) async {
    await _plugin.zonedSchedule(
      id,
      title,
      body,
      // El instante es absoluto: no depende de la zona configurada en tz.
      tz.TZDateTime.from(at, tz.UTC),
      const NotificationDetails(
        android: AndroidNotificationDetails(
          'kiolog_consultas',
          'Consultas',
          channelDescription: 'Recordatorio de la próxima consulta',
          importance: Importance.high,
          priority: Priority.high,
        ),
      ),
      // Sin permiso de alarma exacta; unos minutos de holgura bastan.
      androidScheduleMode: AndroidScheduleMode.inexactAllowWhileIdle,
      uiLocalNotificationDateInterpretation:
          UILocalNotificationDateInterpretation.absoluteTime,
    );
  }

  static Future<void> cancel(int id) => _plugin.cancel(id);

  static Future<void> cancelAll() => _plugin.cancelAll();

  static tz.TZDateTime _nextInstanceOfTime(int hour, int minute) {
    final now = tz.TZDateTime.now(tz.local);
    var scheduled = tz.TZDateTime(tz.local, now.year, now.month, now.day, hour, minute);
    if (scheduled.isBefore(now)) {
      scheduled = scheduled.add(const Duration(days: 1));
    }
    return scheduled;
  }
}
