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

class WaterAdded extends WaterEvent {
  final DateTime date;
  final int amountMl;

  const WaterAdded({required this.date, required this.amountMl});

  @override
  List<Object?> get props => [date, amountMl];
}

class WaterCustomAmountAdded extends WaterEvent {
  final DateTime date;
  final int amountMl;

  const WaterCustomAmountAdded({required this.date, required this.amountMl});

  @override
  List<Object?> get props => [date, amountMl];
}

class WaterConfigLoaded extends WaterEvent {
  const WaterConfigLoaded();
}

class WaterConfigUpdated extends WaterEvent {
  final String unitType;
  final int containerMl;
  final int dailyGoalMl;

  const WaterConfigUpdated({
    required this.unitType,
    required this.containerMl,
    required this.dailyGoalMl,
  });

  @override
  List<Object?> get props => [unitType, containerMl, dailyGoalMl];
}
