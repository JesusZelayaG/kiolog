import 'package:bloc_test/bloc_test.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kiolog/core/database/app_database.dart';
import 'package:kiolog/features/exercise/domain/repositories/exercise_repository.dart';
import 'package:kiolog/features/exercise/presentation/bloc/exercise_bloc.dart';
import 'package:kiolog/features/exercise/presentation/bloc/exercise_event.dart';
import 'package:kiolog/features/exercise/presentation/bloc/exercise_state.dart';
import 'package:mocktail/mocktail.dart';
import 'package:kiolog/features/exercise/domain/models/independent_exercise_log.dart';

class MockExerciseRepository extends Mock implements ExerciseRepository {}

void main() {
  late MockExerciseRepository repository;

  setUp(() {
    repository = MockExerciseRepository();
  });

  group('ExerciseBloc', () {
    final plan = ExercisePlan(id: 1, name: 'Gym', createdAt: DateTime.now(), isActive: true);
    const routine = ExerciseRoutine(id: 1, planId: 1, dayNumber: 1, routineName: 'Pecho', notes: null);
    final items = [
      const ExerciseRoutineItem(id: 1, routineId: 1, exerciseName: 'Press', sets: 4, reps: 10, weightKg: 60, setType: 'normal', orderIndex: 0),
    ];

    blocTest<ExerciseBloc, ExerciseState>(
      'emits [loading, success] when ExerciseLoaded succeeds',
      build: () {
        when(() => repository.getActivePlan()).thenAnswer((_) async => plan);
        when(() => repository.getDailyLog(any())).thenAnswer((_) async => null);
        when(() => repository.getRoutinesForPlan(any())).thenAnswer((_) async => [routine]);
        when(() => repository.getRoutineItemsOrdered(any())).thenAnswer((_) async => items);
        when(() => repository.getSessionsForDate(any())).thenAnswer((_) async => []);
        when(() => repository.getExerciseConfig()).thenAnswer((_) async => null);
        when(() => repository.getCardioLogsForWeek(any())).thenAnswer((_) async => []);
        when(() => repository.getWeeklyStats(weeksBack: any(named: 'weeksBack'))).thenAnswer((_) async => []);
        when(() => repository.getCompletedRoutineSessionsForWeek(any()))
            .thenAnswer((_) async => []);
        when(() => repository.getIndependentSessionsForWeek(any()))
            .thenAnswer((_) async => []);
        return ExerciseBloc(repository);
      },
      act: (bloc) => bloc.add(ExerciseLoaded(date: DateTime(2026, 6, 8))),
      expect: () => [
        const ExerciseState(status: ExerciseStatus.loading),
        ExerciseState(
          status: ExerciseStatus.success,
          activePlan: plan,
          routines: const [routine],
          routineItemsByRoutine: {1: items},
        ),
      ],
    );

    blocTest<ExerciseBloc, ExerciseState>(
      'ExerciseLoaded populates completedRoutineSessionsThisWeek and weeklyIndependentLogs',
      build: () {
        final session = ExerciseSessionLog(
          id: 1,
          date: DateTime(2026, 6, 9),
          gymArrivedAt: DateTime(2026, 6, 9, 7, 0),
          gymLeftAt: DateTime(2026, 6, 9, 8, 0),
          routineId: 1,
        );
        when(() => repository.getActivePlan()).thenAnswer((_) async => null);
        when(() => repository.getDailyLog(any())).thenAnswer((_) async => null);
        when(() => repository.getSessionsForDate(any())).thenAnswer((_) async => []);
        when(() => repository.getExerciseConfig()).thenAnswer((_) async => null);
        when(() => repository.getCardioLogsForWeek(any()))
            .thenAnswer((_) async => []);
        when(() => repository.getWeeklyStats(weeksBack: any(named: 'weeksBack')))
            .thenAnswer((_) async => []);
        when(() => repository.getCompletedRoutineSessionsForWeek(any()))
            .thenAnswer((_) async => [session]);
        when(() => repository.getIndependentSessionsForWeek(any()))
            .thenAnswer((_) async => []);
        return ExerciseBloc(repository);
      },
      act: (bloc) => bloc.add(ExerciseLoaded(date: DateTime(2026, 6, 9))),
      expect: () => [
        const ExerciseState(status: ExerciseStatus.loading),
        ExerciseState(
          status: ExerciseStatus.success,
          completedRoutineSessionsThisWeek: [
            ExerciseSessionLog(
              id: 1,
              date: DateTime(2026, 6, 9),
              gymArrivedAt: DateTime(2026, 6, 9, 7, 0),
              gymLeftAt: DateTime(2026, 6, 9, 8, 0),
              routineId: 1,
            ),
          ],
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
        when(() => repository.getWeeklyStats(weeksBack: any(named: 'weeksBack'))).thenAnswer((_) async => []);
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

    blocTest<ExerciseBloc, ExerciseState>(
      'ExerciseItemCompleted agrega id al set completedRoutineItemIds',
      build: () => ExerciseBloc(repository),
      seed: () => const ExerciseState(
        status: ExerciseStatus.success,
        completedRoutineItemIds: {1},
      ),
      act: (bloc) => bloc.add(const ExerciseItemCompleted(routineItemId: 2)),
      expect: () => [
        isA<ExerciseState>().having(
          (s) => s.completedRoutineItemIds,
          'completedIds',
          containsAll([1, 2]),
        ),
      ],
    );

    blocTest<ExerciseBloc, ExerciseState>(
      'ExerciseSessionResumed carga sessionSetDefs, sessionHistorical y sessionSets',
      build: () {
        const setDef = ExerciseRoutineSetDef(
          id: 1, routineItemId: 1, setNumber: 1,
          dropOfSetNumber: null, reps: 12, weightKg: 75.0,
        );
        final histSet = ExerciseSetLog(
          id: 10, sessionId: 99, exerciseName: 'Press banca',
          setNumber: 1, reps: 12, weightKg: 75.0,
          setType: 'normal', dropOfSetId: null,
        );
        when(() => repository.getRoutineSetDefs(1))
            .thenAnswer((_) async => [setDef]);
        when(() => repository.getLastSessionSetsForExercise('Press banca'))
            .thenAnswer((_) async => [histSet]);
        when(() => repository.getSessionSets(5)).thenAnswer((_) async => []);

        const item = ExerciseRoutineItem(
          id: 1, routineId: 1, exerciseName: 'Press banca',
          sets: 3, reps: 12, weightKg: 60.0,
          setType: 'normal', orderIndex: 0,
        );
        final session = ExerciseSessionLog(
          id: 5, date: DateTime(2026, 6, 9),
          gymArrivedAt: DateTime(2026, 6, 9, 7, 0),
          routineId: 1,
        );
        return ExerciseBloc(repository)
          ..emit(ExerciseState(
            status: ExerciseStatus.success,
            activeSession: session,
            routineItemsByRoutine: const {1: [item]},
          ));
      },
      act: (bloc) => bloc.add(const ExerciseSessionResumed(sessionId: 5)),
      expect: () => [
        isA<ExerciseState>()
            .having((s) => s.sessionSetDefs[1]?.length, 'setDefs item 1', 1)
            .having(
              (s) => s.sessionHistorical['Press banca']?.length,
              'historical Press banca',
              1,
            )
            .having((s) => s.sessionSets.length, 'sessionSets', 0),
      ],
    );

    blocTest<ExerciseBloc, ExerciseState>(
      'IndependentExerciseLogged reloads weeklyIndependentLogs',
      build: () {
        when(() => repository.startSession(any(), routineId: any(named: 'routineId')))
            .thenAnswer((_) async => 42);
        when(() => repository.logSet(
              sessionId: any(named: 'sessionId'),
              exerciseName: any(named: 'exerciseName'),
              setNumber: any(named: 'setNumber'),
              reps: any(named: 'reps'),
              weightKg: any(named: 'weightKg'),
              setType: any(named: 'setType'),
            )).thenAnswer((_) async {});
        when(() => repository.endSession(any())).thenAnswer((_) async {});
        when(() => repository.getSessionsForDate(any())).thenAnswer((_) async => []);
        when(() => repository.getIndependentSessionsForWeek(any()))
            .thenAnswer((_) async => [
                  IndependentExerciseLog(
                    sessionId: 42,
                    date: DateTime(2026, 6, 9),
                    exerciseName: 'Abdominales',
                    sets: 3,
                    reps: 20,
                  ),
                ]);
        return ExerciseBloc(repository)
          ..emit(const ExerciseState(status: ExerciseStatus.success));
      },
      act: (bloc) => bloc.add(IndependentExerciseLogged(
        date: DateTime(2026, 6, 9),
        exerciseName: 'Abdominales',
        sets: 3,
        reps: 20,
      )),
      expect: () => [
        isA<ExerciseState>().having(
          (s) => s.weeklyIndependentLogs.length,
          'weeklyIndependentLogs length',
          1,
        ),
      ],
    );

    blocTest<ExerciseBloc, ExerciseState>(
      'CardioLogged llama repository.logCardio y recarga logs',
      build: () {
        when(() => repository.logCardio(
              date: any(named: 'date'),
              cardioType: any(named: 'cardioType'),
              durationMinutes: any(named: 'durationMinutes'),
              notes: any(named: 'notes'),
            )).thenAnswer((_) async => 1);
        when(() => repository.getCardioLogsForWeek(any()))
            .thenAnswer((_) async => []);
        when(() => repository.getWeeklyStats(
                weeksBack: any(named: 'weeksBack')))
            .thenAnswer((_) async => []);
        return ExerciseBloc(repository);
      },
      seed: () => const ExerciseState(status: ExerciseStatus.success),
      act: (bloc) => bloc.add(CardioLogged(
        date: DateTime(2026, 6, 8),
        cardioType: 'treadmill',
        durationMinutes: 30,
      )),
      verify: (_) {
        verify(() => repository.logCardio(
              date: any(named: 'date'),
              cardioType: 'treadmill',
              durationMinutes: 30,
              notes: null,
            )).called(1);
      },
    );
  });
}
