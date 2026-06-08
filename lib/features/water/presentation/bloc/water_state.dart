import 'package:equatable/equatable.dart';

enum WaterStatus { initial, loading, success, failure }

class WaterState extends Equatable {
  final WaterStatus status;
  final int dailyTotalMl;
  final int dailyGoalMl;
  final String unitType;
  final int containerMl;
  final String? error;

  const WaterState({
    this.status = WaterStatus.initial,
    this.dailyTotalMl = 0,
    this.dailyGoalMl = 3000,
    this.unitType = 'bottle',
    this.containerMl = 1000,
    this.error,
  });

  double get progress => dailyGoalMl > 0 ? dailyTotalMl / dailyGoalMl : 0.0;

  WaterState copyWith({
    WaterStatus? status,
    int? dailyTotalMl,
    int? dailyGoalMl,
    String? unitType,
    int? containerMl,
    String? error,
  }) =>
      WaterState(
        status: status ?? this.status,
        dailyTotalMl: dailyTotalMl ?? this.dailyTotalMl,
        dailyGoalMl: dailyGoalMl ?? this.dailyGoalMl,
        unitType: unitType ?? this.unitType,
        containerMl: containerMl ?? this.containerMl,
        error: error,
      );

  @override
  List<Object?> get props =>
      [status, dailyTotalMl, dailyGoalMl, unitType, containerMl, error];
}
