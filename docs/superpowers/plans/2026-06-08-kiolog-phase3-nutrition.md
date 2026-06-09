# Kiolog — Phase 3: Nutrition Module

**Fecha:** 2026-06-08
**Goal:** Implementar el módulo de Nutrición con gestión de planes alimenticios, opciones por tiempo de comida, registro diario y comidas fuera de plan.

---

## Resumen de Cambios

### Estructura de Carpetas Nuevas

```
lib/features/nutrition/
├── domain/repositories/nutrition_repository.dart
├── data/repositories/nutrition_repository_impl.dart
├── presentation/bloc/
│   ├── nutrition_bloc.dart
│   ├── nutrition_event.dart
│   └── nutrition_state.dart
└── presentation/pages/nutrition_page.dart
```

### Archivos Modificados

- `lib/core/di/injection.dart` — registro de `NutritionRepository` e import de `NutritionDao`
- `test/widget/app_scaffold_test.dart` — ajustado para soportar `NutritionPage` real con mocks

### Tests Nuevos

- `test/features/nutrition/data/nutrition_repository_test.dart`
- `test/features/nutrition/presentation/nutrition_bloc_test.dart`

---

## Funcionalidad

**Nutrición:**
- Detecta si existe un plan activo; si no, muestra pantalla para crear uno
- Muestra el nombre del plan activo
- Para cada tiempo de comida (Desayuno, Almuerzo, Cena, Entrecomida):
  - Lista las opciones configuradas (1, 2, 3)
  - Permite tocar una opción para marcarla como registrada
  - Indica visualmente cuál opción fue elegida
  - Permite registrar "fuera de plan" con descripción libre
  - **Cambiar selección**: botón "Cambiar selección" que deshace el registro y permite reelegir
- Diálogo de gestión de planes (historial, activar otro plan)

**BLoC Events:**
- `NutritionLoaded(date)` — carga plan activo, opciones y logs del día
- `NutritionPlanLoaded()` — carga todos los planes
- `NutritionMealLogged(date, mealType, planOptionId)` — registra comida del plan
- `NutritionOffPlanMealLogged(date, mealType, description)` — registra comida libre
- `NutritionMealLogRemoved(date, mealType)` — elimina el registro de una comida (para reelegir)
- `NutritionPlanActivated(planId)` — cambia plan activo
- `NutritionPlanCreated(name)` — crea nuevo plan
- `NutritionOptionAdded(...)` — agrega opción a un plan

**BLoC State:**
- `activePlan`, `allPlans`, `planOptions` (mapa por mealType), `dailyLogs`
- Helpers: `isMealLogged(mealType)`, `getLogForMeal(mealType)`

---

## Verificación

- [x] `flutter test` → 45 tests pasan
- [x] `flutter build apk --debug` → compila sin errores
- [x] Home → Nutrición navega a página funcional
- [x] Sin plan activo muestra CTA para crear plan
- [x] Con plan activo muestra opciones por tiempo de comida
