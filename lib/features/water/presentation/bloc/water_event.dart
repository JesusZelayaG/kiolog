import 'package:equatable/equatable.dart';

abstract class WaterEvent extends Equatable {
  const WaterEvent();

  @override
  List<Object?> get props => [];
}

class WaterLoaded extends WaterEvent {
  final DateTime date;

  const WaterLoaded({required this.date});

  @override
  List<Object?> get props => [date];
}

/// Una toma de [amountMl], escrita en ml o litros.
class WaterAdded extends WaterEvent {
  final DateTime date;
  final int amountMl;

  const WaterAdded({required this.date, required this.amountMl});

  @override
  List<Object?> get props => [date, amountMl];
}

/// Quita una toma registrada por error.
class WaterLogDeleted extends WaterEvent {
  final int logId;

  const WaterLogDeleted(this.logId);

  @override
  List<Object?> get props => [logId];
}

class WaterGoalUpdated extends WaterEvent {
  final int dailyGoalMl;

  const WaterGoalUpdated(this.dailyGoalMl);

  @override
  List<Object?> get props => [dailyGoalMl];
}
