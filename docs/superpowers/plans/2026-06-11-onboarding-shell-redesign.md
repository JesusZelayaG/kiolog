# Onboarding Shell Redesign — Vitality Dark Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Reemplazar el shell de navegación del onboarding (Column + VitalityProgressBar + Row nav) con un Stack flotante (back arrow arriba-izquierda, pill button + dots abajo) y rediseñar el paso de bienvenida con el layout Vitality Dark de referencia.

**Architecture:** Un solo archivo modificado (`onboarding_page.dart`). El método `build` se reescribe con un `Stack`; se agregan dos métodos privados (`_buildPillButton`, `_buildDotsIndicator`); `_buildWelcomeStep` se reescribe completamente. Sin cambios en lógica de negocio ni en los pasos 2–5.

**Tech Stack:** Flutter, Dart, Material 3, flutter_test (widget tests)

---

### Task 1: Escribir tests de widget (TDD — failing first)

**Files:**
- Create: `test/widget/onboarding_page_test.dart`

- [ ] **Step 1: Crear el archivo de test**

```dart
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kiolog/features/onboarding/presentation/pages/onboarding_page.dart';

Widget _wrap(Widget child) => MaterialApp(home: child);

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
```

- [ ] **Step 2: Correr tests para verificar que fallan**

```bash
flutter test test/widget/onboarding_page_test.dart
```

Esperado: los tests del grupo `welcome step` fallan porque el welcome step actual no tiene la tarjeta ni los textos esperados. Los de `shell` pueden pasar o fallar dependiendo del estado actual.

---

### Task 2: Reescribir el método `build` — Stack flotante

**Files:**
- Modify: `lib/features/onboarding/presentation/pages/onboarding_page.dart` (~líneas 217–266)

- [ ] **Step 1: Reemplazar el método `build` completo en `_OnboardingViewState`**

Buscar el método `build` actual (desde `@override` hasta el `}` de cierre del `Scaffold`) y reemplazarlo por:

```dart
@override
Widget build(BuildContext context) {
  final theme = Theme.of(context);
  final colorScheme = theme.colorScheme;

  return Scaffold(
    body: SafeArea(
      child: Stack(
        children: [
          PageView(
            controller: _pageController,
            physics: const NeverScrollableScrollPhysics(),
            children: [
              _buildWelcomeStep(theme),
              _buildModuleSelectionStep(theme),
              _buildWaterStep(theme),
              _buildNutritionStep(theme),
              _buildExerciseStep(theme),
              _buildInitialDataStep(theme),
            ],
          ),
          if (_currentStep > 0)
            Positioned(
              top: 8,
              left: 4,
              child: IconButton(
                icon: const Icon(Icons.arrow_back_ios_new),
                onPressed: _prevStep,
              ),
            ),
          Positioned(
            bottom: 0,
            left: 0,
            right: 0,
            child: Padding(
              padding: const EdgeInsets.fromLTRB(24, 0, 24, 24),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  _buildPillButton(theme),
                  const SizedBox(height: 8),
                  _buildDotsIndicator(colorScheme),
                ],
              ),
            ),
          ),
        ],
      ),
    ),
  );
}
```

- [ ] **Step 2: Agregar stub temporal de `_buildPillButton` y `_buildDotsIndicator` para que compile**

Insertar justo después del método `build` (antes de `_buildModuleSelectionStep`):

```dart
Widget _buildPillButton(ThemeData theme) => const SizedBox.shrink();
Widget _buildDotsIndicator(ColorScheme colorScheme) => const SizedBox.shrink();
```

- [ ] **Step 3: Verificar que compila**

```bash
flutter build apk --debug 2>&1 | head -20
```

Esperado: sin errores de compilación (puede haber warnings de stubs vacíos).

- [ ] **Step 4: Correr los tests**

```bash
flutter test test/widget/onboarding_page_test.dart
```

Esperado: los tests de shell pasan (`no muestra flecha Atrás`, `muestra ElevatedButton` puede fallar porque el stub retorna SizedBox). Los de welcome step siguen fallando.

---

### Task 3: Implementar `_buildPillButton`

**Files:**
- Modify: `lib/features/onboarding/presentation/pages/onboarding_page.dart`

- [ ] **Step 1: Reemplazar el stub de `_buildPillButton` con la implementación real**

```dart
Widget _buildPillButton(ThemeData theme) {
  final colorScheme = theme.colorScheme;
  return SizedBox(
    width: double.infinity,
    height: 52,
    child: ElevatedButton(
      style: ElevatedButton.styleFrom(
        shape: const StadiumBorder(),
        backgroundColor: colorScheme.primary,
        foregroundColor: colorScheme.onPrimary,
      ),
      onPressed: _canProceed
          ? (_currentStep == _totalSteps - 1 ? _finish : _nextStep)
          : null,
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(_currentStep == _totalSteps - 1 ? 'Finalizar' : 'Siguiente'),
          const SizedBox(width: 8),
          const Icon(Icons.arrow_forward, size: 18),
        ],
      ),
    ),
  );
}
```

- [ ] **Step 2: Correr los tests de shell**

```bash
flutter test test/widget/onboarding_page_test.dart --name "shell"
```

Esperado: ambos tests del grupo `shell` pasan.

---

### Task 4: Implementar `_buildDotsIndicator`

**Files:**
- Modify: `lib/features/onboarding/presentation/pages/onboarding_page.dart`

- [ ] **Step 1: Reemplazar el stub de `_buildDotsIndicator` con la implementación real**

```dart
Widget _buildDotsIndicator(ColorScheme colorScheme) {
  return Row(
    mainAxisAlignment: MainAxisAlignment.center,
    children: List.generate(_totalActiveSteps, (i) {
      final isActive = i == _currentActiveStep - 1;
      return AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        width: isActive ? 20 : 6,
        height: 6,
        margin: const EdgeInsets.symmetric(horizontal: 3),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(3),
          color: isActive
              ? colorScheme.primary
              : colorScheme.onSurface.withValues(alpha: 0.3),
        ),
      );
    }),
  );
}
```

- [ ] **Step 2: Correr todos los tests de shell**

```bash
flutter test test/widget/onboarding_page_test.dart --name "shell"
```

Esperado: PASS en ambos tests.

- [ ] **Step 3: Commit del shell**

```bash
git add lib/features/onboarding/presentation/pages/onboarding_page.dart \
        test/widget/onboarding_page_test.dart
git commit -m "feat(onboarding): replace shell with Stack + pill button + dots"
```

---

### Task 5: Reescribir `_buildWelcomeStep`

**Files:**
- Modify: `lib/features/onboarding/presentation/pages/onboarding_page.dart` (~líneas 376–404)

- [ ] **Step 1: Reemplazar `_buildWelcomeStep` completo**

```dart
Widget _buildWelcomeStep(ThemeData theme) {
  final colorScheme = theme.colorScheme;

  Widget infoRow(IconData icon, String label) => Padding(
        padding: const EdgeInsets.only(bottom: 10),
        child: Row(
          children: [
            Icon(icon, size: 20, color: colorScheme.primary),
            const SizedBox(width: 12),
            Text(label, style: theme.textTheme.bodyMedium),
          ],
        ),
      );

  return SingleChildScrollView(
    padding: const EdgeInsets.fromLTRB(24, 56, 24, 120),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Bienvenida',
          style: theme.textTheme.labelSmall?.copyWith(
            color: colorScheme.primary,
          ),
        ),
        const SizedBox(height: 24),
        Container(
          width: 80,
          height: 80,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: colorScheme.primary,
          ),
          child: Icon(
            Icons.favorite,
            size: 40,
            color: colorScheme.onPrimary,
          ),
        ),
        const SizedBox(height: 24),
        Text(
          'Bienvenido a Kiolog',
          style: theme.textTheme.headlineMedium?.copyWith(
            fontWeight: FontWeight.bold,
          ),
        ),
        const SizedBox(height: 8),
        Text(
          'Vamos a configurar tu bitácora de salud personal. '
          'Este proceso solo toma unos minutos.',
          style: theme.textTheme.bodyLarge?.copyWith(
            color: colorScheme.onSurfaceVariant,
          ),
        ),
        const SizedBox(height: 32),
        Container(
          decoration: BoxDecoration(
            color: colorScheme.surfaceContainerHigh,
            borderRadius: BorderRadius.circular(12),
          ),
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'NECESITAMOS QUE NOS CUENTES:',
                style: theme.textTheme.labelSmall?.copyWith(
                  color: colorScheme.primary,
                ),
              ),
              const SizedBox(height: 12),
              infoRow(Icons.water_drop_outlined, 'Cómo medirás tu agua'),
              infoRow(Icons.restaurant_outlined, 'Tu plan de alimentación'),
              infoRow(Icons.fitness_center_outlined, 'Tu rutina de ejercicio'),
              infoRow(Icons.monitor_weight_outlined, 'Tu peso de inicio'),
            ],
          ),
        ),
      ],
    ),
  );
}
```

- [ ] **Step 2: Correr todos los tests**

```bash
flutter test test/widget/onboarding_page_test.dart
```

Esperado: TODOS los tests pasan (6/6).

- [ ] **Step 3: Commit final**

```bash
git add lib/features/onboarding/presentation/pages/onboarding_page.dart
git commit -m "feat(onboarding): redesign welcome step with Vitality Dark layout"
```
