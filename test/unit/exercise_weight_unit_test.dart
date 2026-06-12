import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:kiolog/features/exercise/data/services/exercise_weight_unit_service.dart';
import 'package:bloc_test/bloc_test.dart';
import 'package:kiolog/features/exercise/presentation/cubit/exercise_weight_unit_cubit.dart';

void main() {
  group('ExerciseWeightUnitService', () {
    setUp(() {
      SharedPreferences.setMockInitialValues({});
    });

    test('getUnit returns lbs by default', () async {
      final prefs = await SharedPreferences.getInstance();
      final service = ExerciseWeightUnitService(prefs);
      expect(await service.getUnit(), 'lbs');
    });

    test('setUnit persists and getUnit returns new value', () async {
      final prefs = await SharedPreferences.getInstance();
      final service = ExerciseWeightUnitService(prefs);
      await service.setUnit('kg');
      expect(await service.getUnit(), 'kg');
    });

    test('getUnit returns stored value on second instance', () async {
      final prefs = await SharedPreferences.getInstance();
      await ExerciseWeightUnitService(prefs).setUnit('kg');
      final service2 = ExerciseWeightUnitService(prefs);
      expect(await service2.getUnit(), 'kg');
    });
  });

  group('ExerciseWeightUnitCubit', () {
    late SharedPreferences prefs;

    setUp(() async {
      SharedPreferences.setMockInitialValues({});
      prefs = await SharedPreferences.getInstance();
    });

    tearDown(() {
      SharedPreferences.setMockInitialValues({});
    });

    blocTest<ExerciseWeightUnitCubit, String>(
      'emits lbs on init when no stored value',
      build: () {
        return ExerciseWeightUnitCubit(ExerciseWeightUnitService(prefs));
      },
      act: (c) async => c.init(),
      expect: () => ['lbs'],
    );

    blocTest<ExerciseWeightUnitCubit, String>(
      'emits kg on init when kg was stored',
      setUp: () async {
        SharedPreferences.setMockInitialValues(
            {'exercise_weight_unit': 'kg'});
        prefs = await SharedPreferences.getInstance();
      },
      build: () {
        return ExerciseWeightUnitCubit(ExerciseWeightUnitService(prefs));
      },
      act: (c) async => c.init(),
      expect: () => ['kg'],
    );

    blocTest<ExerciseWeightUnitCubit, String>(
      'setUnit emits new value and persists',
      build: () {
        return ExerciseWeightUnitCubit(ExerciseWeightUnitService(prefs));
      },
      act: (c) async {
        await c.init();
        await c.setUnit('kg');
      },
      expect: () => ['lbs', 'kg'],
    );
  });
}
