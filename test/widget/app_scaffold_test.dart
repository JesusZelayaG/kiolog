import 'package:bloc_test/bloc_test.dart';
import 'package:flutter/material.dart';
import 'package:iconsax_plus/iconsax_plus.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get_it/get_it.dart';
import 'package:go_router/go_router.dart';
import 'package:kiolog/core/di/injection.dart';
import 'package:kiolog/core/domain/app_module.dart';
import 'package:kiolog/core/modules/cubit/modules_cubit.dart';
import 'package:kiolog/core/modules/cubit/modules_state.dart';
import 'package:kiolog/core/router/app_router.dart';
import 'package:kiolog/core/theme/app_theme.dart';
import 'package:kiolog/features/exercise/domain/repositories/exercise_repository.dart';
import 'package:kiolog/features/nutrition/domain/repositories/nutrition_repository.dart';
import 'package:kiolog/features/nutrition/presentation/pages/nutrition_page.dart';
import 'package:kiolog/features/sleep/domain/repositories/sleep_repository.dart';
import 'package:kiolog/features/water/domain/repositories/water_repository.dart';
import 'package:kiolog/shared/widgets/app_scaffold.dart';
import 'package:mocktail/mocktail.dart';

class MockNutritionRepository extends Mock implements NutritionRepository {}

class MockWaterRepository extends Mock implements WaterRepository {}

class MockSleepRepository extends Mock implements SleepRepository {}

class MockExerciseRepository extends Mock implements ExerciseRepository {}

class MockModulesCubit extends MockCubit<ModulesState> implements ModulesCubit {}

// helper — pump AppScaffold inside a minimal GoRouter shell with a given ModulesState
Widget _wrapWithModules(ModulesState state) {
  final cubit = MockModulesCubit();
  when(() => cubit.state).thenReturn(state);
  whenListen(cubit, Stream.value(state));
  // Replace any existing ModulesCubit registration so AppScaffold gets our mock
  if (getIt.isRegistered<ModulesCubit>()) {
    getIt.unregister<ModulesCubit>();
  }
  getIt.registerSingleton<ModulesCubit>(cubit);
  return MaterialApp.router(
    routerConfig: GoRouter(
      routes: [
        ShellRoute(
          builder: (_, __, child) => AppScaffold(child: child),
          routes: [
            GoRoute(path: '/', builder: (_, __) => const SizedBox()),
          ],
        ),
      ],
    ),
  );
}

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
    // Register a default ModulesCubit so AppScaffold can retrieve it via getIt
    final defaultCubit = MockModulesCubit();
    when(() => defaultCubit.state).thenReturn(const ModulesState());
    whenListen(defaultCubit, Stream<ModulesState>.empty());
    getIt.registerSingleton<ModulesCubit>(defaultCubit);
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

  group('AppScaffold inactive module indicators', () {
    testWidgets('shows lock icon when nutrition is inactive', (tester) async {
      final state = ModulesState(statuses: {
        AppModule.nutrition: false,
        AppModule.water: true,
        AppModule.exercise: true,
      });
      await tester.pumpWidget(_wrapWithModules(state));
      await tester.pumpAndSettle();
      expect(find.byIcon(IconsaxPlusBold.lock), findsOneWidget);
    });

    testWidgets('shows no lock icon when all modules active', (tester) async {
      final state = ModulesState(statuses: {
        AppModule.nutrition: true,
        AppModule.water: true,
        AppModule.exercise: true,
      });
      await tester.pumpWidget(_wrapWithModules(state));
      await tester.pumpAndSettle();
      expect(find.byIcon(IconsaxPlusBold.lock), findsNothing);
    });

    testWidgets('shows two lock icons when nutrition and exercise inactive',
        (tester) async {
      final state = ModulesState(statuses: {
        AppModule.nutrition: false,
        AppModule.water: true,
        AppModule.exercise: false,
      });
      await tester.pumpWidget(_wrapWithModules(state));
      await tester.pumpAndSettle();
      expect(find.byIcon(IconsaxPlusBold.lock), findsNWidgets(2));
    });
  });
}
