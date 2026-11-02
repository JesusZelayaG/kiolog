// lib/core/theme/app_theme.dart
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

/// Tokens de Luminous Tropical que no caben en [ColorScheme].
class Tropical {
  Tropical._();

  static const mintWash = Color(0xFFD7EFE6);
  static const peachWash = Color(0xFFFDEFE3);
  static const guava = Color(0xFFF48B71);
  static const papaya = Color(0xFFFDB574);
  static const cardRadius = 32.0;
  static const softShadow = BoxShadow(
    color: Color(0x142E7D68),
    offset: Offset(0, 8),
    blurRadius: 24,
    spreadRadius: -4,
  );
  static const warmGradient = LinearGradient(colors: [guava, papaya]);
}

class AppTheme {
  AppTheme._();

  static const _onSurface = Color(0xFF1C1C19);
  static const _onSurfaceVariant = Color(0xFF3F4945);
  static const _primary = Color(0xFF076450);
  static const _primaryContainer = Color(0xFF2E7D68);

  static const ColorScheme _cs = ColorScheme(
    brightness: Brightness.light,
    primary: _primary,
    onPrimary: Color(0xFFFFFFFF),
    primaryContainer: _primaryContainer,
    onPrimaryContainer: Color(0xFFD3FFEE),
    secondary: Color(0xFF9A4530),
    onSecondary: Color(0xFFFFFFFF),
    secondaryContainer: Color(0xFFFF9479),
    onSecondaryContainer: Color(0xFF772B18),
    tertiary: Color(0xFF804B13),
    onTertiary: Color(0xFFFFFFFF),
    tertiaryContainer: Color(0xFF9D632A),
    onTertiaryContainer: Color(0xFFFFF3EC),
    error: Color(0xFFBA1A1A),
    onError: Color(0xFFFFFFFF),
    errorContainer: Color(0xFFFFDAD6),
    onErrorContainer: Color(0xFF93000A),
    surface: Color(0xFFFCF9F4),
    onSurface: _onSurface,
    onSurfaceVariant: _onSurfaceVariant,
    outline: Color(0xFF6F7975),
    outlineVariant: Color(0xFFBEC9C3),
    shadow: Color(0xFF000000),
    scrim: Color(0xFF000000),
    inverseSurface: Color(0xFF31302D),
    onInverseSurface: Color(0xFFF3F0EB),
    inversePrimary: Color(0xFF88D5BD),
    surfaceTint: Color(0xFF156B56),
    surfaceContainerLowest: Color(0xFFFFFFFF),
    surfaceContainerLow: Color(0xFFF6F3EE),
    surfaceContainer: Color(0xFFF0EDE9),
    surfaceContainerHigh: Color(0xFFEBE8E3),
    surfaceContainerHighest: Color(0xFFE5E2DD),
  );

  static TextStyle _font(
    double size,
    FontWeight weight,
    double lineHeight, {
    double tracking = 0,
    Color color = _onSurface,
  }) =>
      GoogleFonts.plusJakartaSans(
        fontSize: size,
        fontWeight: weight,
        height: lineHeight / size,
        letterSpacing: tracking * size,
        color: color,
      );

  static TextTheme _buildTextTheme() {
    final base = GoogleFonts.plusJakartaSansTextTheme(ThemeData.light().textTheme);
    return base.copyWith(
      displayLarge: _font(36, FontWeight.w800, 44, tracking: -0.03),
      displayMedium: _font(28, FontWeight.w800, 34, tracking: -0.02),
      headlineLarge: _font(26, FontWeight.w700, 32, tracking: -0.02),
      headlineMedium: _font(20, FontWeight.w700, 26, tracking: -0.01),
      titleLarge: _font(20, FontWeight.w700, 26, tracking: -0.01),
      titleMedium: _font(16, FontWeight.w600, 22),
      titleSmall: _font(14, FontWeight.w600, 18),
      bodyLarge: _font(16, FontWeight.w400, 24),
      bodyMedium: _font(14, FontWeight.w400, 20),
      bodySmall: _font(12, FontWeight.w400, 16, color: _onSurfaceVariant),
      labelLarge: _font(14, FontWeight.w600, 18, tracking: 0.01),
      labelMedium: _font(12, FontWeight.w600, 16, tracking: 0.02),
      labelSmall: _font(10, FontWeight.w700, 14, tracking: 0.04, color: _onSurfaceVariant),
    );
  }

  static final _pill = WidgetStateProperty.all<OutlinedBorder>(const StadiumBorder());

  static ThemeData get light => ThemeData(
        useMaterial3: true,
        colorScheme: _cs,
        textTheme: _buildTextTheme(),
        scaffoldBackgroundColor: _cs.surface,
        appBarTheme: AppBarTheme(
          backgroundColor: _cs.surface,
          foregroundColor: _onSurface,
          elevation: 0,
          scrolledUnderElevation: 0,
          centerTitle: false,
          titleTextStyle: _font(20, FontWeight.w700, 26, tracking: -0.01),
          iconTheme: const IconThemeData(color: _onSurface),
          actionsIconTheme: const IconThemeData(color: _onSurface),
        ),
        cardTheme: CardThemeData(
          color: _cs.surfaceContainerLowest,
          elevation: 0,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(Tropical.cardRadius),
          ),
          margin: EdgeInsets.zero,
        ),
        elevatedButtonTheme: ElevatedButtonThemeData(
          style: ElevatedButton.styleFrom(
            backgroundColor: _primaryContainer,
            foregroundColor: Colors.white,
            minimumSize: const Size(48, 48),
            padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 24),
            textStyle: _font(14, FontWeight.w600, 18, tracking: 0.01),
            elevation: 0,
          ).copyWith(shape: _pill),
        ),
        filledButtonTheme: FilledButtonThemeData(style: ButtonStyle(shape: _pill)),
        outlinedButtonTheme: OutlinedButtonThemeData(
          style: OutlinedButton.styleFrom(
            foregroundColor: _primaryContainer,
            minimumSize: const Size(48, 48),
            side: const BorderSide(color: _primaryContainer, width: 1.5),
            textStyle: _font(14, FontWeight.w600, 18, tracking: 0.01),
          ).copyWith(shape: _pill),
        ),
        textButtonTheme: TextButtonThemeData(
          style: TextButton.styleFrom(
            foregroundColor: _primary,
            textStyle: _font(14, FontWeight.w600, 18, tracking: 0.01),
          ).copyWith(shape: _pill),
        ),
        segmentedButtonTheme: SegmentedButtonThemeData(
          style: ButtonStyle(
            shape: _pill,
            backgroundColor: WidgetStateProperty.resolveWith(
              (states) => states.contains(WidgetState.selected)
                  ? _primaryContainer
                  : _cs.surfaceContainerHigh,
            ),
            foregroundColor: WidgetStateProperty.resolveWith(
              (states) => states.contains(WidgetState.selected) ? Colors.white : _onSurface,
            ),
            side: WidgetStateProperty.all(BorderSide.none),
          ),
        ),
        inputDecorationTheme: InputDecorationTheme(
          filled: true,
          fillColor: _cs.surfaceContainerLow,
          floatingLabelBehavior: FloatingLabelBehavior.always,
          labelStyle: _font(12, FontWeight.w600, 16, color: _onSurfaceVariant),
          floatingLabelStyle: _font(12, FontWeight.w600, 16, color: _primary),
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(16),
            borderSide: BorderSide.none,
          ),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(16),
            borderSide: BorderSide(color: _cs.outlineVariant),
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(16),
            borderSide: const BorderSide(color: _primaryContainer, width: 1.5),
          ),
          contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        ),
        progressIndicatorTheme: ProgressIndicatorThemeData(
          color: _primaryContainer,
          linearTrackColor: _cs.surfaceContainerHighest,
          linearMinHeight: 8,
          borderRadius: const BorderRadius.all(Radius.circular(100)),
        ),
        switchTheme: SwitchThemeData(
          thumbColor: WidgetStateProperty.all(const Color(0xFFFFFDF8)),
          trackColor: WidgetStateProperty.resolveWith(
            (states) => states.contains(WidgetState.selected)
                ? _primaryContainer
                : _cs.surfaceContainerHighest,
          ),
          trackOutlineColor: WidgetStateProperty.all(Colors.transparent),
        ),
        chipTheme: ChipThemeData(
          backgroundColor: _cs.surfaceContainerHigh,
          selectedColor: Tropical.mintWash,
          side: BorderSide.none,
          shape: const StadiumBorder(),
          labelStyle: _font(12, FontWeight.w600, 16, tracking: 0.02),
        ),
        dividerTheme: DividerThemeData(color: _cs.surfaceContainerHigh, thickness: 1),
        snackBarTheme: SnackBarThemeData(
          backgroundColor: _cs.inverseSurface,
          contentTextStyle: _font(14, FontWeight.w400, 20, color: _cs.onInverseSurface),
          shape: const StadiumBorder(),
          behavior: SnackBarBehavior.floating,
        ),
        dialogTheme: DialogThemeData(
          backgroundColor: _cs.surfaceContainerLowest,
          surfaceTintColor: Colors.transparent,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(Tropical.cardRadius),
          ),
        ),
        bottomSheetTheme: BottomSheetThemeData(
          backgroundColor: _cs.surfaceContainerLowest,
          surfaceTintColor: Colors.transparent,
          shape: const RoundedRectangleBorder(
            borderRadius: BorderRadius.vertical(top: Radius.circular(Tropical.cardRadius)),
          ),
        ),
      );
}
