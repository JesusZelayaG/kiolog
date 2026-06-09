import 'package:equatable/equatable.dart';

enum HomeStatus { initial, loading, success, failure }

class HomeState extends Equatable {
  final HomeStatus status;
  final int dailyWaterTotalMl;
  final int dailyWaterGoalMl;
  final double? sleepHours;
  final int mealsLogged;
  final int totalMeals;
  final bool exerciseRoutineDone;
  final bool hasGymSession;
  final String? error;

  const HomeState({
    this.status = HomeStatus.initial,
    this.dailyWaterTotalMl = 0,
    this.dailyWaterGoalMl = 3000,
    this.sleepHours,
    this.mealsLogged = 0,
    this.totalMeals = 4,
    this.exerciseRoutineDone = false,
    this.hasGymSession = false,
    this.error,
  });

  double get waterProgress =>
      dailyWaterGoalMl > 0 ? dailyWaterTotalMl / dailyWaterGoalMl : 0.0;

  HomeState copyWith({
    HomeStatus? status,
    int? dailyWaterTotalMl,
    int? dailyWaterGoalMl,
    double? sleepHours,
    int? mealsLogged,
    int? totalMeals,
    bool? exerciseRoutineDone,
    bool? hasGymSession,
    String? error,
  }) =>
      HomeState(
        status: status ?? this.status,
        dailyWaterTotalMl: dailyWaterTotalMl ?? this.dailyWaterTotalMl,
        dailyWaterGoalMl: dailyWaterGoalMl ?? this.dailyWaterGoalMl,
        sleepHours: sleepHours,
        mealsLogged: mealsLogged ?? this.mealsLogged,
        totalMeals: totalMeals ?? this.totalMeals,
        exerciseRoutineDone: exerciseRoutineDone ?? this.exerciseRoutineDone,
        hasGymSession: hasGymSession ?? this.hasGymSession,
        error: error,
      );

  @override
  List<Object?> get props => [
        status,
        dailyWaterTotalMl,
        dailyWaterGoalMl,
        sleepHours,
        mealsLogged,
        totalMeals,
        exerciseRoutineDone,
        hasGymSession,
        error,
      ];
}
