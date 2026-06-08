import 'package:flutter_bloc/flutter_bloc.dart';
import '../../domain/repositories/water_repository.dart';
import 'water_event.dart';
import 'water_state.dart';

class WaterBloc extends Bloc<WaterEvent, WaterState> {
  final WaterRepository _repository;

  WaterBloc(this._repository) : super(const WaterState()) {
    on<WaterLoaded>(_onLoaded);
    on<WaterAdded>(_onAdded);
    on<WaterCustomAmountAdded>(_onCustomAdded);
    on<WaterConfigLoaded>(_onConfigLoaded);
    on<WaterConfigUpdated>(_onConfigUpdated);
  }

  Future<void> _onLoaded(WaterLoaded event, Emitter<WaterState> emit) async {
    emit(state.copyWith(status: WaterStatus.loading));
    try {
      final total = await _repository.getDailyTotalMl(event.date);
      final config = await _repository.getConfig();
      emit(state.copyWith(
        status: WaterStatus.success,
        dailyTotalMl: total,
        dailyGoalMl: config?.dailyGoalMl ?? 3000,
        unitType: config?.unitType ?? 'bottle',
        containerMl: config?.containerMl ?? 1000,
      ));
    } catch (e) {
      emit(state.copyWith(status: WaterStatus.failure, error: e.toString()));
    }
  }

  Future<void> _onAdded(WaterAdded event, Emitter<WaterState> emit) async {
    if (state.status != WaterStatus.success) return;
    try {
      await _repository.addWater(event.date, event.amountMl);
      final total = await _repository.getDailyTotalMl(event.date);
      emit(state.copyWith(dailyTotalMl: total));
    } catch (e) {
      emit(state.copyWith(status: WaterStatus.failure, error: e.toString()));
    }
  }

  Future<void> _onCustomAdded(
    WaterCustomAmountAdded event,
    Emitter<WaterState> emit,
  ) async {
    if (state.status != WaterStatus.success) return;
    try {
      await _repository.addWater(event.date, event.amountMl);
      final total = await _repository.getDailyTotalMl(event.date);
      emit(state.copyWith(dailyTotalMl: total));
    } catch (e) {
      emit(state.copyWith(status: WaterStatus.failure, error: e.toString()));
    }
  }

  Future<void> _onConfigLoaded(
    WaterConfigLoaded event,
    Emitter<WaterState> emit,
  ) async {
    try {
      final config = await _repository.getConfig();
      if (config != null) {
        emit(state.copyWith(
          dailyGoalMl: config.dailyGoalMl,
          unitType: config.unitType,
          containerMl: config.containerMl,
        ));
      }
    } catch (e) {
      emit(state.copyWith(status: WaterStatus.failure, error: e.toString()));
    }
  }

  Future<void> _onConfigUpdated(
    WaterConfigUpdated event,
    Emitter<WaterState> emit,
  ) async {
    try {
      await _repository.saveConfig(
        unitType: event.unitType,
        containerMl: event.containerMl,
        dailyGoalMl: event.dailyGoalMl,
      );
      emit(state.copyWith(
        unitType: event.unitType,
        containerMl: event.containerMl,
        dailyGoalMl: event.dailyGoalMl,
      ));
    } catch (e) {
      emit(state.copyWith(status: WaterStatus.failure, error: e.toString()));
    }
  }
}
