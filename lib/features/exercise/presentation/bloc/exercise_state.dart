import 'package:equatable/equatable.dart';
import 'package:kiolog/core/database/app_database.dart';

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
    this.error,
  });

  bool get hasActiveSession =>
      activeSession != null && activeSession!.gymLeftAt == null;

  /// Ejercicios de la rutina que se está entrenando en la sesión activa.
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
        error,
      ];
}
