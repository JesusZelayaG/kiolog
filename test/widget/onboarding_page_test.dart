import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kiolog/core/theme/app_theme.dart';
import 'package:kiolog/core/theme/theme_cubit.dart';
import 'package:kiolog/features/onboarding/presentation/pages/onboarding_page.dart';

Widget _wrap(Widget child) => BlocProvider(
      create: (_) => ThemeCubit(KiologThemeId.fallback),
      child: MaterialApp(home: child),
    );

void main() {
  group('OnboardingPage — shell', () {
    testWidgets('no muestra flecha Atrás en el paso 0', (tester) async {
      await tester.pumpWidget(_wrap(const OnboardingPage()));
      await tester.pump();
      expect(find.byIcon(Icons.arrow_back_ios_new), findsNothing);
    });

    testWidgets('muestra pill button con texto Siguiente en paso 0',
        (tester) async {
      await tester.pumpWidget(_wrap(const OnboardingPage()));
      await tester.pump();
      expect(find.text('Siguiente'), findsOneWidget);
      expect(find.byType(ElevatedButton), findsOneWidget);
    });
  });

  group('OnboardingPage — welcome step', () {
    testWidgets('ofrece restaurar un respaldo existente', (tester) async {
      await tester.pumpWidget(_wrap(const OnboardingPage()));
      await tester.pump();
      expect(find.text('¿Ya usabas Kiolog?'), findsOneWidget);
      expect(find.text('Ya tengo un respaldo'), findsOneWidget);
    });

    testWidgets('muestra encabezado Bienvenida', (tester) async {
      await tester.pumpWidget(_wrap(const OnboardingPage()));
      await tester.pump();
      expect(find.text('Bienvenida'), findsOneWidget);
    });

    testWidgets('muestra tarjeta NECESITAMOS QUE NOS CUENTES', (tester) async {
      await tester.pumpWidget(_wrap(const OnboardingPage()));
      await tester.pump();
      expect(find.text('NECESITAMOS QUE NOS CUENTES:'), findsOneWidget);
    });

    testWidgets('muestra los 4 ítems de módulos', (tester) async {
      await tester.pumpWidget(_wrap(const OnboardingPage()));
      await tester.pump();
      expect(find.text('Cómo medirás tu agua'), findsOneWidget);
      expect(find.text('Tu plan de alimentación'), findsOneWidget);
      expect(find.text('Tu rutina de ejercicio'), findsOneWidget);
      expect(find.text('Tu peso de inicio'), findsOneWidget);
    });
  });
}
