import 'package:equatable/equatable.dart';

class WeeklyStat extends Equatable {
  final DateTime weekStart;
  final int routineDaysDone;
  final int cardioDaysDone;

  const WeeklyStat({
    required this.weekStart,
    required this.routineDaysDone,
    required this.cardioDaysDone,
  });

  @override
  List<Object?> get props => [weekStart, routineDaysDone, cardioDaysDone];
}
