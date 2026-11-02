import 'package:flutter_test/flutter_test.dart';
import 'package:kiolog/features/progress/domain/ficha_parser.dart';

OcrLine _row(String text, double top, {double left = 40}) =>
    OcrLine(text, left, top, top + 20);

void main() {
  final date = DateTime.utc(2026, 10, 1);

  test('une cada etiqueta con el valor de su fila', () {
    final m = parseFicha([
      _row('Peso Corporal (kg)', 280),
      _row('74.4 kg', 280, left: 320),
      _row('Estatura (cms)', 300),
      _row('160 cms', 300, left: 320),
      _row('Brazo contraído', 355),
      _row('37.5', 355, left: 340),
      _row('Cintura', 375),
      _row('85.5', 375, left: 340),
      _row('Brazo relajado', 395),
      _row('36', 395, left: 350),
      _row('Cadera', 410),
      _row('103.5', 410, left: 335),
      _row('Muslo (1 cm glúteo)', 468),
      _row('--', 468, left: 350),
      _row('Muslo medio', 487),
      _row('55', 487, left: 350),
      _row('Mesoesternal (tórax)', 505),
      _row('100', 505, left: 345),
      _row('% Masa grasa', 562),
      _row('27.6 %', 562, left: 330),
    ], date)!;

    expect(m.weightKg, 74.4);
    expect(m.heightCm, 160);
    expect(m.armFlexedCm, 37.5);
    expect(m.armRelaxedCm, 36);
    expect(m.waistCm, 85.5);
    expect(m.hipCm, 103.5);
    expect(m.midGluteusCm, isNull);
    expect(m.thighCm, 55);
    expect(m.chestCm, 100);
    expect(m.bodyFatPct, 27.6);
    expect(m.date, date);
    expect(m.id, 0);
  });

  test('no confunde los índices de salud con las medidas', () {
    final m = parseFicha([
      _row('Cintura', 375),
      _row('85.5', 375, left: 340),
      _row('Índice cintura – cadera (ICC)', 700),
      _row('0.83', 700, left: 360),
      _row('Índice de masa corporal (IMC)', 735),
      _row('29.0', 735, left: 360),
    ], date)!;

    expect(m.waistCm, 85.5);
    expect(m.hipCm, isNull);
  });

  test('acepta el valor en la misma línea y con coma decimal', () {
    final m = parseFicha([_row('Pantorrilla 35,5', 100)], date)!;
    expect(m.calfCm, 35.5);
  });

  test('descarta un valor imposible en vez de copiarlo', () {
    final m = parseFicha([
      _row('Cintura', 100),
      _row('855', 100, left: 340),
      _row('Cadera', 130),
      _row('103.5', 130, left: 340),
    ], date)!;

    expect(m.waistCm, isNull);
    expect(m.hipCm, 103.5);
  });

  test('sin medidas reconocibles devuelve null', () {
    expect(parseFicha([_row('Lista del súper', 10)], date), isNull);
  });
}
