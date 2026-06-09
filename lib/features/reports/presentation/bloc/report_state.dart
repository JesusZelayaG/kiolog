import 'package:equatable/equatable.dart';
import '../../domain/repositories/report_repository.dart';

enum ReportStatus { initial, loading, success, failure }

class ReportState extends Equatable {
  final ReportStatus status;
  final ReportData? data;
  final String? error;

  const ReportState({
    this.status = ReportStatus.initial,
    this.data,
    this.error,
  });

  ReportState copyWith({
    ReportStatus? status,
    ReportData? data,
    String? error,
  }) =>
      ReportState(
        status: status ?? this.status,
        data: data,
        error: error,
      );

  @override
  List<Object?> get props => [status, data, error];
}
