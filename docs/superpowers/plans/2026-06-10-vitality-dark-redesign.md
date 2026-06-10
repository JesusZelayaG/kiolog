# Vitality Dark Redesign — Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Rediseñar visualmente Kiolog aplicando el design system Vitality Dark de Stitch — dark mode único, Hanken Grotesk, paleta verde vibrante sobre fondo navy.

**Architecture:** Capa de presentación exclusivamente. BLoC, repositorios, DAOs, modelos y tests de dominio no se tocan. Fase 1 establece el ThemeData + widgets compartidos; Fases 2–6 redesignan las páginas usando esos cimientos. Cada fase termina en commit verde (tests pasan, app compila).

**Tech Stack:** Flutter 3.x · Material 3 · `google_fonts: ^6.2.1` · BLoC · go_router

**Spec:** `docs/superpowers/specs/2026-06-10-vitality-dark-redesign-design.md`

---

## Archivos modificados / creados

| Archivo | Acción |
|---|---|
| `pubspec.yaml` | Modificar — agregar google_fonts |
| `lib/core/theme/app_theme.dart` | Reemplazar completamente |
| `lib/main.dart` | Modificar — themeMode dark + eliminar light |
| `lib/shared/widgets/vitality_progress_bar.dart` | Crear |
| `lib/shared/widgets/vitality_card.dart` | Crear |
| `lib/shared/widgets/section_header.dart` | Crear |
| `lib/shared/widgets/module_icon_badge.dart` | Crear |
| `lib/shared/widgets/stat_chip.dart` | Crear |
| `test/widget/vitality_widgets_test.dart` | Crear |
| `test/widget/app_scaffold_test.dart` | Modificar — AppTheme.light → .dark |
| `lib/features/home/presentation/pages/home_page.dart` | Reemplazar |
| `lib/features/onboarding/presentation/pages/onboarding_page.dart` | Modificar |
| `lib/features/nutrition/presentation/pages/nutrition_page.dart` | Modificar |
| `lib/features/nutrition/presentation/pages/nutrition_progress_page.dart` | Modificar |
| `lib/features/nutrition/presentation/pages/nutrition_config_page.dart` | Modificar |
| `lib/features/exercise/presentation/pages/exercise_page.dart` | Modificar |
| `lib/features/exercise/presentation/pages/exercise_progress_page.dart` | Modificar |
| `lib/features/exercise/presentation/pages/exercise_session_page.dart` | Modificar |
| `lib/features/exercise/presentation/pages/exercise_config_page.dart` | Modificar |
| `lib/features/water/presentation/pages/water_page.dart` | Modificar |
| `lib/features/water/presentation/pages/water_config_page.dart` | Modificar |
| `lib/features/progress/presentation/pages/progress_page.dart` | Modificar |
| `lib/features/history/presentation/pages/history_page.dart` | Modificar |
| `lib/features/achievements/presentation/pages/achievements_page.dart` | Modificar |
| `lib/features/settings/presentation/pages/settings_page.dart` | Modificar |
| `lib/features/sleep/presentation/pages/sleep_page.dart` | Modificar |
| `lib/features/reports/presentation/pages/report_page.dart` | Modificar |

---

## FASE 1 — Fundación

### Task 1: pubspec + google_fonts

**Files:**
- Modify: `pubspec.yaml`

- [ ] **Agregar google_fonts a dependencies**

En `pubspec.yaml`, bajo `# Internationalization`, agregar:

```yaml
  # Fonts
  google_fonts: ^6.2.1
```

- [ ] **Instalar paquete**

```bash
cd /home/jesuszelaya/Documents/kiolog && flutter pub get
```

Expected: `Resolving dependencies... google_fonts 6.x.x`

---

### Task 2: AppTheme — ColorScheme + TextTheme

**Files:**
- Modify: `lib/core/theme/app_theme.dart`

- [ ] **Reemplazar app_theme.dart completamente**

```dart
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
```

- [ ] **Verificar que compila**

```bash
cd /home/jesuszelaya/Documents/kiolog && flutter build apk --debug 2>&1 | head -20
```

Expected: sin errores de compilación relacionados al tema.

---

### Task 3: AppTheme — component themes

**Files:**
- Modify: `lib/core/theme/app_theme.dart`

- [ ] **Agregar component themes al ThemeData.dark**

Reemplazar `static ThemeData get dark => ThemeData(...)` con:

```dart
  static ThemeData get dark => ThemeData(
        useMaterial3: true,
        colorScheme: _cs,
        textTheme: _buildTextTheme(),
        appBarTheme: AppBarTheme(
          backgroundColor: const Color(0xFF0B1326),
          elevation: 0,
          scrolledUnderElevation: 0,
          centerTitle: true,
          titleTextStyle: GoogleFonts.hankenGrotesk(
            fontSize: 24,
            fontWeight: FontWeight.w600,
            color: const Color(0xFFDAE2FD),
          ),
          iconTheme: const IconThemeData(color: Color(0xFFDAE2FD)),
          actionsIconTheme: const IconThemeData(color: Color(0xFFDAE2FD)),
        ),
        cardTheme: CardThemeData(
          color: const Color(0xFF171F33),
          elevation: 0,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
            side: const BorderSide(color: Color(0xFF3D4A3D), width: 0.5),
          ),
          margin: EdgeInsets.zero,
        ),
        elevatedButtonTheme: ElevatedButtonThemeData(
          style: ElevatedButton.styleFrom(
            backgroundColor: const Color(0xFF22C55E),
            foregroundColor: const Color(0xFF004B1E),
            padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 24),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(8),
            ),
            textStyle: GoogleFonts.hankenGrotesk(
              fontSize: 14,
              fontWeight: FontWeight.w600,
            ),
            elevation: 0,
          ),
        ),
        outlinedButtonTheme: OutlinedButtonThemeData(
          style: OutlinedButton.styleFrom(
            foregroundColor: const Color(0xFF4BE277),
            side: const BorderSide(color: Color(0xFF4BE277), width: 1.5),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(8),
            ),
            textStyle: GoogleFonts.hankenGrotesk(
              fontSize: 14,
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
        textButtonTheme: TextButtonThemeData(
          style: TextButton.styleFrom(
            foregroundColor: const Color(0xFF4BE277),
            textStyle: GoogleFonts.hankenGrotesk(
              fontSize: 14,
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
        inputDecorationTheme: InputDecorationTheme(
          filled: true,
          fillColor: const Color(0xFF131B2E),
          floatingLabelBehavior: FloatingLabelBehavior.always,
          labelStyle: GoogleFonts.hankenGrotesk(
            fontSize: 12,
            fontWeight: FontWeight.w500,
            color: const Color(0xFFBCCBB9),
          ),
          floatingLabelStyle: GoogleFonts.hankenGrotesk(
            fontSize: 12,
            fontWeight: FontWeight.w500,
            color: const Color(0xFF4BE277),
          ),
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(8),
            borderSide: BorderSide.none,
          ),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(8),
            borderSide: const BorderSide(color: Color(0xFF3D4A3D)),
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(8),
            borderSide:
                const BorderSide(color: Color(0xFF22C55E), width: 1.5),
          ),
          contentPadding:
              const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        ),
        progressIndicatorTheme: const ProgressIndicatorThemeData(
          color: Color(0xFF22C55E),
          linearTrackColor: Color(0xFF222A3D),
          linearMinHeight: 8,
          borderRadius: BorderRadius.all(Radius.circular(100)),
        ),
        navigationBarTheme: NavigationBarThemeData(
          backgroundColor: const Color(0xFF131B2E),
          height: 64,
          indicatorColor: const Color(0xFF004B1E),
          labelBehavior: NavigationDestinationLabelBehavior.alwaysShow,
          labelTextStyle: WidgetStateProperty.all(
            GoogleFonts.hankenGrotesk(
              fontSize: 12,
              fontWeight: FontWeight.w500,
              color: const Color(0xFFBCCBB9),
            ),
          ),
        ),
        chipTheme: const ChipThemeData(
          backgroundColor: Color(0xFF222A3D),
          side: BorderSide.none,
          shape: StadiumBorder(),
        ),
        dividerTheme: const DividerThemeData(
          color: Color(0xFF3D4A3D),
          thickness: 0.5,
        ),
        snackBarTheme: SnackBarThemeData(
          backgroundColor: const Color(0xFF2D3449),
          contentTextStyle: GoogleFonts.hankenGrotesk(
            fontSize: 14,
            color: const Color(0xFFDAE2FD),
          ),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(8),
          ),
          behavior: SnackBarBehavior.floating,
        ),
        scaffoldBackgroundColor: const Color(0xFF0B1326),
        dialogTheme: DialogThemeData(
          backgroundColor: const Color(0xFF171F33),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
        ),
      );
```

- [ ] **Compilar y verificar**

```bash
cd /home/jesuszelaya/Documents/kiolog && flutter build apk --debug 2>&1 | tail -5
```

Expected: `Built build/app/outputs/flutter-apk/app-debug.apk`

---

### Task 4: main.dart — force dark mode + fix tests

**Files:**
- Modify: `lib/main.dart`
- Modify: `test/widget/app_scaffold_test.dart`

- [ ] **Actualizar main.dart**

```dart
// lib/main.dart
import 'package:flutter/material.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'core/dao/user_profile_dao.dart';
import 'core/di/injection.dart';
import 'core/notifications/notification_service.dart';
import 'core/router/app_router.dart';
import 'core/theme/app_theme.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await initializeDateFormatting('es', null);
  await NotificationService.init();
  await setupDependencies();

  final onboardingComplete =
      await getIt<UserProfileDao>().isOnboardingComplete();

  runApp(KiologApp(onboardingComplete: onboardingComplete));
}

class KiologApp extends StatelessWidget {
  final bool onboardingComplete;

  const KiologApp({super.key, required this.onboardingComplete});

  @override
  Widget build(BuildContext context) {
    return MaterialApp.router(
      title: 'Kiolog',
      theme: AppTheme.dark,
      darkTheme: AppTheme.dark,
      themeMode: ThemeMode.dark,
      routerConfig: createRouter(
        initialLocation: onboardingComplete ? '/' : '/onboarding',
      ),
      debugShowCheckedModeBanner: false,
    );
  }
}
```

- [ ] **Actualizar app_scaffold_test.dart — AppTheme.light → AppTheme.dark**

En `test/widget/app_scaffold_test.dart`, reemplazar las dos ocurrencias de `theme: AppTheme.light` por `theme: AppTheme.dark` (líneas 87 y 102).

- [ ] **Correr todos los tests**

```bash
cd /home/jesuszelaya/Documents/kiolog && flutter test
```

Expected: todos los tests existentes siguen pasando (120+). Si alguno falla por `AppTheme.light`, buscarlo con `grep -rn "AppTheme.light" test/` y reemplazarlo.

- [ ] **Commit fase 1a**

```bash
git add pubspec.yaml pubspec.lock lib/core/theme/app_theme.dart lib/main.dart test/widget/app_scaffold_test.dart
git commit -m "feat(theme): Vitality Dark ThemeData + force dark mode"
```

---

### Task 5: VitalityProgressBar

**Files:**
- Create: `lib/shared/widgets/vitality_progress_bar.dart`
- Create: `test/widget/vitality_widgets_test.dart`

- [ ] **Escribir test primero**

```dart
// test/widget/vitality_widgets_test.dart
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kiolog/core/theme/app_theme.dart';
import 'package:kiolog/shared/widgets/vitality_progress_bar.dart';
import 'package:kiolog/shared/widgets/vitality_card.dart';
import 'package:kiolog/shared/widgets/section_header.dart';
import 'package:kiolog/shared/widgets/module_icon_badge.dart';
import 'package:kiolog/shared/widgets/stat_chip.dart';

Widget _wrap(Widget child) => MaterialApp(
      theme: AppTheme.dark,
      home: Scaffold(body: Center(child: child)),
    );

void main() {
  group('VitalityProgressBar', () {
    testWidgets('renders LinearProgressIndicator', (tester) async {
      await tester.pumpWidget(
          _wrap(const VitalityProgressBar(value: 0.5)));
      expect(find.byType(LinearProgressIndicator), findsOneWidget);
    });

    testWidgets('clamps value between 0 and 1', (tester) async {
      await tester.pumpWidget(
          _wrap(const VitalityProgressBar(value: 1.5)));
      final widget = tester.widget<LinearProgressIndicator>(
          find.byType(LinearProgressIndicator));
      expect(widget.value, equals(1.0));
    });

    testWidgets('uses custom color when provided', (tester) async {
      await tester.pumpWidget(
          _wrap(const VitalityProgressBar(
              value: 0.5, color: Color(0xFFAFC7FF))));
      expect(find.byType(LinearProgressIndicator), findsOneWidget);
    });
  });

  group('VitalityCard', () {
    testWidgets('renders child', (tester) async {
      await tester.pumpWidget(
          _wrap(const VitalityCard(child: Text('hello'))));
      expect(find.text('hello'), findsOneWidget);
    });

    testWidgets('calls onTap when tapped', (tester) async {
      var tapped = false;
      await tester.pumpWidget(
          _wrap(VitalityCard(
              onTap: () => tapped = true,
              child: const Text('tap me'))));
      await tester.tap(find.text('tap me'));
      expect(tapped, isTrue);
    });
  });

  group('SectionHeader', () {
    testWidgets('renders title', (tester) async {
      await tester.pumpWidget(
          _wrap(const SectionHeader(title: 'Módulos')));
      expect(find.text('Módulos'), findsOneWidget);
    });

    testWidgets('renders action button when provided', (tester) async {
      var pressed = false;
      await tester.pumpWidget(
          _wrap(SectionHeader(
              title: 'T',
              actionLabel: 'Ver',
              onAction: () => pressed = true)));
      await tester.tap(find.text('Ver'));
      expect(pressed, isTrue);
    });
  });

  group('ModuleIconBadge', () {
    testWidgets('renders icon', (tester) async {
      await tester.pumpWidget(
          _wrap(const ModuleIconBadge(
              icon: Icons.water_drop, color: Color(0xFFAFC7FF))));
      expect(find.byIcon(Icons.water_drop), findsOneWidget);
    });
  });

  group('StatChip', () {
    testWidgets('renders value and label', (tester) async {
      await tester.pumpWidget(
          _wrap(const StatChip(value: '85%', label: 'Adherencia')));
      expect(find.text('85%'), findsOneWidget);
      expect(find.text('Adherencia'), findsOneWidget);
    });
  });
}
```

- [ ] **Correr test — verificar que falla**

```bash
cd /home/jesuszelaya/Documents/kiolog && flutter test test/widget/vitality_widgets_test.dart 2>&1 | head -20
```

Expected: `Error: Could not resolve the package 'kiolog/shared/widgets/vitality_progress_bar.dart'`

- [ ] **Crear VitalityProgressBar**

```dart
// lib/shared/widgets/vitality_progress_bar.dart
import 'package:flutter/material.dart';

class VitalityProgressBar extends StatelessWidget {
  final double value;
  final Color? color;
  final double height;

  const VitalityProgressBar({
    super.key,
    required this.value,
    this.color,
    this.height = 8,
  });

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return SizedBox(
      height: height,
      child: LinearProgressIndicator(
        value: value.clamp(0.0, 1.0),
        color: color ?? cs.primaryContainer,
        backgroundColor: cs.surfaceContainerHigh,
        borderRadius: BorderRadius.circular(100),
        minHeight: height,
      ),
    );
  }
}
```

---

### Task 6: VitalityCard, SectionHeader, ModuleIconBadge, StatChip

**Files:**
- Create: `lib/shared/widgets/vitality_card.dart`
- Create: `lib/shared/widgets/section_header.dart`
- Create: `lib/shared/widgets/module_icon_badge.dart`
- Create: `lib/shared/widgets/stat_chip.dart`

- [ ] **Crear VitalityCard**

```dart
// lib/shared/widgets/vitality_card.dart
import 'package:flutter/material.dart';

class VitalityCard extends StatelessWidget {
  final Widget child;
  final EdgeInsetsGeometry? padding;
  final VoidCallback? onTap;

  const VitalityCard({
    super.key,
    required this.child,
    this.padding,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Card(
      color: cs.surfaceContainer,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(color: cs.outlineVariant, width: 0.5),
      ),
      elevation: 0,
      clipBehavior: Clip.antiAlias,
      child: onTap != null
          ? InkWell(
              onTap: onTap,
              child: Padding(
                padding: padding ?? const EdgeInsets.all(16),
                child: child,
              ),
            )
          : Padding(
              padding: padding ?? const EdgeInsets.all(16),
              child: child,
            ),
    );
  }
}
```

- [ ] **Crear SectionHeader**

```dart
// lib/shared/widgets/section_header.dart
import 'package:flutter/material.dart';

class SectionHeader extends StatelessWidget {
  final String title;
  final String? actionLabel;
  final VoidCallback? onAction;

  const SectionHeader({
    super.key,
    required this.title,
    this.actionLabel,
    this.onAction,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(title, style: theme.textTheme.headlineMedium),
        if (actionLabel != null && onAction != null)
          TextButton(
            onPressed: onAction,
            child: Text(actionLabel!),
          ),
      ],
    );
  }
}
```

- [ ] **Crear ModuleIconBadge**

```dart
// lib/shared/widgets/module_icon_badge.dart
import 'package:flutter/material.dart';

class ModuleIconBadge extends StatelessWidget {
  final IconData icon;
  final Color color;
  final double size;

  const ModuleIconBadge({
    super.key,
    required this.icon,
    required this.color,
    this.size = 40,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(size / 2),
      ),
      child: Icon(icon, color: color, size: size * 0.5),
    );
  }
}
```

- [ ] **Crear StatChip**

```dart
// lib/shared/widgets/stat_chip.dart
import 'package:flutter/material.dart';

class StatChip extends StatelessWidget {
  final String value;
  final String label;
  final Color? color;

  const StatChip({
    super.key,
    required this.value,
    required this.label,
    this.color,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          value,
          style: theme.textTheme.headlineMedium?.copyWith(
            color: color ?? cs.primary,
            fontWeight: FontWeight.w700,
          ),
        ),
        const SizedBox(height: 2),
        Text(
          label,
          style: theme.textTheme.labelSmall?.copyWith(
            color: cs.onSurfaceVariant,
          ),
          textAlign: TextAlign.center,
        ),
      ],
    );
  }
}
```

- [ ] **Correr todos los tests de widgets compartidos**

```bash
cd /home/jesuszelaya/Documents/kiolog && flutter test test/widget/vitality_widgets_test.dart -v
```

Expected: todos los tests pasan (15 tests).

- [ ] **Commit fase 1b**

```bash
git add lib/shared/widgets/ test/widget/vitality_widgets_test.dart
git commit -m "feat(shared): widgets Vitality Dark — VitalityProgressBar, VitalityCard, SectionHeader, ModuleIconBadge, StatChip"
```

---

## FASE 2 — Home + Onboarding

### Task 7: home_page.dart

**Files:**
- Modify: `lib/features/home/presentation/pages/home_page.dart`

La lógica BLoC (provider, eventos, estado) no cambia. Se reescribe `_HomeView` y se reemplaza `_SummaryCard` con un widget que usa `VitalityCard` + `ModuleIconBadge` + `VitalityProgressBar`.

- [ ] **Reemplazar home_page.dart**

```dart
// lib/features/home/presentation/pages/home_page.dart
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import '../../../../core/di/injection.dart';
import '../../../../features/exercise/domain/repositories/exercise_repository.dart';
import '../../../../features/nutrition/domain/repositories/nutrition_repository.dart';
import '../../../../features/sleep/domain/repositories/sleep_repository.dart';
import '../../../../features/water/domain/repositories/water_repository.dart';
import '../../../../shared/widgets/vitality_card.dart';
import '../../../../shared/widgets/vitality_progress_bar.dart';
import '../../../../shared/widgets/module_icon_badge.dart';
import '../bloc/home_bloc.dart';
import '../bloc/home_event.dart';
import '../bloc/home_state.dart';

class HomePage extends StatelessWidget {
  const HomePage({super.key});

  @override
  Widget build(BuildContext context) {
    return BlocProvider(
      create: (_) => HomeBloc(
        waterRepository: getIt<WaterRepository>(),
        sleepRepository: getIt<SleepRepository>(),
        nutritionRepository: getIt<NutritionRepository>(),
        exerciseRepository: getIt<ExerciseRepository>(),
      )..add(HomeLoaded(date: DateTime.now())),
      child: const _HomeView(),
    );
  }
}

class _HomeView extends StatelessWidget {
  const _HomeView();

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;
    final now = DateTime.now();
    final dateLabel = DateFormat('EEEE, d MMM', 'es').format(now);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Kiolog'),
        actions: [
          IconButton(
            icon: const Icon(Icons.emoji_events_outlined),
            onPressed: () => context.push('/achievements'),
          ),
          IconButton(
            icon: const Icon(Icons.calendar_month_outlined),
            onPressed: () => context.push('/history'),
          ),
        ],
      ),
      body: BlocBuilder<HomeBloc, HomeState>(
        builder: (context, state) {
          if (state.status == HomeStatus.loading) {
            return const Center(child: CircularProgressIndicator());
          }
          if (state.status == HomeStatus.failure) {
            return Center(child: Text('Error: ${state.error}'));
          }

          return CustomScrollView(
            slivers: [
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(24, 24, 24, 8),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Buenos días',
                        style: theme.textTheme.displayLarge,
                      ),
                      const SizedBox(height: 4),
                      Text(
                        dateLabel,
                        style: theme.textTheme.bodyMedium?.copyWith(
                          color: cs.onSurfaceVariant,
                        ),
                      ),
                      const SizedBox(height: 32),
                    ],
                  ),
                ),
              ),
              SliverPadding(
                padding: const EdgeInsets.symmetric(horizontal: 24),
                sliver: SliverList(
                  delegate: SliverChildListDelegate([
                    _ModuleCard(
                      icon: Icons.water_drop,
                      label: 'Agua',
                      color: cs.tertiary,
                      progress: state.waterProgress,
                      subtitle:
                          '${state.dailyWaterTotalMl} / ${state.dailyWaterGoalMl} ml',
                      onTap: () => context.push('/water'),
                    ),
                    const SizedBox(height: 16),
                    _ModuleCard(
                      icon: Icons.nightlight_round,
                      label: 'Sueño',
                      color: const Color(0xFFAFC7FF),
                      progress: state.sleepHours != null
                          ? (state.sleepHours! / 8).clamp(0.0, 1.0)
                          : 0.0,
                      subtitle: state.sleepHours != null
                          ? '${state.sleepHours!.toStringAsFixed(1)} h'
                          : 'No registrado',
                      onTap: () => context.push('/sleep'),
                    ),
                    const SizedBox(height: 16),
                    _ModuleCard(
                      icon: Icons.restaurant,
                      label: 'Nutrición',
                      color: cs.secondary,
                      progress: state.totalMeals > 0
                          ? state.mealsLogged / state.totalMeals
                          : 0.0,
                      subtitle:
                          '${state.mealsLogged} / ${state.totalMeals} comidas',
                      onTap: () => context.go('/nutrition'),
                    ),
                    const SizedBox(height: 16),
                    _ModuleCard(
                      icon: Icons.fitness_center,
                      label: 'Ejercicio',
                      color: cs.primary,
                      progress: state.exerciseRoutineDone ? 1.0 : 0.0,
                      subtitle: state.exerciseRoutineDone
                          ? 'Rutina completada'
                          : state.hasGymSession
                              ? 'Sesión en progreso'
                              : 'Pendiente',
                      onTap: () => context.go('/exercise'),
                    ),
                    const SizedBox(height: 32),
                  ]),
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}

class _ModuleCard extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color color;
  final double progress;
  final String subtitle;
  final VoidCallback onTap;

  const _ModuleCard({
    required this.icon,
    required this.label,
    required this.color,
    required this.progress,
    required this.subtitle,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;

    return VitalityCard(
      onTap: onTap,
      child: Row(
        children: [
          ModuleIconBadge(icon: icon, color: color),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(label, style: theme.textTheme.labelLarge),
                const SizedBox(height: 2),
                Text(
                  subtitle,
                  style: theme.textTheme.bodyMedium?.copyWith(
                    color: cs.onSurfaceVariant,
                  ),
                ),
                const SizedBox(height: 10),
                VitalityProgressBar(value: progress, color: color),
              ],
            ),
          ),
          const SizedBox(width: 12),
          Icon(Icons.chevron_right, color: cs.onSurfaceVariant, size: 20),
        ],
      ),
    );
  }
}
```

- [ ] **Correr tests**

```bash
cd /home/jesuszelaya/Documents/kiolog && flutter test
```

Expected: todos los tests pasan.

---

### Task 8: onboarding_page.dart

**Files:**
- Modify: `lib/features/onboarding/presentation/pages/onboarding_page.dart`

La lógica de `_finish()`, `_nextStep()`, `_prevStep()` y todos los helpers de datos no cambia. Los cambios son visuales:
1. `LinearProgressIndicator` → `VitalityProgressBar` en el top
2. `_buildWelcomeStep`: ícono 96px, `displayLarge` + `bodyLarge`, padding 24px
3. Botón `FilledButton` → `ElevatedButton` (hereda el theme)
4. Padding de los pasos → 24px (ya lo tienen, verificar)

- [ ] **Reemplazar _buildWelcomeStep y actualizar progress bar**

En `onboarding_page.dart`, agregar import:
```dart
import 'package:kiolog/shared/widgets/vitality_progress_bar.dart';
```

Reemplazar el `LinearProgressIndicator` en el `build()` principal:
```dart
// Antes:
LinearProgressIndicator(
  value: _currentActiveStep / _totalActiveSteps,
  backgroundColor: theme.colorScheme.surfaceContainerHighest,
),

// Después:
VitalityProgressBar(value: _currentActiveStep / _totalActiveSteps),
```

Reemplazar `_buildWelcomeStep`:
```dart
Widget _buildWelcomeStep(ThemeData theme) {
  return Padding(
    padding: const EdgeInsets.symmetric(horizontal: 24),
    child: Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Icon(
          Icons.favorite,
          size: 96,
          color: theme.colorScheme.primary,
        ),
        const SizedBox(height: 32),
        Text(
          'Bienvenido a Kiolog',
          style: theme.textTheme.displayLarge,
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: 16),
        Text(
          'Tu bitácora de salud personal.\nRegistra agua, comidas, ejercicio y sueño en un solo lugar.',
          style: theme.textTheme.bodyLarge?.copyWith(
            color: theme.colorScheme.onSurfaceVariant,
          ),
          textAlign: TextAlign.center,
        ),
      ],
    ),
  );
}
```

Reemplazar `FilledButton` por `ElevatedButton` en el `build()`:
```dart
// Antes:
FilledButton(
  onPressed: _canProceed
      ? (_currentStep == _totalSteps - 1 ? _finish : _nextStep)
      : null,
  child: Text(_currentStep == _totalSteps - 1
      ? 'Finalizar'
      : 'Siguiente'),
),

// Después:
SizedBox(
  width: double.infinity,
  child: ElevatedButton(
    onPressed: _canProceed
        ? (_currentStep == _totalSteps - 1 ? _finish : _nextStep)
        : null,
    child: Text(_currentStep == _totalSteps - 1
        ? 'Finalizar'
        : 'Siguiente'),
  ),
),
```

- [ ] **Correr tests**

```bash
cd /home/jesuszelaya/Documents/kiolog && flutter test
```

Expected: todos pasan.

- [ ] **Commit fase 2**

```bash
git add lib/features/home/presentation/pages/home_page.dart lib/features/onboarding/presentation/pages/onboarding_page.dart
git commit -m "feat(ui): redesign Home + Onboarding — Vitality Dark"
```

---

## FASE 3 — Nutrición

### Task 9: nutrition_page.dart

**Files:**
- Modify: `lib/features/nutrition/presentation/pages/nutrition_page.dart`

Cambios visuales: AppBar sin cambio estructural. Secciones de comidas con `VitalityCard` en lugar de `Card` ad-hoc. Padding horizontal 24px. `VitalityProgressBar` donde haya `LinearProgressIndicator`. El BLoC provider wrapper no cambia.

- [ ] **Agregar imports a nutrition_page.dart**

Al inicio de los imports, agregar:
```dart
import 'package:kiolog/shared/widgets/vitality_card.dart';
import 'package:kiolog/shared/widgets/vitality_progress_bar.dart';
import 'package:kiolog/shared/widgets/module_icon_badge.dart';
import 'package:kiolog/shared/widgets/section_header.dart';
```

- [ ] **Actualizar _NutritionView: padding + reemplazar Cards**

Busca en el body de `_NutritionView` todos los `Card(` y `LinearProgressIndicator(` y:
- Reemplaza `Card(` por `VitalityCard(`
- Reemplaza `LinearProgressIndicator(value: v)` por `VitalityProgressBar(value: v)`
- Cambia el `ListView` padding a `const EdgeInsets.symmetric(horizontal: 24, vertical: 16)`
- Reemplaza cualquier `Divider(` con grosor por defecto por `const Divider()` (hereda `DividerTheme`)

- [ ] **Correr tests de nutrición**

```bash
cd /home/jesuszelaya/Documents/kiolog && flutter test test/features/nutrition/
```

Expected: todos pasan.

---

### Task 10: nutrition_progress_page.dart

**Files:**
- Modify: `lib/features/nutrition/presentation/pages/nutrition_progress_page.dart`

Cambios: el `CustomPainter` existente se adapta para leer colores del `ColorScheme`. Los `StatChip` reemplazan chips de stats ad-hoc. El toggle Semana/Mes usa `surfaceContainerHigh`/`surfaceContainerHighest`.

- [ ] **Agregar imports**

```dart
import 'package:kiolog/shared/widgets/vitality_card.dart';
import 'package:kiolog/shared/widgets/stat_chip.dart';
```

- [ ] **Actualizar CustomPainter para usar ColorScheme**

En el `CustomPainter` de barras (búscalo con `grep -n "CustomPainter\|Canvas\|Paint()" lib/features/nutrition/presentation/pages/nutrition_progress_page.dart`):

Agrega un campo `colorScheme` al painter:
```dart
// Ejemplo de patrón a aplicar en el painter existente:
// Antes: paint.color = Colors.orange;
// Después: paint.color = colorScheme.primaryContainer;
//
// Antes: paint.color = Colors.grey.shade200;
// Después: paint.color = colorScheme.surfaceContainerHigh;
```

Pasa el `ColorScheme` al painter desde el `CustomPaint`:
```dart
CustomPaint(
  painter: NutritionBarPainter(
    // ...args existentes...
    colorScheme: Theme.of(context).colorScheme,
  ),
)
```

- [ ] **Reemplazar _Chip por StatChip en _buildSemanaChips y _buildMesChips**

La página tiene un `_Chip` widget interno con colores hardcodeados (`Colors.orange`, `Colors.green`, `Colors.blueGrey`). Reemplaza los usos de `_Chip` en `_buildSemanaChips`:

```dart
Widget _buildSemanaChips(NutritionState state) {
  final stat = _statAt(state.weeklyAdherence, _weekOffset);
  final pct = stat == null || stat.mealsExpected == 0
      ? null
      : (stat.adherencePct * 100).round();
  final logged = stat?.mealsLogged ?? 0;
  final offPlan = stat?.offPlanMeals ?? 0;

  return Row(
    mainAxisAlignment: MainAxisAlignment.spaceEvenly,
    children: [
      StatChip(value: pct == null ? '—' : '$pct%', label: 'Adherencia'),
      StatChip(value: '$logged', label: 'En plan'),
      StatChip(
        value: '$offPlan',
        label: 'Fuera plan',
        color: Theme.of(context).colorScheme.error,
      ),
    ],
  );
}
```

Aplica el mismo patrón a `_buildMesChips` usando los mismos valores `pct`, `totalLogged`, `totalOff`.

El widget `_Chip` se puede eliminar del archivo si ya no se usa.

- [ ] **Correr tests**

```bash
cd /home/jesuszelaya/Documents/kiolog && flutter test test/features/nutrition/
```

Expected: todos pasan.

---

### Task 11: nutrition_config_page.dart

**Files:**
- Modify: `lib/features/nutrition/presentation/pages/nutrition_config_page.dart`

Cambio mínimo: el tema global ya aplica `InputDecorationTheme` y `AppBarTheme`. Solo verificar padding y eliminar estilos ad-hoc.

- [ ] **Auditar y limpiar nutrition_config_page.dart**

```bash
grep -n "Color\|TextStyle\|padding.*EdgeInsets\|Card(" lib/features/nutrition/presentation/pages/nutrition_config_page.dart
```

Para cada hallazgo:
- `Colors.xxx` → reemplazar con `Theme.of(context).colorScheme.xxx`
- `TextStyle(` hardcodeado → eliminar (hereda del theme)
- `Card(` → `VitalityCard(`
- Padding horizontal < 24 en el body → cambiar a 24

- [ ] **Commit fase 3**

```bash
git add lib/features/nutrition/
git commit -m "feat(ui): redesign Nutrición — Vitality Dark"
```

---

## FASE 4 — Ejercicio

### Task 12: exercise_page.dart

**Files:**
- Modify: `lib/features/exercise/presentation/pages/exercise_page.dart`

- [ ] **Agregar imports**

```dart
import 'package:kiolog/shared/widgets/vitality_card.dart';
import 'package:kiolog/shared/widgets/vitality_progress_bar.dart';
import 'package:kiolog/shared/widgets/section_header.dart';
import 'package:kiolog/shared/widgets/module_icon_badge.dart';
```

- [ ] **Reemplazar Cards y LinearProgressIndicators**

Mismo patrón que nutrición:
- `Card(` → `VitalityCard(`
- `LinearProgressIndicator(value: v)` → `VitalityProgressBar(value: v)`
- Padding del body ListView/Column → `const EdgeInsets.symmetric(horizontal: 24, vertical: 16)`
- Sección headers → `SectionHeader(title: 'Rutina')` etc.

- [ ] **Actualizar botón "Iniciar rutina"**

El botón sticky al fondo debe ser full-width con safe area:
```dart
Padding(
  padding: const EdgeInsets.fromLTRB(24, 8, 24, 16),
  child: SafeArea(
    top: false,
    child: SizedBox(
      width: double.infinity,
      child: ElevatedButton.icon(
        onPressed: _onStartRoutine,
        icon: const Icon(Icons.play_arrow),
        label: const Text('Iniciar rutina del día'),
      ),
    ),
  ),
),
```

- [ ] **Correr tests de ejercicio**

```bash
cd /home/jesuszelaya/Documents/kiolog && flutter test test/features/exercise/ 2>/dev/null || flutter test
```

---

### Task 13: exercise_progress_page.dart

**Files:**
- Modify: `lib/features/exercise/presentation/pages/exercise_progress_page.dart`

- [ ] **Agregar imports**

```dart
import 'package:kiolog/shared/widgets/stat_chip.dart';
import 'package:kiolog/shared/widgets/vitality_card.dart';
```

- [ ] **Actualizar CustomPainters para usar ColorScheme**

Mismo patrón que nutrición: pasar `colorScheme` al painter, reemplazar colores hardcodeados.

Para el chart de rutina: `paint.color = colorScheme.primary`
Para el chart de cardio: `paint.color = colorScheme.secondary`
Track: `paint.color = colorScheme.surfaceContainerHigh`

- [ ] **Reemplazar stats con StatChip**

```dart
Row(
  mainAxisAlignment: MainAxisAlignment.spaceEvenly,
  children: [
    StatChip(value: '$routinePct%', label: 'Rutina'),
    StatChip(
      value: '$cardioPct%',
      label: 'Cardio',
      color: Theme.of(context).colorScheme.secondary,
    ),
    StatChip(value: '$totalSessions', label: 'Sesiones'),
  ],
),
```

---

### Task 14: exercise_session_page.dart

**Files:**
- Modify: `lib/features/exercise/presentation/pages/exercise_session_page.dart`

- [ ] **Agregar imports + actualizar header**

```dart
import 'package:kiolog/shared/widgets/vitality_progress_bar.dart';
import 'package:kiolog/shared/widgets/vitality_card.dart';
```

Header con VitalityProgressBar:
```dart
// Reemplaza el LinearProgressIndicator en el header de la sesión
VitalityProgressBar(value: completedCount / totalCount),
```

- [ ] **Actualizar cards de ítems**

Reemplaza `Card(` por `VitalityCard(` en la lista de ítems de la sesión.

El color del borde de estado se puede indicar via `side` en el `VitalityCard` o con un `Container` con border:
```dart
// Ítem activo — borde en primary
VitalityCard(
  padding: EdgeInsets.zero,
  child: Container(
    decoration: BoxDecoration(
      border: Border(
        left: BorderSide(
          color: cs.primary,
          width: 3,
        ),
      ),
    ),
    child: // ...contenido existente...
  ),
),
```

---

### Task 15: exercise_config_page.dart

**Files:**
- Modify: `lib/features/exercise/presentation/pages/exercise_config_page.dart`

- [ ] **Limpiar colores hardcodeados + reemplazar Cards**

Mismo patrón de auditoría:
```bash
grep -n "Color\|TextStyle\|Card(" lib/features/exercise/presentation/pages/exercise_config_page.dart
```

Reemplazar con tokens del ColorScheme y `VitalityCard`.

- [ ] **Commit fase 4**

```bash
git add lib/features/exercise/
git commit -m "feat(ui): redesign Ejercicio — Vitality Dark"
```

---

## FASE 5 — Agua + Progreso de Peso

### Task 16: water_page.dart

**Files:**
- Modify: `lib/features/water/presentation/pages/water_page.dart`

- [ ] **Agregar imports**

```dart
import 'package:kiolog/shared/widgets/vitality_progress_bar.dart';
import 'package:kiolog/shared/widgets/vitality_card.dart';
import 'package:kiolog/shared/widgets/stat_chip.dart';
```

- [ ] **Actualizar VitalityProgressBar con color tertiary (azul)**

```dart
// Barra de progreso de agua en azul
VitalityProgressBar(
  value: state.dailyTotalMl / state.dailyGoalMl,
  color: Theme.of(context).colorScheme.tertiary,
  height: 24,
),
```

- [ ] **Reemplazar Cards + botones rápidos**

- `Card(` → `VitalityCard(`
- Botones rápidos (vaso/botella): `OutlinedButton` con `StadiumBorder` — hereda el `OutlinedButtonTheme`
- `LinearProgressIndicator` → `VitalityProgressBar` con `color: cs.tertiary`

- [ ] **Agregar StatChip de consumo**

```dart
StatChip(
  value: '${state.dailyTotalMl} ml',
  label: '/ ${state.dailyGoalMl} ml meta',
  color: Theme.of(context).colorScheme.tertiary,
),
```

---

### Task 17: water_config_page.dart

**Files:**
- Modify: `lib/features/water/presentation/pages/water_config_page.dart`

- [ ] **Auditar y limpiar**

```bash
grep -n "Color\|TextStyle\|Card(" lib/features/water/presentation/pages/water_config_page.dart
```

Reemplazar colores hardcodeados y `Card(` → `VitalityCard(`. El `SegmentedButton` hereda el theme automáticamente.

---

### Task 18: progress_page.dart

**Files:**
- Modify: `lib/features/progress/presentation/pages/progress_page.dart`

- [ ] **Agregar imports**

```dart
import 'package:kiolog/shared/widgets/vitality_card.dart';
import 'package:kiolog/shared/widgets/stat_chip.dart';
```

- [ ] **Actualizar CustomPainter si existe**

Si la página de progreso tiene un `CustomPainter` para el chart:
```dart
// Reemplazar colores hardcodeados
// paint.color = Colors.green → paint.color = colorScheme.primary
// paint.color = Colors.grey → paint.color = colorScheme.surfaceContainerHigh
```

- [ ] **Reemplazar Cards de registros**

`Card(` → `VitalityCard(`, padding 16px, delta (↑↓) con `cs.primary` / `cs.error`.

- [ ] **Commit fase 5**

```bash
git add lib/features/water/ lib/features/progress/
git commit -m "feat(ui): redesign Agua + Progreso de Peso — Vitality Dark"
```

---

## FASE 6 — Historial + Logros + Sin Stitch

### Task 19: history_page.dart

**Files:**
- Modify: `lib/features/history/presentation/pages/history_page.dart`

- [ ] **Agregar imports**

```dart
import 'package:kiolog/shared/widgets/vitality_card.dart';
import 'package:kiolog/shared/widgets/module_icon_badge.dart';
```

- [ ] **Calendario: marcadores en primaryContainer**

Busca la implementación del calendario. El día seleccionado/marcado debe usar `cs.primaryContainer` como fondo del indicador.

Patrón para cada celda de día con actividad:
```dart
Container(
  decoration: BoxDecoration(
    color: hasActivity ? cs.primaryContainer : Colors.transparent,
    borderRadius: BorderRadius.circular(8),
  ),
  child: Text(
    '${day.day}',
    style: theme.textTheme.bodyMedium?.copyWith(
      color: hasActivity ? cs.onPrimaryContainer : cs.onSurface,
      fontWeight: hasActivity ? FontWeight.w600 : FontWeight.w400,
    ),
  ),
),
```

- [ ] **Lista de actividades: VitalityCard + ModuleIconBadge**

```dart
VitalityCard(
  child: Row(
    children: [
      ModuleIconBadge(icon: activityIcon, color: activityColor),
      const SizedBox(width: 16),
      Expanded(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(description, style: theme.textTheme.labelLarge),
            Text(timeLabel, style: theme.textTheme.labelSmall),
          ],
        ),
      ),
    ],
  ),
),
```

---

### Task 20: achievements_page.dart

**Files:**
- Modify: `lib/features/achievements/presentation/pages/achievements_page.dart`

- [ ] **Agregar imports**

```dart
import 'package:kiolog/shared/widgets/vitality_card.dart';
```

La página actual usa `ListView` con `_AchievementTile`. La redesignamos para que `_AchievementTile` use `VitalityCard` y colores del theme, manteniendo la estructura lista (no grid, para no romper el layout de BLoC).

- [ ] **Actualizar _AchievementTile con VitalityCard y colores del theme**

```dart
class _AchievementTile extends StatelessWidget {
  final dynamic achievement;
  final bool isUnlocked;

  const _AchievementTile({
    required this.achievement,
    required this.isUnlocked,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;

    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: VitalityCard(
        padding: EdgeInsets.zero,
        child: ListTile(
          leading: Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: isUnlocked
                  ? cs.primaryContainer.withValues(alpha: 0.2)
                  : cs.surfaceContainerHighest,
              borderRadius: BorderRadius.circular(20),
            ),
            child: Icon(
              isUnlocked ? Icons.emoji_events : Icons.emoji_events_outlined,
              color: isUnlocked ? cs.primaryContainer : cs.onSurfaceVariant,
              size: 20,
            ),
          ),
          title: Text(
            achievement.title,
            style: theme.textTheme.labelLarge,
          ),
          subtitle: Text(
            achievement.description,
            style: theme.textTheme.labelSmall,
          ),
          trailing: isUnlocked
              ? Icon(Icons.check_circle, color: cs.primary, size: 20)
              : null,
        ),
      ),
    );
  }
}
```

También actualizar en `_AchievementsView`:
- `ListView` padding → `const EdgeInsets.symmetric(horizontal: 24, vertical: 16)`
- Headers `'Desbloqueados'` / `'Por desbloquear'` → `SectionHeader(title: 'Desbloqueados')`
- Agregar import: `import 'package:kiolog/shared/widgets/vitality_card.dart';` y `import 'package:kiolog/shared/widgets/section_header.dart';`

---

### Task 21: settings + sleep + report (theme pass)

**Files:**
- Modify: `lib/features/settings/presentation/pages/settings_page.dart`
- Modify: `lib/features/sleep/presentation/pages/sleep_page.dart`
- Modify: `lib/features/reports/presentation/pages/report_page.dart`

Estas pantallas reciben la mayoría de mejoras automáticamente con el theme global. Solo se hace una auditoría para eliminar colores ad-hoc y reemplazar `Card(` con `VitalityCard(`.

- [ ] **Auditar las 3 páginas**

```bash
grep -n "Color\|TextStyle\|Card(" \
  lib/features/settings/presentation/pages/settings_page.dart \
  lib/features/sleep/presentation/pages/sleep_page.dart \
  lib/features/reports/presentation/pages/report_page.dart
```

- [ ] **Para cada hallazgo en cada archivo:**

- `Colors.xxx` hardcodeado → `Theme.of(context).colorScheme.xxx`
- `TextStyle(fontSize:..., color:...)` → eliminar (hereda del theme)
- `Card(` → `VitalityCard(` — agregar import correspondiente
- Padding horizontal < 24px en el body principal → cambiar a 24px

- [ ] **Correr todos los tests finales**

```bash
cd /home/jesuszelaya/Documents/kiolog && flutter test
```

Expected: todos los tests pasan (120+).

- [ ] **Compilar APK final**

```bash
cd /home/jesuszelaya/Documents/kiolog && flutter build apk --debug
```

Expected: `Built build/app/outputs/flutter-apk/app-debug.apk`

- [ ] **Commit fase 6 — final**

```bash
git add lib/features/history/ lib/features/achievements/ lib/features/settings/ lib/features/sleep/ lib/features/reports/
git commit -m "feat(ui): redesign Historial + Logros + pantallas sin Stitch — Vitality Dark completo"
```
