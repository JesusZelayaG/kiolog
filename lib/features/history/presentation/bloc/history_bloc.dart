import 'package:flutter_bloc/flutter_bloc.dart';
import '../../domain/repositories/history_repository.dart';
import 'history_event.dart';
import 'history_state.dart';

class HistoryBloc extends Bloc<HistoryEvent, HistoryState> {
  final HistoryRepository _repository;

  HistoryBloc(this._repository)
      : super(HistoryState(currentMonth: DateTime.now())) {
    on<HistoryMonthLoaded>(_onMonthLoaded);
    on<HistoryPreviousMonth>(_onPreviousMonth);
    on<HistoryNextMonth>(_onNextMonth);
  }

  Future<void> _onMonthLoaded(
    HistoryMonthLoaded event,
    Emitter<HistoryState> emit,
  ) async {
    emit(state.copyWith(status: HistoryStatus.loading));
    try {
      final days = await _repository.getMonthSummary(event.month);
      emit(state.copyWith(
        status: HistoryStatus.success,
        currentMonth: event.month,
        days: days,
        compliance: computeMonthCompliance(days),
      ));
    } catch (e) {
      emit(state.copyWith(status: HistoryStatus.failure, error: e.toString()));
    }
  }

  void _onPreviousMonth(
    HistoryPreviousMonth event,
    Emitter<HistoryState> emit,
  ) {
    final month = DateTime(
      state.currentMonth.year,
      state.currentMonth.month - 1,
    );
    add(HistoryMonthLoaded(month: month));
  }

  void _onNextMonth(
    HistoryNextMonth event,
    Emitter<HistoryState> emit,
  ) {
    final month = DateTime(
      state.currentMonth.year,
      state.currentMonth.month + 1,
    );
    add(HistoryMonthLoaded(month: month));
  }
}
