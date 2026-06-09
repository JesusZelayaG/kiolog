# Kiolog — Onboarding Wizard

**Fecha:** 2026-06-08
**Goal:** Implementar flujo de configuración inicial obligatorio antes de usar la app.

---

## Cambios en Base de Datos

- Nueva tabla `user_profiles` en `config_tables.dart`
- `schemaVersion` incrementado de `1` a `2`
- Migración `onUpgrade` que crea `user_profiles` al actualizar
- Nuevo `UserProfileDao` para gestionar el estado del onboarding

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
- 7 días de la semana expandibles
- Por cada día: agregar ejercicios con nombre, sets, reps y peso
- Días sin ejercicios se consideran descanso

### Paso 5 — Datos de Inicio
- Peso inicial en kg
- Fecha de inicio (default: hoy)
- Explicación de que planes se actualizan aproximadamente cada mes

---

## Comportamiento de la App

- Al iniciar, `main.dart` verifica `UserProfileDao.isOnboardingComplete()`
- Si es `false`, la ruta inicial es `/onboarding`
- Si es `true`, la ruta inicial es `/` (Home)
- Al finalizar el wizard, se guarda todo y se marca `onboardingCompleted = true`

---

## Notas de Instalación

Como el schema de la base de datos cambió (versión 1 → 2), **es necesario reinstalar la app** en el teléfono para que Drift aplique la migración correctamente:

```bash
flutter clean
flutter run
```

O desinstala manualmente la app del teléfono y vuelve a ejecutar `F5` en VS Code.
