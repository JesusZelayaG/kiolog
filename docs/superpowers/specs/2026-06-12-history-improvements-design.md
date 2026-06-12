# History Feature Improvements — Design Spec
**Fecha:** 2026-06-12  
**Estado:** Aprobado

---

## Alcance

Tres mejoras a `lib/features/history`:

1. **Textos en blanco** — los colores de texto heredan correctamente del tema oscuro.
2. **Resumen de cumplimiento por segmento** — reemplaza el área inferior con barras de progreso individuales por segmento.
3. **Pantalla de detalle de día** — al tocar una celda del calendario se navega a una pantalla con el detalle de agua, nutrición y ejercicio de ese día. Sueño excluido de esta vista.

---

## 1. Corrección de colores de texto

El problema actual es que varios `Text` en `_DayCell` y `_LegendDot` no especifican color o usan un color gris fijo, ignorando el tema. La corrección es eliminar esos overrides y dejar que el `TextStyle` herede de `theme.textTheme`, que en el tema oscuro usa `#DAE2FD` (blanco azulado).

Cambios concretos:
- `_DayCell`: el número de día usa `theme.textTheme.bodySmall` sin override de color.
- `_LegendDot`: el label usa `theme.textTheme.bodySmall` sin override de color.
- Eliminar la leyenda de "Sueño" (excluido del scope de esta vista).

---

## 2. Resumen de cumplimiento por segmento

**Reemplaza** la leyenda inferior actual por un card con tres filas, una por segmento activo (agua, comida, ejercicio).

### Estructura visual

```
┌─────────────────────────────────────────┐
│  Cumplimiento del mes                   │
│  💧 Agua    [████████░░] 83%            │
│  🍽️ Comida  [███████░░░] 75%            │
│  🏋️ Ejercicio [█████░░░░░] 58%          │
└─────────────────────────────────────────┘
```

Cada fila contiene:
- Icono con fondo de color del segmento (azul/naranja/rojo)
- Label del segmento (12px, bold, blanco)
- Barra de progreso con gradiente del color del segmento
- Porcentaje a la derecha (10px, bold, color del segmento)

### Cálculo del porcentaje

Para cada segmento, se calcula sobre los días transcurridos del mes (no el total de días):

```
días_transcurridos = días del mes desde el 1 hasta hoy (inclusive), máx = total_días_del_mes
% agua      = días_con_agua      / días_transcurridos * 100
% comida    = días_con_comida    / días_transcurridos * 100
% ejercicio = días_con_ejercicio / días_transcurridos * 100
```

Para meses pasados, `días_transcurridos = total_días_del_mes`.

### Modelo de datos

`DaySummary` ya expone `hasWater`, `hasMeals`, `hasExercise`. El cálculo se hace en `HistoryState` o en un getter del mismo, sin tocar la capa de datos.

Se agrega un getter `MonthCompliance` (o directo en el estado) con tres valores `double` (0.0–1.0):

```dart
class MonthCompliance {
  final double water;
  final double meals;
  final double exercise;
}
```

Calculado en el bloc al momento de emitir el nuevo estado después de cargar el mes.

---

## 3. Pantalla de detalle de día

### Navegación

Tap en `_DayCell` → `GoRouter` navega a `/history/day/:date` (formato `yyyy-MM-dd`).  
La pantalla tiene botón de regreso a `/history`.

### Datos que se cargan

La pantalla hace sus propias queries directamente a los DAOs existentes para esa fecha:

| Segmento | DAO / método | Datos mostrados |
|----------|-------------|-----------------|
| Agua | `WaterSleepDao.getDailyWaterLogs(date)` | Total ml + lista de tomas con hora y ml |
| Nutrición | `NutritionDao.getDailyMealLogs(date)` | Una fila por tipo de comida (desayuno, almuerzo, cena, snack) con el número de opción |
| Ejercicio | `ExerciseDao.getSessionsForDate(date)` + `getDailyExerciseLog(date)` | Sesiones con hora de llegada/salida; si hay `DailyExerciseLog.completed = true` sin sesión, se muestra "Completado sin sesión registrada" |

Sueño: **excluido** de esta pantalla.

### Estructura de la pantalla

```
AppBar: "martes 11 jun 2026" + back button
Body (scrollable):
  SubHeader: "X de 3 segmentos completos"
  SegmentCard(agua)
    header: 💧 Agua | chip "Cumplido" / "Sin registro"
    ── divider ──
    Total: 2,400 ml  ·  4 tomas
    Chips: [08:00 · 600ml] [12:30 · 500ml] …
  SegmentCard(nutrición)
    header: 🍽️ Nutrición | chip
    ── divider ──
    Desayuno: Opción 2
    Almuerzo: Opción 1
    Cena:     Opción 3
    Snack:    Opción 1
  SegmentCard(ejercicio)
    header: 🏋️ Ejercicio | chip
    ── divider ──
    [si hay sesiones]
      Sesión 1: 07:00 – 08:15
    [si no hay]
      "No hay sesiones registradas este día"
```

### BLoC / estado

Nueva clase `DayDetailBloc` con evento `DayDetailLoaded(DateTime date)` y estado con:

```dart
class DayDetailState {
  final DayDetailStatus status;
  final DateTime date;
  final List<DailyWaterLog> waterLogs;
  final List<DailyMealLog> mealLogs;
  final List<ExerciseSessionLog> exerciseSessions;
  final DailyExerciseLog? exerciseLog;
}
```

El BLoC recibe los tres DAOs por DI (`getIt`).

### Página

`DayDetailPage` — `StatelessWidget`, recibe la fecha como parámetro de ruta, provee el BLoC y renderiza `_DayDetailView`.

---

## Archivos nuevos / modificados

| Archivo | Acción |
|---------|--------|
| `lib/features/history/presentation/pages/history_page.dart` | Modificar: colores, cumplimiento por segmento, onTap en celda |
| `lib/features/history/domain/repositories/history_repository.dart` | Modificar: agregar `MonthCompliance` al estado (o getter) |
| `lib/features/history/presentation/bloc/history_state.dart` | Modificar: agregar campo `compliance` |
| `lib/features/history/presentation/bloc/history_bloc.dart` | Modificar: calcular compliance al cargar mes |
| `lib/features/history/presentation/pages/day_detail_page.dart` | Nuevo |
| `lib/features/history/presentation/bloc/day_detail_bloc.dart` | Nuevo |
| `lib/features/history/presentation/bloc/day_detail_event.dart` | Nuevo |
| `lib/features/history/presentation/bloc/day_detail_state.dart` | Nuevo |
| `lib/core/router/app_router.dart` | Modificar: agregar ruta `/history/day/:date` |

---

## Fuera de alcance

- Sueño en la pantalla de detalle (excluido explícitamente).
- Edición de registros desde la pantalla de detalle (solo lectura).
- Navegación entre días desde el detalle (se regresa al calendario).
