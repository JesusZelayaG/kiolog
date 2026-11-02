import 'package:bloc_test/bloc_test.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kiolog/core/database/app_database.dart';
import 'package:kiolog/features/nutrition/presentation/bloc/nutrition_bloc.dart';
import 'package:kiolog/features/nutrition/presentation/bloc/nutrition_event.dart';
import 'package:kiolog/features/nutrition/presentation/bloc/nutrition_state.dart';
import 'package:kiolog/features/nutrition/presentation/pages/nutrition_page.dart';
import 'package:mocktail/mocktail.dart';

class MockNutritionBloc
    extends MockBloc<NutritionEvent, NutritionState>
    implements NutritionBloc {}

final _plan = MealPlan(
  id: 1,
  name: 'Plan Test',
  createdAt: DateTime(2026, 6, 1),
  isActive: true,
  dailyMealGoal: 2,
  periodStart: DateTime(2026, 6, 1),
  periodEnd: null,
);

final _optDesayuno = MealPlanOption(
  id: 1,
  planId: 1,
  mealType: 'Desayuno',
  optionNumber: 1,
  description: 'Avena con frutas',
);

final _optAlmuerzo = MealPlanOption(
  id: 2,
  planId: 1,
  mealType: 'Almuerzo',
  optionNumber: 1,
  description: 'Arroz con pollo',
);

Widget _wrap(NutritionBloc bloc) => MaterialApp(
      home: BlocProvider<NutritionBloc>.value(
        value: bloc,
        child: Scaffold(
          body: BlocBuilder<NutritionBloc, NutritionState>(
            builder: (context, state) {
              if (state.activePlan == null) {
                return const Center(child: Text('Sin plan'));
              }
              return ListView(
                children: state.planOptions.keys.map((type) {
                  return Card(
                    key: Key('meal_$type'),
                    child: Column(
                      children: [
                        Text(type),
                        if (state.getLogForMeal(type) == null) ...[
                          TextButton(
                            key: Key('no_seguido_$type'),
                            onPressed: () => context
                                .read<NutritionBloc>()
                                .add(NutritionOffPlanMealLogged(
                                  date: DateTime(2026, 6, 8),
                                  mealType: type,
                                  description: null,
                                )),
                            child: const Text('No seguí el plan'),
                          ),
                          TextButton(
                            key: Key('fuera_plan_$type'),
                            onPressed: () {},
                            child: const Text('Fuera de plan'),
                          ),
                        ] else
                          Builder(builder: (context) {
                            final log = state.getLogForMeal(type)!;
                            if (log.planOptionId != null) {
                              return const Text('Registrado');
                            } else if (log.freeDescription != null) {
                              return Text('Fuera de plan: ${log.freeDescription}');
                            } else {
                              return const Text('No seguido');
                            }
                          }),
                      ],
                    ),
                  );
                }).toList(),
              );
            },
          ),
        ),
      ),
    );

void main() {
  late MockNutritionBloc bloc;

  setUpAll(() {
    registerFallbackValue(
        NutritionOffPlanMealLogged(date: DateTime(2026), mealType: 'x'));
    registerFallbackValue(NutritionLoaded(date: DateTime(2026)));
    registerFallbackValue(const NutritionPlanActivated(planId: 0));
  });

  setUp(() => bloc = MockNutritionBloc());

  group('NutritionPage dynamic display', () {
    testWidgets('shows meal sections for each key in planOptions',
        (tester) async {
      when(() => bloc.state).thenReturn(NutritionState(
        status: NutritionStatus.success,
        activePlan: _plan,
        planOptions: {
          'Desayuno': [_optDesayuno],
          'Almuerzo': [_optAlmuerzo],
        },
      ));
      whenListen(bloc, Stream.fromIterable([bloc.state]));

      await tester.pumpWidget(_wrap(bloc));
      await tester.pumpAndSettle();

      expect(find.text('Desayuno'), findsOneWidget);
      expect(find.text('Almuerzo'), findsOneWidget);
    });

    testWidgets('"No seguí el plan" fires NutritionOffPlanMealLogged with null description',
        (tester) async {
      when(() => bloc.state).thenReturn(NutritionState(
        status: NutritionStatus.success,
        activePlan: _plan,
        planOptions: {'Desayuno': [_optDesayuno]},
      ));
      whenListen(bloc, Stream.fromIterable([bloc.state]));

      await tester.pumpWidget(_wrap(bloc));
      await tester.pumpAndSettle();

      await tester.tap(find.byKey(const Key('no_seguido_Desayuno')));
      await tester.pumpAndSettle();

      verify(() => bloc.add(NutritionOffPlanMealLogged(
            date: DateTime(2026, 6, 8),
            mealType: 'Desayuno',
            description: null,
          ))).called(1);
    });

    testWidgets('shows "Registrado" when meal logged with planOptionId',
        (tester) async {
      when(() => bloc.state).thenReturn(NutritionState(
        status: NutritionStatus.success,
        activePlan: _plan,
        planOptions: {'Desayuno': [_optDesayuno]},
        dailyLogs: [
          DailyMealLog(
            id: 1,
            date: DateTime(2026, 6, 8),
            mealType: 'Desayuno',
            planOptionId: 1,
            freeDescription: null,
            photoPath: null,
          ),
        ],
      ));
      whenListen(bloc, Stream.fromIterable([bloc.state]));

      await tester.pumpWidget(_wrap(bloc));
      await tester.pumpAndSettle();

      expect(find.text('Registrado'), findsOneWidget);
    });

    testWidgets('shows "No seguido" when meal logged with null planOptionId and null freeDescription',
        (tester) async {
      when(() => bloc.state).thenReturn(NutritionState(
        status: NutritionStatus.success,
        activePlan: _plan,
        planOptions: {'Desayuno': [_optDesayuno]},
        dailyLogs: [
          DailyMealLog(
            id: 1,
            date: DateTime(2026, 6, 8),
            mealType: 'Desayuno',
            planOptionId: null,
            freeDescription: null,
            photoPath: null,
          ),
        ],
      ));
      whenListen(bloc, Stream.fromIterable([bloc.state]));

      await tester.pumpWidget(_wrap(bloc));
      await tester.pumpAndSettle();

      expect(find.text('No seguido'), findsOneWidget);
    });

    testWidgets('shows freeDescription when meal logged off-plan with text',
        (tester) async {
      when(() => bloc.state).thenReturn(NutritionState(
        status: NutritionStatus.success,
        activePlan: _plan,
        planOptions: {'Almuerzo': [_optAlmuerzo]},
        dailyLogs: [
          DailyMealLog(
            id: 2,
            date: DateTime(2026, 6, 8),
            mealType: 'Almuerzo',
            planOptionId: null,
            freeDescription: 'Pizza con amigos',
            photoPath: null,
          ),
        ],
      ));
      whenListen(bloc, Stream.fromIterable([bloc.state]));

      await tester.pumpWidget(_wrap(bloc));
      await tester.pumpAndSettle();

      expect(find.text('Fuera de plan: Pizza con amigos'), findsOneWidget);
    });
  });
}
