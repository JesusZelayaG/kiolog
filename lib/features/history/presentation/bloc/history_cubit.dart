import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:kiolog/features/reports/domain/repositories/report_repository.dart';

import '../../domain/month_overview.dart';

class HistoryState {
  const HistoryState({required this.month, this.overview, this.loading = true, this.error});

  final DateTime month;
  final MonthOverview? overview;
  final bool loading;
  final String? error;
}

/// El calendario de un mes con el cumplimiento de cada día.
class HistoryCubit extends Cubit<HistoryState> {
  HistoryCubit(this._reports) : super(HistoryState(month: _monthOf(DateTime.now())));

  final ReportRepository _reports;

  static DateTime _monthOf(DateTime d) => DateTime(d.year, d.month);

  Future<void> load([DateTime? month]) async {
    final target = _monthOf(month ?? state.month);
    // Deja el mes anterior en pantalla mientras carga el nuevo.
    emit(HistoryState(month: target, overview: state.overview, loading: true));
    try {
      final now = DateTime.now();
      final lastDay = DateTime(target.year, target.month + 1, 0, 23, 59);
      final end = lastDay.isBefore(now) ? lastDay : now;
      final report = end.isBefore(target) ? null : await _reports.generateReport(target, end);
      if (isClosed || state.month != target) return;
      emit(HistoryState(
        month: target,
        loading: false,
        overview: buildMonthOverview(
          month: target,
          days: report?.days ?? const [],
          goals: report?.goals ?? const ReportGoals(),
          today: now,
        ),
      ));
    } catch (e) {
      if (!isClosed) emit(HistoryState(month: target, loading: false, error: e.toString()));
    }
  }

  void previous() => load(DateTime(state.month.year, state.month.month - 1));

  void next() => load(DateTime(state.month.year, state.month.month + 1));
}
