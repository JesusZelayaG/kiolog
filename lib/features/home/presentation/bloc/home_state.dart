import 'package:equatable/equatable.dart';

enum HomeStatus { initial, loading, success, failure }

class HomeState extends Equatable {
  final HomeStatus status;
  final int dailyWaterTotalMl;
  final int dailyWaterGoalMl;

  /// Lo que suma un toque en "+": el envase configurado.
  final int waterContainerMl;
  final String waterContainerLabel;
  final double? sleepHours;

  /// Horas dormidas de los últimos 7 días, de hace 6 días a hoy.
  final List<double> sleepWeek;
  final int mealsLogged;
  final int totalMeals;

  /// El primer tiempo de comida del plan que falta hoy.
  final String? nextMeal;
  final bool exerciseRoutineDone;
  final bool hasGymSession;

  /// La rutina que toca: la primera de la semana que no se ha hecho.
  final String? routineName;
  final int? routineDay;
  final int routineExercises;
  final int weekRoutineDays;
  final int weekRoutineGoal;
  final String? error;

  const HomeState({
    this.status = HomeStatus.initial,
    this.dailyWaterTotalMl = 0,
    this.dailyWaterGoalMl = 3000,
    this.waterContainerMl = 250,
    this.waterContainerLabel = 'vaso',
    this.sleepHours,
    this.sleepWeek = const [0, 0, 0, 0, 0, 0, 0],
    this.mealsLogged = 0,
    this.totalMeals = 4,
    this.nextMeal,
    this.exerciseRoutineDone = false,
    this.hasGymSession = false,
    this.routineName,
    this.routineDay,
    this.routineExercises = 0,
    this.weekRoutineDays = 0,
    this.weekRoutineGoal = 4,
    this.error,
  });

  double get waterProgress =>
      dailyWaterGoalMl > 0 ? dailyWaterTotalMl / dailyWaterGoalMl : 0.0;

  double get mealsProgress => totalMeals > 0 ? mealsLogged / totalMeals : 0.0;

  double get sleepProgress => ((sleepHours ?? 0) / 8).clamp(0.0, 1.0);

  double get exerciseProgress => exerciseRoutineDone ? 1.0 : (hasGymSession ? 0.5 : 0.0);

  HomeState copyWith({
    HomeStatus? status,
    int? dailyWaterTotalMl,
    String? error,
  }) =>
      HomeState(
        status: status ?? this.status,
        dailyWaterTotalMl: dailyWaterTotalMl ?? this.dailyWaterTotalMl,
        dailyWaterGoalMl: dailyWaterGoalMl,
        waterContainerMl: waterContainerMl,
        waterContainerLabel: waterContainerLabel,
        sleepHours: sleepHours,
        sleepWeek: sleepWeek,
        mealsLogged: mealsLogged,
        totalMeals: totalMeals,
        nextMeal: nextMeal,
        exerciseRoutineDone: exerciseRoutineDone,
        hasGymSession: hasGymSession,
        routineName: routineName,
        routineDay: routineDay,
        routineExercises: routineExercises,
        weekRoutineDays: weekRoutineDays,
        weekRoutineGoal: weekRoutineGoal,
        error: error,
      );

  @override
  List<Object?> get props => [
        status,
        dailyWaterTotalMl,
        dailyWaterGoalMl,
        waterContainerMl,
        waterContainerLabel,
        sleepHours,
        sleepWeek,
        mealsLogged,
        totalMeals,
        nextMeal,
        exerciseRoutineDone,
        hasGymSession,
        routineName,
        routineDay,
        routineExercises,
        weekRoutineDays,
        weekRoutineGoal,
        error,
      ];
}
