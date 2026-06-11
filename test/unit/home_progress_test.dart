import 'package:flutter_test/flutter_test.dart';
import 'package:kiolog/features/home/presentation/bloc/home_state.dart';
import 'package:kiolog/features/home/presentation/pages/home_page.dart';

void main() {
  group('calcOverallProgress', () {
    test('returns 0.0 cuando todos los módulos están en cero', () {
      const s = HomeState();
      expect(calcOverallProgress(s), 0.0);
    });

    test('returns 1.0 cuando todos los módulos están completos', () {
      const s = HomeState(
        dailyWaterTotalMl: 3000,
        dailyWaterGoalMl: 3000,
        sleepHours: 8.0,
        mealsLogged: 4,
        totalMeals: 4,
        exerciseRoutineDone: true,
      );
      expect(calcOverallProgress(s), 1.0);
    });

    test('returns promedio correcto con valores parciales', () {
      // agua: 0.5, sueño: 0.5, nutrición: 0.5, ejercicio: 0.0 → 0.375
      const s = HomeState(
        dailyWaterTotalMl: 1500,
        dailyWaterGoalMl: 3000,
        sleepHours: 4.0,
        mealsLogged: 2,
        totalMeals: 4,
      );
      expect(calcOverallProgress(s), closeTo(0.375, 0.001));
    });

    test('hasGymSession aporta 0.5 al progreso de ejercicio', () {
      // agua: 0, sueño: 0, nutrición: 0, ejercicio: 0.5 → 0.125
      const s = HomeState(hasGymSession: true);
      expect(calcOverallProgress(s), closeTo(0.125, 0.001));
    });
  });
}
