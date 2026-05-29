// test/widget/app_scaffold_test.dart
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kiolog/core/router/app_router.dart';
import 'package:kiolog/core/theme/app_theme.dart';

void main() {
  testWidgets('AppScaffold muestra NavigationBar con 5 destinos',
      (tester) async {
    await tester.pumpWidget(
      MaterialApp.router(
        routerConfig: appRouter,
        theme: AppTheme.light,
      ),
    );

    expect(find.byType(NavigationBar), findsOneWidget);
    expect(find.text('Inicio'), findsOneWidget);
    expect(find.text('Nutrición'), findsOneWidget);
    expect(find.text('Ejercicio'), findsOneWidget);
    expect(find.text('Progreso'), findsOneWidget);
    expect(find.text('Ajustes'), findsOneWidget);
  });

  testWidgets('tap en Nutrición navega a la página correcta', (tester) async {
    await tester.pumpWidget(
      MaterialApp.router(
        routerConfig: appRouter,
        theme: AppTheme.light,
      ),
    );

    await tester.tap(find.text('Nutrición'));
    await tester.pumpAndSettle();

    expect(find.text('Nutrición — Próximamente'), findsOneWidget);
  });
}
