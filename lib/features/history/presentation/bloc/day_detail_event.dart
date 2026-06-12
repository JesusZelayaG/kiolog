import 'package:equatable/equatable.dart';

abstract class DayDetailEvent extends Equatable {
  const DayDetailEvent();

  @override
  List<Object?> get props => [];
}

class DayDetailLoaded extends DayDetailEvent {
  final DateTime date;

  const DayDetailLoaded({required this.date});

  @override
  List<Object?> get props => [date];
}
