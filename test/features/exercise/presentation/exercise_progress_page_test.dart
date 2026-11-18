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
import 'package:intl/date_symbol_data_local.dart';
import 'package:kiolog/core/theme/app_theme.dart';
import 'package:mocktail/mocktail.dart';

class MockExerciseBloc
    extends MockBloc<ExerciseEvent, ExerciseState>
    implements ExerciseBloc {}

Widget _wrap(ExerciseBloc bloc) => MaterialApp(
      theme: AppTheme.of(KiologThemeId.noche),
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

  setUpAll(() async {
    await initializeDateFormatting('es');
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
      await tester.pumpAndSettle();

      expect(find.text('1/4'), findsOneWidget); // días rutina
      expect(find.text('1/3'), findsOneWidget); // días cardio
      expect(find.text('2'), findsOneWidget); // sesiones (1 routine + 1 cardio + 0 independent)
    });

    testWidgets('la semana actual no deja avanzar', (tester) async {
      whenListen(bloc, const Stream<ExerciseState>.empty(),
          initialState: _state());

      await tester.pumpWidget(_wrap(bloc));
      await tester.pumpAndSettle();

      expect(find.text('Esta semana'), findsOneWidget);
      await tester.tap(find.byTooltip('Siguiente'));
      await tester.pumpAndSettle();
      expect(find.text('Esta semana'), findsOneWidget);
    });

    testWidgets('‹ va a la semana anterior y › regresa', (tester) async {
      final stat = WeeklyStat(
        weekStart: DateTime.utc(2026, 6, 2),
        routineDaysDone: 3,
        cardioDaysDone: 2,
      );
      whenListen(bloc, const Stream<ExerciseState>.empty(),
          initialState: _state(weeklyStats: [stat, stat]));

      await tester.pumpWidget(_wrap(bloc));
      await tester.pumpAndSettle();

      await tester.tap(find.byTooltip('Anterior'));
      await tester.pumpAndSettle();
      expect(find.text('Hace 1 semana'), findsOneWidget);
      expect(find.text('3/4'), findsOneWidget);

      await tester.tap(find.byTooltip('Siguiente'));
      await tester.pumpAndSettle();
      expect(find.text('Esta semana'), findsOneWidget);
    });

    testWidgets('en Mes suma las semanas del mes contra la meta', (tester) async {
      final now = DateTime.now();
      final stat = WeeklyStat(
        weekStart: DateTime(now.year, now.month, 9),
        routineDaysDone: 3,
        cardioDaysDone: 2,
      );
      whenListen(bloc, const Stream<ExerciseState>.empty(),
          initialState: _state(weeklyStats: [stat]));

      await tester.pumpWidget(_wrap(bloc));
      await tester.pumpAndSettle();

      await tester.tap(find.text('Mes'));
      await tester.pumpAndSettle();

      // rutina: 3 de 1 semana × 4 = 75 %
      expect(find.text('75%'), findsOneWidget);
      expect(find.text('3/4'), findsOneWidget);
      expect(find.text('2/3'), findsOneWidget);
      expect(find.text('Este mes'), findsOneWidget);
    });

    testWidgets('Rutina y Cardio cambian la gráfica', (tester) async {
      final stat = WeeklyStat(
        weekStart: DateTime.utc(2026, 6, 2),
        routineDaysDone: 3,
        cardioDaysDone: 2,
      );
      whenListen(bloc, const Stream<ExerciseState>.empty(),
          initialState: _state(weeklyStats: [stat]));

      await tester.pumpWidget(_wrap(bloc));
      await tester.pumpAndSettle();

      expect(find.text('Meta: 4 días por semana'), findsOneWidget);
      await tester.tap(find.text('Cardio'));
      await tester.pumpAndSettle();
      expect(find.text('Meta: 3 días por semana'), findsOneWidget);
    });

    // Test 6: renders without error when weeklyStats is empty
    testWidgets('renders without error when weeklyStats is empty',
        (tester) async {
      whenListen(bloc, const Stream<ExerciseState>.empty(),
          initialState: _state(weeklyStats: []));

      await tester.pumpWidget(_wrap(bloc));
      await tester.pumpAndSettle();

      expect(tester.takeException(), isNull);
      expect(find.text('Todavía no hay semanas registradas.'), findsOneWidget);
    });
  });
}
