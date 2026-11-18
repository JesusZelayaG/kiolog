import 'package:flutter_test/flutter_test.dart';
import 'package:kiolog/core/database/app_database.dart';
import 'package:kiolog/features/exercise/presentation/widgets/set_plan_editor.dart';

ExerciseRoutineItem item({String setType = 'normal', String? repsLabel}) => ExerciseRoutineItem(
      id: 1,
      routineId: 1,
      exerciseName: 'Jalones al pecho',
      sets: 4,
      reps: 12,
      weightKg: 40,
      setType: setType,
      orderIndex: 0,
      repsLabel: repsLabel,
    );

ExerciseRoutineSetDef def(int n, int reps, double? w, {int? dropOf}) =>
    ExerciseRoutineSetDef(id: n, routineItemId: 1, setNumber: n, dropOfSetNumber: dropOf, reps: reps, weightKg: w);

void main() {
  test('series iguales con drops al final se abren en ese modo', () {
    final draft = SetPlanDraft.fromItem(item(setType: 'drop', repsLabel: '10-12'), [
      def(1, 12, 40),
      def(2, 12, 40),
      def(3, 12, 30, dropOf: 2),
      def(4, 15, 20, dropOf: 2),
    ]);

    expect(draft.perSet, isFalse);
    expect(draft.sets.text, '2');
    expect(draft.reps.text, '10-12');
    final result = draft.build()!;
    expect(result.setType, 'drop');
    expect(result.repsLabel, '10-12');
    expect(result.defs.map((d) => d.dropOfSetNumber), [null, null, 2, 2]);
  });

  test('una pirámide se abre serie por serie', () {
    final draft = SetPlanDraft.fromItem(item(setType: 'pyramid'), [def(1, 12, 20), def(2, 10, 22.5), def(3, 8, 25)]);

    expect(draft.perSet, isTrue);
    final result = draft.build()!;
    expect(result.setType, 'pyramid');
    expect(result.sets, 3);
    expect(result.defs.map((d) => d.weightKg), [20, 22.5, 25]);
  });

  test('sin series por separado es un ejercicio normal y no guarda filas', () {
    final result = SetPlanDraft.fromItem(item(), const []).build()!;

    expect(result.setType, 'normal');
    expect(result.sets, 4);
    expect(result.defs, isEmpty);
  });

  test('pasar a pirámide y volver conserva series y drops', () {
    final draft = SetPlanDraft(sets: '3', reps: '10', weight: '20')..switchToPerSet();
    expect(draft.rows.length, 3);

    draft.switchToUniform();
    expect(draft.sets.text, '3');
    expect(draft.weight.text, '20');
  });

  test('sin reps no se puede guardar', () {
    expect(SetPlanDraft(sets: '3', reps: '').build(), isNull);
  });
}
