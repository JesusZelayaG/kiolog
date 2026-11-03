import 'package:flutter_test/flutter_test.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:kiolog/core/notifications/consultation_reminders.dart';
import 'package:kiolog/features/progress/presentation/widgets/next_consultation_card.dart';

void main() {
  setUpAll(() => initializeDateFormatting('es'));

  test('reminds the evening before and two hours before', () {
    final reminders = consultationReminders(DateTime(2026, 11, 30, 9, 30));

    expect(reminders.map((r) => r.$2), [
      DateTime(2026, 11, 29, 19),
      DateTime(2026, 11, 30, 7, 30),
    ]);
    expect(reminders.first.$3, contains('Mañana'));
  });

  test('the evening before crosses month boundaries', () {
    final reminders = consultationReminders(DateTime(2026, 12, 1, 9));

    expect(reminders.first.$2, DateTime(2026, 11, 30, 19));
  });

  test('counts calendar days, not 24-hour blocks', () {
    final now = DateTime(2026, 11, 2, 21);

    expect(daysUntilLabel(DateTime(2026, 11, 3, 8), now), 'mañana');
    expect(daysUntilLabel(DateTime(2026, 11, 30, 9, 30), now), 'faltan 28 días');
    expect(daysUntilLabel(DateTime(2026, 11, 2, 22), now), 'hoy');
  });
}
