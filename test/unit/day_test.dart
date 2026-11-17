import 'package:flutter_test/flutter_test.dart';
import 'package:kiolog/core/domain/day.dart';

void main() {
  test('storedDay devuelve el mismo día local que se guardó', () {
    final today = DateTime(2026, 11, 17, 20, 30);
    final stored = utcDayOf(today);
    // Drift entrega la fecha en hora local.
    final fromDb = DateTime.fromMillisecondsSinceEpoch(
        stored.millisecondsSinceEpoch);

    final day = storedDay(fromDb);

    expect(day, DateTime(2026, 11, 17));
    expect(day.weekday, DateTime.tuesday);
  });
}
