import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kiolog/features/water/presentation/pages/water_config_page.dart';

void main() {
  group('WaterConfigPage', () {
    testWidgets('pide solo la meta diaria, sin botella ni vaso', (tester) async {
      await tester.pumpWidget(MaterialApp(home: WaterConfigPage(onComplete: () {})));

      expect(find.text('¿Cuánta agua quieres tomar al día?'), findsOneWidget);
      expect(find.text('3 L'), findsOneWidget);
      expect(find.textContaining('Botella'), findsNothing);
      expect(find.textContaining('Vaso'), findsNothing);
    });

    testWidgets('elegir un atajo cambia la meta', (tester) async {
      await tester.pumpWidget(MaterialApp(home: WaterConfigPage(onComplete: () {})));

      await tester.tap(find.text('2.5 L'));
      await tester.pump();

      expect(find.text('2500 ml'), findsOneWidget);
    });

    testWidgets('tiene el botón Guardar', (tester) async {
      await tester.pumpWidget(MaterialApp(home: WaterConfigPage(onComplete: () {})));

      expect(find.widgetWithText(ElevatedButton, 'Guardar'), findsOneWidget);
    });
  });
}
