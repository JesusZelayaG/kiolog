# Optional Modules Design

## Overview

Allow users to choose which tracking modules (Nutrition, Hydration, Exercise) they want to use. Inactive modules remain visible in the navigation but show a locked state with an option to activate and configure them at any time.

---

## Module Identifiers

A Dart enum `AppModule` with three values:

```dart
enum AppModule { nutrition, water, exercise }
```

Used as the canonical identifier in the DB, domain, and UI layers.

---

## Data Layer

### New table: `user_modules`

| column    | type   | notes                           |
|-----------|--------|---------------------------------|
| `module`  | TEXT   | `'nutrition'`, `'water'`, `'exercise'` (primary key) |
| `enabled` | BOOL   | `true` = active, `false` = inactive |

**Seeded** at onboarding completion with the user's selections. Every module that was not disabled gets `enabled: true`; disabled ones get `enabled: false`.

### `UserModulesDao`

- `getModuleStatus(AppModule module) → Future<bool>` — returns `enabled` for the given module (defaults to `true` if row missing)
- `getAllModuleStatuses() → Future<Map<AppModule, bool>>` — returns all three statuses
- `setModuleEnabled(AppModule module, bool enabled) → Future<void>` — upsert

---

## Onboarding Changes

### New step: Module selection (step index 1, after Welcome)

Position: inserted between "Bienvenida" and "Configuración de Agua".

**UI:** Three rows with Switch widgets, all enabled by default. Each row: icon + name + description + Switch. At least one module must remain enabled (the last enabled switch cannot be turned off).

**Behavior:**
- Disabled modules skip their configuration step entirely.
- The step order becomes: Welcome → **Module Selection** → [Water Config?] → [Nutrition Config?] → [Exercise Config?] → Initial Data.
- `_finish()` seeds `user_modules` with the selections before marking onboarding complete.

---

## Navigation — Inactive Tab Indicator

`AppScaffold` consumes `ModulesCubit` and rebuilds when module state changes. For each module tab that is `enabled: false`:

- Tab icon is rendered at reduced opacity (≈ 30%).
- A small lock icon (🔒) overlays the tab icon.
- Label text is dimmed.

Tapping an inactive tab navigates to that module's page, which renders the **inactive state screen** instead of normal content.

---

## Inactive Module Screen

Each module page (`NutritionPage`, `WaterPage`, `ExercisePage`) checks module status on load. If inactive:

```
[large dimmed icon]
[Module name] no activado

Este módulo está desactivado.
Configúralo para empezar a registrar.

[ Activar y configurar ]

También puedes activarlo desde Settings → Módulos.
```

Tapping "Activar y configurar" pushes the **module config flow** (see below) as a full-screen route. On completion the module is marked `enabled: true` and the page reloads normally. On cancellation, stays on the inactive screen.

---

## Module Config Flow (reusable)

Each module's onboarding configuration step is extracted into a standalone widget/page that can be launched from:
1. The inactive module screen ("Activar y configurar")
2. Settings → Módulos (when toggling a disabled module on)

The three config pages:
- `WaterConfigPage` — unit type, container size, daily goal
- `NutritionConfigPage` — plan name, meal times with options
- `ExerciseConfigPage` — plan name, routine days with exercises

Each config page receives an `onComplete` callback. On completion it saves the config, calls `setModuleEnabled(module, true)`, then calls `onComplete`.

The onboarding steps reuse these same pages (the step is now just a thin wrapper).

---

## Settings — "Módulos activos" Section

New section at the top of the Settings page, above Notifications.

**UI:** Three rows (same as onboarding selection step). Each row shows: icon + name + status subtitle ("Plan activo" / "Sin configurar") + Switch.

**Toggle behaviors:**

- **Deactivating an active module:** Show confirmation dialog: "Tu historial se conserva. Solo dejará de verse como activo. ¿Desactivar?" → on confirm: `setModuleEnabled(module, false)`.
- **Activating an unconfigured module:** Show dialog: "Necesitas configurar este módulo." → "Configurar" button pushes the config flow. On completion the module becomes active.
- **Activating a previously configured module:** Direct `setModuleEnabled(module, true)` — no re-config needed (existing plan/config is preserved).

**Minimum 1 active module:** The last active switch cannot be turned off (switch is disabled with a tooltip).

---

## State Propagation

`AppScaffold` and each module page need to react to module status changes. The simplest approach: a `ModulesCubit` (or `ChangeNotifier`) that wraps `UserModulesDao` and exposes the current `Map<AppModule, bool>`. Widgets that need module status consume it via `BlocBuilder` / `context.watch`.

---

## What Does NOT Change

- The data inside each module (plans, logs, config) is never deleted when a module is deactivated — only visibility changes.
- The Progress and Home pages are always active; they are not optional modules.
- The Sleep module is not included in optional modules (it has no onboarding config step and no dedicated nav tab).
