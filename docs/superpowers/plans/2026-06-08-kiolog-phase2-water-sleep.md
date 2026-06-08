# Kiolog — Phase 2: Water & Sleep Modules

**Fecha:** 2026-06-08
**Goal:** Implementar los módulos de Agua y Sueño con arquitectura BLoC + Clean Architecture, navegación funcional desde Home, y tests.

---

## Resumen de Cambios

### Estructura de Carpetas Nuevas

```
lib/features/water/
├── domain/repositories/water_repository.dart
├── data/repositories/water_repository_impl.dart
├── presentation/bloc/
│   ├── water_bloc.dart
│   ├── water_event.dart
│   └── water_state.dart
└── presentation/pages/water_page.dart

lib/features/sleep/
├── domain/repositories/sleep_repository.dart
├── data/repositories/sleep_repository_impl.dart
├── presentation/bloc/
│   ├── sleep_bloc.dart
│   ├── sleep_event.dart
│   └── sleep_state.dart
└── presentation/pages/sleep_page.dart
```

### Archivos Modificados

- `pubspec.yaml` — agregada dependencia `intl: ^0.19.0`
- `lib/core/di/injection.dart` — registro de `WaterRepository` y `SleepRepository`
- `lib/core/router/app_router.dart` — rutas `/water` y `/sleep`
- `lib/features/home/presentation/pages/home_page.dart` — grid de acceso rápido a módulos
- `test/widget/app_scaffold_test.dart` — ajustado para soportar múltiples widgets con mismo texto

### Tests Nuevos

- `test/features/water/data/water_repository_test.dart`
- `test/features/water/presentation/water_bloc_test.dart`
- `test/features/sleep/data/sleep_repository_test.dart`
- `test/features/sleep/presentation/sleep_bloc_test.dart`

---

## Módulo Agua

**Funcionalidad:**
- Visualizar progreso diario de consumo de agua (circular progress + texto en ml/L)
- Agregar una unidad (botella/vaso) con un botón principal
- Agregar cantidad personalizada via diálogo
- Configurar tipo de unidad, tamaño del contenedor (ml) y meta diaria
- Celebración visual cuando se alcanza la meta

**BLoC Events:**
- `WaterLoaded(date)` — carga total del día y configuración
- `WaterAdded(date, amountMl)` — agrega ingesta estándar
- `WaterCustomAmountAdded(date, amountMl)` — agrega ingesta personalizada
- `WaterConfigLoaded()` — carga configuración
- `WaterConfigUpdated(unitType, containerMl, dailyGoalMl)` — guarda configuración

**BLoC State:**
- `dailyTotalMl`, `dailyGoalMl`, `unitType`, `containerMl`, `progress`

---

## Módulo Sueño

**Funcionalidad:**
- Visualizar registro de sueño de hoy (horas, rango de horas)
- Ver promedio semanal de horas dormidas
- Listado de los últimos 7 días con detalle
- Registrar nueva entrada de sueño con selector de hora

**BLoC Events:**
- `SleepLoaded(date)` — carga registro del día
- `SleepWeeklyLoaded(endDate)` — carga semana terminando en fecha
- `SleepLogAdded(date, sleepTime, wakeTime)` — guarda nuevo registro

**BLoC State:**
- `todayLog`, `weeklyLogs`, `weeklyAverage`

---

## Verificación

- [x] `flutter test` → 37 tests pasan
- [x] `flutter build apk --debug` → compila sin errores
- [x] Home muestra grid con acceso a Agua y Sueño
- [x] Navegación funcional desde Home a WaterPage y SleepPage
