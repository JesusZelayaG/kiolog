# Onboarding Shell Redesign — Vitality Dark

**Date:** 2026-06-11  
**Scope:** `lib/features/onboarding/presentation/pages/onboarding_page.dart`

## Objetivo

Rediseñar el shell de navegación del onboarding y el paso de bienvenida para que coincidan con la imagen de referencia del tema Vitality Dark. El diseño usa un layout Stack flotante con pill button y dots de página, eliminando la `VitalityProgressBar` y los botones de navegación actuales.

---

## 1. Shell — `build` method

### Estructura actual
```
Column
  VitalityProgressBar (top)
  Expanded → PageView
  Padding → Row(Atrás | Spacer | Siguiente)
```

### Estructura nueva
```
Scaffold
  body: SafeArea
    Stack
      PageView (fills full space, NeverScrollableScrollPhysics)
      Positioned(top: 8, left: 4)  ← solo si _currentStep > 0
        IconButton(Icons.arrow_back_ios_new, onPressed: _prevStep)
      Positioned(bottom: 0, left: 0, right: 0)
        Padding(horizontal: 24, bottom: 24)
          Column
            _buildPillButton()
            SizedBox(8)
            _buildDotsIndicator()
```

- `VitalityProgressBar` se elimina.
- La flecha Atrás es invisible en el paso 0 (`_currentStep == 0`).
- El `Row(Atrás | Spacer | Siguiente)` se elimina.

---

## 2. Pill Button — `_buildPillButton`

```dart
SizedBox(
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
    child: Row(mainAxisSize: MainAxisSize.min, children: [
      Text(_currentStep == _totalSteps - 1 ? 'Finalizar' : 'Siguiente'),
      SizedBox(width: 8),
      Icon(Icons.arrow_forward, size: 18),
    ]),
  ),
)
```

---

## 3. Dots Indicator — `_buildDotsIndicator`

- Un dot por cada paso activo (`_totalActiveSteps`).
- El dot del paso actual (`_currentActiveStep - 1`) es un pill ancho (20px); los demás son círculos pequeños (6px).
- Usa `AnimatedContainer` con duración 200ms para la transición de ancho.
- Color activo: `colorScheme.primary`. Inactivo: `onSurface.withValues(alpha: 0.3)`.

```dart
Row(
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
)
```

---

## 4. Welcome Step — `_buildWelcomeStep`

### Estructura nueva
```
SingleChildScrollView
  Padding(horizontal: 24, top: 56, bottom: 120)
    Column(crossAxisAlignment: start)
      Text("Bienvenida", labelSmall, color: primary)
      SizedBox(24)
      Container(80×80, circle, color: primary)
        Icon(Icons.favorite, size: 40, color: onPrimary)
      SizedBox(24)
      Text("Bienvenido a Kiolog", headlineMedium, fontWeight: bold)
      SizedBox(8)
      Text("Vamos a configurar tu bitácora de salud personal.
            Este proceso solo toma unos minutos.", bodyLarge, onSurfaceVariant)
      SizedBox(32)
      Container(decoration: rounded(12), color: colorScheme.surfaceContainerHigh)
        Padding(all: 16)
          Column
            Text("NECESITAMOS QUE NOS CUENTES:", labelSmall, color: primary)
            SizedBox(12)
            _infoRow(Icons.water_drop_outlined,     "Cómo medirás tu agua")
            _infoRow(Icons.restaurant_outlined,     "Tu plan de alimentación")
            _infoRow(Icons.fitness_center_outlined, "Tu rutina de ejercicio")
            _infoRow(Icons.monitor_weight_outlined, "Tu peso de inicio")
```

### `_infoRow` helper (función local dentro de `_buildWelcomeStep`)
```dart
Widget _infoRow(IconData icon, String label) => Padding(
  padding: const EdgeInsets.only(bottom: 10),
  child: Row(children: [
    Icon(icon, size: 20, color: colorScheme.primary),
    const SizedBox(width: 12),
    Text(label, style: theme.textTheme.bodyMedium),
  ]),
);
```

---

## 5. Archivos afectados

| Archivo | Cambio |
|---|---|
| `onboarding_page.dart` | Shell, welcome step, helpers |

No se crean archivos nuevos. Los demás pasos (water, nutrition, exercise, initial data) no cambian internamente; solo se benefician del nuevo shell.

---

## 6. Out of scope

- Rediseño de los pasos 2–5 (agua, nutrición, ejercicio, datos iniciales).
- Cambios en lógica de negocio o persistencia.
- Animaciones de transición entre páginas.
