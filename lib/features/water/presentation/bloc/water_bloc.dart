import 'package:flutter_bloc/flutter_bloc.dart';
import '../../domain/repositories/water_repository.dart';
import 'water_event.dart';
import 'water_state.dart';

class WaterBloc extends Bloc<WaterEvent, WaterState> {
  final WaterRepository _repository;

  WaterBloc(this._repository) : super(const WaterState()) {
    on<WaterLoaded>(_onLoaded);
    on<WaterAdded>(_onAdded);
    on<WaterLogDeleted>(_onLogDeleted);
    on<WaterGoalUpdated>(_onGoalUpdated);
  }

  Future<WaterState> _today(WaterState from) async {
    final now = DateTime.now();
    final logs = await _repository.getDailyLogs(now);
    return from.copyWith(
      status: WaterStatus.success,
      logs: logs,
      dailyTotalMl: logs.fold<int>(0, (sum, log) => sum + log.amountMl),
    );
  }

  Future<void> _onLoaded(WaterLoaded event, Emitter<WaterState> emit) async {
    emit(state.copyWith(status: WaterStatus.loading));
    try {
      final config = await _repository.getConfig();
      emit(await _today(state.copyWith(dailyGoalMl: config?.dailyGoalMl ?? 3000)));
    } catch (e) {
      emit(state.copyWith(status: WaterStatus.failure, error: e.toString()));
    }
  }

  Future<void> _onAdded(WaterAdded event, Emitter<WaterState> emit) async {
    if (state.status != WaterStatus.success) return;
    try {
      await _repository.addWater(event.date, event.amountMl);
      emit(await _today(state));
    } catch (e) {
      emit(state.copyWith(status: WaterStatus.failure, error: e.toString()));
    }
  }

  Future<void> _onLogDeleted(WaterLogDeleted event, Emitter<WaterState> emit) async {
    if (state.status != WaterStatus.success) return;
    try {
      await _repository.deleteWaterLog(event.logId);
      emit(await _today(state));
    } catch (e) {
      emit(state.copyWith(status: WaterStatus.failure, error: e.toString()));
    }
  }

  Future<void> _onGoalUpdated(WaterGoalUpdated event, Emitter<WaterState> emit) async {
    try {
      await _repository.saveGoal(event.dailyGoalMl);
      emit(state.copyWith(dailyGoalMl: event.dailyGoalMl));
    } catch (e) {
      emit(state.copyWith(status: WaterStatus.failure, error: e.toString()));
    }
  }
}
