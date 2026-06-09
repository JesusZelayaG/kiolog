# Spec: Rutinas, Sesiones y Progreso de Ejercicio

**Fecha:** 2026-06-08  
**Alcance:** Rediseño del módulo de ejercicio — configuración de rutinas con tipos de serie, sesión activa con check por ejercicio, cardio independiente y dashboard de progreso semanal/mensual.

---

## Contexto

El módulo de ejercicio actual permite crear planes y días de rutina, iniciar sesiones y registrar series manualmente. Sin embargo carece de:
- UI para agregar ejercicios a cada día de rutina
- Soporte para series piramidales, drop sets y combinaciones
- Check de ejercicios durante la sesión (solo log libre de series)
- Referencia histórica en sesión (cuánto levantaste la última vez)
- Registro de cardio independiente con meta semanal
- Dashboard de progreso semanal/mensual

El usuario recibe rutinas pre-definidas por un entrenador y necesita poder ingresarlas con todo el detalle. El diseño debe ser flexible: soportar tanto el ingreso detallado (serie por serie) como el ingreso básico (solo tipo y conteo).

---

## Cambios al esquema de base de datos

### 1. `ExerciseRoutineItems` — agregar columnas

```dart
TextColumn get setType => text().withDefault(const Constant('normal'))();
// valores: normal | pyramid | drop | pyramid_drop
IntColumn get orderIndex => integer().withDefault(const Constant(0))();
```

### 2. Nueva tabla `ExerciseRoutineSetDefs`

Definiciones opcionales por serie dentro de un ítem de rutina. Si existen, pre-llenan la sesión. Si no, se generan filas vacías según el conteo del ítem.

```dart
class ExerciseRoutineSetDefs extends Table {
  IntColumn get id => integer().autoIncrement()();
  IntColumn get routineItemId => integer().references(ExerciseRoutineItems, #id)();
  IntColumn get setNumber => integer()();
  // null = serie normal; non-null = drop de la serie indicada
  IntColumn get dropOfSet => integer().nullable()();
  IntColumn get reps => integer()();
  RealColumn get weightKg => real().nullable()();
}
```

### 3. `ExerciseSetLogs` — agregar columnas

```dart
TextColumn get setType => text().withDefault(const Constant('normal'))();
// valores: normal | pyramid | drop
IntColumn get dropOfSetId => integer().nullable()
    .references(ExerciseSetLogs, #id)();
```

### 4. Nueva tabla `CardioLogs`

```dart
class CardioLogs extends Table {
  IntColumn get id => integer().autoIncrement()();
  DateTimeColumn get date => dateTime()();
  // treadmill | elliptical | bike | other
  TextColumn get cardioType => text()();
  IntColumn get durationMinutes => integer()();
  TextColumn get notes => text().nullable()();
}
```

### 5. Nueva tabla `ExerciseConfig`

```dart
class ExerciseConfig extends Table {
  IntColumn get id => integer().autoIncrement()();
  IntColumn get weeklyRoutineDaysGoal => integer().withDefault(const Constant(4))();
  IntColumn get weeklyCardioDaysGoal => integer().withDefault(const Constant(3))();
  IntColumn get cardioMinutesGoal => integer().withDefault(const Constant(30))();
}
```

**Migración:** schema version 4. Crear las dos tablas nuevas y agregar columnas con `addColumn`.

---

## Pantalla principal — Dashboard semanal

### Secciones

**1. Rutina del plan activo**
- Header: nombre del plan + progreso `X / N días`
- Barra de progreso
- Grid de tarjetas por día:
  - Completado: fondo verde, nombre del día, fecha y duración
  - Pendiente: fondo gris, nombre del día
- Botón **"▶ Iniciar rutina del día"** → selecciona el primer día de rutina (por `dayNumber`) que no tenga `ExerciseSessionLog` con `gymLeftAt != null` en la semana en curso (lunes–domingo). Si todos están completos, permite elegir cualquier día.

**2. Cardio semanal**
- Header: `X / N días` (meta de `ExerciseConfig.weeklyCardioDaysGoal`)
- Barra de progreso
- Lista de sesiones registradas: tipo + duración, icono de edición
- Botón **"+ Registrar cardio"** → dialog de registro

**3. Ejercicio independiente**
- Lista de ejercicios libres del día/semana
- Editables (editar o eliminar)
- Botón **"+ Agregar"**

**4. Gráficas de progreso** (toggle Semana / Mes)
- Barras de días de rutina completados por semana vs. meta
- Barras de días de cardio completados por semana vs. meta
- 3 stats: % cumplimiento rutina, % cumplimiento cardio, total sesiones del mes
- Vista Mes: agrupa semanas del mes, muestra tendencia mensual

---

## Configuración de rutina (inline)

Al tocar el botón de edición en una tarjeta de día, la tarjeta se expande mostrando la lista de ejercicios configurados y un formulario inline al final.

### Formulario de ejercicio

```
[Nombre del ejercicio         ]
[Series] [Reps] [Peso ref. kg]  Tipo: [Normal▼]
                                       Normal
                                       Pirámide
                                       Drop
                                       Pirámide+Drop
[ + Definir series ] (expandible)
[ Guardar ]
```

**Sección expandible "Definir series":** muestra tabla con filas editables:
- Nº de serie, reps, peso kg
- Para drops: botón **"+ Drop"** agrega una fila marcada como `dropOfSet = setNumber`
- Si no se expande, al guardar no se crean `ExerciseRoutineSetDefs`

**Restricción:** el tipo `normal` no permite drops; `pyramid` permite peso distinto por serie; `drop` y `pyramid_drop` permiten filas drop.

### Edición de ejercicio existente
Tap en un ejercicio de la lista → abre el mismo formulario pre-llenado. Botón de eliminar.

---

## Sesión activa

### Inicio de sesión
El usuario toca **"Iniciar rutina del día"** o elige un día desde la pantalla principal. Se crea un `ExerciseSessionLog` con la fecha y `routineId` del día elegido.

### Vista de sesión

```
┌─────────────────────────────────┐
│ Sesión activa — Día 3: Piernas  │
│ Iniciada a las 07:15            │
│ ████████░░░░░░░ 2/4 ejercicios  │
├─────────────────────────────────┤
│ ✅ Sentadilla           (listo) │
│ 🔄 Prensa               (activo)│ ← expandido
│ ⬜ Extensión cuádriceps         │
│ ⬜ Curl femoral                 │
├─────────────────────────────────┤
│           [ Finalizar sesión ]  │
└─────────────────────────────────┘
```

### Panel expandido de ejercicio

Al tocar un ejercicio pendiente se expande (solo uno abierto a la vez):

```
┌── Prensa ─────────────────────────────────────┐
│ Última sesión (hace 5 días):                  │
│   Serie 1: 12 reps @ 75kg                     │
│   Serie 2: 10 reps @ 85kg  ← referencia       │
├────────────────────────────────────────────────┤
│ #  │ Tipo    │ Reps │ Peso kg │               │
│ 1  │ Normal▼ │ [12] │ [75]    │ ✓ guardado    │
│ 2  │ Normal▼ │ [10] │ [85]    │ ✓ guardado    │
│ 3  │ Drop▼   │ [  ] │ [  ]    │ [ Guardar ]   │
├────────────────────────────────────────────────┤
│  [ + Serie ]  [ + Drop ]  [ 🏁 Ejercicio listo ]│
└────────────────────────────────────────────────┘
```

- **Referencia histórica:** query a `ExerciseSetLogs` buscando la última sesión que contenga el mismo `exerciseName`
- **Pre-llenado:** si existen `ExerciseRoutineSetDefs` para este ítem, se generan las filas con los valores de referencia. Si no, se genera una fila vacía por cada serie del ítem.
- **Tipo de serie:** selector por fila — Normal / Pirámide / Drop
- **"+ Drop"**: agrega fila con `dropOfSetId = id` de la fila activa
- **"Ejercicio listo"**: marca el ítem como completo en la sesión (actualiza el conteo de progreso)
- **Guardar serie**: persiste cada fila en `ExerciseSetLogs` inmediatamente al tocarla (no al finalizar)

### Finalizar sesión
Botón **"Finalizar sesión"** → registra `gymLeftAt`. La sesión queda en el historial y sus sets sirven de referencia para la próxima sesión del mismo ejercicio.

---

## Registro de cardio

Dialog simple al tocar **"+ Registrar cardio"**:

```
Tipo:     [ Caminadora ▼ ]   (Caminadora | Elíptica | Bicicleta | Otro)
Duración: [ 32 ] min
Notas:    [ opcional        ]
[ Cancelar ]  [ Guardar ]
```

Persiste en `CardioLogs`. Desde la lista en el dashboard, tap en ✏️ abre el mismo dialog pre-llenado para editar.

---

## Ejercicio independiente

Dialog al tocar **"+ Agregar"**:

```
Ejercicio: [                  ]
Series:    [ 3 ]  Reps: [ 15 ]  Peso: [ -- ] kg
[ Cancelar ]  [ Guardar ]
```

Se persiste como `ExerciseSessionLog` sin `routineId` + sus `ExerciseSetLogs`. Es editable y eliminable desde el dashboard.

---

## Cambios al BLoC

### Nuevos eventos
- `ExerciseRoutineItemAdded` — agrega ejercicio a un día con tipo y set defs opcionales
- `ExerciseRoutineItemUpdated` — edita ejercicio existente
- `ExerciseRoutineItemDeleted`
- `ExerciseItemCompleted` — marca ejercicio como listo en sesión activa
- `CardioLogged` — registra sesión de cardio
- `CardioUpdated` — edita sesión de cardio
- `CardioDeleted`
- `IndependentExerciseLogged`
- `IndependentExerciseDeleted`
- `ExerciseWeekLoaded` — carga progreso semanal completo (rutina + cardio + independientes)

### Nuevos campos en `ExerciseState`
- `completedRoutineItemIds: Set<int>` — IDs de ítems completados en la sesión activa
- `weeklyCardioLogs: List<CardioLog>`
- `cardioGoal: int` — días de cardio por semana
- `routineGoal: int` — días de rutina por semana
- `weeklyProgress: WeeklyExerciseProgress` — datos para las gráficas (nuevo modelo: lista de `WeeklyStat{weekStart, routineDaysDone, cardioDaysDone}`)

---

## Cambios al DAO (`ExerciseDao`)

Nuevos métodos:
- `addRoutineItem(...)` / `updateRoutineItem(...)` / `deleteRoutineItem(...)`
- `getRoutineSetDefs(routineItemId)` / `upsertRoutineSetDefs(...)`
- `getLastSessionSetsForExercise(exerciseName)` → referencia histórica
- `logCardio(...)` / `updateCardio(...)` / `deleteCardio(...)`
- `getCardioLogsForWeek(weekStart)` → para progreso semanal
- `logIndependentExercise(...)` / `deleteIndependentExercise(...)`
- `getWeeklyRoutineProgress(weekStart)` → días completados vs. meta
- `getExerciseConfig()` / `upsertExerciseConfig(...)`

---

## Onboarding

El onboarding existente (paso de ejercicio) ya permite crear plan y días de rutina. Se extiende para que, al crear un día, aparezca el mismo formulario inline descrito arriba para agregar ejercicios al vuelo.

---

## Fuera de alcance (este spec)

- Rediseño del módulo de Sueño (calendario + meta de horas) — spec separado
- Timer de descanso entre series
- Reordenamiento drag-and-drop de ejercicios
- Historial de sesiones pasadas (pantalla dedicada)
