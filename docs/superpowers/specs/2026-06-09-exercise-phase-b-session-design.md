# Spec: Fase B — Sesión activa de ejercicio

**Fecha:** 2026-06-09  
**Alcance:** Pantalla `ExerciseSessionPage` — flujo completo de sesión activa: inicio, progreso por ejercicio, log de series, finalización y reanudación.  
**Dependencia:** Fase A completa (schema v4, DAO, repository, BLoC base).

---

## Contexto

Fase A construyó los cimientos: schema, DAO con todos los métodos de sesión, repository e interfaces BLoC. Fase B construye la UI de sesión activa que los consume.

El usuario inicia una sesión desde el dashboard (Fase C), completa ejercicios uno a uno, y finaliza. Si sale a mitad de sesión, puede reanudarla desde el dashboard.

---

## Comportamiento de sesión

### Ciclo de vida

| Estado | Condición en DB |
|--------|----------------|
| Sin sesión | No existe `ExerciseSessionLog` para la semana actual sin `gymLeftAt` |
| En progreso | Existe `ExerciseSessionLog` con `gymLeftAt == null` |
| Completada | `gymLeftAt != null` |

### Inicio
- El usuario toca **"▶ Iniciar rutina del día"** en el dashboard.
- Se selecciona automáticamente el primer día de rutina sin sesión completada en la semana en curso.
- Se crea un `ExerciseSessionLog` con `gymEnteredAt = now()` y `gymLeftAt = null`.
- Se hace push de `ExerciseSessionPage`.

### Navegación back (salida sin finalizar)
- Al hacer pop (botón back del sistema o del AppBar), la sesión queda en DB con `gymLeftAt == null`.
- No hay dialog de confirmación — la salida es silenciosa.
- El dashboard detecta la sesión en progreso y muestra el banner de reanudación.

### Reanudación
- Banner en el dashboard: **"Sesión en curso — Reanudar ▶"**.
- Tap en el banner hace push de `ExerciseSessionPage` con la sesión existente.
- Los ítems ya marcados como listos se restauran desde `completedRoutineItemIds`.

### Finalización
- Botón **"Finalizar sesión"** (siempre visible en el bottom de la pantalla).
- Escribe `gymLeftAt = now()` en `ExerciseSessionLog`.
- Hace pop de la pantalla.
- El banner de reanudación desaparece en el dashboard.

---

## Pantalla `ExerciseSessionPage`

### Header
```
┌─────────────────────────────────────────┐
│ ← Sesión activa                         │
│ Día 3: Piernas   •   Iniciada a las 07:15│
│ ████████░░░░░░░░  2 / 4 ejercicios      │
└─────────────────────────────────────────┘
```
- Título: nombre del día de rutina (`ExerciseRoutineDay.dayName`).
- Subtítulo: hora de inicio formateada.
- Barra de progreso: `completedRoutineItemIds.length / totalItems`.

### Lista de ejercicios
Cada ítem muestra:
- **⬜ Pendiente** — fondo neutro, nombre del ejercicio.
- **🔄 Activo** — fondo resaltado, expandido con el panel de series.
- **✅ Listo** — fondo verde claro, nombre tachado, no expandible.

Solo un ítem puede estar expandido a la vez. Tap en un ítem pendiente colapsa el actual y expande el nuevo.

### Panel expandido por ejercicio

```
┌── Prensa ──────────────────────────────────┐
│ Última sesión (hace 5 días):               │
│   Serie 1: 12 reps @ 75 kg                │
│   Serie 2: 10 reps @ 85 kg               │
├────────────────────────────────────────────┤
│ #  │ Tipo    │ Reps │ Peso kg │            │
│ 1  │ Normal▼ │ [12] │ [75]   │ ✓ guardado │
│ 2  │ Normal▼ │ [10] │ [85]   │ ✓ guardado │
│ 3  │ Drop▼   │ [  ] │ [  ]   │ [Guardar]  │
├────────────────────────────────────────────┤
│ [+ Serie]  [+ Drop]  [🏁 Ejercicio listo]  │
└────────────────────────────────────────────┘
```

**Referencia histórica:**
- Query: `getLastSessionSetsForExercise(exerciseName)` — busca la sesión más reciente que contenga sets con ese nombre.
- Muestra fecha relativa ("hace N días") y la lista de series registradas.
- Si no hay historial, muestra "Primera vez".

**Pre-llenado de series:**
- Si existen `ExerciseRoutineSetDefs` para el ítem → se generan filas con `reps` y `weightKg` de referencia.
- Si no existen → se genera una fila vacía por cada `sets` del ítem.
- Las filas drop (donde `dropOfSet != null`) se renderizan indentadas bajo su serie padre.

**Guardado de series:**
- Cada fila tiene un botón "Guardar" individual.
- Al tocar "Guardar", la fila persiste en `ExerciseSetLogs` inmediatamente (no al finalizar sesión).
- La fila cambia a estado "✓ guardado" y se vuelve readonly.

**Controles:**
- **"+ Serie"**: agrega fila nueva vacía al final (tipo Normal por defecto).
- **"+ Drop"**: agrega fila marcada como drop de la última serie guardada.
- **"🏁 Ejercicio listo"**: agrega el ítem a `completedRoutineItemIds`, colapsa el panel, actualiza la barra de progreso.

### Bottom bar
```
┌─────────────────────────────────────────┐
│           [ Finalizar sesión ]          │
└─────────────────────────────────────────┘
```
- Siempre visible, no se oculta al hacer scroll.
- Al tocar: escribe `gymLeftAt`, hace pop.

---

## Cambios al BLoC

### Nuevo evento

```dart
class ExerciseSessionResumed extends ExerciseEvent {
  // Carga la sesión activa (gymLeftAt == null) y sus ítems completados
}
```

### Nuevo campo en `ExerciseState`

```dart
ExerciseSessionLog? activeSession;
```

- `null` → no hay sesión en progreso.
- Non-null → sesión en curso; el dashboard muestra el banner.

### Handlers afectados

| Evento | Cambio |
|--------|--------|
| `ExerciseSessionStarted` | Crea `ExerciseSessionLog`, popula `activeSession` |
| `ExerciseSessionResumed` | Carga sesión existente desde DB, restaura `completedRoutineItemIds` |
| `ExerciseSessionFinished` | Escribe `gymLeftAt`, limpia `activeSession` y `completedRoutineItemIds` |
| `ExerciseItemCompleted` | Ya existe — agrega id a `completedRoutineItemIds` |
| `ExerciseSetLogged` | Ya existe — persiste fila en `ExerciseSetLogs` |

---

## Datos necesarios en `ExerciseSessionPage`

La pantalla recibe como argumento el `sessionId`. Al montarse:
1. Carga los `ExerciseRoutineItems` del día de la sesión (ordenados por `orderIndex`).
2. Carga los `ExerciseRoutineSetDefs` por ítem.
3. Carga el historial de última sesión por nombre de ejercicio.
4. Lee `completedRoutineItemIds` del estado BLoC.

Todos estos datos se cargan vía `ExerciseSessionResumed` al montar la pantalla, sin importar si la sesión es nueva o reanudada. `ExerciseSessionStarted` solo crea el registro en DB y es disparado desde el dashboard antes del push.

---

## Navegación

```
ExercisePage (dashboard)
  └─ push → ExerciseSessionPage(sessionId)
               └─ pop → ExercisePage (con estado actualizado)
```

La ruta se registra en `go_router` como sub-ruta de `/exercise`. La sesión activa se pasa como parámetro extra (no en la URL) para evitar estado stale en deep links.

---

## Fuera de alcance (esta fase)

- Timer de descanso entre series.
- Reordenamiento de ejercicios durante la sesión.
- Historial completo de sesiones pasadas.
- Dashboard semanal y banner de reanudación (Fase C los implementa, Fase B solo expone `activeSession` en el estado).
