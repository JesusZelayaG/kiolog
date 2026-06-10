import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kiolog/features/water/presentation/pages/water_config_page.dart';

void main() {
  group('WaterConfigPage', () {
    testWidgets('shows unit selector and goal field', (tester) async {
      await tester.pumpWidget(
        MaterialApp(home: WaterConfigPage(onComplete: () {})),
      );
      expect(find.text('Configuración de Agua'), findsOneWidget);
      expect(find.byType(SegmentedButton<String>), findsOneWidget);
    });

    testWidgets('Guardar button exists', (tester) async {
      await tester.pumpWidget(
        MaterialApp(home: WaterConfigPage(onComplete: () {})),
      );
      expect(find.widgetWithText(FilledButton, 'Guardar'), findsOneWidget);
    });
  });
}
