import 'package:equatable/equatable.dart';

class IndependentExerciseLog extends Equatable {
  final int sessionId;
  final DateTime date;
  final String exerciseName;
  final int sets;
  final int reps;
  final double? weightKg;

  const IndependentExerciseLog({
    required this.sessionId,
    required this.date,
    required this.exerciseName,
    required this.sets,
    required this.reps,
    this.weightKg,
  });

  @override
  List<Object?> get props =>
      [sessionId, date, exerciseName, sets, reps, weightKg];
}
