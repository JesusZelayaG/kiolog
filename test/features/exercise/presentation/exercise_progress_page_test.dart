import 'package:bloc_test/bloc_test.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kiolog/core/database/app_database.dart';
import 'package:kiolog/features/exercise/domain/models/independent_exercise_log.dart';
import 'package:kiolog/features/exercise/domain/models/weekly_stat.dart';
import 'package:kiolog/features/exercise/presentation/bloc/exercise_bloc.dart';
import 'package:kiolog/features/exercise/presentation/bloc/exercise_event.dart';
import 'package:kiolog/features/exercise/presentation/bloc/exercise_state.dart';
import 'package:kiolog/features/exercise/presentation/pages/exercise_progress_page.dart';
import 'package:mocktail/mocktail.dart';

class MockExerciseBloc
    extends MockBloc<ExerciseEvent, ExerciseState>
    implements ExerciseBloc {}

Widget _wrap(ExerciseBloc bloc) => MaterialApp(
      home: BlocProvider<ExerciseBloc>.value(
        value: bloc,
        child: const ExerciseProgressPage(),
      ),
    );

ExerciseState _state({
  List<WeeklyStat> weeklyStats = const [],
  List<ExerciseSessionLog> completedRoutine = const [],
  List<CardioLog> cardioLogs = const [],
  List<IndependentExerciseLog> independentLogs = const [],
  int routineDaysGoal = 4,
  int cardioDaysGoal = 3,
}) =>
    ExerciseState(
      status: ExerciseStatus.success,
      weeklyStats: weeklyStats,
      completedRoutineSessionsThisWeek: completedRoutine,
      weeklyCardioLogs: cardioLogs,
      weeklyIndependentLogs: independentLogs,
      routineDaysGoal: routineDaysGoal,
      cardioDaysGoal: cardioDaysGoal,
    );

void main() {
  late MockExerciseBloc bloc;

  setUpAll(() {
    registerFallbackValue(ExerciseLoaded(date: DateTime(2026)));
  });

  setUp(() => bloc = MockExerciseBloc());

  group('ExerciseProgressPage', () {
    // Test 1: Semana chips show correct current-week values
    testWidgets('semana chips show correct values for current week',
        (tester) async {
      final session = ExerciseSessionLog(
        id: 1,
        date: DateTime(2026, 6, 9),
        gymArrivedAt: DateTime(2026, 6, 9, 7),
        gymLeftAt: DateTime(2026, 6, 9, 8),
        routineId: 1,
      );
      final cardio = CardioLog(
        id: 1,
        date: DateTime.utc(2026, 6, 9),
        cardioType: 'Correr',
        durationMinutes: 30,
      );
      final state = _state(
        completedRoutine: [session],
        cardioLogs: [cardio],
        routineDaysGoal: 4,
        cardioDaysGoal: 3,
      );
      whenListen(bloc, const Stream<ExerciseState>.empty(),
          initialState: state);

      await tester.pumpWidget(_wrap(bloc));
      await tester.pump();

      expect(find.text('1/4'), findsOneWidget); // días rutina
      expect(find.text('1/3'), findsOneWidget); // días cardio
      expect(find.text('2'), findsOneWidget); // sesiones (1 routine + 1 cardio + 0 independent)
    });

    // Test 2: › button is disabled when weekOffset == 0
    testWidgets('week › button is disabled when weekOffset is 0',
        (tester) async {
      whenListen(bloc, const Stream<ExerciseState>.empty(),
          initialState: _state());

      await tester.pumpWidget(_wrap(bloc));
      await tester.pump();

      final rightBtn = tester.widget<IconButton>(
          find.widgetWithIcon(IconButton, Icons.chevron_right));
      expect(rightBtn.onPressed, isNull);
    });

    // Test 3: tapping ‹ decrements weekOffset and enables ›
    testWidgets('tapping ‹ decrements weekOffset and enables ›',
        (tester) async {
      final stat = WeeklyStat(
        weekStart: DateTime.utc(2026, 6, 2),
        routineDaysDone: 3,
        cardioDaysDone: 2,
      );
      // Two entries: length=2, so canGoBack at _weekOffset=0 is: 0 > -(2-1) = 0 > -1 = true
      whenListen(bloc, const Stream<ExerciseState>.empty(),
          initialState: _state(weeklyStats: [stat, stat]));

      await tester.pumpWidget(_wrap(bloc));
      await tester.pump();

      await tester.tap(find.widgetWithIcon(IconButton, Icons.chevron_left));
      await tester.pump();

      final rightBtn = tester.widget<IconButton>(
          find.widgetWithIcon(IconButton, Icons.chevron_right));
      expect(rightBtn.onPressed, isNotNull);
    });

    // Test 4: switching to Mes shows % in chips
    testWidgets('switching to Mes shows percentage chips', (tester) async {
      final now = DateTime.now().toUtc();
      final stat = WeeklyStat(
        weekStart: DateTime.utc(now.year, now.month, 9),
        routineDaysDone: 3,
        cardioDaysDone: 2,
      );
      whenListen(bloc, const Stream<ExerciseState>.empty(),
          initialState: _state(
            weeklyStats: [stat],
            routineDaysGoal: 4,
            cardioDaysGoal: 3,
          ));

      await tester.pumpWidget(_wrap(bloc));
      await tester.pump();

      await tester.tap(find.text('Mes'));
      await tester.pump();

      // rutina: 3 / (1 week * 4) = 75%
      expect(find.text('75%'), findsOneWidget);
      // at least 2 chips with % (rutina and cardio)
      expect(find.textContaining('%'), findsNWidgets(2));
    });

    // Test 5: Rutina/Cardio toggle does not throw
    testWidgets('Rutina/Cardio toggle does not throw', (tester) async {
      whenListen(bloc, const Stream<ExerciseState>.empty(),
          initialState: _state());

      await tester.pumpWidget(_wrap(bloc));
      await tester.pump();

      await tester.tap(find.text('🏃 Cardio'));
      await tester.pump();

      expect(tester.takeException(), isNull);
    });

    // Test 6: renders without error when weeklyStats is empty
    testWidgets('renders without error when weeklyStats is empty',
        (tester) async {
      whenListen(bloc, const Stream<ExerciseState>.empty(),
          initialState: _state(weeklyStats: []));

      await tester.pumpWidget(_wrap(bloc));
      await tester.pump();

      expect(tester.takeException(), isNull);
    });
  });
}
