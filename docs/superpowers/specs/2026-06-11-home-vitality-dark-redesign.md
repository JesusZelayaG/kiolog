# Home Page Redesign — Vitality Dark

**Date:** 2026-06-11
**Scope:** `lib/features/home/presentation/pages/home_page.dart`

## Objetivo

Rediseñar la página principal para que coincida con el diseño Vitality Dark de referencia: hero con progreso global, tarjetas con imagen de fondo, grid de 2 columnas para Sueño/Nutrición, y botón acción en Ejercicio.

---

## 1. Header / Hero

Reemplaza el bloque actual de `_greeting` + `_dateLabel` en el `SliverToBoxAdapter`.

```
Padding(horizontal: 24, top: 24)
  Column
    Row
      Column(crossAxisAlignment: start)
        Text("BIENVENIDO DE NUEVO", labelSmall, color: primary)
        Text("Resumen del día", headlineMedium, bold, onSurface)
      Spacer
      Column(crossAxisAlignment: end)
        Text("XX%", headlineMedium, bold, primary)   ← overallProgress * 100
        Text("META DIARIA", labelSmall, onSurfaceVariant)
    SizedBox(12)
    VitalityProgressBar(value: overallProgress, color: primary)
    SizedBox(24)
```

`overallProgress` es un método privado calculado en `build`:
```dart
double _overallProgress(HomeState s) {
  final values = [
    s.waterProgress,
    s.sleepHours != null ? (s.sleepHours! / 8).clamp(0.0, 1.0) : 0.0,
    s.totalMeals > 0 ? s.mealsLogged / s.totalMeals : 0.0,
    s.exerciseRoutineDone ? 1.0 : (s.hasGymSession ? 0.5 : 0.0),
  ];
  return values.reduce((a, b) => a + b) / values.length;
}
```

`_greeting`, `_dateLabel`, `_timeGreeting` se eliminan — ya no se usan.

---

## 2. Layout del body

Reemplaza los 4 `_ModuleCard` en el `SliverList`:

```
SliverPadding(horizontal: 24)
  SliverList
    _WideModuleCard(agua)
    SizedBox(12)
    Row
      Expanded → _CompactModuleCard(sueño)
      SizedBox(12)
      Expanded → _CompactModuleCard(nutrición)
    SizedBox(12)
    _WideModuleCard(ejercicio)
    SizedBox(32)
```

---

## 3. `_WideModuleCard`

Widget para Agua y Ejercicio. Alto fijo: 100px.

```
GestureDetector(onTap: onTap)
  ClipRRect(borderRadius: 12)
    Stack
      Positioned.fill
        Image.asset(bgImage, fit: BoxFit.cover)
      Positioned.fill
        Container(color: Colors.black.withValues(alpha: 0.50))
      Padding(all: 16)
        Row
          ModuleIconBadge(icon: icon, color: color)
          SizedBox(12)
          Expanded
            Column(crossAxisAlignment: start)
              Text(label, labelLarge, onSurface)
              SizedBox(4)
              Text(subtitle, bodySmall, onSurface.withValues(alpha: 0.7))
          // Si showAction == true:
          ElevatedButton("VER AHORA", StadiumBorder, primary)
          // Si showAction == false:
          Icon(chevron_right, onSurface.withValues(alpha: 0.6))
```

Parámetros:
- `icon`, `label`, `subtitle`, `color`, `bgImage`, `onTap` — requeridos
- `showAction: bool` — si true muestra pill "VER AHORA", si false muestra chevron

---

## 4. `_CompactModuleCard`

Widget para Sueño y Nutrición. Alto: IntrinsicHeight o fijo 120px.

```
GestureDetector(onTap: onTap)
  ClipRRect(borderRadius: 12)
    Stack
      Positioned.fill
        Image.asset(bgImage, fit: BoxFit.cover)
      Positioned.fill
        Container(color: Colors.black.withValues(alpha: 0.55))
      Padding(all: 12)
        Column(crossAxisAlignment: start)
          ModuleIconBadge(icon: icon, color: color, size: 32)
          Spacer
          Text(label, labelMedium, onSurface)
          SizedBox(2)
          Text(subtitle, bodySmall, onSurface.withValues(alpha: 0.7))
```

Parámetros: `icon`, `label`, `subtitle`, `color`, `bgImage`, `onTap`.

---

## 5. Archivos afectados

| Archivo | Cambio |
|---|---|
| `home_page.dart` | Header, layout, 2 nuevos widgets, elimina `_ModuleCard` |
| `pubspec.yaml` | Ya actualizado — `assets/img/` registrado |

## 6. Assets

| Asset | Usado en |
|---|---|
| `assets/img/water_bg.png` | `_WideModuleCard` agua |
| `assets/img/sleep_bg.png` | `_CompactModuleCard` sueño |
| `assets/img/nutrition_bg.png` | `_CompactModuleCard` nutrición |
| `assets/img/exercise_bg.png` | `_WideModuleCard` ejercicio |

## 7. Out of scope

- Challenge banner
- Cambios en `HomeBloc` / `HomeState`
- Rediseño de otras páginas
