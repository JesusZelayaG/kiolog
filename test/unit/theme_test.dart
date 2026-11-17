import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kiolog/core/theme/app_theme.dart';
import 'package:kiolog/core/theme/theme_cubit.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('sin elección guardada se usa Kiolog noche', () async {
    SharedPreferences.setMockInitialValues({});

    final cubit = await ThemeCubit.load();

    expect(cubit.state, KiologThemeId.noche);
  });

  test('la elección se guarda y se recupera al abrir', () async {
    SharedPreferences.setMockInitialValues({});

    await (await ThemeCubit.load()).select(KiologThemeId.salvia);

    expect((await ThemeCubit.load()).state, KiologThemeId.salvia);
  });

  test('un nombre desconocido vuelve al tema por defecto', () {
    expect(KiologThemeId.fromName('tropical'), KiologThemeId.fallback);
  });

  test('cada tema trae sus colores de área y noche es oscuro', () {
    for (final id in KiologThemeId.values) {
      expect(AppTheme.of(id).extension<KiologColors>(), isNotNull, reason: id.name);
    }
    expect(AppTheme.of(KiologThemeId.noche).brightness, Brightness.dark);
    expect(AppTheme.of(KiologThemeId.claro).brightness, Brightness.light);
  });
}
