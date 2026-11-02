import 'package:equatable/equatable.dart';

abstract class ProgressEvent extends Equatable {
  const ProgressEvent();

  @override
  List<Object?> get props => [];
}

class ProgressLoaded extends ProgressEvent {
  const ProgressLoaded();
}

class ProgressWeightAdded extends ProgressEvent {
  final DateTime date;
  final double weightKg;

  const ProgressWeightAdded({required this.date, required this.weightKg});

  @override
  List<Object?> get props => [date, weightKg];
}
