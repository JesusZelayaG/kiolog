import 'package:bloc_test/bloc_test.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kiolog/features/nutrition/domain/models/nutrition_weekly_stat.dart';
import 'package:kiolog/features/nutrition/presentation/bloc/nutrition_bloc.dart';
import 'package:kiolog/features/nutrition/presentation/bloc/nutrition_event.dart';
import 'package:kiolog/features/nutrition/presentation/bloc/nutrition_state.dart';
import 'package:kiolog/features/nutrition/presentation/pages/nutrition_progress_page.dart';
import 'package:mocktail/mocktail.dart';

class MockNutritionBloc
    extends MockBloc<NutritionEvent, NutritionState>
    implements NutritionBloc {}

Widget _wrap(NutritionBloc bloc) => MaterialApp(
      home: BlocProvider<NutritionBloc>.value(
        value: bloc,
        child: const NutritionProgressPage(),
      ),
    );

NutritionState _state({
  List<NutritionWeeklyStat> weeklyAdherence = const [],
}) =>
    NutritionState(
      status: NutritionStatus.success,
      weeklyAdherence: weeklyAdherence,
    );

NutritionWeeklyStat _stat({
  required DateTime weekStart,
  int logged = 0,
  int expected = 0,
  int offPlan = 0,
}) =>
    NutritionWeeklyStat(
      weekStart: weekStart,
      mealsLogged: logged,
      mealsExpected: expected,
      offPlanMeals: offPlan,
    );

void main() {
  late MockNutritionBloc bloc;

  setUpAll(() {
    registerFallbackValue(NutritionLoaded(date: DateTime(2026)));
  });

  setUp(() => bloc = MockNutritionBloc());

  group('NutritionProgressPage', () {
    // Test 1: adherencia chip shows correct %
    testWidgets('semana chips show correct adherence %', (tester) async {
      final now = DateTime.now().toUtc();
      final monday = now.subtract(Duration(days: now.weekday - 1));
      final weekStart = DateTime.utc(monday.year, monday.month, monday.day);

      final stats = [
        _stat(weekStart: weekStart, logged: 3, expected: 4, offPlan: 1),
      ];
      whenListen(bloc, const Stream<NutritionState>.empty(),
          initialState: _state(weeklyAdherence: stats));

      await tester.pumpWidget(_wrap(bloc));
      await tester.pump();

      // 3/4 = 75%
      expect(find.text('75%'), findsOneWidget);
      expect(find.text('3'), findsOneWidget); // comidas plan
      expect(find.text('1'), findsOneWidget); // fuera plan
    });

    // Test 2: › disabled at weekOffset == 0
    testWidgets('week › button is disabled when weekOffset is 0',
        (tester) async {
      whenListen(bloc, const Stream<NutritionState>.empty(),
          initialState: _state());

      await tester.pumpWidget(_wrap(bloc));
      await tester.pump();

      final rightBtn = tester.widget<IconButton>(
          find.widgetWithIcon(IconButton, Icons.chevron_right));
      expect(rightBtn.onPressed, isNull);
    });

    // Test 3: tapping ‹ enables ›
    testWidgets('tapping ‹ decrements weekOffset and enables ›',
        (tester) async {
      final now = DateTime.now().toUtc();
      final monday = now.subtract(Duration(days: now.weekday - 1));
      final w1 = DateTime.utc(monday.year, monday.month, monday.day)
          .subtract(const Duration(days: 7));
      final w2 = DateTime.utc(monday.year, monday.month, monday.day);

      whenListen(bloc, const Stream<NutritionState>.empty(),
          initialState: _state(weeklyAdherence: [
            _stat(weekStart: w1),
            _stat(weekStart: w2),
          ]));

      await tester.pumpWidget(_wrap(bloc));
      await tester.pump();

      await tester.tap(find.widgetWithIcon(IconButton, Icons.chevron_left));
      await tester.pump();

      final rightBtn = tester.widget<IconButton>(
          find.widgetWithIcon(IconButton, Icons.chevron_right));
      expect(rightBtn.onPressed, isNotNull);
    });

    // Test 4: switching to Mes shows monthly aggregate chips
    testWidgets('switching to Mes shows monthly percentage chip',
        (tester) async {
      final now = DateTime.now().toUtc();
      final monday = now.subtract(Duration(days: now.weekday - 1));
      final weekStart = DateTime.utc(monday.year, monday.month, monday.day);

      whenListen(bloc, const Stream<NutritionState>.empty(),
          initialState: _state(weeklyAdherence: [
            _stat(weekStart: weekStart, logged: 2, expected: 4),
          ]));

      await tester.pumpWidget(_wrap(bloc));
      await tester.pump();

      await tester.tap(find.text('Mes'));
      await tester.pump();

      // 2/4 = 50%
      expect(find.text('50%'), findsOneWidget);
    });

    // Test 5: no-plan week shows — in adherencia chip
    testWidgets('weeks with no plan show — in adherencia chip',
        (tester) async {
      final now = DateTime.now().toUtc();
      final monday = now.subtract(Duration(days: now.weekday - 1));
      final weekStart = DateTime.utc(monday.year, monday.month, monday.day);

      whenListen(bloc, const Stream<NutritionState>.empty(),
          initialState: _state(weeklyAdherence: [
            _stat(weekStart: weekStart, logged: 0, expected: 0),
          ]));

      await tester.pumpWidget(_wrap(bloc));
      await tester.pump();

      expect(find.text('—'), findsOneWidget);
    });

    // Test 6: empty list does not crash
    testWidgets('renders without crash when weeklyAdherence is empty',
        (tester) async {
      whenListen(bloc, const Stream<NutritionState>.empty(),
          initialState: _state());

      await tester.pumpWidget(_wrap(bloc));
      await tester.pump();

      expect(tester.takeException(), isNull);
    });

    // Test 7: month › button is disabled at current month
    testWidgets('month › button is disabled at current month',
        (tester) async {
      whenListen(bloc, const Stream<NutritionState>.empty(),
          initialState: _state());

      await tester.pumpWidget(_wrap(bloc));
      await tester.pump();

      // Switch to Mes mode
      await tester.tap(find.text('Mes'));
      await tester.pump();

      final rightBtn = tester.widget<IconButton>(
          find.widgetWithIcon(IconButton, Icons.chevron_right));
      expect(rightBtn.onPressed, isNull);
    });
  });
}
