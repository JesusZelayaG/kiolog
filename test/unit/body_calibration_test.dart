import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:kiolog/features/progress/domain/body_calibration.dart';

const _ficha = {
  'pecho': 100.0,
  'cintura': 85.5,
  'abdomen': 89.0,
  'cadera': 103.5,
  'brazo': 36.0,
  'muslo': 55.0,
  'pantorrilla': 35.0,
};

void main() {
  final calibration =
      BodyCalibration.parse(File('assets/models/anatomy_body.json').readAsStringSync());

  test('escala el modelo a la estatura de la persona', () {
    final shape = calibration.solve(
      sex: BodySex.male,
      perimetersCm: _ficha,
      heightCm: 160,
      fatPercent: 27.6,
    );
    expect(shape.scale, closeTo(160 / calibration.heightCm, 1e-9));
  });

  test('una medida faltante deja esa zona en el tamaño base', () {
    final shape = calibration.solve(
      sex: BodySex.male,
      perimetersCm: {..._ficha, 'pantorrilla': null},
      heightCm: 160,
      fatPercent: 27.6,
    );
    expect(shape.weights['pantorrilla'], 0);
    expect(shape.weights['muslo'], greaterThan(0));
  });

  test('sin porcentaje de grasa las almohadillas quedan ocultas', () {
    final shape = calibration.solve(
      sex: BodySex.male,
      perimetersCm: _ficha,
      heightCm: 160,
    );
    for (final name in calibration.fat) {
      expect(shape.weights[name], 0);
    }
  });

  test('marca la forma femenina según el sexo', () {
    final shape = calibration.solve(
      sex: BodySex.female,
      perimetersCm: _ficha,
      heightCm: 160,
      fatPercent: 27.6,
    );
    expect(shape.weights['femenino'], 1);
  });
}
