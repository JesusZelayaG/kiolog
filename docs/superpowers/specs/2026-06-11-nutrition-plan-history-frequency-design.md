# Nutrition — Plan History & Option Frequency Design

**Date:** 2026-06-11
**Scope:** `lib/features/nutrition/` — sin cambios al schema de BD

---

## Objetivo

Tres mejoras relacionadas al ciclo de vida de planes nutricionales:

1. **Frecuencia por opción** — en la pantalla de Progreso, mostrar cuántas veces se repitió cada opción de cada tiempo de comida durante el período del plan.
2. **Historial de planes** — poder navegar al progreso/frecuencia de un plan anterior desde un selector en la pantalla de Progreso.
3. **Nueva consulta mensual** — crear el plan que da la nutricionista cada mes y activarlo en el momento indicado, con un banner de recordatorio.

---

## Contexto del dominio

- Cada plan cubre un período (`periodStart` → `periodEnd`). El plan activo no tiene `periodEnd` (null).
- Cada plan tiene tiempos de comida (mealType: string libre) y opciones por tiempo (`MealPlanOption`).
- Los planes cambian completamente entre consultas: distintos tiempos de comida y opciones nuevas.
- Los registros diarios (`DailyMealLog`) apuntan a `planOptionId` (nullable) para saber qué opción se comió.

---

## 1. Capa de datos

### 1.1 Nuevo modelo: `OptionFrequencyStat`

```dart
// lib/features/nutrition/domain/models/option_frequency_stat.dart
class OptionFrequencyStat extends Equatable {
  final int planOptionId;
  final String mealType;
  final int optionNumber;
  final String description;
  final int count; // veces registrado en el período del plan

  const OptionFrequencyStat({
    required this.planOptionId,
    required this.mealType,
    required this.optionNumber,
    required this.description,
    required this.count,
  });

  @override
  List<Object?> get props => [planOptionId, mealType, optionNumber, description, count];
}
```

### 1.2 DAO — `NutritionDao`

Agregar método `getOptionFrequenciesForPlan(int planId)`:

```dart
Future<List<OptionFrequencyStat>> getOptionFrequenciesForPlan(int planId) async {
  // 1. Obtener el plan para conocer su período
  final plan = await (select(mealPlans)..where((t) => t.id.equals(planId))).getSingleOrNull();
  if (plan == null) return [];

  final start = plan.periodStart;
  if (start == null) return [];
  final startUtc = DateTime.utc(start.year, start.month, start.day);
  final endUtc = plan.periodEnd != null
      ? DateTime.utc(plan.periodEnd!.year, plan.periodEnd!.month, plan.periodEnd!.day)
          .add(const Duration(days: 1)) // inclusive
      : DateTime.now().toUtc().add(const Duration(days: 1)); // hasta hoy inclusive

  // 2. Obtener todas las opciones del plan
  final opts = await (select(mealPlanOptions)
        ..where((t) => t.planId.equals(planId))
        ..orderBy([
          (t) => OrderingTerm.asc(t.mealType),
          (t) => OrderingTerm.asc(t.optionNumber),
        ]))
      .get();

  if (opts.isEmpty) return [];

  // 3. Contar los logs que apuntan a cada opción dentro del período
  final optionIds = opts.map((o) => o.id).toList();
  final logs = await (select(dailyMealLogs)
        ..where((t) =>
            t.planOptionId.isIn(optionIds) &
            t.date.isBiggerOrEqualValue(startUtc) &
            t.date.isSmallerThanValue(endUtc)))
      .get();

  final countMap = <int, int>{};
  for (final log in logs) {
    if (log.planOptionId != null) {
      countMap[log.planOptionId!] = (countMap[log.planOptionId!] ?? 0) + 1;
    }
  }

  return opts
      .map((o) => OptionFrequencyStat(
            planOptionId: o.id,
            mealType: o.mealType,
            optionNumber: o.optionNumber,
            description: o.description,
            count: countMap[o.id] ?? 0,
          ))
      .toList();
}
```

### 1.3 Repository — `NutritionRepository` / `NutritionRepositoryImpl`

```dart
// domain/repositories/nutrition_repository.dart — agregar:
Future<List<OptionFrequencyStat>> getOptionFrequency(int planId);

// data/repositories/nutrition_repository_impl.dart — agregar:
@override
Future<List<OptionFrequencyStat>> getOptionFrequency(int planId) =>
    _nutritionDao.getOptionFrequenciesForPlan(planId);
```

---

## 2. BLoC / Estado

### 2.1 `NutritionState` — nuevos campos

```dart
final int? viewingPlanId;           // null = plan activo
final List<OptionFrequencyStat> optionFrequencies;

// getter de conveniencia
bool get hasPendingPlan {
  // true si existe un plan inactivo creado después del plan activo
  if (activePlan == null) return false;
  return allPlans.any((p) =>
      !p.isActive &&
      p.createdAt.isAfter(activePlan!.createdAt));
}

MealPlan? get pendingPlan {
  if (activePlan == null) return null;
  return allPlans
      .where((p) => !p.isActive && p.createdAt.isAfter(activePlan!.createdAt))
      .firstOrNull;
}

MealPlan? get viewingPlan =>
    viewingPlanId == null
        ? activePlan
        : allPlans.firstWhereOrNull((p) => p.id == viewingPlanId);
```

`copyWith` usa un sentinel para poder limpiar `viewingPlanId` a null:

```dart
static const _unset = Object();

NutritionState copyWith({
  // ... campos existentes ...
  Object? viewingPlanId = _unset,
  List<OptionFrequencyStat>? optionFrequencies,
}) =>
    NutritionState(
      // ...
      viewingPlanId: viewingPlanId == _unset
          ? this.viewingPlanId
          : viewingPlanId as int?,
      optionFrequencies: optionFrequencies ?? this.optionFrequencies,
    );
```

### 2.2 Nuevos eventos

```dart
// Seleccionar qué plan ver en la pantalla de Progreso
class NutritionProgressPlanSelected extends NutritionEvent {
  final int planId;
  const NutritionProgressPlanSelected({required this.planId});
  @override List<Object?> get props => [planId];
}
```

### 2.3 Nuevo handler en `NutritionBloc`

```dart
on<NutritionProgressPlanSelected>(_onProgressPlanSelected);

Future<void> _onProgressPlanSelected(
  NutritionProgressPlanSelected event,
  Emitter<NutritionState> emit,
) async {
  emit(state.copyWith(status: NutritionStatus.loading));
  try {
    final frequencies = await _repository.getOptionFrequency(event.planId);
    final isActive = state.activePlan?.id == event.planId;
    List<NutritionWeeklyStat> adherence = state.weeklyAdherence;
    if (isActive) {
      adherence = await _repository.getWeeklyAdherence(weeksBack: 8);
    }
    emit(state.copyWith(
      status: NutritionStatus.success,
      viewingPlanId: event.planId,
      optionFrequencies: frequencies,
      weeklyAdherence: adherence,
      error: null,
    ));
  } catch (e) {
    emit(state.copyWith(status: NutritionStatus.failure, error: e.toString()));
  }
}
```

`NutritionLoaded` también carga `allPlans` y frecuencias del plan activo al inicializar:

```dart
// en _onLoaded, agregar junto a las otras llamadas:
final plans = await _repository.getAllPlans();
final frequencies = plan != null
    ? await _repository.getOptionFrequency(plan.id)
    : <OptionFrequencyStat>[];

// incluir en el emit final:
emit(state.copyWith(
  status: NutritionStatus.success,
  activePlan: plan,
  allPlans: plans,
  dailyLogs: logs,
  planOptions: options,
  weeklyAdherence: adherence,
  optionFrequencies: frequencies,
  error: null,
));
```

---

## 3. UI

### 3.1 `NutritionProgressPage` — refactor completo

**Estructura nueva:**

```
Scaffold
  AppBar: "Progreso Nutrición"
  body:
    Column
      _PlanChip (selector siempre visible)
      if (viewingPlan == activePlan):
        TabBar ["Adherencia", "Frecuencia"]
        Expanded > TabBarView [_AdherenciaTab, _FrecuenciaTab]
      else:
        // plan anterior: solo frecuencia, sin tab bar
        Expanded > _FrecuenciaTab
```

`NutritionProgressPage` extiende `StatefulWidget` con `SingleTickerProviderStateMixin`. El `TabController` se crea solo cuando `viewingPlan == activePlan`. Al cambiar a un plan anterior, el TabController se destruye para evitar errores de animación.

**`_PlanChip`** — chip desplegable que abre un `showModalBottomSheet`:
- Muestra nombre del plan actual y "▼"
- Al tocar → `_PlanSelectorSheet`

**`_PlanSelectorSheet`** — bottom sheet con:
- Plan activo destacado (borde primary, chip "ACTIVO")
- Planes anteriores con nombre, período y botón "Ver stats" → dispatcha `NutritionProgressPlanSelected(planId: plan.id)` y cierra el sheet
- Botón "Nueva consulta" (borde punteado) → navega a `NutritionConfigPage(onComplete: () { bloc.add(NutritionLoaded(date: DateTime.now())); })` — recargar desde cero al terminar actualiza `allPlans` y muestra el banner

**`_FrecuenciaTab`** — para cada `mealType` único en `optionFrequencies`:
```
Label "DESAYUNO · N días"
Card:
  por cada opción:
    Row: descripción + count (ej: "18×")
    LinearProgressIndicator(value: count / maxCount)
```
`maxCount` = el máximo count entre todas las opciones de ese mealType (para normalizar las barras).

**`_AdherenciaTab`** — el código actual de `NutritionProgressPage` movido sin cambios.

### 3.2 `NutritionPage` — banner de plan pendiente

En el body del `BlocBuilder`, antes del contenido principal:

```dart
if (state.hasPendingPlan)
  _PendingPlanBanner(plan: state.pendingPlan!)
```

**`_PendingPlanBanner`:**
```dart
Container(
  color: colorScheme.primaryContainer.withValues(alpha: 0.5),
  padding: EdgeInsets.symmetric(horizontal: 16, vertical: 10),
  child: Row(
    children: [
      Icon(Icons.new_releases_outlined, color: colorScheme.primary),
      SizedBox(width: 10),
      Expanded(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(plan.name, style: textTheme.labelLarge),
            Text('Listo para activar', style: textTheme.bodySmall),
          ],
        ),
      ),
      TextButton(
        onPressed: () => context.read<NutritionBloc>()
            .add(NutritionPlanActivated(planId: plan.id)),
        child: Text('Activar'),
      ),
    ],
  ),
)
```

### 3.3 Eliminar `_showCreatePlanDialog` de `NutritionPage`

El botón "Crear plan" en `_buildNoPlanView` y el ícono de historia en el AppBar que actualmente abre `_PlansDialog` se simplifican:
- `_buildNoPlanView`: el botón "Crear plan" navega directamente a `NutritionConfigPage`.
- AppBar: el ícono de historia sigue abriendo `_PlansDialog` (existente), pero `_PlansDialog` agrega un botón "Nueva consulta" que navega a `NutritionConfigPage`.
- `_showCreatePlanDialog` (el diálogo simple con solo nombre + goal): **eliminado**.

---

## 4. Archivos afectados

| Archivo | Cambio |
|---|---|
| `lib/features/nutrition/domain/models/option_frequency_stat.dart` | **Crear** nuevo modelo |
| `lib/core/dao/nutrition_dao.dart` | Agregar `getOptionFrequenciesForPlan` |
| `lib/features/nutrition/domain/repositories/nutrition_repository.dart` | Agregar `getOptionFrequency` |
| `lib/features/nutrition/data/repositories/nutrition_repository_impl.dart` | Implementar `getOptionFrequency` |
| `lib/features/nutrition/presentation/bloc/nutrition_event.dart` | Agregar `NutritionProgressPlanSelected` |
| `lib/features/nutrition/presentation/bloc/nutrition_state.dart` | Agregar `viewingPlanId`, `optionFrequencies`, getters `hasPendingPlan`, `pendingPlan`, `viewingPlan` |
| `lib/features/nutrition/presentation/bloc/nutrition_bloc.dart` | Handler `_onProgressPlanSelected`, cargar frecuencias en `_onLoaded` |
| `lib/features/nutrition/presentation/pages/nutrition_progress_page.dart` | Refactor: `_PlanChip`, `_PlanSelectorSheet`, tabs, `_FrecuenciaTab` |
| `lib/features/nutrition/presentation/pages/nutrition_page.dart` | `_PendingPlanBanner`, simplificar plan creation, actualizar `_PlansDialog` |

---

## 5. Fuera de alcance

- Editar opciones de un plan existente
- Comparar frecuencias entre dos planes
- Notificaciones de "activa tu nuevo plan"
- Exportar stats
