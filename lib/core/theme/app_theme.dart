// lib/core/theme/app_theme.dart
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

/// Los temas que el usuario elige en Ajustes o al configurar la app.
enum KiologThemeId {
  noche('Kiolog noche', 'Oscuro, con los colores del ícono'),
  claro('Kiolog claro', 'Claro, con los colores del ícono'),
  salvia('Salvia', 'Verde salvia y terracota sobre arena');

  const KiologThemeId(this.label, this.description);
  final String label;
  final String description;

  static const fallback = KiologThemeId.noche;

  static KiologThemeId fromName(String? name) =>
      values.where((t) => t.name == name).firstOrNull ?? fallback;
}

/// Medidas compartidas por todos los temas.
class Tropical {
  Tropical._();

  static const cardRadius = 32.0;
}

/// Colores de cada área (agua, sueño, comida, ejercicio) y de marca que no
/// caben en [ColorScheme]. Se leen con `context.kc`.
@immutable
class KiologColors extends ThemeExtension<KiologColors> {
  const KiologColors({
    required this.waterWash,
    required this.waterInk,
    required this.sleepWash,
    required this.sleepInk,
    required this.foodWash,
    required this.foodInk,
    required this.foodAccent,
    required this.gymWash,
    required this.gymInk,
    required this.brandGradient,
    required this.shadow,
    required this.success,
    required this.warning,
    required this.gold,
  });

  final Color waterWash;
  final Color waterInk;
  final Color sleepWash;
  final Color sleepInk;
  final Color foodWash;
  final Color foodInk;
  final Color foodAccent;
  final Color gymWash;
  final Color gymInk;

  /// El degradado del ícono, para botones y acentos destacados.
  final LinearGradient brandGradient;
  final BoxShadow shadow;
  final Color success;
  final Color warning;
  final Color gold;

  @override
  KiologColors copyWith() => this;

  @override
  KiologColors lerp(ThemeExtension<KiologColors>? other, double t) {
    if (other is! KiologColors) return this;
    Color c(Color a, Color b) => Color.lerp(a, b, t)!;
    return KiologColors(
      waterWash: c(waterWash, other.waterWash),
      waterInk: c(waterInk, other.waterInk),
      sleepWash: c(sleepWash, other.sleepWash),
      sleepInk: c(sleepInk, other.sleepInk),
      foodWash: c(foodWash, other.foodWash),
      foodInk: c(foodInk, other.foodInk),
      foodAccent: c(foodAccent, other.foodAccent),
      gymWash: c(gymWash, other.gymWash),
      gymInk: c(gymInk, other.gymInk),
      brandGradient: LinearGradient.lerp(brandGradient, other.brandGradient, t)!,
      shadow: BoxShadow.lerp(shadow, other.shadow, t)!,
      success: c(success, other.success),
      warning: c(warning, other.warning),
      gold: c(gold, other.gold),
    );
  }
}


/// Colores del Home: anillos del día, ola del agua, tarjeta de la rutina y
/// manchas del fondo. Se leen con `context.hc`.
@immutable
class KiologHomeColors extends ThemeExtension<KiologHomeColors> {
  const KiologHomeColors({
    required this.rings,
    required this.ringTrack,
    required this.waterFill,
    required this.waveBack,
    required this.waterNumber,
    required this.barOn,
    required this.barOff,
    required this.foodOn,
    required this.foodOff,
    required this.gymCard,
    required this.gymChip,
    required this.gymInk,
    required this.gymSub,
    required this.gymButton,
    required this.pulse,
    required this.blobs,
  });

  /// Agua, comidas, sueño y ejercicio, de afuera hacia adentro.
  final List<Color> rings;
  final Color ringTrack;

  /// Arriba y abajo del agua que llena la tarjeta.
  final List<Color> waterFill;
  final Color waveBack;
  final Color waterNumber;
  final Color barOn;
  final Color barOff;
  final Color foodOn;
  final Color foodOff;
  final LinearGradient gymCard;
  final Color gymChip;
  final Color gymInk;
  final Color gymSub;
  final LinearGradient gymButton;
  final Color pulse;
  final List<Color> blobs;

  @override
  KiologHomeColors copyWith() => this;

  @override
  KiologHomeColors lerp(ThemeExtension<KiologHomeColors>? other, double t) {
    if (other is! KiologHomeColors) return this;
    Color c(Color a, Color b) => Color.lerp(a, b, t)!;
    List<Color> l(List<Color> a, List<Color> b) => [for (var i = 0; i < a.length; i++) c(a[i], b[i])];
    return KiologHomeColors(
      rings: l(rings, other.rings),
      ringTrack: c(ringTrack, other.ringTrack),
      waterFill: l(waterFill, other.waterFill),
      waveBack: c(waveBack, other.waveBack),
      waterNumber: c(waterNumber, other.waterNumber),
      barOn: c(barOn, other.barOn),
      barOff: c(barOff, other.barOff),
      foodOn: c(foodOn, other.foodOn),
      foodOff: c(foodOff, other.foodOff),
      gymCard: LinearGradient.lerp(gymCard, other.gymCard, t)!,
      gymChip: c(gymChip, other.gymChip),
      gymInk: c(gymInk, other.gymInk),
      gymSub: c(gymSub, other.gymSub),
      gymButton: LinearGradient.lerp(gymButton, other.gymButton, t)!,
      pulse: c(pulse, other.pulse),
      blobs: l(blobs, other.blobs),
    );
  }
}

LinearGradient _solid(Color color) => LinearGradient(colors: [color, color]);

extension KiologThemeContext on BuildContext {
  /// Sin tema de Kiolog (un MaterialApp de prueba), usa los colores del tema
  /// claro u oscuro según el brillo.
  KiologColors get kc {
    final theme = Theme.of(this);
    return theme.extension<KiologColors>() ??
        (theme.brightness == Brightness.dark ? _noche.colors : _claro.colors);
  }

  KiologHomeColors get hc {
    final theme = Theme.of(this);
    return theme.extension<KiologHomeColors>() ??
        (theme.brightness == Brightness.dark ? _noche.home : _claro.home);
  }
}

/// Todo lo que cambia de un tema a otro.
class _Palette {
  const _Palette({required this.scheme, required this.action, required this.colors, required this.home});

  final ColorScheme scheme;

  /// Relleno de los botones con texto blanco.
  final Color action;
  final KiologColors colors;
  final KiologHomeColors home;
}

const _brandGradient = LinearGradient(
  begin: Alignment.topLeft,
  end: Alignment.bottomRight,
  colors: [Color(0xFF1E7A4C), Color(0xFF6DAE3E)],
);

final _noche = _Palette(
  action: Color(0xFF2E8A55),
  scheme: const ColorScheme(
    brightness: Brightness.dark,
    primary: Color(0xFF8BBF3F),
    onPrimary: Color(0xFF0C1120),
    primaryContainer: Color(0xFF2E8A55),
    onPrimaryContainer: Color(0xFFE8F5DA),
    secondary: Color(0xFF3FAE6A),
    onSecondary: Color(0xFF0C1120),
    secondaryContainer: Color(0xFF1B3329),
    onSecondaryContainer: Color(0xFFA8DDB9),
    tertiary: Color(0xFFC9E39F),
    onTertiary: Color(0xFF0C1120),
    tertiaryContainer: Color(0xFF2B3A1C),
    onTertiaryContainer: Color(0xFFDDEFC0),
    error: Color(0xFFFFB4AB),
    onError: Color(0xFF690005),
    errorContainer: Color(0xFF93000A),
    onErrorContainer: Color(0xFFFFDAD6),
    surface: Color(0xFF0C1120),
    onSurface: Color(0xFFEEF2EA),
    onSurfaceVariant: Color(0xFFA3ABBD),
    outline: Color(0xFF6C7488),
    outlineVariant: Color(0xFF2E3850),
    shadow: Color(0xFF000000),
    scrim: Color(0xFF000000),
    inverseSurface: Color(0xFFEEF2EA),
    onInverseSurface: Color(0xFF0C1120),
    inversePrimary: Color(0xFF1E7A4C),
    surfaceTint: Color(0xFF8BBF3F),
    surfaceContainerLowest: Color(0xFF161D30),
    surfaceContainerLow: Color(0xFF131A2B),
    surfaceContainer: Color(0xFF1A2236),
    surfaceContainerHigh: Color(0xFF212A40),
    surfaceContainerHighest: Color(0xFF29334B),
  ),
  colors: const KiologColors(
    waterWash: Color(0xFF13261F),
    waterInk: Color(0xFFA8DDB9),
    sleepWash: Color(0xFF1C2439),
    sleepInk: Color(0xFFB7C1D9),
    foodWash: Color(0xFF1F2A17),
    foodInk: Color(0xFFC9E39F),
    foodAccent: Color(0xFF8BBF3F),
    gymWash: Color(0xFF173225),
    gymInk: Color(0xFFD8F0B0),
    brandGradient: _brandGradient,
    shadow: BoxShadow(color: Color(0x40000000), offset: Offset(0, 8), blurRadius: 24, spreadRadius: -4),
    success: Color(0xFF8BBF3F),
    warning: Color(0xFFE0B252),
    gold: Color(0xFFE5B63A),
  ),
  home: KiologHomeColors(
    rings: const [Color(0xFF8BBF3F), Color(0xFF3FAE6A), Color(0xFF5E6B8A), Color(0xFFC9D3E6)],
    ringTrack: const Color(0xFF222A3D),
    waterFill: const [Color(0xFF1E6B45), Color(0xFF165236)],
    waveBack: const Color(0xFF24563E),
    waterNumber: const Color(0xFFFFFFFF),
    barOn: const Color(0xFF8BBF3F),
    barOff: const Color(0xFF2C3549),
    foodOn: const Color(0xFF8BBF3F),
    foodOff: const Color(0xFF2C3549),
    gymCard: const LinearGradient(
      begin: Alignment.topLeft,
      end: Alignment.bottomRight,
      colors: [Color(0xFF17603C), Color(0xFF3E9A48)],
    ),
    gymChip: const Color(0x24FFFFFF),
    gymInk: const Color(0xFFD8F0B0),
    gymSub: const Color(0xFFD3E8D8),
    gymButton: _solid(const Color(0xFF0C1120)),
    pulse: const Color(0x808BBF3F),
    blobs: const [Color(0x382EA05A), Color(0x1F8CC03F)],
  ),
);

final _claro = _Palette(
  action: Color(0xFF1E7A4C),
  scheme: const ColorScheme(
    brightness: Brightness.light,
    primary: Color(0xFF1E7A4C),
    onPrimary: Color(0xFFFFFFFF),
    primaryContainer: Color(0xFF1E7A4C),
    onPrimaryContainer: Color(0xFFE7F2E6),
    secondary: Color(0xFF0E1424),
    onSecondary: Color(0xFFFFFFFF),
    secondaryContainer: Color(0xFFEEF0F4),
    onSecondaryContainer: Color(0xFF2A3350),
    tertiary: Color(0xFF4F7A1C),
    onTertiary: Color(0xFFFFFFFF),
    tertiaryContainer: Color(0xFFF0F5E6),
    onTertiaryContainer: Color(0xFF3F5F14),
    error: Color(0xFFBA1A1A),
    onError: Color(0xFFFFFFFF),
    errorContainer: Color(0xFFFFDAD6),
    onErrorContainer: Color(0xFF93000A),
    surface: Color(0xFFF6F7F2),
    onSurface: Color(0xFF0E1424),
    onSurfaceVariant: Color(0xFF4A5263),
    outline: Color(0xFF7A8292),
    outlineVariant: Color(0xFFCDD3CA),
    shadow: Color(0xFF000000),
    scrim: Color(0xFF000000),
    inverseSurface: Color(0xFF0E1424),
    onInverseSurface: Color(0xFFF6F7F2),
    inversePrimary: Color(0xFF8BBF3F),
    surfaceTint: Color(0xFF1E7A4C),
    surfaceContainerLowest: Color(0xFFFFFFFF),
    surfaceContainerLow: Color(0xFFF0F2EC),
    surfaceContainer: Color(0xFFEAEDE6),
    surfaceContainerHigh: Color(0xFFE4E8E0),
    surfaceContainerHighest: Color(0xFFDDE2D9),
  ),
  colors: const KiologColors(
    waterWash: Color(0xFFE7F2E6),
    waterInk: Color(0xFF1E5E3C),
    sleepWash: Color(0xFFEEF0F4),
    sleepInk: Color(0xFF2A3350),
    foodWash: Color(0xFFF0F5E6),
    foodInk: Color(0xFF3F5F14),
    foodAccent: Color(0xFF6DAE3E),
    gymWash: Color(0xFFE3E6EE),
    gymInk: Color(0xFF0E1424),
    brandGradient: _brandGradient,
    shadow: BoxShadow(color: Color(0x140E1424), offset: Offset(0, 8), blurRadius: 24, spreadRadius: -4),
    success: Color(0xFF1E7A4C),
    warning: Color(0xFFB7791F),
    gold: Color(0xFFD9A21E),
  ),
  home: KiologHomeColors(
    rings: const [Color(0xFF1E7A4C), Color(0xFF8BBF3F), Color(0xFF0E1424), Color(0xFF9AA3B5)],
    ringTrack: const Color(0xFFEDF0EA),
    waterFill: const [Color(0xFFC5E3B8), Color(0xFFA6D396)],
    waveBack: const Color(0xFFD8ECCF),
    waterNumber: const Color(0xFF0E3B24),
    barOn: const Color(0xFF0E1424),
    barOff: const Color(0xFFCDD2DC),
    foodOn: const Color(0xFF6DAE3E),
    foodOff: const Color(0xFFD6E5C2),
    gymCard: _solid(const Color(0xFF0E1424)),
    gymChip: const Color(0xFF1C2438),
    gymInk: const Color(0xFF9BD15A),
    gymSub: const Color(0xFFB9C0CF),
    gymButton: const LinearGradient(
      begin: Alignment.topLeft,
      end: Alignment.bottomRight,
      colors: [Color(0xFF1E7A4C), Color(0xFF8BBF3F)],
    ),
    pulse: const Color(0x808BBF3F),
    blobs: const [Color(0x428BBF3F), Color(0x1F1E7A4C)],
  ),
);

final _salvia = _Palette(
  action: Color(0xFF4E7A62),
  scheme: const ColorScheme(
    brightness: Brightness.light,
    primary: Color(0xFF4E7A62),
    onPrimary: Color(0xFFFFFFFF),
    primaryContainer: Color(0xFF4E7A62),
    onPrimaryContainer: Color(0xFFEBF0E8),
    secondary: Color(0xFFB86B47),
    onSecondary: Color(0xFFFFFFFF),
    secondaryContainer: Color(0xFFF5EBE2),
    onSecondaryContainer: Color(0xFF8C4F32),
    tertiary: Color(0xFF8C4F32),
    onTertiary: Color(0xFFFFFFFF),
    tertiaryContainer: Color(0xFFF5EBE2),
    onTertiaryContainer: Color(0xFF6B3A24),
    error: Color(0xFFBA1A1A),
    onError: Color(0xFFFFFFFF),
    errorContainer: Color(0xFFFFDAD6),
    onErrorContainer: Color(0xFF93000A),
    surface: Color(0xFFF7F3EC),
    onSurface: Color(0xFF2A2723),
    onSurfaceVariant: Color(0xFF5E574F),
    outline: Color(0xFF8A8278),
    outlineVariant: Color(0xFFD6CEC2),
    shadow: Color(0xFF000000),
    scrim: Color(0xFF000000),
    inverseSurface: Color(0xFF2A2723),
    onInverseSurface: Color(0xFFF7F3EC),
    inversePrimary: Color(0xFFA9C9B5),
    surfaceTint: Color(0xFF4E7A62),
    surfaceContainerLowest: Color(0xFFFFFDF9),
    surfaceContainerLow: Color(0xFFF1EDE6),
    surfaceContainer: Color(0xFFECE7DF),
    surfaceContainerHigh: Color(0xFFE6E0D6),
    surfaceContainerHighest: Color(0xFFDFD8CD),
  ),
  colors: const KiologColors(
    waterWash: Color(0xFFEBF0E8),
    waterInk: Color(0xFF3D5E4C),
    sleepWash: Color(0xFFEDEAE4),
    sleepInk: Color(0xFF5A6159),
    foodWash: Color(0xFFF5EBE2),
    foodInk: Color(0xFF8C4F32),
    foodAccent: Color(0xFFB86B47),
    gymWash: Color(0xFFEFE4DC),
    gymInk: Color(0xFF6B3A24),
    brandGradient: LinearGradient(
      begin: Alignment.topLeft,
      end: Alignment.bottomRight,
      colors: [Color(0xFF4E7A62), Color(0xFF6F9A80)],
    ),
    shadow: BoxShadow(color: Color(0x142A2723), offset: Offset(0, 8), blurRadius: 24, spreadRadius: -4),
    success: Color(0xFF4E7A62),
    warning: Color(0xFFC08A2E),
    gold: Color(0xFFD9A21E),
  ),
  home: KiologHomeColors(
    rings: const [Color(0xFF4E7A62), Color(0xFFB86B47), Color(0xFF93B3A2), Color(0xFFD7B58F)],
    ringTrack: const Color(0xFFEFE9DF),
    waterFill: const [Color(0xFFBFD1C3), Color(0xFFA0BCAA)],
    waveBack: const Color(0xFFD3E0D6),
    waterNumber: const Color(0xFF2B4639),
    barOn: const Color(0xFF4E7A62),
    barOff: const Color(0xFFD9D2C6),
    foodOn: const Color(0xFFB86B47),
    foodOff: const Color(0xFFE8D3C4),
    gymCard: _solid(const Color(0xFF2A2723)),
    gymChip: const Color(0xFF3C3631),
    gymInk: const Color(0xFFE3AC8E),
    gymSub: const Color(0xFFCFC6BC),
    gymButton: _solid(const Color(0xFFB86B47)),
    pulse: const Color(0x73B86B47),
    blobs: const [Color(0x4DA0B9A0), Color(0x47E1C3AA)],
  ),
);

class AppTheme {
  AppTheme._();

  static final _cache = <KiologThemeId, ThemeData>{};

  static ThemeData of(KiologThemeId id) => _cache.putIfAbsent(
        id,
        () => _build(switch (id) {
          KiologThemeId.noche => _noche,
          KiologThemeId.claro => _claro,
          KiologThemeId.salvia => _salvia,
        }),
      );

  static TextStyle _font(
    Color color,
    double size,
    FontWeight weight,
    double lineHeight, {
    double tracking = 0,
  }) =>
      GoogleFonts.plusJakartaSans(
        fontSize: size,
        fontWeight: weight,
        height: lineHeight / size,
        letterSpacing: tracking * size,
        color: color,
      );

  static TextTheme _textTheme(ColorScheme cs) {
    final on = cs.onSurface;
    final variant = cs.onSurfaceVariant;
    final base = GoogleFonts.plusJakartaSansTextTheme(
      cs.brightness == Brightness.dark ? ThemeData.dark().textTheme : ThemeData.light().textTheme,
    );
    return base.copyWith(
      displayLarge: _font(on, 36, FontWeight.w800, 44, tracking: -0.03),
      displayMedium: _font(on, 28, FontWeight.w800, 34, tracking: -0.02),
      headlineLarge: _font(on, 26, FontWeight.w700, 32, tracking: -0.02),
      headlineMedium: _font(on, 20, FontWeight.w700, 26, tracking: -0.01),
      titleLarge: _font(on, 20, FontWeight.w700, 26, tracking: -0.01),
      titleMedium: _font(on, 16, FontWeight.w600, 22),
      titleSmall: _font(on, 14, FontWeight.w600, 18),
      bodyLarge: _font(on, 16, FontWeight.w400, 24),
      bodyMedium: _font(on, 14, FontWeight.w400, 20),
      bodySmall: _font(variant, 12, FontWeight.w400, 16),
      labelLarge: _font(on, 14, FontWeight.w600, 18, tracking: 0.01),
      labelMedium: _font(on, 12, FontWeight.w600, 16, tracking: 0.02),
      labelSmall: _font(variant, 10, FontWeight.w700, 14, tracking: 0.04),
    );
  }

  static final _pill = WidgetStateProperty.all<OutlinedBorder>(const StadiumBorder());

  static ThemeData _build(_Palette p) {
    final cs = p.scheme;
    final on = cs.onSurface;
    return ThemeData(
      useMaterial3: true,
      brightness: cs.brightness,
      colorScheme: cs,
      extensions: [p.colors, p.home],
      textTheme: _textTheme(cs),
      scaffoldBackgroundColor: cs.surface,
      appBarTheme: AppBarTheme(
        backgroundColor: cs.surface,
        foregroundColor: on,
        elevation: 0,
        scrolledUnderElevation: 0,
        centerTitle: false,
        titleTextStyle: _font(on, 20, FontWeight.w700, 26, tracking: -0.01),
        iconTheme: IconThemeData(color: on),
        actionsIconTheme: IconThemeData(color: on),
      ),
      cardTheme: CardThemeData(
        color: cs.surfaceContainerLowest,
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(Tropical.cardRadius),
        ),
        margin: EdgeInsets.zero,
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: p.action,
          foregroundColor: Colors.white,
          minimumSize: const Size(48, 48),
          padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 24),
          textStyle: _font(Colors.white, 14, FontWeight.w600, 18, tracking: 0.01),
          elevation: 0,
        ).copyWith(shape: _pill),
      ),
      filledButtonTheme: FilledButtonThemeData(style: ButtonStyle(shape: _pill)),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: cs.primary,
          minimumSize: const Size(48, 48),
          side: BorderSide(color: cs.primary, width: 1.5),
          textStyle: _font(cs.primary, 14, FontWeight.w600, 18, tracking: 0.01),
        ).copyWith(shape: _pill),
      ),
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(
          foregroundColor: cs.primary,
          textStyle: _font(cs.primary, 14, FontWeight.w600, 18, tracking: 0.01),
        ).copyWith(shape: _pill),
      ),
      segmentedButtonTheme: SegmentedButtonThemeData(
        style: ButtonStyle(
          shape: _pill,
          backgroundColor: WidgetStateProperty.resolveWith(
            (states) => states.contains(WidgetState.selected) ? p.action : cs.surfaceContainerHigh,
          ),
          foregroundColor: WidgetStateProperty.resolveWith(
            (states) => states.contains(WidgetState.selected) ? Colors.white : on,
          ),
          side: WidgetStateProperty.all(BorderSide.none),
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: cs.surfaceContainerLow,
        floatingLabelBehavior: FloatingLabelBehavior.always,
        labelStyle: _font(cs.onSurfaceVariant, 12, FontWeight.w600, 16),
        floatingLabelStyle: _font(cs.primary, 12, FontWeight.w600, 16),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: BorderSide.none,
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: BorderSide(color: cs.outlineVariant),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: BorderSide(color: cs.primary, width: 1.5),
        ),
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      ),
      progressIndicatorTheme: ProgressIndicatorThemeData(
        color: cs.primary,
        linearTrackColor: cs.surfaceContainerHighest,
        linearMinHeight: 8,
        borderRadius: const BorderRadius.all(Radius.circular(100)),
      ),
      switchTheme: SwitchThemeData(
        thumbColor: WidgetStateProperty.all(const Color(0xFFFFFDF8)),
        trackColor: WidgetStateProperty.resolveWith(
          (states) => states.contains(WidgetState.selected) ? p.action : cs.surfaceContainerHighest,
        ),
        trackOutlineColor: WidgetStateProperty.all(Colors.transparent),
      ),
      chipTheme: ChipThemeData(
        backgroundColor: cs.surfaceContainerHigh,
        selectedColor: p.colors.waterWash,
        side: BorderSide.none,
        shape: const StadiumBorder(),
        labelStyle: _font(on, 12, FontWeight.w600, 16, tracking: 0.02),
      ),
      dividerTheme: DividerThemeData(color: cs.surfaceContainerHigh, thickness: 1),
      snackBarTheme: SnackBarThemeData(
        backgroundColor: cs.inverseSurface,
        contentTextStyle: _font(cs.onInverseSurface, 14, FontWeight.w400, 20),
        shape: const StadiumBorder(),
        behavior: SnackBarBehavior.floating,
      ),
      dialogTheme: DialogThemeData(
        backgroundColor: cs.surfaceContainerLowest,
        surfaceTintColor: Colors.transparent,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(Tropical.cardRadius),
        ),
      ),
      bottomSheetTheme: BottomSheetThemeData(
        backgroundColor: cs.surfaceContainerLowest,
        surfaceTintColor: Colors.transparent,
        shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(Tropical.cardRadius)),
        ),
      ),
    );
  }
}
