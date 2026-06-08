import 'package:equatable/equatable.dart';
import 'package:kiolog/core/database/app_database.dart';

enum ExerciseStatus { initial, loading, success, failure }

class ExerciseState extends Equatable {
  final ExerciseStatus status;
  final ExercisePlan? activePlan;
  final List<ExercisePlan> allPlans;
  final ExerciseRoutine? todayRoutine;
  final List<ExerciseRoutineItem> routineItems;
  final DailyExerciseLog? dailyLog;
  final ExerciseSessionLog? activeSession;
  final List<ExerciseSetLog> sessionSets;
  final List<ExerciseSessionLog> recentSessions;
  final String? error;

  const ExerciseState({
    this.status = ExerciseStatus.initial,
    this.activePlan,
    this.allPlans = const [],
    this.todayRoutine,
    this.routineItems = const [],
    this.dailyLog,
    this.activeSession,
    this.sessionSets = const [],
    this.recentSessions = const [],
    this.error,
  });

  bool get hasActiveSession =>
      activeSession != null && activeSession!.gymLeftAt == null;

  ExerciseState copyWith({
    ExerciseStatus? status,
    ExercisePlan? activePlan,
    List<ExercisePlan>? allPlans,
    ExerciseRoutine? todayRoutine,
    List<ExerciseRoutineItem>? routineItems,
    DailyExerciseLog? dailyLog,
    ExerciseSessionLog? activeSession,
    List<ExerciseSetLog>? sessionSets,
    List<ExerciseSessionLog>? recentSessions,
    String? error,
  }) =>
      ExerciseState(
        status: status ?? this.status,
        activePlan: activePlan,
        allPlans: allPlans ?? this.allPlans,
        todayRoutine: todayRoutine,
        routineItems: routineItems ?? this.routineItems,
        dailyLog: dailyLog,
        activeSession: activeSession,
        sessionSets: sessionSets ?? this.sessionSets,
        recentSessions: recentSessions ?? this.recentSessions,
        error: error,
      );

  @override
  List<Object?> get props => [
        status,
        activePlan,
        allPlans,
        todayRoutine,
        routineItems,
        dailyLog,
        activeSession,
        sessionSets,
        recentSessions,
        error,
      ];
}
