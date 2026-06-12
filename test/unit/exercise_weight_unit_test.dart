import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:kiolog/features/exercise/data/services/exercise_weight_unit_service.dart';

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
}
