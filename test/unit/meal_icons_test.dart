import 'package:flutter_test/flutter_test.dart';
import 'package:kiolog/shared/widgets/meal_icons.dart';

void main() {
  test('sugiere por el nombre del tiempo de comida', () {
    expect(MealIcon.suggest('Desayuno'), MealIcon.sunrise);
    expect(MealIcon.suggest('Refacción de la tarde'), MealIcon.coffee);
    expect(MealIcon.suggest('CENA'), MealIcon.moon);
    expect(MealIcon.suggest('Almuerzo'), MealIcon.bowl);
  });

  test('el ícono elegido gana sobre la sugerencia', () {
    expect(MealIcon.resolve('cake', 'Desayuno'), MealIcon.cake);
    expect(MealIcon.resolve(null, 'Desayuno'), MealIcon.sunrise);
    expect(MealIcon.resolve('desconocido', 'Cena'), MealIcon.moon);
  });
}
