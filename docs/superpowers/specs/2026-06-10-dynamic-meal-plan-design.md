# Dynamic Meal Plan — Spec

**Date:** 2026-06-10  
**Status:** Approved

## Overview

Make the nutrition meal plan fully dynamic: the user defines any number of meal times with any number of dish options per time, using free-form names. `dailyMealGoal` is set automatically. The NutritionPage is updated to display whatever meal types the active plan contains, and adds a "no seguí el plan" quick action.

## Scope

Two surfaces change:

1. **Onboarding** — `_buildNutritionStep` in `onboarding_page.dart`
2. **NutritionPage** — `nutrition_page.dart` (display + logging actions)

One event changes:

3. **`NutritionOffPlanMealLogged`** — `description` becomes nullable

No DB schema changes needed (`freeDescription` is already nullable in `DailyMealLogs`).

---

## Component 1: Onboarding — Dynamic Meal Times

### Data model (local to onboarding)

Replace `Map<String, List<TextEditingController>> _mealOptions` with:

```dart
class _MealTime {
  final nameController = TextEditingController();
  final List<TextEditingController> options = [TextEditingController()];
}

List<_MealTime> _mealTimes = [_MealTime()]; // starts with 1
```

### UI behavior

- Each `_MealTime` renders as a Card:
  - Header row: label "Tiempo N", name text field (placeholder "Ej: Desayuno"), delete icon button
  - Body: list of option text fields, each with a ✕ button to remove
  - Footer: "+ Agregar opción" button
- Delete card: only enabled when `_mealTimes.length > 1`
- Remove option (✕): only enabled when the meal time has more than 1 option
- "+ Agregar tiempo de comida" button below all cards
- Helper text below the button: "Meta diaria automática: N comidas"

### `_finish()` changes

```dart
final planId = await nutritionRepo.createPlan(
  _mealPlanNameController.text,
  dailyMealGoal: _mealTimes.length,  // was hardcoded to 4
);
for (final mealTime in _mealTimes) {
  final typeName = mealTime.nameController.text.trim();
  if (typeName.isEmpty) continue;
  for (int i = 0; i < mealTime.options.length; i++) {
    final text = mealTime.options[i].text.trim();
    if (text.isNotEmpty) {
      await nutritionRepo.addPlanOption(
        planId: planId,
        mealType: typeName,
        optionNumber: i + 1,
        description: text,
      );
    }
  }
}
```

### `dispose()` changes

Update to dispose the new structure:
```dart
for (final mt in _mealTimes) {
  mt.nameController.dispose();
  for (final c in mt.options) c.dispose();
}
```

---

## Component 2: NutritionPage — Dynamic Display

### Meal section list

Replace the hardcoded list:
```dart
// before
...['breakfast', 'lunch', 'dinner', 'snack'].map((type) => _MealSection(...))

// after
...state.planOptions.keys.map((type) => _MealSection(
  mealType: type,
  label: type,        // free-form name, no translation
  icon: '🍽️',         // generic icon
  options: state.planOptions[type] ?? [],
  log: state.getLogForMeal(type),
))
```

Remove `_mealTypeLabel()` and `_mealTypeIcon()` helper methods.

### Logging actions (when not logged)

Replace single "Registrar fuera de plan" button with two buttons:

| Button | Action |
|---|---|
| "✗ No seguí el plan" | Fires `NutritionOffPlanMealLogged(description: null)` immediately — no dialog |
| "✎ Fuera de plan" | Opens existing `_showOffPlanDialog` (records what was eaten) |

### Display states (when logged)

| Condition | Chip | Card background color | Icon + text |
|---|---|---|---|
| `planOptionId != null` | "Registrado" (green) | green-tinted | ✓ Opción N: descripción |
| `planOptionId == null && freeDescription == null` | "No seguido" (red) | red-tinted | ✗ No seguí el plan |
| `planOptionId == null && freeDescription != null` | "Fuera de plan" (orange) | orange-tinted | 📝 texto libre |

All states show "↩ Cambiar selección" button.

---

## Component 3: `NutritionOffPlanMealLogged` — Nullable description

```dart
// before
class NutritionOffPlanMealLogged extends NutritionEvent {
  final String description;  // required
  ...
}

// after
class NutritionOffPlanMealLogged extends NutritionEvent {
  final String? description;  // nullable
  ...
}
```

Propagate through:
- BLoC `_onOffPlanMealLogged` handler → pass nullable description to repository
- `NutritionRepository.logOffPlanMeal(description: String?)` interface + impl
- `NutritionDao` insert → `freeDescription` already nullable, no change needed

---

## Out of scope

- Icons per meal time (free-form names don't map to fixed icons; generic icon is used)
- Editing an existing plan's meal times (create new plan workflow already exists in NutritionPage)
- Validation that meal time names are unique within a plan
