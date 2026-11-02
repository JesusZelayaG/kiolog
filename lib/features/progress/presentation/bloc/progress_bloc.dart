import 'package:flutter_bloc/flutter_bloc.dart';
import '../../domain/repositories/progress_repository.dart';
import 'progress_event.dart';
import 'progress_state.dart';

class ProgressBloc extends Bloc<ProgressEvent, ProgressState> {
  final ProgressRepository _repository;

  ProgressBloc(this._repository) : super(const ProgressState()) {
    on<ProgressLoaded>(_onLoaded);
    on<ProgressWeightAdded>(_onWeightAdded);
  }

  Future<void> _onLoaded(ProgressLoaded event, Emitter<ProgressState> emit) async {
    emit(state.copyWith(status: ProgressStatus.loading));
    try {
      final end = DateTime.now();
      final start = end.subtract(const Duration(days: 365));
      final logs = await _repository.getWeightLogs(start, end);
      final measurement = await _repository.getLatestMeasurement();
      emit(state.copyWith(
        status: ProgressStatus.success,
        weightLogs: logs,
        latestMeasurement: measurement,
      ));
    } catch (e) {
      emit(state.copyWith(status: ProgressStatus.failure, error: e.toString()));
    }
  }

  Future<void> _onWeightAdded(
    ProgressWeightAdded event,
    Emitter<ProgressState> emit,
  ) async {
    if (state.status != ProgressStatus.success) return;
    try {
      await _repository.addWeightLog(event.date, event.weightKg);
      final end = DateTime.now();
      final start = end.subtract(const Duration(days: 365));
      final logs = await _repository.getWeightLogs(start, end);
      emit(state.copyWith(weightLogs: logs));
    } catch (e) {
      emit(state.copyWith(status: ProgressStatus.failure, error: e.toString()));
    }
  }
}
