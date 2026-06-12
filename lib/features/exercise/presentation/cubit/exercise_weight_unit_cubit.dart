import 'package:flutter_bloc/flutter_bloc.dart';
import '../../data/services/exercise_weight_unit_service.dart';

class ExerciseWeightUnitCubit extends Cubit<String> {
  final ExerciseWeightUnitService _service;

  ExerciseWeightUnitCubit(this._service) : super('lbs');

  Future<void> init() async => emit(await _service.getUnit());

  Future<void> setUnit(String unit) async {
    await _service.setUnit(unit);
    emit(unit);
  }
}
