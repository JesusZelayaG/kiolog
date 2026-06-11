import 'package:flutter_bloc/flutter_bloc.dart';
import '../../domain/repositories/sleep_repository.dart';
import 'sleep_event.dart';
import 'sleep_state.dart';

class SleepBloc extends Bloc<SleepEvent, SleepState> {
  final SleepRepository _repository;

  SleepBloc(this._repository) : super(const SleepState()) {
    on<SleepLoaded>(_onLoaded);
    on<SleepWeeklyLoaded>(_onWeeklyLoaded);
    on<SleepLogAdded>(_onLogAdded);
    on<SleepLogDeleted>(_onLogDeleted);
  }

  Future<void> _onLoaded(SleepLoaded event, Emitter<SleepState> emit) async {
    emit(state.copyWith(status: SleepStatus.loading));
    try {
      final logs = await _repository.getSleepLogsForDate(event.date);
      emit(state.copyWith(status: SleepStatus.success, todayLogs: logs));
    } catch (e) {
      emit(state.copyWith(status: SleepStatus.failure, error: e.toString()));
    }
  }

  Future<void> _onWeeklyLoaded(
    SleepWeeklyLoaded event,
    Emitter<SleepState> emit,
  ) async {
    emit(state.copyWith(status: SleepStatus.loading));
    try {
      final start = event.endDate.subtract(const Duration(days: 6));
      final logs = await _repository.getSleepLogsInRange(start, event.endDate);
      emit(state.copyWith(status: SleepStatus.success, weeklyLogs: logs));
    } catch (e) {
      emit(state.copyWith(status: SleepStatus.failure, error: e.toString()));
    }
  }

  Future<void> _onLogAdded(SleepLogAdded event, Emitter<SleepState> emit) async {
    emit(state.copyWith(status: SleepStatus.loading));
    try {
      await _repository.addSleepLog(
        date: event.date,
        sleepTime: event.sleepTime,
        wakeTime: event.wakeTime,
        type: event.type,
      );
      final todayLogs = await _repository.getSleepLogsForDate(event.date);
      final start = event.date.subtract(const Duration(days: 6));
      final weeklyLogs = await _repository.getSleepLogsInRange(start, event.date);
      emit(state.copyWith(status: SleepStatus.success, todayLogs: todayLogs, weeklyLogs: weeklyLogs));
    } catch (e) {
      emit(state.copyWith(status: SleepStatus.failure, error: e.toString()));
    }
  }

  Future<void> _onLogDeleted(SleepLogDeleted event, Emitter<SleepState> emit) async {
    emit(state.copyWith(status: SleepStatus.loading));
    try {
      await _repository.deleteSleepLog(event.id);
      final todayLogs = await _repository.getSleepLogsForDate(event.date);
      final start = event.date.subtract(const Duration(days: 6));
      final weeklyLogs = await _repository.getSleepLogsInRange(start, event.date);
      emit(state.copyWith(status: SleepStatus.success, todayLogs: todayLogs, weeklyLogs: weeklyLogs));
    } catch (e) {
      emit(state.copyWith(status: SleepStatus.failure, error: e.toString()));
    }
  }
}
