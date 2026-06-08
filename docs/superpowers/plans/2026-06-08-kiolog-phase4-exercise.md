# Kiolog — Phase 4: Exercise Module

**Fecha:** 2026-06-08
**Goal:** Implementar el módulo de Ejercicio con planes, rutinas diarias, sesiones de gym y registro de series.

---

## Resumen de Cambios

### Estructura de Carpetas Nuevas

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

- `lib/core/di/injection.dart` — registro de `ExerciseRepository` e import de `ExerciseDao`
- `lib/core/dao/exercise_dao.dart` — método `getSessionsForDate` agregado
- `lib/core/dao/exercise_dao.g.dart` — regenerado por drift_dev

### Tests Nuevos

- `test/features/exercise/data/exercise_repository_test.dart`
- `test/features/exercise/presentation/exercise_bloc_test.dart`

---

## Funcionalidad

**Ejercicio:**
- Detecta si existe un plan activo; si no, muestra CTA para crear uno
- Muestra la rutina del día según el plan activo y día de la semana
- Lista ejercicios con sets, reps y peso de referencia
- Botón para marcar rutina como completada
- Tarjeta de sesión de gym:
  - Iniciar sesión (crea `ExerciseSessionLog`)
  - Durante sesión activa: registrar series con ejercicio, reps y peso
  - Finalizar sesión (registra hora de salida)
- Vista de sesiones recientes con duración
- Diálogo de gestión de planes (activar, ver historial)

**BLoC Events:**
- `ExerciseLoaded(date)` — carga plan, rutina del día, items, sesiones y log diario
- `ExercisePlanLoaded()` — carga todos los planes
- `ExercisePlanActivated(planId)` — cambia plan activo
- `ExercisePlanCreated(name)` — crea nuevo plan
- `ExerciseRoutineMarkedDone(date, routineId)` — marca rutina como hecha
- `ExerciseSessionStarted(date)` — inicia sesión de gym
- `ExerciseSessionEnded(sessionId)` — finaliza sesión
- `ExerciseSetLogged(...)` — registra una serie

**BLoC State:**
- `activePlan`, `allPlans`, `todayRoutine`, `routineItems`, `dailyLog`
- `activeSession`, `sessionSets`, `recentSessions`
- Helper: `hasActiveSession` (sesión sin `gymLeftAt`)

---

## Verificación

- [x] `flutter test` → 54 tests pasan
- [x] `flutter build apk --debug` → compila sin errores
- [x] Home → Ejercicio navega a página funcional
- [x] Sin plan activo muestra CTA para crear plan
- [x] Con plan y rutina: muestra ejercicios y permite marcar como completada
- [x] Iniciar/finalizar sesión de gym funciona
- [x] Registrar series durante sesión activa funciona
