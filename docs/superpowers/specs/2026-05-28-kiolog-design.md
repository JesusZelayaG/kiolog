# Kiolog — Diseño de Aplicación

**Fecha:** 2026-05-28  
**Plataforma:** Flutter — Android primero (preparado para iOS sin cambios estructurales)  
**Tipo:** App personal de bitácora de salud — offline first

---

## Resumen

Kiolog es una app móvil personal para llevar registro del plan alimenticio indicado por la nutricionista, días de ejercicio, ingesta de agua, horas de sueño, peso y medidas antropométricas. Incluye historial, estadísticas, reporte de consulta exportable, alarmas configurables, integración opcional con IA para importar planes desde PDF, y un sistema de logros orientado al progreso personal.

---

## Stack Tecnológico

| Capa | Tecnología |
|---|---|
| Framework | Flutter |
| Estado | `flutter_bloc` (BLoC pattern) |
| Base de datos | Drift (SQLite, tipado, code generation) |
| Almacenamiento seguro | `flutter_secure_storage` (API keys) |
| Notificaciones | `flutter_local_notifications` |
| Geolocalización | `geolocator` |
| Mapas | `flutter_map` + OpenStreetMap (sin API key de Google) |
| PDF import/parse | `file_picker` + llamada a API de IA |
| PDF export | `pdf` package |
| Compartir | `share_plus` |
| Fotos | `image_picker` |

---

## Arquitectura

### Patrón General

BLoC + Clean Architecture por features, tres capas por módulo:

- **data/** — modelos Drift, DAOs, repositorios concretos
- **domain/** — entidades, contratos de repositorio, casos de uso
- **presentation/** — BLoCs, pantallas, widgets

### Estructura de Carpetas

```
lib/
├── core/
│   ├── ai/                  # abstracción de proveedores IA
│   ├── notifications/       # servicio de alarmas
│   ├── theme/
│   ├── router/
│   └── utils/
├── features/
│   ├── nutrition/
│   │   ├── data/
│   │   ├── domain/
│   │   └── presentation/
│   ├── exercise/
│   ├── water/
│   ├── sleep/
│   ├── measurements/
│   ├── weight/
│   ├── history/
│   ├── achievements/
│   └── reports/
└── main.dart
```

Cada feature es completamente independiente. La comunicación entre features ocurre únicamente a través de casos de uso o eventos BLoC expuestos en `core/`.

---

## Modelo de Datos (Drift)

### Planes (versionados)

```
meal_plans
  id, name, created_at, is_active

meal_plan_options
  id, plan_id, meal_type (breakfast|lunch|dinner|snack), option_number (1|2|3), description

exercise_plans
  id, name, created_at, is_active

exercise_routines
  id, plan_id, day_of_week, routine_name, notes
  
exercise_routine_items
  id, routine_id, exercise_name, sets, reps, weight_kg (nullable)
```

Los planes son versionados: al crear un plan nuevo el anterior se marca `is_active = false` pero no se elimina. Los logs históricos mantienen referencia al `plan_id` original.

### Logs Diarios

```
daily_meal_logs
  id, date, meal_type, plan_option_id (nullable), free_description (nullable), photo_path (nullable)
  -- plan_option_id null indica comida fuera de plan

daily_exercise_logs
  id, date, routine_id, completed

exercise_session_logs
  id, date, gym_arrived_at, gym_left_at, lat, lng (últimos dos nullable si sin GPS)

exercise_set_logs
  id, session_id, exercise_name, set_number, reps, weight_kg

daily_water_logs
  id, date, timestamp, amount_ml

sleep_logs
  id, date, sleep_time, wake_time, hours_calculated

weight_logs
  id, date, weight_kg

measurements
  id, date, weight_kg, height_cm, arm_flexed_cm, arm_relaxed_cm,
  waist_cm, hip_cm, calf_cm, lower_abdomen_cm, thigh_cm,
  mid_gluteus_cm, chest_cm, body_fat_pct, lean_mass_kg, visceral_mass
  -- append-only: cada consulta agrega un registro nuevo
```

### Configuración

```
water_config
  unit_type (bottle|glass), container_ml, daily_goal_ml

gym_config
  name, lat, lng, proximity_radius_m, proximity_enabled

notification_settings
  module (nutrition|water|sleep|exercise), enabled, hour, minute,
  reminder_type (fixed_time|interval), interval_minutes (nullable)
  -- agua usa interval, los demás usan fixed_time

ai_config
  provider (claude|gemini|openai|manual), api_key_encrypted (nullable)
```

---

## Módulos y Pantallas

### Home

Pantalla principal con resumen del día actual:

- Tarjeta **Nutrición**: progreso de comidas del día (ej. 2/4 completadas)
- Tarjeta **Agua**: barra de progreso hacia meta diaria
- Tarjeta **Ejercicio**: si hoy hay rutina, si fue completada; si hubo sesión de gym
- Tarjeta **Sueño**: horas registradas anoche
- Acceso rápido a registro manual de cada módulo

### Nutrición

- Ver las 3 opciones del plan para cada tiempo de comida del día
- Marcar cuál opción se eligió (1, 2 o 3)
- Registrar "fuera de plan": descripción libre + foto opcional
- Configurar/editar plan manualmente o importar desde PDF vía IA
- Historial de comidas por día
- Gestión de planes: ver versiones anteriores, activar una versión distinta

### Ejercicio

- Ver rutina del día según plan activo (con sets, reps y peso de referencia)
- Marcar sesión de gym:
  - **Manual**: botón de check-in manual + registro de ejercicios realizados (sets, reps, peso levantado)
  - **Por proximidad** (opcional): botón de check-in aparece automáticamente al estar dentro del radio configurado del gimnasio
- Marcar ejercicios individuales como completados durante la sesión
- Registrar peso levantado por serie
- Ver historial de progreso por ejercicio (evolución de peso/reps a lo largo del tiempo)
- Configurar/editar plan de ejercicio o importar desde PDF vía IA
- Gestión de planes con versionado

### Agua

- Botón principal para sumar una unidad (botella o vaso)
- Barra de progreso hacia meta diaria en litros
- Ajuste manual para cantidades parciales
- Configuración: tipo de unidad, tamaño del contenedor en ml, meta diaria en litros

### Sueño

- Registrar hora de dormir y hora de despertar
- Cálculo automático de horas dormidas
- Vista semanal: promedio de horas por noche

### Medidas y Peso

- Registro de peso semanal con gráfica de evolución
- Registro de medidas antropométricas completas (solo en consulta):
  - Peso, talla, brazo contraído, brazo relajado, cintura, cadera, pantorrilla, abdomen bajo, muslo (1cm del glúteo), glúteo medio, mesoesternal/tórax, % grasa, masa magra, masa visceral
- Comparación visual entre consultas (línea de tiempo)
- Importar medidas desde PDF de consulta vía IA

### Historial

- Calendario mensual con indicadores por día (cuántos módulos se completaron)
- Filtros por módulo (ver solo días de ejercicio, solo cumplimiento de agua, etc.)
- Sin penalización por días sin registro — cada día registrado cuenta positivamente

### Logros

Sistema de logros acumulativos y orientados al progreso personal. Sin rachas que romper.

**Ejemplos de logros:**
- Cumplimiento acumulativo: "30 días totales de agua meta cumplida", "20 sesiones de gym registradas"
- Consistencia semanal: "4/4 días de gym en una semana", "7/7 días de agua en una semana"
- Primeras veces: "primer plan importado", "primera sesión de gym", "primera consulta registrada"
- Progreso personal: "primera mejora en medidas", "primera semana con +7h de sueño promedio"

Los logros se evalúan automáticamente al registrar datos. No hay penalización por días sin actividad.

### Reporte de Consulta

- Selección de período (semana, mes, rango personalizado)
- Resumen con porcentajes de cumplimiento por módulo
- Evolución de peso y medidas entre consultas
- Pantalla de resumen organizada para mostrar en teléfono durante la consulta
- Exportar como PDF
- Compartir vía apps del sistema (WhatsApp, email, etc.)

### Configuración

- Perfil de agua (unidad, tamaño, meta)
- Configuración de gimnasio (ubicación, radio, activar/desactivar proximidad)
- Alarmas por módulo con hora personalizable
- Proveedor IA: selección de proveedor + ingreso de API key (almacenada cifrada)
- Modo sin API key: la app genera un prompt con el formato JSON esperado para que el usuario lo copie, lo pegue junto con su PDF en cualquier IA, y pegue la respuesta de vuelta en la app
- Gestión de planes activos

---

## Integración con IA

### Flujo con API Key

1. Usuario selecciona PDF (plan alimenticio, ejercicio o medidas)
2. La app envía el PDF + prompt al proveedor configurado (Claude, Gemini, etc.)
3. El proveedor retorna un JSON estructurado
4. La app parsea el JSON y pre-llena el formulario del plan para revisión del usuario
5. Usuario confirma o ajusta antes de guardar

### Flujo sin API Key (modo manual)

1. La app genera un prompt con el esquema JSON esperado y las instrucciones para la IA
2. Usuario copia el prompt, va a cualquier IA (Claude.ai, ChatGPT, Gemini, etc.), adjunta su PDF y pega el prompt
3. Usuario copia la respuesta JSON de la IA
4. Usuario pega el JSON en la app
5. La app parsea, pre-llena y el usuario confirma antes de guardar

### Abstracción de Proveedores

```dart
abstract class AiProvider {
  Future<MealPlanJson> parseMealPlan(String pdfContent);
  Future<ExercisePlanJson> parseExercisePlan(String pdfContent);
  Future<MeasurementsJson> parseMeasurements(String pdfContent);
}
```

Implementaciones concretas: `ClaudeProvider`, `GeminiProvider`, `OpenAiProvider`. El proveedor activo se inyecta vía `get_it` según la configuración del usuario.

---

## Notificaciones y Alarmas

Alarmas configurables por módulo usando `flutter_local_notifications`:

- **Comidas**: alarma por tiempo de comida (desayuno, almuerzo, cena, entrecomida) — horas individuales configurables
- **Agua**: recordatorio periódico configurable (ej. cada 2 horas)
- **Sueño**: alarma para hora de ir a dormir

Las alarmas se configuran desde el módulo de Configuración y persisten entre reinicios de la app.

---

## Geolocalización (Opcional)

- El usuario configura la ubicación del gimnasio una sola vez (GPS actual o búsqueda en mapa)
- Radio de proximidad configurable (default 100m)
- La app verifica proximidad solo cuando el usuario abre el módulo de ejercicio o el home — no en background continuo para preservar batería
- Si el usuario está dentro del radio, el botón de check-in se activa automáticamente
- Los permisos de ubicación se solicitan únicamente si el usuario activa esta función en configuración

---

## Alcance Actual (v1)

**Incluido:**
- Todos los módulos descritos arriba
- Android únicamente
- Offline first (excepto llamadas a API de IA)
- Un solo usuario (sin cuentas ni sync)

**Fuera de alcance por ahora:**
- iOS, web, desktop
- Sincronización en la nube
- Múltiples usuarios / perfiles
- Social features
