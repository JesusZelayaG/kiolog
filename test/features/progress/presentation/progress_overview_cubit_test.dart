import 'package:flutter_test/flutter_test.dart';
import 'package:kiolog/core/database/app_database.dart';
import 'package:kiolog/features/exercise/domain/models/weekly_stat.dart';
import 'package:kiolog/features/exercise/domain/repositories/exercise_repository.dart';
import 'package:kiolog/features/nutrition/domain/models/nutrition_weekly_stat.dart';
import 'package:kiolog/features/nutrition/domain/repositories/nutrition_repository.dart';
import 'package:kiolog/features/progress/domain/repositories/progress_repository.dart';
import 'package:kiolog/features/progress/presentation/bloc/progress_overview_cubit.dart';
import 'package:kiolog/features/sleep/domain/repositories/sleep_repository.dart';
import 'package:kiolog/features/water/domain/repositories/water_repository.dart';
import 'package:mocktail/mocktail.dart';

class MockExercise extends Mock implements ExerciseRepository {}

class MockNutrition extends Mock implements NutritionRepository {}

class MockWater extends Mock implements WaterRepository {}

class MockSleep extends Mock implements SleepRepository {}

class MockProgress extends Mock implements ProgressRepository {}

void main() {
  late MockExercise exercise;
  late MockNutrition nutrition;
  late MockWater water;
  late MockSleep sleep;
  late MockProgress progress;
  final monday = DateTime.utc(2026, 10, 26);

  setUpAll(() => registerFallbackValue(DateTime(2026)));

  setUp(() {
    exercise = MockExercise();
    nutrition = MockNutrition();
    water = MockWater();
    sleep = MockSleep();
    progress = MockProgress();
    when(() => exercise.getWeeklyStats(weeksBack: any(named: 'weeksBack'))).thenAnswer(
      (_) async => [WeeklyStat(weekStart: monday, routineDaysDone: 3, cardioDaysDone: 1)],
    );
    when(() => nutrition.getWeeklyAdherence(weeksBack: any(named: 'weeksBack'))).thenAnswer(
      (_) async => [
        NutritionWeeklyStat(weekStart: monday, mealsLogged: 14, mealsExpected: 28, offPlanMeals: 0),
        NutritionWeeklyStat(
          weekStart: monday.add(const Duration(days: 7)),
          mealsLogged: 0,
          mealsExpected: 0,
          offPlanMeals: 0,
        ),
      ],
    );
    when(() => water.getConfig()).thenAnswer((_) async => null);
    when(() => water.getDailyTotalMl(any())).thenAnswer((_) async => 1500);
    when(() => sleep.getSleepLogsInRange(any(), any())).thenAnswer(
      (_) async => [
        SleepLog(
          id: 1,
          date: DateTime.utc(2026, 11, 2),
          sleepTime: DateTime.utc(2026, 11, 1, 23),
          wakeTime: DateTime.utc(2026, 11, 2, 6),
          hoursCalculated: 7,
          type: 'main',
        ),
        SleepLog(
          id: 2,
          date: DateTime.utc(2026, 11, 2),
          sleepTime: DateTime.utc(2026, 11, 2, 14),
          wakeTime: DateTime.utc(2026, 11, 2, 15),
          hoursCalculated: 1,
          type: 'nap',
        ),
      ],
    );
    when(() => progress.getMeasurements()).thenAnswer((_) async => []);
    when(() => nutrition.getAllPlans()).thenAnswer((_) async => []);
  });

  Future<ProgressOverviewState> load() async {
    final cubit = ProgressOverviewCubit(
      exercise: exercise,
      nutrition: nutrition,
      water: water,
      sleep: sleep,
      progress: progress,
      now: () => DateTime(2026, 11, 2, 12),
    );
    await cubit.load();
    final state = cubit.state;
    await cubit.close();
    return state;
  }

  test('separa rutina y cardio en cada semana', () async {
    final state = await load();
    expect(state.exercise.single.values, [3, 1]);
    expect(state.exercise.single.label, '26/10');
  });

  test('una semana sin comidas esperadas vale cero, no divide entre cero', () async {
    final state = await load();
    expect(state.nutrition.map((b) => b.total), [50, 0]);
  });

  test('pasa el agua a litros y termina en el día de hoy', () async {
    final state = await load();
    expect(state.water, hasLength(7));
    expect(state.water.last, const ChartBar('L', [1.5]));
  });

  test('suma todas las siestas del mismo día', () async {
    final state = await load();
    expect(state.sleep.last.total, 8);
    expect(state.sleep.first.total, 0);
  });

  test('comidas cumplidas solo muestra semanas del plan actual', () async {
    final plan = MealPlan(
      id: 1,
      name: 'Noviembre',
      createdAt: DateTime.utc(2026, 11, 3),
      isActive: true,
      dailyMealGoal: 4,
      periodStart: DateTime.utc(2026, 11, 3),
    );
    when(() => nutrition.getAllPlans()).thenAnswer((_) async => [plan]);
    when(() => nutrition.getPlanMealCounts(plan))
        .thenAnswer((_) async => (logged: 2, expected: 4));

    final state = await load();

    expect(state.nutrition.map((b) => b.label), ['02/11']);
    expect(state.plans.single.adherencePercent, 50);
  });

  test('si una fuente falla queda en error en vez de romper la pantalla', () async {
    when(() => progress.getMeasurements()).thenThrow(Exception('db'));
    final state = await load();
    expect(state.status, OverviewStatus.failure);
  });
}
