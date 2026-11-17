import 'package:equatable/equatable.dart';
import 'package:kiolog/core/database/app_database.dart';

enum WaterStatus { initial, loading, success, failure }

class WaterState extends Equatable {
  final WaterStatus status;
  final int dailyTotalMl;
  final int dailyGoalMl;

  /// Las tomas de hoy, de la primera a la última.
  final List<DailyWaterLog> logs;
  final String? error;

  const WaterState({
    this.status = WaterStatus.initial,
    this.dailyTotalMl = 0,
    this.dailyGoalMl = 3000,
    this.logs = const [],
    this.error,
  });

  double get progress => dailyGoalMl > 0 ? dailyTotalMl / dailyGoalMl : 0.0;

  WaterState copyWith({
    WaterStatus? status,
    int? dailyTotalMl,
    int? dailyGoalMl,
    List<DailyWaterLog>? logs,
    String? error,
  }) =>
      WaterState(
        status: status ?? this.status,
        dailyTotalMl: dailyTotalMl ?? this.dailyTotalMl,
        dailyGoalMl: dailyGoalMl ?? this.dailyGoalMl,
        logs: logs ?? this.logs,
        error: error,
      );

  @override
  List<Object?> get props => [status, dailyTotalMl, dailyGoalMl, logs, error];
}
