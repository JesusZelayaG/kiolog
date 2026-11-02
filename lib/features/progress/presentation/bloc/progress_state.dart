import 'package:equatable/equatable.dart';
import 'package:kiolog/core/database/app_database.dart';

enum ProgressStatus { initial, loading, success, failure }

class ProgressState extends Equatable {
  final ProgressStatus status;
  final List<WeightLog> weightLogs;
  final Measurement? latestMeasurement;
  final String? error;

  const ProgressState({
    this.status = ProgressStatus.initial,
    this.weightLogs = const [],
    this.latestMeasurement,
    this.error,
  });

  double? get latestWeight =>
      weightLogs.isNotEmpty ? weightLogs.last.weightKg : null;

  double? get startingWeight =>
      weightLogs.isNotEmpty ? weightLogs.first.weightKg : null;

  double? get weightChange =>
      latestWeight != null && startingWeight != null
          ? latestWeight! - startingWeight!
          : null;

  ProgressState copyWith({
    ProgressStatus? status,
    List<WeightLog>? weightLogs,
    Measurement? latestMeasurement,
    String? error,
  }) =>
      ProgressState(
        status: status ?? this.status,
        weightLogs: weightLogs ?? this.weightLogs,
        latestMeasurement: latestMeasurement ?? this.latestMeasurement,
        error: error,
      );

  @override
  List<Object?> get props => [status, weightLogs, latestMeasurement, error];
}
