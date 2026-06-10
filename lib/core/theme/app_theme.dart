// lib/core/theme/app_theme.dart
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

class AppTheme {
  AppTheme._();

  static const ColorScheme _cs = ColorScheme(
    brightness: Brightness.dark,
    primary: Color(0xFF4BE277),
    onPrimary: Color(0xFF003915),
    primaryContainer: Color(0xFF22C55E),
    onPrimaryContainer: Color(0xFF004B1E),
    secondary: Color(0xFF4EDEA3),
    onSecondary: Color(0xFF003824),
    secondaryContainer: Color(0xFF00A572),
    onSecondaryContainer: Color(0xFF00311F),
    tertiary: Color(0xFFAFC7FF),
    onTertiary: Color(0xFF002E6A),
    tertiaryContainer: Color(0xFF82ABFF),
    onTertiaryContainer: Color(0xFF003D88),
    error: Color(0xFFFFB4AB),
    onError: Color(0xFF690005),
    errorContainer: Color(0xFF93000A),
    onErrorContainer: Color(0xFFFFDAD6),
    surface: Color(0xFF0B1326),
    onSurface: Color(0xFFDAE2FD),
    onSurfaceVariant: Color(0xFFBCCBB9),
    outline: Color(0xFF869585),
    outlineVariant: Color(0xFF3D4A3D),
    shadow: Color(0xFF000000),
    scrim: Color(0xFF000000),
    inverseSurface: Color(0xFFDAE2FD),
    onInverseSurface: Color(0xFF283044),
    inversePrimary: Color(0xFF006E2F),
    surfaceTint: Color(0xFF4AE176),
    surfaceContainerLowest: Color(0xFF060E20),
    surfaceContainerLow: Color(0xFF131B2E),
    surfaceContainer: Color(0xFF171F33),
    surfaceContainerHigh: Color(0xFF222A3D),
    surfaceContainerHighest: Color(0xFF2D3449),
  );

  static TextTheme _buildTextTheme() {
    final base = GoogleFonts.hankenGroteskTextTheme();
    return base.copyWith(
      displayLarge: GoogleFonts.hankenGrotesk(
        fontSize: 40,
        fontWeight: FontWeight.w700,
        letterSpacing: -0.02 * 40,
        height: 48 / 40,
        color: const Color(0xFFDAE2FD),
      ),
      headlineLarge: GoogleFonts.hankenGrotesk(
        fontSize: 32,
        fontWeight: FontWeight.w600,
        letterSpacing: -0.01 * 32,
        height: 40 / 32,
        color: const Color(0xFFDAE2FD),
      ),
      headlineMedium: GoogleFonts.hankenGrotesk(
        fontSize: 24,
        fontWeight: FontWeight.w600,
        height: 32 / 24,
        color: const Color(0xFFDAE2FD),
      ),
      bodyLarge: GoogleFonts.hankenGrotesk(
        fontSize: 18,
        fontWeight: FontWeight.w400,
        height: 28 / 18,
        color: const Color(0xFFDAE2FD),
      ),
      bodyMedium: GoogleFonts.hankenGrotesk(
        fontSize: 16,
        fontWeight: FontWeight.w400,
        height: 24 / 16,
        color: const Color(0xFFDAE2FD),
      ),
      labelLarge: GoogleFonts.hankenGrotesk(
        fontSize: 14,
        fontWeight: FontWeight.w600,
        letterSpacing: 0.02 * 14,
        height: 20 / 14,
        color: const Color(0xFFDAE2FD),
      ),
      labelSmall: GoogleFonts.hankenGrotesk(
        fontSize: 12,
        fontWeight: FontWeight.w500,
        height: 16 / 12,
        color: const Color(0xFFBCCBB9),
      ),
    );
  }

  static ThemeData get dark => ThemeData(
        useMaterial3: true,
        colorScheme: _cs,
        textTheme: _buildTextTheme(),
      );
}
