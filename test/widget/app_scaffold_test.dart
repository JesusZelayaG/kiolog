import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get_it/get_it.dart';
import 'package:kiolog/core/di/injection.dart';
import 'package:kiolog/core/router/app_router.dart';
import 'package:kiolog/core/theme/app_theme.dart';
import 'package:kiolog/features/exercise/domain/repositories/exercise_repository.dart';
import 'package:kiolog/features/nutrition/domain/repositories/nutrition_repository.dart';
import 'package:kiolog/features/nutrition/presentation/pages/nutrition_page.dart';
import 'package:kiolog/features/sleep/domain/repositories/sleep_repository.dart';
import 'package:kiolog/features/water/domain/repositories/water_repository.dart';
import 'package:mocktail/mocktail.dart';

class MockNutritionRepository extends Mock implements NutritionRepository {}

class MockWaterRepository extends Mock implements WaterRepository {}

class MockSleepRepository extends Mock implements SleepRepository {}

class MockExerciseRepository extends Mock implements ExerciseRepository {}

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
  });

  tearDown(() async {
    await getIt.reset();
  });

  testWidgets('AppScaffold muestra NavigationBar con 5 destinos',
      (tester) async {
    await tester.pumpWidget(
      MaterialApp.router(
        routerConfig: createRouter(),
        theme: AppTheme.light,
      ),
    );

    expect(find.byType(NavigationBar), findsOneWidget);
    expect(find.text('Inicio'), findsWidgets);
    expect(find.text('Nutrición'), findsWidgets);
    expect(find.text('Ejercicio'), findsWidgets);
    expect(find.text('Progreso'), findsWidgets);
    expect(find.text('Ajustes'), findsWidgets);
  });

  testWidgets('tap en Nutrición navega a la página correcta', (tester) async {
    await tester.pumpWidget(
      MaterialApp.router(
        routerConfig: createRouter(),
        theme: AppTheme.light,
      ),
    );

    await tester.tap(
      find.descendant(
        of: find.byType(NavigationBar),
        matching: find.text('Nutrición'),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.byType(NutritionPage), findsOneWidget);
  });
}
