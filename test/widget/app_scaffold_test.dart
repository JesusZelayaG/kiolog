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

    expect(find.text('Nutrición — Próximamente'), findsOneWidget);
  });
}
