# Kiolog — Contexto Global del Proyecto

**Última actualización:** 2026-06-08
**Versión de schema:** 3
**Tests:** 64 pasan
**Build:** ✅ Compila sin errores

---

## Qué es Kiolog

App Flutter personal de bitácora de salud — offline first, Android. Lleva registro de:
- Plan alimenticio indicado por nutricionista (con opciones por tiempo de comida)
- Rutina de ejercicio flexible (días numerados, no fijos por semana)
- Ingesta de agua
- Horas de sueño
- Peso y medidas antropométricas
- Historial completo con calendario
- Reportes PDF exportables
- Sistema de logros
- Notificaciones configurables

**Idioma:** Español (`es` locale)

---

## Arquitectura

### Patrón
BLoC + Clean Architecture por features. Tres capas:
- **data/** — DAOs Drift, repositorios concretos
- **domain/** — contratos de repositorio
- **presentation/** — BLoCs, pantallas, widgets

### Dependencias Principales
```yaml
flutter_bloc, go_router, drift, get_it, intl,
flutter_local_notifications, pdf, share_plus,
path_provider, equatable, mocktail (tests)
```

### Inyección de Dependencias
`get_it` en `lib/core/di/injection.dart`. Todos los DAOs y repositorios se registran ahí.

### Router
`createRouter({String initialLocation})` — función que crea el GoRouter.
- Si onboarding no está completo → `initialLocation = '/onboarding'`
- Si está completo → `initialLocation = '/'`

---

## Base de Datos (Drift — Schema v3)

### Tablas principales

**Nutrición:**
- `meal_plans` — planes de alimentación (versionados, uno activo)
- `meal_plan_options` — opciones por tiempo de comida (hasta 3 por tipo)
- `daily_meal_logs` — registro diario de qué se comió

**Ejercicio:**
- `exercise_plans` — planes de ejercicio (versionados)
- `exercise_routines` — días de rutina (`day_number`, NO día de semana)
- `exercise_routine_items` — ejercicios por día de rutina
- `daily_exercise_logs` — marcador de rutina completada
- `exercise_session_logs` — sesiones de gym con `routine_id`
- `exercise_set_logs` — series registradas en una sesión

**Agua:**
- `daily_water_logs` — ingesta de agua por timestamp

**Sueño:**
- `sleep_logs` — hora de dormir, despertar, horas calculadas

**Medidas:**
- `weight_logs` — peso por fecha
- `measurements` — medidas antropométricas completas (append-only)

**Configuración:**
- `water_config` — unidad, tamaño contenedor, meta diaria
- `gym_config` — ubicación, radio de proximidad
- `notification_settings` — alarmas por módulo
- `user_profiles` — onboarding completado, fecha de registro

**Otros:**
- `achievements` — sistema de logros

### Migraciones
- v1 → v2: crea `user_profiles`
- v2 → v3: recrea tablas de ejercicio (`dayOfWeek` → `dayNumber`, `routineId` en sesiones)

---

## Flujo de Onboarding (Obligatorio)

Antes de usar la app, el usuario debe completar un wizard de 5 pasos:

1. **Bienvenida** — explicación
2. **Agua** — unidad, tamaño, meta
3. **Nutrición** — crear plan con opciones por comida
4. **Ejercicio** — crear plan con días de rutina numerados (Día 1, Día 2...)
5. **Datos de inicio** — peso inicial y fecha de registro

Al completar, `onboarding_completed = true` y `registration_date` se guardan en `user_profiles`.

---

## Módulos y Flujos

### Agua (Water)
- Home → tarjeta Agua → /water
- Botón para sumar una unidad (botella/vaso)
- Meta diaria en ml con barra de progreso
- Configuración: tipo de unidad, tamaño, meta

### Sueño (Sleep)
- Home → tarjeta Sueño → /sleep
- Registrar hora de dormir y despertar
- Promedio semanal
- Vista de últimos 7 días

### Nutrición (Nutrition)
- Bottom nav → Nutrición
- 4 tiempos de comida (desayuno, almuerzo, cena, entrecomida)
- Hasta 3 opciones por tiempo
- Tocar opción → la marca como registrada (chip verde)
- **Cambiar selección**: botón que elimina el log y permite reelegir
- "Registrar fuera de plan" → descripción libre
- Gestión de planes: ver versiones, activar otra

### Ejercicio (Exercise)
- Bottom nav → Ejercicio
- Muestra plan activo y lista de días de rutina
- Cada día: nombre + ejercicios (sets, reps, peso referencia)
- **"Entrené este día"** → inicia sesión vinculada a esa rutina
- Durante sesión: ver ejercicios como guía + registrar series
- "Finalizar sesión" → marca hora de salida
- Sesiones recientes: qué día se entrenó, duración
- **+ Día** → agregar nuevos días de rutina al plan activo

### Progreso (Progress)
- Bottom nav → Progreso
- Peso: historia con gráfica, tendencia (↑↓→)
- Medidas: último registro + formulario completo
- Indicadores de variación entre registros

### Home
- Resumen del día: agua, sueño, nutrición, ejercicio, peso
- Grid de acceso rápido a módulos
- Tarjeta de sueño con botón "Registrar sueño"

### Historial (History)
- Calendario mensual con dots de cumplimiento
- Filtros por módulo
- Sin penalización por días sin registro

### Logros (Achievements)
- Logros predefinidos seedeados en DB
- Se desbloquean automáticamente al registrar datos
- Sin rachas que romper

### Reportes (Reports)
- Selección de rango de fechas
- Métricas de cumplimiento por módulo
- Exportar a PDF + compartir

### Configuración (Settings)
- Bottom nav → Ajustes
- Navegación a subpáginas: Agua, Notificaciones, Gimnasio, Historial, Logros, Reporte, Ayuda

---

## Decisiones Técnicas Clave

### Drift models como entidades
Por practicidad, las clases generadas por Drift se pasan directamente a través de los repositorios en lugar de crear entidades separadas. Esto reduce boilerplate.

### Normalización de fechas
Todas las fechas en repositorios usan `_dateOnly()` → `DateTime.utc(year, month, day)`. Esto asegura comparaciones consistentes sin problemas de timezone.

### copyWith y campos nullable
**Bug crítico corregido:** los `copyWith` de estados BLoC deben usar `?? this.field` para campos nullable, de lo contrario se pierden al hacer updates parciales.

- `ExerciseState.copyWith` — preserva `activePlan`, `routines`, `routineItemsByRoutine`, etc.
- `NutritionState.copyWith` — preserva `activePlan`, `planOptions`, `dailyLogs`
- `SleepState.copyWith` — preserva `todayLog`

### router como función
`createRouter({String initialLocation})` en vez de `appRouter` global, para poder pasar la ruta inicial dinámica según onboarding.

### `ExerciseState` reconstruido en `_onLoaded`
En vez de `copyWith`, `_onLoaded` construye un `ExerciseState` completo para poder limpiar `activeSession` cuando no hay sesión activa.

---

## Tests

64 tests en total:
- DAO tests: nutrition, exercise, water/sleep, measurements, config, achievements
- Repository tests: todos los features
- BLoC tests: todos los features
- Widget tests: app scaffold, navigation

Ejecutar: `flutter test`

---

## Build y Deploy

```bash
# Tests
flutter test

# Build debug APK
flutter build apk --debug

# Instalar en dispositivo
flutter run
# o F5 en VS Code
```

**Nota:** Después de cambios de schema de DB, desinstalar la app del dispositivo antes de reinstalar.

---

## Estructura de Carpetas

```
lib/
├── core/
│   ├── ai/
│   ├── dao/                  # todos los DAOs Drift
│   ├── database/
│   │   ├── app_database.dart
│   │   └── tables/           # definiciones de tablas Drift
│   ├── di/injection.dart
│   ├── notifications/
│   ├── router/app_router.dart
│   ├── theme/
│   └── utils/
├── features/
│   ├── nutrition/
│   ├── exercise/
│   ├── water/
│   ├── sleep/
│   ├── progress/             # peso + medidas
│   ├── home/
│   ├── history/
│   ├── achievements/
│   ├── reports/
│   ├── settings/
│   └── onboarding/           # wizard inicial
├── shared/widgets/
└── main.dart
test/
├── dao/                      # tests de DAOs
├── features/                 # tests de repos y blocs
├── widget/                   # tests de widgets
└── helpers/database_helper.dart
```

---

## Pendientes / Ideas Futuras

- [ ] Integración con IA para importar planes desde PDF
- [ ] Geolocalización del gimnasio (proximidad para check-in)
- [ ] iOS support
- [ ] Sincronización en la nube
- [ ] Múltiples perfiles de usuario
- [ ] Dark mode refinado
- [ ] Notificaciones recurrentes (alarmas reales)
