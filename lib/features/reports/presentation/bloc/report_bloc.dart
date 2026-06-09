import 'package:flutter_bloc/flutter_bloc.dart';
import '../../domain/repositories/report_repository.dart';
import 'report_event.dart';
import 'report_state.dart';

class ReportBloc extends Bloc<ReportEvent, ReportState> {
  final ReportRepository _repository;

  ReportBloc(this._repository) : super(const ReportState()) {
    on<ReportGenerated>(_onGenerated);
  }

  Future<void> _onGenerated(
    ReportGenerated event,
    Emitter<ReportState> emit,
  ) async {
    emit(state.copyWith(status: ReportStatus.loading));
    try {
      final data = await _repository.generateReport(event.start, event.end);
      emit(state.copyWith(status: ReportStatus.success, data: data));
    } catch (e) {
      emit(state.copyWith(status: ReportStatus.failure, error: e.toString()));
    }
  }
}
