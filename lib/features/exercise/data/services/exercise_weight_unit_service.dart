import 'package:shared_preferences/shared_preferences.dart';

class ExerciseWeightUnitService {
  static const _key = 'exercise_weight_unit';
  static const _default = 'lbs';

  final SharedPreferences _prefs;

  ExerciseWeightUnitService(this._prefs);

  Future<String> getUnit() async => _prefs.getString(_key) ?? _default;

  Future<void> setUnit(String unit) async =>
      _prefs.setString(_key, unit);
}
