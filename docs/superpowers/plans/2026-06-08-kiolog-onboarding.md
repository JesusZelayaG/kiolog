# Kiolog — Onboarding Wizard

**Fecha:** 2026-06-08
**Goal:** Implementar flujo de configuración inicial obligatorio antes de usar la app.

---

## Cambios en Base de Datos

- Nueva tabla `user_profiles` en `config_tables.dart`
- `schemaVersion` incrementado a `3` (v1 → v2 creó `user_profiles`; v2 → v3 recreó tablas de ejercicio)
- Migración `onUpgrade` que crea/migra tablas según versión
- Nuevo `UserProfileDao` para gestionar el estado del onboarding y la fecha de registro

---

## Flujo de Onboarding (5 pasos)

### Paso 1 — Bienvenida
- Explicación de la app
- Botón "Comenzar"

### Paso 2 — Configuración de Agua
- Selección de unidad: Botella o Vaso
- Tamaño del contenedor en ml
- Meta diaria en ml
- Cálculo automático de cuántas unidades equivale la meta

### Paso 3 — Plan de Alimentación
- Nombre del plan
- 4 tiempos de comida (Desayuno, Almuerzo, Cena, Entrecomida)
- Hasta 3 opciones por tiempo de comida
- Campos libres (pueden dejarse en blanco)

### Paso 4 — Plan de Ejercicio
- Nombre del plan
- **Días de rutina numerados** (Día 1, Día 2, Día 3...) — **no** días de la semana
- Cada día tiene un **nombre libre** (ej: "Pecho y tríceps", "Pierna", "Espalda")
- Por cada día: agregar ejercicios con nombre, sets, reps y peso de referencia
- Se pueden agregar tantos días como se quiera
- El usuario elige qué día entrena al ir al gimnasio, independientemente del calendario

### Paso 5 — Datos de Inicio
- Peso inicial en kg
- Fecha de inicio (default: hoy) — ancla todos los registros históricos
- Explicación de que planes se actualizan aproximadamente cada mes

---

## Comportamiento de la App

- Al iniciar, `main.dart` verifica `UserProfileDao.isOnboardingComplete()`
- Si es `false`, la ruta inicial es `/onboarding`
- Si es `true`, la ruta inicial es `/` (Home)
- Al finalizar el wizard, se guarda todo y se marca `onboardingCompleted = true` con la `registration_date`
- `createRouter({String initialLocation})` soporta ruta inicial dinámica

---

## Notas de Instalación

Como el schema de la base de datos cambió varias veces, **es necesario reinstalar la app** en el teléfono para que Drift aplique la migración correctamente:

```bash
flutter clean
flutter run
```

O desinstala manualmente la app del teléfono y vuelve a ejecutar `F5` en VS Code.
