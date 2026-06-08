import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get_it/get_it.dart';
import 'package:kiolog/core/di/injection.dart';
import 'package:kiolog/core/router/app_router.dart';
import 'package:kiolog/core/theme/app_theme.dart';
import 'package:kiolog/features/nutrition/domain/repositories/nutrition_repository.dart';
import 'package:kiolog/features/nutrition/presentation/pages/nutrition_page.dart';
import 'package:mocktail/mocktail.dart';

class MockNutritionRepository extends Mock implements NutritionRepository {}

void main() {
  setUp(() {
    getIt.registerLazySingleton<NutritionRepository>(
      () => MockNutritionRepository(),
    );
  });

  tearDown(() async {
    await getIt.reset();
  });

  testWidgets('AppScaffold muestra NavigationBar con 5 destinos',
      (tester) async {
    await tester.pumpWidget(
      MaterialApp.router(
        routerConfig: appRouter,
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
        routerConfig: appRouter,
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
