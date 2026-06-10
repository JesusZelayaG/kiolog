import 'package:bloc_test/bloc_test.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kiolog/core/database/app_database.dart';
import 'package:kiolog/features/nutrition/domain/models/nutrition_weekly_stat.dart';
import 'package:kiolog/features/nutrition/domain/repositories/nutrition_repository.dart';
import 'package:kiolog/features/nutrition/presentation/bloc/nutrition_bloc.dart';
import 'package:kiolog/features/nutrition/presentation/bloc/nutrition_event.dart';
import 'package:kiolog/features/nutrition/presentation/bloc/nutrition_state.dart';
import 'package:mocktail/mocktail.dart';

class MockNutritionRepository extends Mock implements NutritionRepository {}

void main() {
  late MockNutritionRepository repository;

  setUp(() {
    repository = MockNutritionRepository();
  });

  group('NutritionBloc', () {
    final plan = MealPlan(
      id: 1,
      name: 'Plan',
      createdAt: DateTime.now(),
      isActive: true,
      dailyMealGoal: 4,
      periodStart: null,
      periodEnd: null,
    );
    final options = [
      MealPlanOption(
          id: 1,
          planId: 1,
          mealType: 'breakfast',
          optionNumber: 1,
          description: 'Avena'),
    ];
    final adherence = [
      NutritionWeeklyStat(
        weekStart: DateTime.utc(2026, 6, 2),
        mealsLogged: 3,
        mealsExpected: 4,
        offPlanMeals: 1,
      ),
    ];

    blocTest<NutritionBloc, NutritionState>(
      'emits [loading, success] grouping options by mealType via getAllPlanOptions',
      build: () {
        when(() => repository.getActivePlan()).thenAnswer((_) async => plan);
        when(() => repository.getDailyLogs(any())).thenAnswer((_) async => []);
        when(() => repository.getAllPlanOptions(any()))
            .thenAnswer((_) async => options);
        when(() => repository.getWeeklyAdherence(weeksBack: 8))
            .thenAnswer((_) async => adherence);
        return NutritionBloc(repository);
      },
      act: (bloc) => bloc.add(NutritionLoaded(date: DateTime(2026, 6, 8))),
      expect: () => [
        const NutritionState(status: NutritionStatus.loading),
        NutritionState(
          status: NutritionStatus.success,
          activePlan: plan,
          planOptions: {'breakfast': options},
          weeklyAdherence: adherence,
        ),
      ],
    );

    blocTest<NutritionBloc, NutritionState>(
      'logs meal and refreshes daily logs',
      build: () {
        when(() => repository.logMeal(
              date: any(named: 'date'),
              mealType: any(named: 'mealType'),
              planOptionId: any(named: 'planOptionId'),
            )).thenAnswer((_) async {});
        when(() => repository.getDailyLogs(any())).thenAnswer((_) async => [
              DailyMealLog(
                  id: 1,
                  date: DateTime(2026, 6, 8),
                  mealType: 'breakfast',
                  planOptionId: 1,
                  freeDescription: null,
                  photoPath: null),
            ]);
        when(() => repository.getWeeklyAdherence(weeksBack: 8))
            .thenAnswer((_) async => []);
        return NutritionBloc(repository)
          ..emit(const NutritionState(status: NutritionStatus.success));
      },
      act: (bloc) => bloc.add(NutritionMealLogged(
        date: DateTime(2026, 6, 8),
        mealType: 'breakfast',
        planOptionId: 1,
      )),
      expect: () => [
        NutritionState(
          status: NutritionStatus.success,
          dailyLogs: [
            DailyMealLog(
                id: 1,
                date: DateTime(2026, 6, 8),
                mealType: 'breakfast',
                planOptionId: 1,
                freeDescription: null,
                photoPath: null),
          ],
          weeklyAdherence: [],
        ),
      ],
    );

    blocTest<NutritionBloc, NutritionState>(
      '_onLoaded emits failure on repository error',
      build: () {
        when(() => repository.getActivePlan())
            .thenThrow(Exception('DB error'));
        return NutritionBloc(repository);
      },
      act: (bloc) => bloc.add(NutritionLoaded(date: DateTime(2026, 6, 8))),
      expect: () => [
        const NutritionState(status: NutritionStatus.loading),
        isA<NutritionState>().having(
          (s) => s.status,
          'status',
          NutritionStatus.failure,
        ),
      ],
    );

    blocTest<NutritionBloc, NutritionState>(
      '_onLoaded emits empty weeklyAdherence when list is empty',
      build: () {
        when(() => repository.getActivePlan()).thenAnswer((_) async => null);
        when(() => repository.getDailyLogs(any())).thenAnswer((_) async => []);
        when(() => repository.getWeeklyAdherence(weeksBack: 8))
            .thenAnswer((_) async => []);
        return NutritionBloc(repository);
      },
      act: (bloc) => bloc.add(NutritionLoaded(date: DateTime(2026, 6, 8))),
      expect: () => [
        const NutritionState(status: NutritionStatus.loading),
        const NutritionState(
          status: NutritionStatus.success,
          weeklyAdherence: [],
        ),
      ],
    );

    blocTest<NutritionBloc, NutritionState>(
      'activates plan and refreshes',
      build: () {
        when(() => repository.activatePlan(any())).thenAnswer((_) async {});
        when(() => repository.getActivePlan()).thenAnswer((_) async => plan);
        when(() => repository.getAllPlans()).thenAnswer((_) async => [plan]);
        return NutritionBloc(repository);
      },
      act: (bloc) => bloc.add(const NutritionPlanActivated(planId: 1)),
      expect: () => [
        NutritionState(activePlan: plan, allPlans: [plan]),
      ],
    );

    blocTest<NutritionBloc, NutritionState>(
      'creates plan with dailyMealGoal',
      build: () {
        when(() => repository.createPlan(any(), dailyMealGoal: any(named: 'dailyMealGoal')))
            .thenAnswer((_) async => 1);
        when(() => repository.getAllPlans()).thenAnswer((_) async => [plan]);
        return NutritionBloc(repository);
      },
      act: (bloc) => bloc.add(
          const NutritionPlanCreated(name: 'Plan Junio', dailyMealGoal: 5)),
      expect: () => [
        NutritionState(allPlans: [plan]),
      ],
    );

    blocTest<NutritionBloc, NutritionState>(
      'logs off-plan meal with null description (no seguí el plan)',
      build: () {
        when(() => repository.logOffPlanMeal(
              date: any(named: 'date'),
              mealType: any(named: 'mealType'),
              description: null,
            )).thenAnswer((_) async {});
        when(() => repository.getDailyLogs(any())).thenAnswer((_) async => [
              DailyMealLog(
                id: 2,
                date: DateTime(2026, 6, 8),
                mealType: 'Almuerzo',
                planOptionId: null,
                freeDescription: null,
                photoPath: null,
              ),
            ]);
        when(() => repository.getWeeklyAdherence(weeksBack: 8))
            .thenAnswer((_) async => []);
        return NutritionBloc(repository)
          ..emit(const NutritionState(status: NutritionStatus.success));
      },
      act: (bloc) => bloc.add(NutritionOffPlanMealLogged(
        date: DateTime(2026, 6, 8),
        mealType: 'Almuerzo',
        description: null,
      )),
      expect: () => [
        NutritionState(
          status: NutritionStatus.success,
          dailyLogs: [
            DailyMealLog(
              id: 2,
              date: DateTime(2026, 6, 8),
              mealType: 'Almuerzo',
              planOptionId: null,
              freeDescription: null,
              photoPath: null,
            ),
          ],
          weeklyAdherence: [],
        ),
      ],
    );
  });
}
