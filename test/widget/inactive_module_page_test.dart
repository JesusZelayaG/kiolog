import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kiolog/core/domain/app_module.dart';
import 'package:kiolog/shared/widgets/inactive_module_page.dart';

void main() {
  group('InactiveModulePage', () {
    testWidgets('shows correct title for nutrition', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(home: InactiveModulePage(module: AppModule.nutrition)),
      );
      expect(find.text('Nutrición no activado'), findsOneWidget);
    });

    testWidgets('shows correct title for exercise', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(home: InactiveModulePage(module: AppModule.exercise)),
      );
      expect(find.text('Ejercicio no activado'), findsOneWidget);
    });

    testWidgets('shows correct title for water', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(home: InactiveModulePage(module: AppModule.water)),
      );
      expect(find.text('Hidratación no activado'), findsOneWidget);
    });

    testWidgets('shows Activar y configurar button', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(home: InactiveModulePage(module: AppModule.nutrition)),
      );
      expect(
        find.widgetWithText(FilledButton, 'Activar y configurar'),
        findsOneWidget,
      );
    });
  });
}
