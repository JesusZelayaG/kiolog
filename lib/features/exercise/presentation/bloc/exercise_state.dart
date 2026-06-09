import 'package:equatable/equatable.dart';
import 'package:kiolog/core/database/app_database.dart';
import 'package:kiolog/features/exercise/domain/models/weekly_stat.dart';

enum ExerciseStatus { initial, loading, success, failure }

class ExerciseState extends Equatable {
  final ExerciseStatus status;
  final ExercisePlan? activePlan;
  final List<ExercisePlan> allPlans;
  final List<ExerciseRoutine> routines;
  final Map<int, List<ExerciseRoutineItem>> routineItemsByRoutine;
  final DailyExerciseLog? dailyLog;
  final ExerciseSessionLog? activeSession;
  final List<ExerciseSetLog> sessionSets;
  final List<ExerciseSessionLog> recentSessions;
  final Set<int> completedRoutineItemIds;
  final List<CardioLog> weeklyCardioLogs;
  final int routineDaysGoal;
  final int cardioDaysGoal;
  final List<WeeklyStat> weeklyStats;
  final String? error;

  const ExerciseState({
    this.status = ExerciseStatus.initial,
    this.activePlan,
    this.allPlans = const [],
    this.routines = const [],
    this.routineItemsByRoutine = const {},
    this.dailyLog,
    this.activeSession,
    this.sessionSets = const [],
    this.recentSessions = const [],
    this.completedRoutineItemIds = const {},
    this.weeklyCardioLogs = const [],
    this.routineDaysGoal = 4,
    this.cardioDaysGoal = 3,
    this.weeklyStats = const [],
    this.error,
  });

  bool get hasActiveSession =>
      activeSession != null && activeSession!.gymLeftAt == null;

  List<ExerciseRoutineItem> get activeRoutineItems {
    final routineId = activeSession?.routineId;
    if (routineId == null) return const [];
    return routineItemsByRoutine[routineId] ?? const [];
  }

  ExerciseRoutine? routineById(int? id) {
    if (id == null) return null;
    for (final r in routines) {
      if (r.id == id) return r;
    }
    return null;
  }

  int get completedRoutineSessionsThisWeek => recentSessions
      .where((s) => s.routineId != null && s.gymLeftAt != null)
      .length;

  ExerciseState copyWith({
    ExerciseStatus? status,
    ExercisePlan? activePlan,
    List<ExercisePlan>? allPlans,
    List<ExerciseRoutine>? routines,
    Map<int, List<ExerciseRoutineItem>>? routineItemsByRoutine,
    DailyExerciseLog? dailyLog,
    ExerciseSessionLog? activeSession,
    List<ExerciseSetLog>? sessionSets,
    List<ExerciseSessionLog>? recentSessions,
    Set<int>? completedRoutineItemIds,
    List<CardioLog>? weeklyCardioLogs,
    int? routineDaysGoal,
    int? cardioDaysGoal,
    List<WeeklyStat>? weeklyStats,
    String? error,
  }) =>
      ExerciseState(
        status: status ?? this.status,
        activePlan: activePlan ?? this.activePlan,
        allPlans: allPlans ?? this.allPlans,
        routines: routines ?? this.routines,
        routineItemsByRoutine:
            routineItemsByRoutine ?? this.routineItemsByRoutine,
        dailyLog: dailyLog ?? this.dailyLog,
        activeSession: activeSession ?? this.activeSession,
        sessionSets: sessionSets ?? this.sessionSets,
        recentSessions: recentSessions ?? this.recentSessions,
        completedRoutineItemIds:
            completedRoutineItemIds ?? this.completedRoutineItemIds,
        weeklyCardioLogs: weeklyCardioLogs ?? this.weeklyCardioLogs,
        routineDaysGoal: routineDaysGoal ?? this.routineDaysGoal,
        cardioDaysGoal: cardioDaysGoal ?? this.cardioDaysGoal,
        weeklyStats: weeklyStats ?? this.weeklyStats,
        error: error,
      );

  @override
  List<Object?> get props => [
        status,
        activePlan,
        allPlans,
        routines,
        routineItemsByRoutine,
        dailyLog,
        activeSession,
        sessionSets,
        recentSessions,
        completedRoutineItemIds,
        weeklyCardioLogs,
        routineDaysGoal,
        cardioDaysGoal,
        weeklyStats,
        error,
      ];
}
