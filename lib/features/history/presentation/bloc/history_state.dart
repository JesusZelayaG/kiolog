import 'package:equatable/equatable.dart';
import '../../domain/repositories/history_repository.dart';

enum HistoryStatus { initial, loading, success, failure }

class HistoryState extends Equatable {
  final HistoryStatus status;
  final DateTime currentMonth;
  final List<DaySummary> days;
  final String? error;

  const HistoryState({
    this.status = HistoryStatus.initial,
    required this.currentMonth,
    this.days = const [],
    this.error,
  });

  HistoryState copyWith({
    HistoryStatus? status,
    DateTime? currentMonth,
    List<DaySummary>? days,
    String? error,
  }) =>
      HistoryState(
        status: status ?? this.status,
        currentMonth: currentMonth ?? this.currentMonth,
        days: days ?? this.days,
        error: error,
      );

  @override
  List<Object?> get props => [status, currentMonth, days, error];
}
