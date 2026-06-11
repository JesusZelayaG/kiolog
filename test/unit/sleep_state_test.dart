import 'package:flutter_test/flutter_test.dart';
import 'package:kiolog/core/database/app_database.dart';
import 'package:kiolog/features/sleep/presentation/bloc/sleep_state.dart';

SleepLog _log({
  int id = 1,
  double hours = 0.0,
  String type = 'main',
}) {
  final now = DateTime(2026, 6, 11);
  return SleepLog(
    id: id,
    date: now,
    sleepTime: now,
    wakeTime: now,
    hoursCalculated: hours,
    type: type,
  );
}

void main() {
  group('SleepState.mainSleepHours', () {
    test('returns 0.0 cuando todayLogs está vacío', () {
      const s = SleepState();
      expect(s.mainSleepHours, 0.0);
    });

    test('suma solo los registros de tipo main', () {
      final s = SleepState(todayLogs: [
        _log(id: 1, hours: 7.0, type: 'main'),
        _log(id: 2, hours: 1.5, type: 'nap'),
      ]);
      expect(s.mainSleepHours, 7.0);
    });
  });

  group('SleepState.napHours', () {
    test('returns 0.0 sin siestas', () {
      final s = SleepState(todayLogs: [_log(hours: 7.0, type: 'main')]);
      expect(s.napHours, 0.0);
    });

    test('suma todas las siestas', () {
      final s = SleepState(todayLogs: [
        _log(id: 1, hours: 0.5, type: 'nap'),
        _log(id: 2, hours: 1.0, type: 'nap'),
      ]);
      expect(s.napHours, closeTo(1.5, 0.001));
    });
  });

  group('SleepState.totalHours', () {
    test('suma main + naps', () {
      final s = SleepState(todayLogs: [
        _log(id: 1, hours: 7.0, type: 'main'),
        _log(id: 2, hours: 0.5, type: 'nap'),
        _log(id: 3, hours: 1.0, type: 'nap'),
      ]);
      expect(s.totalHours, closeTo(8.5, 0.001));
    });
  });

  group('SleepState.weeklyAverage', () {
    test('returns null cuando weeklyLogs está vacío', () {
      const s = SleepState();
      expect(s.weeklyAverage, isNull);
    });

    test('promedia por día, no por entrada', () {
      final day1 = DateTime(2026, 6, 10);
      final day2 = DateTime(2026, 6, 11);
      // día 1: 7h main + 1h nap = 8h; día 2: 6h main = 6h → promedio = 7h
      final s = SleepState(weeklyLogs: [
        SleepLog(id: 1, date: day1, sleepTime: day1, wakeTime: day1, hoursCalculated: 7.0, type: 'main'),
        SleepLog(id: 2, date: day1, sleepTime: day1, wakeTime: day1, hoursCalculated: 1.0, type: 'nap'),
        SleepLog(id: 3, date: day2, sleepTime: day2, wakeTime: day2, hoursCalculated: 6.0, type: 'main'),
      ]);
      expect(s.weeklyAverage, closeTo(7.0, 0.001));
    });
  });
}
