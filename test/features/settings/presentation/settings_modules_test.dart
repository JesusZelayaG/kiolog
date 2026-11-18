// test/features/settings/presentation/settings_modules_test.dart
import 'package:bloc_test/bloc_test.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kiolog/core/domain/app_module.dart';
import 'package:kiolog/core/modules/cubit/modules_cubit.dart';
import 'package:kiolog/core/modules/cubit/modules_state.dart';
import 'package:kiolog/core/theme/app_theme.dart';
import 'package:kiolog/core/theme/theme_cubit.dart';
import 'package:kiolog/features/settings/presentation/pages/settings_page.dart';
import 'package:mocktail/mocktail.dart';

class MockModulesCubit extends MockCubit<ModulesState> implements ModulesCubit {}

Widget _wrap(ModulesState state) {
  final cubit = MockModulesCubit();
  when(() => cubit.state).thenReturn(state);
  whenListen(cubit, Stream.value(state));
  when(() => cubit.setModuleEnabled(any(), any())).thenAnswer((_) async {});
  return MultiBlocProvider(
    providers: [
      BlocProvider<ModulesCubit>.value(value: cubit),
      BlocProvider(create: (_) => ThemeCubit(KiologThemeId.fallback)),
    ],
    child: const MaterialApp(home: SettingsPage()),
  );
}

void main() {
  // Pantalla de teléfono: la lista construye todos los módulos.
  setUp(() {
    final view = TestWidgetsFlutterBinding.instance.platformDispatcher.views.first;
    view.physicalSize = const Size(1080, 2400);
    view.devicePixelRatio = 2.625;
  });
  tearDown(() {
    final view = TestWidgetsFlutterBinding.instance.platformDispatcher.views.first;
    view.resetPhysicalSize();
    view.resetDevicePixelRatio();
  });

  setUpAll(() {
    registerFallbackValue(AppModule.nutrition);
  });

  group('Settings — Módulos activos', () {
    testWidgets('shows the modules section header', (tester) async {
      await tester.pumpWidget(_wrap(ModulesState(statuses: {
        AppModule.nutrition: true,
        AppModule.water: true,
        AppModule.exercise: true,
      })));
      await tester.pumpAndSettle();
      expect(find.text('MÓDULOS'), findsOneWidget);
      expect(find.text('3 de 3 encendidos'), findsOneWidget);
    });

    testWidgets('shows three module switch tiles', (tester) async {
      await tester.pumpWidget(_wrap(ModulesState(statuses: {
        AppModule.nutrition: true,
        AppModule.water: true,
        AppModule.exercise: true,
      })));
      await tester.pumpAndSettle();
      expect(find.byType(SwitchListTile), findsNWidgets(3));
    });

    testWidgets('inactive module shows switch as off', (tester) async {
      await tester.pumpWidget(_wrap(ModulesState(statuses: {
        AppModule.nutrition: false,
        AppModule.water: true,
        AppModule.exercise: true,
      })));
      await tester.pumpAndSettle();
      final switches = tester
          .widgetList<SwitchListTile>(find.byType(SwitchListTile))
          .toList();
      final nutritionSwitch = switches.firstWhere(
          (s) => (s.title as Text).data == 'Nutrición');
      expect(nutritionSwitch.value, isFalse);
    });

    testWidgets('tapping active switch shows deactivation confirm dialog',
        (tester) async {
      await tester.pumpWidget(_wrap(ModulesState(statuses: {
        AppModule.nutrition: true,
        AppModule.water: true,
        AppModule.exercise: true,
      })));
      await tester.pumpAndSettle();
      final switches = tester
          .widgetList<SwitchListTile>(find.byType(SwitchListTile))
          .toList();
      final nutritionTile = switches.firstWhere(
          (s) => (s.title as Text).data == 'Nutrición');
      nutritionTile.onChanged!(false);
      await tester.pumpAndSettle();
      expect(find.text('Desactivar'), findsOneWidget);
      expect(find.text('Cancelar'), findsOneWidget);
    });
  });
}
