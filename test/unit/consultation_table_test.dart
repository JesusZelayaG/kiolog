import 'package:flutter_test/flutter_test.dart';
import 'package:kiolog/core/database/app_database.dart';
import 'package:kiolog/features/reports/data/pdf_report_service.dart';

Measurement _consultation(int day, double weight, {double? waist}) => Measurement(
      id: day,
      date: DateTime.utc(2026, 10, day),
      weightKg: weight,
      heightCm: 160,
      waistCm: waist,
    );

void main() {
  test('una sola consulta no lleva fila de cambio', () {
    final table = PdfReportService.consultationTable([_consultation(1, 74.4)]);
    expect(table, hasLength(2));
    expect(table.last.first, '01/10/26');
  });

  test('el cambio compara la primera y la última consulta', () {
    final table = PdfReportService.consultationTable([
      _consultation(1, 80.6, waist: 90),
      _consultation(2, 77.5),
      _consultation(3, 74.4, waist: 85.5),
    ]);
    expect(table.last[0], 'Cambio');
    expect(table.last[1], '-6.2');
    expect(table.last[2], '-4.5');
    expect(table.last[3], '—');
  });

  test('muestra solo las 8 más recientes, pero el cambio usa todas', () {
    final table = PdfReportService.consultationTable([
      for (var day = 1; day <= 10; day++) _consultation(day, 80 - day.toDouble()),
    ]);
    expect(table, hasLength(1 + 8 + 1));
    expect(table[1].first, '03/10/26');
    expect(table.last[1], '-9.0');
  });
}
