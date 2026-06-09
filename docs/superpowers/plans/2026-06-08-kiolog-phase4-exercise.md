# Kiolog — Phase 4: Exercise Module

**Fecha:** 2026-06-08 (última actualización)
**Goal:** Implementar el módulo de Ejercicio con planes, rutinas por día numerado (NO fijas por semana), sesiones de gym y registro de series.

---

## Resumen de Cambios

### Cambios Importantes en el Modelo (v3)

- `exercise_routines.day_of_week` → `exercise_routines.day_number` (Día 1, Día 2...)
- `exercise_session_logs` ahora tiene `routine_id` (nullable) para vincular la sesión al día de rutina entrenado
- El usuario **elige** qué día de rutina entrena al ir al gimnasio, independientemente del calendario

### Estructura de Carpetas

```
lib/features/exercise/
├── domain/repositories/exercise_repository.dart
├── data/repositories/exercise_repository_impl.dart
├── presentation/bloc/
│   ├── exercise_bloc.dart
│   ├── exercise_event.dart
│   └── exercise_state.dart
└── presentation/pages/exercise_page.dart
```

### Archivos Modificados

- `lib/core/database/tables/exercise_tables.dart` — schema cambiado: `dayOfWeek` → `dayNumber`, `routineId` en sesiones
- `lib/core/database/app_database.dart` — schemaVersion 3, migración recrea tablas de ejercicio
- `lib/core/dao/exercise_dao.dart` — `getRoutinesForPlan`/`getRoutine` reemplazan `getRoutineForDay`
- `lib/core/di/injection.dart` — registro de `ExerciseRepository`
- `lib/features/onboarding/presentation/pages/onboarding_page.dart` — onboarding usa días numerados

### Tests Nuevos/Actualizados

- `test/features/exercise/data/exercise_repository_test.dart`
- `test/features/exercise/presentation/exercise_bloc_test.dart`
- `test/dao/exercise_dao_test.dart`

---

## Funcionalidad

### Planes
- Detecta si existe un plan activo; si no, muestra CTA para crear uno
- Diálogo de gestión de planes: crear, activar, ver lista

### Rutinas (Días de Rutina Numerados)
- Muestra **todos los días de rutina** del plan activo como tarjetas
- Cada tarjeta muestra: número de día, nombre de la rutina (ej: "Pecho y tríceps"), lista de ejercicios
- Botón **"Entrené este día"** para iniciar una sesión vinculada a esa rutina
- Botón **"+ Día"** para agregar nuevos días de rutina al plan activo

### Sesiones de Gym — Flujo Flexible
1. Usuario ve la lista de días de rutina
2. Toca "Entrené este día" en el día que va a hacer
3. Se crea `ExerciseSessionLog` con `routine_id` vinculado
4. Durante la sesión activa:
   - Se muestran los ejercicios de la rutina como guía
   - Botón "Registrar serie": ejercicio, reps, peso
   - Se van acumulando las series
5. Botón "Finalizar sesión": registra `gymLeftAt`

### Sesiones Recientes
- Lista de últimas sesiones con: nombre del día de rutina, hora de inicio, duración

**BLoC Events:**
- `ExerciseLoaded(date)` — carga plan, todas las rutinas con sus items, sesiones y log diario
- `ExercisePlanLoaded()` — carga todos los planes
- `ExercisePlanActivated(planId)` — cambia plan activo
- `ExercisePlanCreated(name)` — crea nuevo plan
- `ExerciseRoutineAdded(planId, dayNumber, routineName)` — agrega día de rutina
- `ExerciseRoutineMarkedDone(date, routineId)` — marca rutina como hecha
- `ExerciseSessionStarted(date, routineId)` — inicia sesión vinculada a un día de rutina
- `ExerciseSessionEnded(sessionId)` — finaliza sesión
- `ExerciseSetLogged(...)` — registra una serie

**BLoC State:**
- `activePlan`, `allPlans`
- `routines` — lista de días de rutina del plan activo
- `routineItemsByRoutine` — `Map<int, List<ExerciseRoutineItem>>`
- `dailyLog`, `activeSession`, `sessionSets`, `recentSessions`
- Helper: `hasActiveSession`, `activeRoutineItems`, `routineById(id)`

---

## Verificación

- [x] `flutter test` → 64 tests pasan
- [x] `flutter build apk --debug` → compila sin errores
- [x] Home → Ejercicio navega a página funcional
- [x] Sin plan activo muestra CTA para crear plan
- [x] Con plan: muestra tarjetas de días de rutina con ejercicios
- [x] "Entrené este día" inicia sesión vinculada a la rutina correcta
- [x] Durante sesión activa: se ven ejercicios de la rutina y se registran series
- [x] Finalizar sesión funciona
- [x] Sesiones recientes muestran nombre de rutina y duración
- [x] Onboarding crea días de rutina numerados correctamente
