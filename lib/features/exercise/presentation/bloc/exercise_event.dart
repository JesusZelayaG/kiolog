import 'package:equatable/equatable.dart';

abstract class ExerciseEvent extends Equatable {
  const ExerciseEvent();

  @override
  List<Object?> get props => [];
}

// ── Carga ────────────────────────────────────────────────────────────────────

class ExerciseLoaded extends ExerciseEvent {
  final DateTime date;
  const ExerciseLoaded({required this.date});
  @override
  List<Object?> get props => [date];
}

class ExercisePlanLoaded extends ExerciseEvent {
  const ExercisePlanLoaded();
}

// ── Planes ───────────────────────────────────────────────────────────────────

class ExercisePlanActivated extends ExerciseEvent {
  final int planId;
  const ExercisePlanActivated({required this.planId});
  @override
  List<Object?> get props => [planId];
}

class ExercisePlanCreated extends ExerciseEvent {
  final String name;
  const ExercisePlanCreated({required this.name});
  @override
  List<Object?> get props => [name];
}

// ── Rutinas ──────────────────────────────────────────────────────────────────

class ExerciseRoutineAdded extends ExerciseEvent {
  final int planId;
  final int dayNumber;
  final String routineName;
  const ExerciseRoutineAdded({
    required this.planId,
    required this.dayNumber,
    required this.routineName,
  });
  @override
  List<Object?> get props => [planId, dayNumber, routineName];
}

// ── Items de rutina ──────────────────────────────────────────────────────────

class ExerciseRoutineItemAdded extends ExerciseEvent {
  final int routineId;
  final String exerciseName;
  final int sets;
  final int reps;
  final double? weightKg;
  final String setType;
  final int orderIndex;
  final List<({int setNumber, int? dropOfSetNumber, int reps, double? weightKg})>
      setDefs;

  const ExerciseRoutineItemAdded({
    required this.routineId,
    required this.exerciseName,
    required this.sets,
    required this.reps,
    this.weightKg,
    this.setType = 'normal',
    this.orderIndex = 0,
    this.setDefs = const [],
  });

  @override
  List<Object?> get props =>
      [routineId, exerciseName, sets, reps, weightKg, setType, orderIndex];
}

class ExerciseRoutineItemUpdated extends ExerciseEvent {
  final int itemId;
  final String? exerciseName;
  final int? sets;
  final int? reps;
  final double? weightKg;
  final String? setType;
  final List<({int setNumber, int? dropOfSetNumber, int reps, double? weightKg})>?
      setDefs;

  const ExerciseRoutineItemUpdated({
    required this.itemId,
    this.exerciseName,
    this.sets,
    this.reps,
    this.weightKg,
    this.setType,
    this.setDefs,
  });

  @override
  List<Object?> get props => [itemId, exerciseName, sets, reps, weightKg, setType];
}

class ExerciseRoutineItemDeleted extends ExerciseEvent {
  final int itemId;
  final int routineId;
  const ExerciseRoutineItemDeleted({
    required this.itemId,
    required this.routineId,
  });
  @override
  List<Object?> get props => [itemId, routineId];
}

// ── Sesión ───────────────────────────────────────────────────────────────────

class ExerciseSessionStarted extends ExerciseEvent {
  final DateTime date;
  final int? routineId;
  const ExerciseSessionStarted({required this.date, this.routineId});
  @override
  List<Object?> get props => [date, routineId];
}

class ExerciseSessionEnded extends ExerciseEvent {
  final int sessionId;
  const ExerciseSessionEnded({required this.sessionId});
  @override
  List<Object?> get props => [sessionId];
}

class ExerciseItemCompleted extends ExerciseEvent {
  final int routineItemId;
  const ExerciseItemCompleted({required this.routineItemId});
  @override
  List<Object?> get props => [routineItemId];
}

// ── Sets ─────────────────────────────────────────────────────────────────────

class ExerciseSetLogged extends ExerciseEvent {
  final int sessionId;
  final String exerciseName;
  final int setNumber;
  final int reps;
  final double? weightKg;
  final String setType;
  final int? dropOfSetId;

  const ExerciseSetLogged({
    required this.sessionId,
    required this.exerciseName,
    required this.setNumber,
    required this.reps,
    this.weightKg,
    this.setType = 'normal',
    this.dropOfSetId,
  });

  @override
  List<Object?> get props =>
      [sessionId, exerciseName, setNumber, reps, weightKg, setType, dropOfSetId];
}

// ── Cardio ───────────────────────────────────────────────────────────────────

class CardioLogged extends ExerciseEvent {
  final DateTime date;
  final String cardioType;
  final int durationMinutes;
  final String? notes;

  const CardioLogged({
    required this.date,
    required this.cardioType,
    required this.durationMinutes,
    this.notes,
  });

  @override
  List<Object?> get props => [date, cardioType, durationMinutes, notes];
}

class CardioUpdated extends ExerciseEvent {
  final int cardioId;
  final String? cardioType;
  final int? durationMinutes;
  final String? notes;

  const CardioUpdated({
    required this.cardioId,
    this.cardioType,
    this.durationMinutes,
    this.notes,
  });

  @override
  List<Object?> get props => [cardioId, cardioType, durationMinutes, notes];
}

class CardioDeleted extends ExerciseEvent {
  final int cardioId;
  const CardioDeleted({required this.cardioId});
  @override
  List<Object?> get props => [cardioId];
}

// ── Ejercicio independiente ───────────────────────────────────────────────────

class IndependentExerciseLogged extends ExerciseEvent {
  final DateTime date;
  final String exerciseName;
  final int sets;
  final int reps;
  final double? weightKg;

  const IndependentExerciseLogged({
    required this.date,
    required this.exerciseName,
    required this.sets,
    required this.reps,
    this.weightKg,
  });

  @override
  List<Object?> get props => [date, exerciseName, sets, reps, weightKg];
}

class IndependentExerciseDeleted extends ExerciseEvent {
  final int sessionId;
  const IndependentExerciseDeleted({required this.sessionId});
  @override
  List<Object?> get props => [sessionId];
}

// ── Config ───────────────────────────────────────────────────────────────────

class ExerciseConfigUpdated extends ExerciseEvent {
  final int? weeklyRoutineDaysGoal;
  final int? weeklyCardioDaysGoal;
  final int? cardioMinutesGoal;

  const ExerciseConfigUpdated({
    this.weeklyRoutineDaysGoal,
    this.weeklyCardioDaysGoal,
    this.cardioMinutesGoal,
  });

  @override
  List<Object?> get props =>
      [weeklyRoutineDaysGoal, weeklyCardioDaysGoal, cardioMinutesGoal];
}

// ── Legacy ───────────────────────────────────────────────────────────────────

class ExerciseRoutineMarkedDone extends ExerciseEvent {
  final DateTime date;
  final int routineId;
  const ExerciseRoutineMarkedDone({required this.date, required this.routineId});
  @override
  List<Object?> get props => [date, routineId];
}
