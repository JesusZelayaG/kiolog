import 'package:bloc_test/bloc_test.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kiolog/core/database/app_database.dart';
import 'package:kiolog/core/theme/app_theme.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:kiolog/features/nutrition/domain/models/nutrition_weekly_stat.dart';
import 'package:kiolog/features/nutrition/domain/models/option_frequency_stat.dart';
import 'package:kiolog/features/nutrition/presentation/bloc/nutrition_bloc.dart';
import 'package:kiolog/features/nutrition/presentation/bloc/nutrition_event.dart';
import 'package:kiolog/features/nutrition/presentation/bloc/nutrition_state.dart';
import 'package:kiolog/features/nutrition/presentation/pages/nutrition_progress_page.dart';
import 'package:mocktail/mocktail.dart';

class MockNutritionBloc
    extends MockBloc<NutritionEvent, NutritionState>
    implements NutritionBloc {}

Widget _wrap(NutritionBloc bloc) => MaterialApp(
      theme: AppTheme.of(KiologThemeId.claro),
      home: BlocProvider<NutritionBloc>.value(
        value: bloc,
        child: const NutritionProgressPage(),
      ),
    );

NutritionState _state({
  List<NutritionWeeklyStat> weeklyAdherence = const [],
  List<OptionFrequencyStat> optionFrequencies = const [],
  MealPlan? activePlan,
  int? viewingPlanId,
}) =>
    NutritionState(
      status: NutritionStatus.success,
      weeklyAdherence: weeklyAdherence,
      optionFrequencies: optionFrequencies,
      activePlan: activePlan,
      viewingPlanId: viewingPlanId,
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


MealPlan _plan(int id, String name, {bool active = true, DateTime? end}) => MealPlan(
      id: id,
      name: name,
      createdAt: DateTime(2026, 6, 1),
      isActive: active,
      dailyMealGoal: 4,
      periodStart: DateTime(2026, 6, 1),
      periodEnd: end,
    );

DateTime _thisMonday() {
  final now = DateTime.now().toUtc();
  final monday = now.subtract(Duration(days: now.weekday - 1));
  return DateTime.utc(monday.year, monday.month, monday.day);
}

void main() {
  late MockNutritionBloc bloc;

  setUpAll(() async {
    await initializeDateFormatting('es');
    registerFallbackValue(NutritionLoaded(date: DateTime(2026)));
    registerFallbackValue(const NutritionProgressPlanSelected(planId: 0));
  });

  setUp(() => bloc = MockNutritionBloc());

  Future<void> show(WidgetTester tester, NutritionState state) async {
    whenListen(bloc, const Stream<NutritionState>.empty(), initialState: state);
    await tester.pumpWidget(_wrap(bloc));
    await tester.pumpAndSettle();
  }

  group('NutritionProgressPage', () {
    testWidgets('la semana muestra el % del plan y las comidas', (tester) async {
      await show(tester, _state(weeklyAdherence: [_stat(weekStart: _thisMonday(), logged: 3, expected: 4, offPlan: 1)]));

      // En el anillo y en la barra de la semana.
      expect(find.text('75%'), findsNWidgets(2));
      expect(find.text('3'), findsOneWidget);
      expect(find.text('1'), findsOneWidget);
      expect(find.text('Esta semana'), findsWidgets);
    });

    testWidgets('anterior y siguiente recorren las semanas sin pasar de hoy', (tester) async {
      final monday = _thisMonday();
      await show(
        tester,
        _state(weeklyAdherence: [
          _stat(weekStart: monday.subtract(const Duration(days: 7)), logged: 2, expected: 4),
          _stat(weekStart: monday, logged: 4, expected: 4),
        ]),
      );

      // El anillo muestra la semana elegida; las barras, todas.
      await tester.tap(find.byTooltip('Siguiente'));
      await tester.pumpAndSettle();
      expect(find.text('Esta semana'), findsWidgets);
      expect(find.text('100%'), findsNWidgets(2));

      await tester.tap(find.byTooltip('Anterior'));
      await tester.pumpAndSettle();
      expect(find.text('Hace 1 semana'), findsOneWidget);
      expect(find.text('50%'), findsNWidgets(2));

      await tester.tap(find.byTooltip('Siguiente'));
      await tester.pumpAndSettle();
      expect(find.text('100%'), findsNWidgets(2));
    });

    testWidgets('la vista de mes suma las semanas del mes', (tester) async {
      await show(tester, _state(weeklyAdherence: [_stat(weekStart: _thisMonday(), logged: 2, expected: 4)]));

      await tester.tap(find.text('Mes'));
      await tester.pumpAndSettle();

      expect(find.text('Este mes'), findsOneWidget);
    });

    testWidgets('una semana sin plan muestra un guion', (tester) async {
      await show(tester, _state(weeklyAdherence: [_stat(weekStart: _thisMonday())]));

      expect(find.text('—'), findsOneWidget);
    });

    testWidgets('sin datos no falla', (tester) async {
      await show(tester, _state());

      expect(find.text('Nutrición'), findsOneWidget);
    });

    testWidgets('muestra el plan que se mira', (tester) async {
      final plan = _plan(1, 'Plan Verano');
      await show(tester, NutritionState(status: NutritionStatus.success, activePlan: plan, allPlans: [plan]));

      expect(find.text('Plan Verano'), findsOneWidget);
    });

    testWidgets('"Lo que más comes" ordena las opciones por veces', (tester) async {
      final plan = _plan(1, 'Plan');
      await show(
        tester,
        NutritionState(
          status: NutritionStatus.success,
          activePlan: plan,
          allPlans: [plan],
          optionFrequencies: const [
            OptionFrequencyStat(planOptionId: 2, mealType: 'Desayuno', optionNumber: 2, description: 'Huevos revueltos', count: 7),
            OptionFrequencyStat(planOptionId: 1, mealType: 'Desayuno', optionNumber: 1, description: 'Avena con frutas', count: 18),
          ],
        ),
      );

      await tester.tap(find.text('Lo que más comes'));
      await tester.pumpAndSettle();

      expect(find.text('18×'), findsOneWidget);
      expect(find.text('7×'), findsOneWidget);
      expect(find.text('25 veces'), findsOneWidget);
      final avena = tester.getTopLeft(find.text('Avena con frutas')).dy;
      final huevos = tester.getTopLeft(find.text('Huevos revueltos')).dy;
      expect(avena, lessThan(huevos));
    });

    testWidgets('un plan anterior muestra solo lo que más se comió', (tester) async {
      final active = _plan(1, 'Plan Actual');
      final prev = _plan(2, 'Plan Anterior', active: false, end: DateTime(2026, 5, 31));
      await show(
        tester,
        NutritionState(
          status: NutritionStatus.success,
          activePlan: active,
          allPlans: [active, prev],
          viewingPlanId: 2,
          optionFrequencies: const [
            OptionFrequencyStat(planOptionId: 10, mealType: 'Almuerzo', optionNumber: 1, description: 'Pollo al horno', count: 12),
          ],
        ),
      );

      expect(find.text('Cumplimiento'), findsNothing);
      expect(find.text('Pollo al horno'), findsOneWidget);
      expect(find.text('12×'), findsOneWidget);
    });
  });
}
