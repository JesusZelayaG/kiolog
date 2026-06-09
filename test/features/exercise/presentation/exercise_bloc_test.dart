import 'package:bloc_test/bloc_test.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kiolog/core/database/app_database.dart';
import 'package:kiolog/features/exercise/domain/repositories/exercise_repository.dart';
import 'package:kiolog/features/exercise/presentation/bloc/exercise_bloc.dart';
import 'package:kiolog/features/exercise/presentation/bloc/exercise_event.dart';
import 'package:kiolog/features/exercise/presentation/bloc/exercise_state.dart';
import 'package:mocktail/mocktail.dart';

class MockExerciseRepository extends Mock implements ExerciseRepository {}

void main() {
  late MockExerciseRepository repository;

  setUp(() {
    repository = MockExerciseRepository();
  });

  group('ExerciseBloc', () {
    final plan = ExercisePlan(id: 1, name: 'Gym', createdAt: DateTime.now(), isActive: true);
    final routine = ExerciseRoutine(id: 1, planId: 1, dayNumber: 1, routineName: 'Pecho', notes: null);
    final items = [
      ExerciseRoutineItem(id: 1, routineId: 1, exerciseName: 'Press', sets: 4, reps: 10, weightKg: 60),
    ];

    blocTest<ExerciseBloc, ExerciseState>(
      'emits [loading, success] when ExerciseLoaded succeeds',
      build: () {
        when(() => repository.getActivePlan()).thenAnswer((_) async => plan);
        when(() => repository.getDailyLog(any())).thenAnswer((_) async => null);
        when(() => repository.getRoutinesForPlan(any())).thenAnswer((_) async => [routine]);
        when(() => repository.getRoutineItems(any())).thenAnswer((_) async => items);
        when(() => repository.getSessionsForDate(any())).thenAnswer((_) async => []);
        return ExerciseBloc(repository);
      },
      act: (bloc) => bloc.add(ExerciseLoaded(date: DateTime(2026, 6, 8))),
      expect: () => [
        const ExerciseState(status: ExerciseStatus.loading),
        ExerciseState(
          status: ExerciseStatus.success,
          activePlan: plan,
          routines: [routine],
          routineItemsByRoutine: {1: items},
        ),
      ],
    );

    blocTest<ExerciseBloc, ExerciseState>(
      'starts session and updates state',
      build: () {
        final session = ExerciseSessionLog(
          id: 1,
          date: DateTime(2026, 6, 8),
          gymArrivedAt: DateTime(2026, 6, 8, 10, 0),
        );
        when(() => repository.startSession(any(), routineId: any(named: 'routineId'))).thenAnswer((_) async => 1);
        when(() => repository.getSession(any())).thenAnswer((_) async => session);
        when(() => repository.getSessionsForDate(any())).thenAnswer((_) async => [session]);
        return ExerciseBloc(repository)
          ..emit(const ExerciseState(status: ExerciseStatus.success));
      },
      act: (bloc) => bloc.add(ExerciseSessionStarted(date: DateTime(2026, 6, 8))),
      expect: () => [
        ExerciseState(
          status: ExerciseStatus.success,
          activeSession: ExerciseSessionLog(
            id: 1,
            date: DateTime(2026, 6, 8),
            gymArrivedAt: DateTime(2026, 6, 8, 10, 0),
          ),
          recentSessions: [
            ExerciseSessionLog(
              id: 1,
              date: DateTime(2026, 6, 8),
              gymArrivedAt: DateTime(2026, 6, 8, 10, 0),
            ),
          ],
        ),
      ],
    );

    blocTest<ExerciseBloc, ExerciseState>(
      'ends session and updates state',
      build: () {
        final session = ExerciseSessionLog(
          id: 1,
          date: DateTime(2026, 6, 8),
          gymArrivedAt: DateTime(2026, 6, 8, 10, 0),
          gymLeftAt: DateTime(2026, 6, 8, 11, 0),
        );
        when(() => repository.endSession(any())).thenAnswer((_) async {});
        when(() => repository.getSession(any())).thenAnswer((_) async => session);
        return ExerciseBloc(repository)
          ..emit(ExerciseState(
            status: ExerciseStatus.success,
            activeSession: ExerciseSessionLog(
              id: 1,
              date: DateTime(2026, 6, 8),
              gymArrivedAt: DateTime(2026, 6, 8, 10, 0),
            ),
          ));
      },
      act: (bloc) => bloc.add(const ExerciseSessionEnded(sessionId: 1)),
      expect: () => [
        ExerciseState(
          status: ExerciseStatus.success,
          activeSession: ExerciseSessionLog(
            id: 1,
            date: DateTime(2026, 6, 8),
            gymArrivedAt: DateTime(2026, 6, 8, 10, 0),
            gymLeftAt: DateTime(2026, 6, 8, 11, 0),
          ),
        ),
      ],
    );
  });
}
