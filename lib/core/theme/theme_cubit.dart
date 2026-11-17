import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'app_theme.dart';

/// El tema elegido. Se guarda en el teléfono; no viaja en los respaldos.
class ThemeCubit extends Cubit<KiologThemeId> {
  ThemeCubit(super.initial);

  static const _key = 'kiolog.theme';

  /// Lee el tema guardado antes de mostrar la app, para que no parpadee.
  static Future<ThemeCubit> load() async {
    final prefs = await SharedPreferences.getInstance();
    return ThemeCubit(KiologThemeId.fromName(prefs.getString(_key)));
  }

  Future<void> select(KiologThemeId id) async {
    emit(id);
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_key, id.name);
  }
}
