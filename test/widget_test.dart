import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get_it/get_it.dart';
import 'package:kiolog/core/di/injection.dart';
import 'package:kiolog/core/router/app_router.dart';
import 'package:kiolog/core/theme/app_theme.dart';
import 'package:kiolog/features/exercise/domain/repositories/exercise_repository.dart';
import 'package:kiolog/features/nutrition/domain/repositories/nutrition_repository.dart';
import 'package:kiolog/features/progress/domain/repositories/progress_repository.dart';
import 'package:kiolog/features/sleep/domain/repositories/sleep_repository.dart';
import 'package:kiolog/features/water/domain/repositories/water_repository.dart';
import 'package:mocktail/mocktail.dart';

class MockNutritionRepository extends Mock implements NutritionRepository {}

class MockWaterRepository extends Mock implements WaterRepository {}

class MockSleepRepository extends Mock implements SleepRepository {}

class MockExerciseRepository extends Mock implements ExerciseRepository {}

class MockProgressRepository extends Mock implements ProgressRepository {}

void main() {
  setUp(() {
    getIt.registerLazySingleton<NutritionRepository>(
      () => MockNutritionRepository(),
    );
    getIt.registerLazySingleton<WaterRepository>(
      () => MockWaterRepository(),
    );
    getIt.registerLazySingleton<SleepRepository>(
      () => MockSleepRepository(),
    );
    getIt.registerLazySingleton<ExerciseRepository>(
      () => MockExerciseRepository(),
    );
    getIt.registerLazySingleton<ProgressRepository>(
      () => MockProgressRepository(),
    );
  });

  tearDown(() async {
    await getIt.reset();
  });

  testWidgets('KiologApp smoke test — renders NavigationBar',
      (WidgetTester tester) async {
    await tester.pumpWidget(
      MaterialApp.router(
        routerConfig: createRouter(),
        theme: AppTheme.light,
      ),
    );

    expect(find.byType(NavigationBar), findsOneWidget);
  });
}
