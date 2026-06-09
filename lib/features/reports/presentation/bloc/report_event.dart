import 'package:equatable/equatable.dart';

abstract class ReportEvent extends Equatable {
  const ReportEvent();

  @override
  List<Object?> get props => [];
}

class ReportGenerated extends ReportEvent {
  final DateTime start;
  final DateTime end;

  const ReportGenerated({required this.start, required this.end});

  @override
  List<Object?> get props => [start, end];
}
