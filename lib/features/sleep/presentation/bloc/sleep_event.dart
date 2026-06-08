import 'package:equatable/equatable.dart';

abstract class SleepEvent extends Equatable {
  const SleepEvent();

  @override
  List<Object?> get props => [];
}

class SleepLoaded extends SleepEvent {
  final DateTime date;

  const SleepLoaded({required this.date});

  @override
  List<Object?> get props => [date];
}

class SleepWeeklyLoaded extends SleepEvent {
  final DateTime endDate;

  const SleepWeeklyLoaded({required this.endDate});

  @override
  List<Object?> get props => [endDate];
}

class SleepLogAdded extends SleepEvent {
  final DateTime date;
  final DateTime sleepTime;
  final DateTime wakeTime;

  const SleepLogAdded({
    required this.date,
    required this.sleepTime,
    required this.wakeTime,
  });

  @override
  List<Object?> get props => [date, sleepTime, wakeTime];
}
