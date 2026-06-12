import 'package:equatable/equatable.dart';
import 'package:kiolog/core/database/app_database.dart';

enum DayDetailStatus { initial, loading, success, failure }

class DayDetailState extends Equatable {
  final DayDetailStatus status;
  final DateTime date;
  final List<DailyWaterLog> waterLogs;
  final List<DailyMealLog> mealLogs;
  final Map<int, MealPlanOption> mealOptions;
  final List<ExerciseSessionLog> exerciseSessions;
  final DailyExerciseLog? exerciseLog;
  final String? error;

  const DayDetailState({
    this.status = DayDetailStatus.initial,
    required this.date,
    this.waterLogs = const [],
    this.mealLogs = const [],
    this.mealOptions = const {},
    this.exerciseSessions = const [],
    this.exerciseLog,
    this.error,
  });

  int get totalWaterMl =>
      waterLogs.fold(0, (sum, log) => sum + log.amountMl);

  bool get hasWater => waterLogs.isNotEmpty;
  bool get hasMeals => mealLogs.isNotEmpty;
  bool get hasExercise =>
      (exerciseLog?.completed ?? false) || exerciseSessions.isNotEmpty;

  int get completedSegments =>
      (hasWater ? 1 : 0) + (hasMeals ? 1 : 0) + (hasExercise ? 1 : 0);

  DayDetailState copyWith({
    DayDetailStatus? status,
    DateTime? date,
    List<DailyWaterLog>? waterLogs,
    List<DailyMealLog>? mealLogs,
    Map<int, MealPlanOption>? mealOptions,
    List<ExerciseSessionLog>? exerciseSessions,
    DailyExerciseLog? exerciseLog,
    bool clearExerciseLog = false,
    String? error,
  }) =>
      DayDetailState(
        status: status ?? this.status,
        date: date ?? this.date,
        waterLogs: waterLogs ?? this.waterLogs,
        mealLogs: mealLogs ?? this.mealLogs,
        mealOptions: mealOptions ?? this.mealOptions,
        exerciseSessions: exerciseSessions ?? this.exerciseSessions,
        exerciseLog: clearExerciseLog ? null : (exerciseLog ?? this.exerciseLog),
        error: error ?? this.error,
      );

  @override
  List<Object?> get props => [
        status,
        date,
        waterLogs,
        mealLogs,
        mealOptions,
        exerciseSessions,
        exerciseLog,
        error,
      ];
}
