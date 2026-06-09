# Kiolog — Phase 6: Home Dashboard + History + Achievements

**Fecha:** 2026-06-08
**Goal:** Implementar el Home con resumen real del día, historial mensual con calendario, y pantalla de logros.

---

## Resumen de Cambios

### Estructura de Carpetas Nuevas

```
lib/features/home/presentation/bloc/
├── home_bloc.dart
├── home_event.dart
└── home_state.dart

lib/features/history/
├── domain/repositories/history_repository.dart
├── data/repositories/history_repository_impl.dart
├── presentation/bloc/
│   ├── history_bloc.dart
│   ├── history_event.dart
│   └── history_state.dart
└── presentation/pages/history_page.dart

lib/features/achievements/
└── presentation/
    ├── bloc/
    │   ├── achievements_bloc.dart
    │   ├── achievements_event.dart
    │   └── achievements_state.dart
    └── pages/achievements_page.dart
```

### Archivos Modificados

- `lib/features/home/presentation/pages/home_page.dart` — dashboard funcional con datos reales
- `lib/core/di/injection.dart` — registro de `HistoryRepository`
- `lib/core/router/app_router.dart` — rutas `/history` y `/achievements`
- `test/widget_test.dart` y `test/widget/app_scaffold_test.dart` — mocks para todas las dependencias del Home

### Tests Nuevos

- `test/features/history/data/history_repository_test.dart`
- `test/features/history/presentation/history_bloc_test.dart`
- `test/features/achievements/presentation/achievements_bloc_test.dart`

---

## Funcionalidad

**Home Dashboard:**
- Carga resumen del día actual desde todos los módulos
- Tarjeta Agua: barra de progreso con ml consumidos / meta
- Tarjeta Sueño: horas dormidas (o "No registrado")
- Tarjeta Nutrición: comidas registradas / 4
- Tarjeta Ejercicio: rutina completada, sesión en progreso, o pendiente
- Acceso rápido a cada módulo al tocar la tarjeta
- Botones de app bar para Historial y Logros

**Historial:**
- Calendario mensual en grid (7 columnas)
- Navegación entre meses con flechas
- Cada día muestra mini-dots de color por módulo completado
- Días con 4/4 módulos resaltados con color primario
- Leyenda en la parte inferior

**Logros:**
- Lista separada en "Desbloqueados" y "Por desbloquear"
- Icono dorado para logros desbloqueados
- Chips con título y descripción

---

## Verificación

- [x] `flutter test` → 62 tests pasan
- [x] `flutter build apk --debug` → compila sin errores
- [x] Home muestra resumen real del día
- [x] Navegación a Historial y Logros funciona
- [x] Calendario mensual renderiza correctamente
