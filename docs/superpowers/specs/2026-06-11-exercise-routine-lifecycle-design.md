# Exercise Routine Lifecycle & Day Selection Design

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task.

**Goal:** Añadir selección explícita del día de rutina al llegar al gym, ciclo de vida de planes (periodStart/periodEnd), historial de planes con stats de cumplimiento, y creación de planes a partir de plantillas anteriores.

**Architecture:** Extensión incremental sobre el sistema de ejercicio existente. Se agrega `periodStart`/`periodEnd` a `ExercisePlan`, un nuevo modelo `PlanComplianceStat`, una consulta DAO de historial, y tres cambios de UI: card de selección de día en exercise_page, tab Historial en exercise_progress_page, y flujo de plantilla en exercise_config_page.

**Tech Stack:** Flutter · Drift ORM · BLoC · existing exercise feature structure

---

## 1. Data Model

### ExercisePlan — campos nuevos

```
periodStart: DateTime   // se llena al crear o activar el plan (DateTime.now())
periodEnd: DateTime?    // null mientras activo; se llena al activar otro plan
```

- `createdAt` ya existe y se mantiene sin cambios
- `periodStart` puede diferir de `createdAt` si el plan fue creado pero activado después (raro, pero correcto)
- Al llamar `setActiveExercisePlan(planId)`, en la misma transacción: `UPDATE exercise_plans SET period_end = now() WHERE is_active = true`, luego activar el nuevo con `period_start = now()`

### PlanComplianceStat — nuevo modelo de dominio

```dart
class PlanComplianceStat extends Equatable {
  final int planId;
  final String planName;
  final DateTime periodStart;
  final DateTime? periodEnd;   // null = plan activo
  final int totalSessions;     // sesiones de rutina completadas en el período
  final int weeksActive;       // semanas entre periodStart y periodEnd (o hoy)
  final double weeklyAvg;      // totalSessions / weeksActive
  final int compliancePercent; // (totalSessions / (weeklyRoutineDaysGoal × weeksActive)).clamp(0,100) × 100
  // weeklyRoutineDaysGoal: usa el valor actual de ExerciseConfig — no se guarda por período de plan
}
```

Archivo: `lib/features/exercise/domain/models/plan_compliance_stat.dart`

---

## 2. Base de Datos (DAO)

### Migración

`ExercisePlans` gana dos columnas nuevas:
- `period_start` — `DateTime` NOT NULL, default `created_at` (para planes existentes)
- `period_end` — `DateTime` nullable

Drift schema version bump: versión actual → versión + 1. Migration:
```sql
ALTER TABLE exercise_plans ADD COLUMN period_start INTEGER NOT NULL DEFAULT 0;
ALTER TABLE exercise_plans ADD COLUMN period_end INTEGER;
UPDATE exercise_plans SET period_start = created_at WHERE period_start = 0;
```
(Drift usa epoch millis para DateTime. El UPDATE copia `created_at` como valor inicial para planes existentes.)

### setActiveExercisePlan — modificación

```dart
// Dentro de la transacción existente:
// 1. SET period_end = now() WHERE is_active = true AND period_end IS NULL
// 2. SET is_active = false WHERE id != planId
// 3. SET is_active = true, period_start = now() WHERE id == planId
```

### getPlanHistory() — nuevo método DAO

Para cada plan, cuenta `ExerciseSessionLogs` donde:
- `routineId` pertenece al plan (via JOIN con `ExerciseRoutines`)
- `gym_left_at IS NOT NULL` (sesión completada)
- `date >= period_start AND (period_end IS NULL OR date <= period_end)`

Devuelve lista de `PlanComplianceStat` ordenada por `period_start DESC`.

Archivo: `lib/core/dao/exercise_dao.dart`

---

## 3. Repository

### Interface — nuevo método

```dart
Future<List<PlanComplianceStat>> getPlanHistory();
```

Archivo: `lib/features/exercise/domain/repositories/exercise_repository.dart`

### Implementation

Delega a `_exerciseDao.getPlanHistory()`. El cálculo de `compliancePercent` usa `weeklyRoutineDaysGoal` del config (se pasa como parámetro o se lee internamente).

Archivo: `lib/features/exercise/data/repositories/exercise_repository_impl.dart`

---

## 4. BLoC

### Nuevos eventos

```dart
class ExercisePlanHistoryLoaded extends ExerciseEvent {}
// Carga historial de planes — usado al entrar al tab Historial
```

### Estado — campo nuevo

```dart
final List<PlanComplianceStat> planHistory;  // default []
```

### Handler _onLoaded — sin cambios

El historial se carga lazy (solo cuando el usuario toca el tab Historial).

### Handler _onPlanHistoryLoaded — nuevo

```dart
Future<void> _onPlanHistoryLoaded(
  ExercisePlanHistoryLoaded event,
  Emitter<ExerciseState> emit,
) async {
  final history = await _repository.getPlanHistory();
  emit(state.copyWith(planHistory: history));
}
```

### Handler _onPlanActivated — modificado

Después de activar el plan, recargar el historial:
```dart
await _repository.activatePlan(event.planId);
final history = await _repository.getPlanHistory();
emit(state.copyWith(planHistory: history, ...));
```

Archivos: `exercise_event.dart`, `exercise_state.dart`, `exercise_bloc.dart`

---

## 5. UI — Selección de día (exercise_page.dart)

### Card "¿Qué harás hoy?"

Se muestra cuando `!state.hasActiveSession`. Reemplaza la interacción implícita de expandir una tarjeta.

**Estructura:**
```
Container "¿Qué harás hoy?"
  ├── Wrap de chips — uno por cada ExerciseRoutine del plan activo
  │     Cada chip: "Día N · {routineName}"
  │     Chip seleccionado: borde con colorScheme.primary
  │     Chip no seleccionado: borde sutil
  └── ElevatedButton "Iniciar sesión — Día N"
        → dispatch ExerciseSessionStarted(date: today, routineId: selectedRoutine.id)
```

**Estado local:** `_selectedRoutineId` — inicializa con la primera rutina disponible.

**Mini-calendario semanal** debajo de la card:
- 7 círculos L M X J V S D
- Verde con icono check = día con sesión completada (de `completedRoutineSessionsThisWeek`)
- Rojo = hoy sin sesión
- Gris punteado = día futuro o sin sesión pasada

**Cuando hay sesión activa:** la card de selección se reemplaza por la card de sesión en curso existente (sin cambios).

---

## 6. UI — Tab Historial (exercise_progress_page.dart)

### TabBar

Agregar tercer tab al `TabController` existente (actualmente: Semana / Mes):
```
Semana | Mes | Historial
```

Al seleccionar "Historial", dispatch `ExercisePlanHistoryLoaded` si `state.planHistory.isEmpty`.

### _HistorialTab widget

Lista de `PlanComplianceStat` cards:

```
Card por plan:
  ├── Row: nombre del plan + badge (Activo en verde / Finalizado en gris)
  ├── Subtitle: "12 ene — 11 abr 2026 · 13 semanas"  (si activo: "Desde 12 abr · En curso")
  ├── Grid 3 columnas: cumplimiento %, sesiones totales, semanas
  └── LinearProgressIndicator con valor = compliancePercent / 100
        color: primary (activo) / secondary (finalizado)
```

**Orden:** plan activo primero (borde `colorScheme.primary`), luego anteriores por `periodStart DESC`.

---

## 7. UI — Plantilla en ConfigPage (exercise_config_page.dart)

### Botón "Partir de plan anterior"

Aparece en la parte superior del formulario de creación, antes de los días de rutina:

```dart
OutlinedButton.icon(
  icon: Icon(Icons.copy_outlined),
  label: Text('Partir de plan anterior'),
  onPressed: () => _showTemplatePicker(context),
)
```

Solo visible cuando `state.allPlans.isNotEmpty`.

### _showTemplatePicker bottom sheet

`showModalBottomSheet` con lista de `ExercisePlan` de `state.allPlans`:
- Cada item: ícono + nombre + "N días · X% cumplimiento" (si hay historial cargado)
- Plan activo destacado con color primary

### Comportamiento al seleccionar plantilla

1. Carga `ExerciseRoutine`s del plan seleccionado via `repository.getRoutinesForPlan(planId)`
2. Para cada rutina, carga sus `ExerciseRoutineItem`s
3. Pre-llena el estado local del formulario con esos días y ejercicios
4. El nombre del plan queda vacío (el usuario escribe el nuevo nombre)
5. Todo es editable: puede agregar/quitar días y ejercicios antes de guardar

**No se copian:** sesiones, logs, periodStart/periodEnd — solo la estructura de días y ejercicios.

---

## 8. Testing

### DAO tests — nuevo

- `getPlanHistory()` devuelve stats correctos para múltiples planes con sesiones en distintos períodos
- `setActiveExercisePlan()` setea `period_end` en el plan anteriormente activo

### Repository tests — nuevo

- `getPlanHistory()` delega al DAO y devuelve `List<PlanComplianceStat>`

### BLoC tests — nuevos

- `ExercisePlanHistoryLoaded` emite estado con `planHistory` poblado
- `ExercisePlanActivated` actualiza `planHistory` después de activar

### Widget tests — nuevos

- `exercise_page`: card "¿Qué harás hoy?" muestra chips de rutinas; tap chip cambia selección; tap "Iniciar" dispara `ExerciseSessionStarted`
- `exercise_progress_page`: tab Historial muestra cards con stats; dispatch de `ExercisePlanHistoryLoaded` al entrar
- `exercise_config_page`: botón plantilla aparece cuando hay planes; selección pre-llena el formulario

---

## 9. Archivos afectados

| Archivo | Acción |
|---|---|
| `lib/core/database/tables/exercise_tables.dart` | Modify: +`periodStart`, +`periodEnd` a `ExercisePlans` |
| `lib/core/database/app_database.dart` | Modify: bump schema version, agregar migration |
| `lib/core/dao/exercise_dao.dart` | Modify: `setActiveExercisePlan` + nuevo `getPlanHistory` |
| `lib/features/exercise/domain/models/plan_compliance_stat.dart` | Create: nuevo modelo |
| `lib/features/exercise/domain/repositories/exercise_repository.dart` | Modify: +`getPlanHistory` |
| `lib/features/exercise/data/repositories/exercise_repository_impl.dart` | Modify: implementar `getPlanHistory` |
| `lib/features/exercise/presentation/bloc/exercise_event.dart` | Modify: +`ExercisePlanHistoryLoaded` |
| `lib/features/exercise/presentation/bloc/exercise_state.dart` | Modify: +`planHistory` field |
| `lib/features/exercise/presentation/bloc/exercise_bloc.dart` | Modify: +handler, modificar `_onPlanActivated` |
| `lib/features/exercise/presentation/pages/exercise_page.dart` | Modify: card selección de día + mini-calendario |
| `lib/features/exercise/presentation/pages/exercise_progress_page.dart` | Modify: +tab Historial + `_HistorialTab` |
| `lib/features/exercise/presentation/pages/exercise_config_page.dart` | Modify: botón plantilla + bottom sheet |
| `test/dao/exercise_dao_test.dart` | Modify: nuevos tests DAO |
| `test/features/exercise/data/exercise_repository_test.dart` | Modify: +`getPlanHistory` test |
| `test/features/exercise/presentation/exercise_bloc_test.dart` | Modify: nuevos tests BLoC |
| `test/features/exercise/presentation/exercise_page_test.dart` | Create: tests selección de día |
| `test/features/exercise/presentation/exercise_progress_page_test.dart` | Modify: +test tab Historial |
