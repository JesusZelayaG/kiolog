# Spec: Fase C — Dashboard semanal de ejercicio

**Fecha:** 2026-06-09  
**Alcance:** Rediseño completo de `ExercisePage` como dashboard semanal con tres secciones: rutina, cardio, y ejercicio libre.  
**Dependencia:** Fases A y B completas.

---

## Contexto

Fases A y B construyeron el motor (schema, BLoC, sesión activa). Fase C construye la pantalla principal de ejercicio como un dashboard que muestra el progreso de la semana en tres secciones: rutina semanal, cardio, y ejercicio libre. El flujo de sesión activa (Fase B) se mantiene intacto.

---

## Arquitectura y datos

### Nuevos archivos

| Archivo | Responsabilidad |
|---------|----------------|
| `lib/features/exercise/domain/models/independent_exercise_log.dart` | Modelo compacto para ejercicios libres |

### Archivos modificados

| Archivo | Cambio |
|---------|--------|
| `lib/core/dao/exercise_dao.dart` | Nuevo método `getIndependentSessionsForWeek` |
| `lib/features/exercise/domain/repositories/exercise_repository.dart` | Nuevo método en interfaz |
| `lib/features/exercise/data/repositories/exercise_repository_impl.dart` | Implementación del nuevo método |
| `lib/features/exercise/presentation/bloc/exercise_state.dart` | 2 nuevos campos |
| `lib/features/exercise/presentation/bloc/exercise_bloc.dart` | Extender `_onLoaded`, `_onIndependentExerciseLogged/_Deleted` |
| `lib/features/exercise/presentation/pages/exercise_page.dart` | Reescritura completa del builder |

---

## Nuevo modelo: `IndependentExerciseLog`

Los ejercicios libres se almacenan como `ExerciseSessionLog` con `routineId = null`. Para mostrarlos en el dashboard se necesita el nombre del ejercicio (que vive en `ExerciseSetLog`), así que se usa un modelo compacto con join:

```dart
class IndependentExerciseLog extends Equatable {
  final int sessionId;
  final DateTime date;
  final String exerciseName;
  final int sets;
  final int reps;
  final double? weightKg;

  const IndependentExerciseLog({
    required this.sessionId,
    required this.date,
    required this.exerciseName,
    required this.sets,
    required this.reps,
    this.weightKg,
  });

  @override
  List<Object?> get props => [sessionId, date, exerciseName, sets, reps, weightKg];
}
```

---

## Nuevo método DAO: `getIndependentSessionsForWeek`

Query que obtiene sesiones con `routineId IS NULL` y `gymLeftAt IS NOT NULL` para la semana dada, haciendo join con el primer `ExerciseSetLog` de cada sesión para obtener nombre/sets/reps/peso.

```dart
Future<List<IndependentExerciseLog>> getIndependentSessionsForWeek(
  DateTime weekStart,
) async {
  final start = DateTime.utc(weekStart.year, weekStart.month, weekStart.day);
  final end = start.add(const Duration(days: 7));
  final sessions = await (select(exerciseSessionLogs)
        ..where((t) =>
            t.date.isBiggerOrEqualValue(start) &
            t.date.isSmallerThanValue(end) &
            t.routineId.isNull() &
            t.gymLeftAt.isNotNull()))
      .get();

  final result = <IndependentExerciseLog>[];
  for (final s in sessions) {
    final sets = await (select(exerciseSetLogs)
          ..where((t) => t.sessionId.equals(s.id))
          ..orderBy([(t) => OrderingTerm.asc(t.setNumber)]))
        .get();
    if (sets.isEmpty) continue;
    result.add(IndependentExerciseLog(
      sessionId: s.id,
      date: s.date,
      exerciseName: sets.first.exerciseName,
      sets: sets.length,
      reps: sets.first.reps,
      weightKg: sets.first.weightKg,
    ));
  }
  return result;
}
```

---

## Cambios al BLoC

### 2 nuevos campos en `ExerciseState`

```dart
final List<ExerciseSessionLog> completedRoutineSessionsThisWeek; // default: const []
final List<IndependentExerciseLog> weeklyIndependentLogs;        // default: const []
```

`completedRoutineSessionsThisWeek` es necesario porque `weeklyStats` solo provee conteos (no qué `routineId` específico se completó), y el dashboard necesita saber qué tarjetas pintar en verde.

Ambos campos se agregan a `copyWith` y `props`.

### `_onLoaded` — agregar 2 fetches paralelos

Al final del handler, junto con `getCardioLogsForWeek`, agregar:

```dart
final monday = _mondayOf(DateTime.now().toUtc());
final results = await Future.wait([
  _repository.getCardioLogsForWeek(monday),
  _repository.getCompletedRoutineSessionsForWeek(monday),
  _repository.getIndependentSessionsForWeek(monday),
  _repository.getWeeklyStats(weeksBack: 8),
]);
```

Reemplaza las llamadas secuenciales existentes por este `Future.wait`.

### `_onIndependentExerciseLogged` — recargar lista semanal

Después de `endSession`, recargar `weeklyIndependentLogs`:

```dart
final logs = await _repository.getIndependentSessionsForWeek(monday);
emit(state.copyWith(weeklyIndependentLogs: logs));
```

### `_onIndependentExerciseDeleted` — recargar lista semanal

Después de `deleteSession`, recargar `weeklyIndependentLogs`:

```dart
final logs = await _repository.getIndependentSessionsForWeek(monday);
emit(state.copyWith(weeklyIndependentLogs: logs));
```

---

## Pantalla `ExercisePage` — dashboard

### Estructura general

Scroll vertical. Tres secciones separadas por `SizedBox(height: 16)`. Botón "▶ Iniciar rutina del día" como `bottomNavigationBar` sticky.

```
AppBar: "Ejercicio" + acciones (historial ☰, config ⚙)
└── ListView
    ├── Plan header (nombre del plan)
    ├── Sección 1: Rutina semanal
    ├── Sección 2: Cardio semanal
    └── Sección 3: Ejercicio libre
bottomNavigationBar: Botón "▶ Iniciar rutina del día"
```

El `BlocConsumer` existente con su `listenWhen` para auto-navegación a `ExerciseSessionPage` se mantiene intacto.

---

### Sección 1: Rutina semanal

**Header:**
- Título "🏋️ Rutina semanal" + chip `X / N días` (verde si `X == N`, gris si no)
- `LinearProgressIndicator` con `value: completedThisWeek / routineDaysGoal`
- `completedThisWeek`: IDs únicos de `routineId` en `completedRoutineSessionsThisWeek`

**Tarjetas de días:**

Cada `ExerciseRoutine` del plan activo se renderiza como una tarjeta vertical. Las tarjetas se muestran ordenadas por `dayNumber`.

Estado de cada tarjeta:
- **Completado** (`routineId` aparece en `completedRoutineSessionsThisWeek`): fondo verde oscuro, borde izquierdo verde, avatar verde con ✓, subtítulo con día de la semana completado
- **Pendiente**: fondo neutro, borde izquierdo gris, avatar gris con número de día

Al tocar una tarjeta pendiente se expande (solo una a la vez — colapsa la anterior). La tarjeta expandida muestra:
- Lista de `ExerciseRoutineItem` del día con nombre + `sets × reps @ weightKg · setType`
- Iconos ✏ y 🗑 por ítem
- Botón `＋ Ejercicio` al fondo de la lista

Las tarjetas completadas también son expandibles para editar la rutina.

**Dialogs de rutina:**

`_showAddExerciseDialog(context, routineId)` y `_showEditExerciseDialog(context, item)` — `AlertDialog` con:
- Campo `Nombre` (TextField, requerido)
- Campos `Series` / `Reps` / `Peso (kg)` en fila (numéricos; peso opcional)
- Dropdown `Tipo de serie` (global para el ítem): Normal / Pirámide / Pirámide+Drop
  - Drop puro no aparece aquí — los sets drop se crean desde la sesión activa con "+Drop"
  - El tipo aplica a todas las series; variación por serie se ajusta en vivo durante la sesión
- **Si tipo ≠ Normal**: aparece sección "Detalle por serie" con tabla de N filas
  - Cada fila: `# | Reps | kg` — sin selector de tipo por fila (el schema no lo soporta en `ExerciseRoutineSetDefs`)
  - Al cambiar `Series`, la tabla agrega/quita filas al final preservando las existentes
- Botones Cancelar / Guardar

**Al guardar un ejercicio nuevo:**
- Dispara `ExerciseRoutineItemAdded` con nombre, sets, reps, weightKg, setType, routineId
- Si hay detalle por serie: dispara `ExerciseRoutineSetDefsUpdated` con la lista de setDefs por ítem

**Al editar:**
- Dispara `ExerciseRoutineItemUpdated` + (si cambió el detalle) `ExerciseRoutineSetDefsUpdated`

**Al borrar:**
- `showDialog` de confirmación → `ExerciseRoutineItemDeleted`

---

### Sección 2: Cardio semanal

**Header:**
- Título "🏃 Cardio semanal" + chip `X / N días`
- `LinearProgressIndicator` con `value: weeklyCardioLogs.length / cardioDaysGoal`

**Lista:**
- Cada `CardioLog` de `weeklyCardioLogs` como `ListTile` con:
  - Leading: ícono por tipo (Correr=🏃, Bici=🚴, Elíptica=⬡, Nadar=🏊, Otro=💧)
  - Title: tipo de cardio
  - Subtitle: `${durationMinutes} min · ${díaDeLaSemana}`
  - Trailing: iconos ✏ 🗑

**Botón "＋ Registrar cardio"** — borde punteado, abre `_showCardioDialog`.

**Dialog de cardio** (`_showCardioDialog`):
- Dropdown `Tipo`: Correr / Bici / Elíptica / Nadar / Otro
- Campo `Duración (min)` (numérico, requerido)
- Cancelar / Guardar → `CardioLogged` o `CardioUpdated`

---

### Sección 3: Ejercicio libre

**Header:** "💪 Ejercicio libre" + subtítulo "esta semana"

**Lista:**
- Cada `IndependentExerciseLog` de `weeklyIndependentLogs` como `ListTile` con:
  - Title: `exerciseName`
  - Subtitle: `${sets} × ${reps}${weightKg != null ? ' @ ${weightKg}kg' : ''} · ${díaDeLaSemana}`
  - Trailing: ícono 🗑 (solo delete; no se edita un ejercicio libre, se borra y se recrea)

**Botón "＋ Registrar ejercicio libre"** — borde punteado, abre `_showIndependentExerciseDialog`.

**Dialog de ejercicio libre** (`_showIndependentExerciseDialog`):
- Campo `Nombre` (requerido)
- Campos `Series` / `Reps` / `Peso (kg)` en fila (peso opcional)
- Sin tipo de serie — siempre Normal
- Cancelar / Guardar → `IndependentExerciseLogged`

---

### Bottom bar — "▶ Iniciar rutina del día"

Renderizado como `bottomNavigationBar` del `Scaffold` para mantenerse sticky.

**Lógica de auto-selección:**
1. Obtener los `routineId` completados esta semana desde `completedRoutineSessionsThisWeek`
2. De `routines` (ordenadas por `dayNumber`), seleccionar el primero cuyo `id` no está en los completados
3. Si todos están completados: seleccionar el primero del plan (resetear)
4. Si no hay rutinas: deshabilitar el botón con texto "Sin días de rutina configurados"

Al tocar: dispara `ExerciseSessionStarted(date: DateTime.now(), routineId: routineId)`.  
La navegación a `ExerciseSessionPage` ya la maneja el `BlocConsumer.listenWhen` existente.

---

## Eventos reutilizados (sin cambios)

| Evento | Uso en Fase C |
|--------|--------------|
| `ExerciseRoutineItemAdded` | Dialog agregar ejercicio |
| `ExerciseRoutineItemUpdated` | Dialog editar ejercicio |
| `ExerciseRoutineItemDeleted` | Confirmación borrar ejercicio |
| `CardioLogged` | Dialog registrar cardio |
| `CardioUpdated` | Dialog editar cardio |
| `CardioDeleted` | Icono 🗑 en lista cardio |
| `IndependentExerciseLogged` | Dialog ejercicio libre |
| `IndependentExerciseDeleted` | Icono 🗑 en lista ejercicio libre |
| `ExerciseSessionStarted` | Botón "▶ Iniciar rutina del día" |

---

## Evento nuevo: `ExerciseRoutineSetDefsUpdated`

Necesario para guardar el detalle por serie desde el dialog de rutina:

```dart
class ExerciseRoutineSetDefsUpdated extends ExerciseEvent {
  final int routineItemId;
  final List<({int setNumber, int? dropOfSetNumber, int reps, double? weightKg})> setDefs;

  const ExerciseRoutineSetDefsUpdated({
    required this.routineItemId,
    required this.setDefs,
  });

  @override
  List<Object?> get props => [routineItemId, setDefs];
}
```

El handler llama `_repository.replaceRoutineSetDefs(routineItemId: ..., defs: setDefs)` — firma que ya existe en el repositorio desde Fase A. `dropOfSetNumber` siempre es `null` desde este dialog (los drops se crean en sesión).

---

## Fuera de alcance (esta fase)

- Configuración de metas (routineDaysGoal, cardioDaysGoal, cardioMinutesGoal) — ya existe `ExerciseConfigUpdated`, se puede exponer en un settings dialog separado
- Reordenamiento de días de rutina o ejercicios dentro de un día
- Gráficas de progreso (Fase D)
- Historial de sesiones pasadas más allá de la semana actual
