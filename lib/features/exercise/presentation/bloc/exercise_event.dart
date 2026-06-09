import 'package:equatable/equatable.dart';

abstract class ExerciseEvent extends Equatable {
  const ExerciseEvent();

  @override
  List<Object?> get props => [];
}

class ExerciseLoaded extends ExerciseEvent {
  final DateTime date;

  const ExerciseLoaded({required this.date});

  @override
  List<Object?> get props => [date];
}

class ExercisePlanLoaded extends ExerciseEvent {
  const ExercisePlanLoaded();
}

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

class ExerciseRoutineMarkedDone extends ExerciseEvent {
  final DateTime date;
  final int routineId;

  const ExerciseRoutineMarkedDone({
    required this.date,
    required this.routineId,
  });

  @override
  List<Object?> get props => [date, routineId];
}

class ExerciseSessionStarted extends ExerciseEvent {
  final DateTime date;
  final int? routineId;

  const ExerciseSessionStarted({required this.date, this.routineId});

  @override
  List<Object?> get props => [date, routineId];
}

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

class ExerciseSessionEnded extends ExerciseEvent {
  final int sessionId;

  const ExerciseSessionEnded({required this.sessionId});

  @override
  List<Object?> get props => [sessionId];
}

class ExerciseSetLogged extends ExerciseEvent {
  final int sessionId;
  final String exerciseName;
  final int setNumber;
  final int reps;
  final double weightKg;

  const ExerciseSetLogged({
    required this.sessionId,
    required this.exerciseName,
    required this.setNumber,
    required this.reps,
    required this.weightKg,
  });

  @override
  List<Object?> get props => [sessionId, exerciseName, setNumber, reps, weightKg];
}
