import 'package:flutter_test/flutter_test.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:kiolog/features/progress/presentation/widgets/next_consultation_card.dart';

void main() {
  setUpAll(() => initializeDateFormatting('es'));

  test('la hora de la consulta dice a.m. o p.m.', () {
    expect(consultationTime(DateTime(2026, 11, 30, 9, 30)), '9:30 a.m.');
    expect(consultationTime(DateTime(2026, 11, 30, 15, 5)), '3:05 p.m.');
    expect(consultationTime(DateTime(2026, 11, 30, 12, 0)), '12:00 p.m.');
  });

  test('cuenta los días hasta la consulta', () {
    final now = DateTime(2026, 11, 17, 18);
    expect(daysUntilLabel(DateTime(2026, 11, 17, 20), now), 'hoy');
    expect(daysUntilLabel(DateTime(2026, 11, 18, 9), now), 'mañana');
    expect(daysUntilLabel(DateTime(2026, 11, 30, 9, 30), now), 'faltan 13 días');
    expect(daysUntilLabel(DateTime(2026, 11, 16), now), 'ya pasó');
  });
}
