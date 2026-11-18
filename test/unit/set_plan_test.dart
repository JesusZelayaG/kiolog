import 'package:flutter_test/flutter_test.dart';
import 'package:kiolog/features/exercise/domain/set_plan.dart';

const s10 = PlannedSet(reps: 10, weight: 20);

void main() {
  group('setTypeFor', () {
    test('series iguales son normales', () {
      expect(setTypeFor([s10, s10, s10]), 'normal');
    });

    test('series distintas son pirámide', () {
      expect(setTypeFor([const PlannedSet(reps: 12, weight: 20), const PlannedSet(reps: 10, weight: 22.5)]), 'pyramid');
    });

    test('con drops es drop o pirámide + drop', () {
      expect(setTypeFor([s10, s10, const PlannedSet(reps: 12, isDrop: true)]), 'drop');
      expect(
        setTypeFor([
          const PlannedSet(reps: 12, weight: 20),
          const PlannedSet(reps: 8, weight: 25),
          const PlannedSet(reps: 12, weight: 15, isDrop: true),
        ]),
        'pyramid_drop',
      );
    });
  });

  test('los drops apuntan a la serie de la que salen', () {
    final defs = toSetDefs([
      s10,
      s10,
      const PlannedSet(reps: 12, weight: 15, isDrop: true),
      const PlannedSet(reps: 15, weight: 10, isDrop: true),
    ]);

    expect(defs.map((d) => d.setNumber), [1, 2, 3, 4]);
    expect(defs.map((d) => d.dropOfSetNumber), [null, null, 2, 2]);
  });

  test('un drop sin serie antes se ignora', () {
    expect(toSetDefs([const PlannedSet(reps: 12, isDrop: true), s10]).length, 1);
  });

  group('setPlanSummary', () {
    test('series iguales con la etiqueta de reps del plan', () {
      expect(setPlanSummary([s10, s10, s10], 'kg'), '3 × 10 @ 20 kg');
      expect(setPlanSummary([const PlannedSet(reps: 8), const PlannedSet(reps: 8)], 'kg', repsLabel: '6-8'), '2 × 6-8');
    });

    test('pirámide serie por serie', () {
      expect(
        setPlanSummary([
          const PlannedSet(reps: 12, weight: 20),
          const PlannedSet(reps: 10, weight: 22.5),
          const PlannedSet(reps: 8, weight: 25),
        ], 'kg'),
        '12 × 20 → 10 × 22.5 → 8 × 25 kg',
      );
    });

    test('drops en la última serie, como los escribe el entrenador', () {
      expect(
        setPlanSummary([
          const PlannedSet(reps: 10),
          const PlannedSet(reps: 10),
          const PlannedSet(reps: 12, isDrop: true),
          const PlannedSet(reps: 15, isDrop: true),
        ], 'kg'),
        '2 × 10 + drop 12 → 15',
      );
    });
  });
}
