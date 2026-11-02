import 'package:kiolog/core/database/app_database.dart';

/// Una línea reconocida por OCR, con su posición en la página.
class OcrLine {
  const OcrLine(this.text, this.left, this.top, this.bottom);

  final String text;
  final double left;
  final double top;
  final double bottom;

  double get middle => (top + bottom) / 2;
}

class _Rule {
  const _Rule(this.field, this.keywords, this.min, this.max, {this.excludes = const []});

  final String field;
  final List<String> keywords;
  final double min;
  final double max;
  final List<String> excludes;

  bool matches(String label) =>
      keywords.every(label.contains) && !excludes.any(label.contains);
}

const _indices = ['indice', 'icc', 'imc'];

// Order matters: the first rule that matches a label wins.
const _rules = [
  _Rule('weight', ['peso'], 20, 300, excludes: ['seguimiento', 'kg.']),
  _Rule('height', ['estatura'], 100, 230),
  _Rule('armFlexed', ['brazo', 'contra'], 10, 80),
  _Rule('armRelaxed', ['brazo', 'relaj'], 10, 80),
  _Rule('waist', ['cintura'], 30, 200, excludes: _indices),
  _Rule('hip', ['cadera'], 40, 200, excludes: [..._indices, 'cintura']),
  _Rule('calf', ['pantorrilla'], 15, 80),
  _Rule('abdomen', ['abdomen'], 30, 200),
  _Rule('glute', ['muslo', 'gluteo'], 20, 120),
  _Rule('thigh', ['muslo'], 20, 120),
  _Rule('chest', ['torax'], 40, 200),
  _Rule('chest', ['mesoesternal'], 40, 200),
  _Rule('fat', ['masa', 'grasa'], 1, 80),
  _Rule('visceral', ['masa', 'visceral'], 1, 80),
];

final _number = RegExp(r'\d+(?:[.,]\d+)?');

String _normalize(String text) {
  const accents = {'á': 'a', 'é': 'e', 'í': 'i', 'ó': 'o', 'ú': 'u'};
  return text
      .toLowerCase()
      .split('')
      .map((c) => accents[c] ?? c)
      .join();
}

double? _lastNumber(String text) {
  final matches = _number.allMatches(text).toList();
  if (matches.isEmpty) return null;
  return double.parse(matches.last.group(0)!.replaceAll(',', '.'));
}

/// Lee una ficha antropométrica. Devuelve una consulta sin guardar para que la
/// persona la revise, o null si no reconoció ninguna medida. Peso y talla quedan
/// en 0 si no aparecen. Un valor fuera de rango suele ser un error de lectura,
/// así que se descarta en vez de copiarlo.
Measurement? parseFicha(List<OcrLine> lines, DateTime date) {
  final values = <String, double>{};
  for (final line in lines) {
    final label = _normalize(line.text);
    final rule = _rules.where((r) => r.matches(label)).firstOrNull;
    if (rule == null || values.containsKey(rule.field)) continue;

    final cells = lines
        .where((other) =>
            other != line &&
            other.left > line.left &&
            other.middle >= line.top &&
            other.middle <= line.bottom)
        .toList()
      ..sort((a, b) => a.left.compareTo(b.left));
    // A value may sit in the label's own line, or in the nearest cell to its right.
    final ownText = label.replaceAll(RegExp(r'\(.*?\)'), '');
    final value = _lastNumber(ownText) ??
        (cells.isEmpty ? null : _lastNumber(cells.first.text));
    if (value != null && value >= rule.min && value <= rule.max) {
      values[rule.field] = value;
    }
  }
  if (values.isEmpty) return null;
  return Measurement(
    id: 0,
    date: date,
    weightKg: values['weight'] ?? 0,
    heightCm: values['height'] ?? 0,
    armFlexedCm: values['armFlexed'],
    armRelaxedCm: values['armRelaxed'],
    waistCm: values['waist'],
    hipCm: values['hip'],
    calfCm: values['calf'],
    lowerAbdomenCm: values['abdomen'],
    thighCm: values['thigh'],
    midGluteusCm: values['glute'],
    chestCm: values['chest'],
    bodyFatPct: values['fat'],
    visceralMass: values['visceral'],
  );
}
