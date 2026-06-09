import 'package:equatable/equatable.dart';

abstract class HistoryEvent extends Equatable {
  const HistoryEvent();

  @override
  List<Object?> get props => [];
}

class HistoryMonthLoaded extends HistoryEvent {
  final DateTime month;

  const HistoryMonthLoaded({required this.month});

  @override
  List<Object?> get props => [month];
}

class HistoryPreviousMonth extends HistoryEvent {
  const HistoryPreviousMonth();
}

class HistoryNextMonth extends HistoryEvent {
  const HistoryNextMonth();
}
