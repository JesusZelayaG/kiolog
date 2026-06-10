# Kiolog — Vitality Dark Redesign

**Fecha:** 2026-06-10  
**Estado:** Aprobado  
**Stitch project:** `projects/4667506181120038605`

## Resumen

Rediseño visual completo de la app Kiolog aplicando el design system **Vitality Dark** de Stitch. El objetivo es modernizar la interfaz sin alterar la lógica de negocio: BLoC, repositorios, DAOs, modelos de dominio y tests permanecen intactos. Solo se reescribe la capa de presentación (árboles de widgets).

La app pasa de Material 3 con tema claro (verde sage) a un tema oscuro exclusivo con verde vibrante, fondo navy profundo y tipografía Hanken Grotesk.

---

## Design System: Vitality Dark

### Paleta de colores

| Token Flutter | Valor Hex | Uso |
|---|---|---|
| `primary` | `#4BE277` | Iconos activos, texto destacado |
| `primaryContainer` | `#22C55E` | Fondo de botones primarios, fills de progreso |
| `onPrimary` | `#003915` | Texto sobre botones primarios |
| `onPrimaryContainer` | `#004B1E` | Texto sobre primaryContainer |
| `secondary` | `#4EDEA3` | Accento secundario (nutrición/verde-teal) |
| `tertiary` | `#AFC7FF` | Acento azul (agua, informativo) |
| `surface` | `#0B1326` | Fondo principal (canvas) |
| `surfaceContainerLow` | `#131B2E` | NavigationBar, inputs |
| `surfaceContainer` | `#171F33` | Cards, contenedores primarios |
| `surfaceContainerHigh` | `#222A3D` | Track de progress bars, bordes sutiles |
| `surfaceContainerHighest` | `#2D3449` | Chips, elementos elevados |
| `onSurface` | `#DAE2FD` | Texto principal |
| `onSurfaceVariant` | `#BCCBB9` | Texto secundario, labels |
| `outline` | `#869585` | Bordes visibles |
| `outlineVariant` | `#3D4A3D` | Bordes sutiles en cards |
| `error` | `#FFB4AB` | Estados de error |

### Tipografía: Hanken Grotesk

Paquete: `google_fonts: ^6.2.1`

| Flutter TextStyle | Tamaño | Peso | Line Height | Letter Spacing |
|---|---|---|---|---|
| `displayLarge` | 40px | 700 | 48px | -0.02em |
| `headlineLarge` | 32px | 600 | 40px | -0.01em |
| `headlineMedium` | 24px | 600 | 32px | — |
| `bodyLarge` | 18px | 400 | 28px | — |
| `bodyMedium` | 16px | 400 | 24px | — |
| `labelLarge` | 14px | 600 | 20px | +0.02em |
| `labelSmall` | 12px | 500 | 16px | — |

### Espaciado y forma

- Base unit: **8px**
- Container padding: **24px** horizontal
- Stack gap (ítems relacionados): **16px**
- Section gap (secciones distintas): **32px**
- Card radius: **16px**
- Button/input radius: **8px**
- Progress pill: **fully rounded**

---

## Fase 1 — Fundación

### 1.1 pubspec.yaml
Agregar dependencia:
```yaml
google_fonts: ^6.2.1
```

### 1.2 lib/core/theme/app_theme.dart

Reemplazar completamente. El tema claro (`light`) se elimina. `dark` pasa a ser el único tema con `ColorScheme` explícito de Vitality Dark.

**ColorScheme:** construido con `ColorScheme(brightness: Brightness.dark, ...)` con todos los tokens de la paleta arriba. No usar `ColorScheme.fromSeed`.

**TextTheme:** `GoogleFonts.hankenGroteskTextTheme()` como base, con override de cada estilo para respetar la escala de Stitch.

**Component themes incluidos:**

- `AppBarTheme`: bg `surface`, elevation 0, centerTitle true, titleStyle `headlineMedium`
- `CardTheme`: color `surfaceContainer`, elevation 0, shape `RoundedRectangleBorder(radius 16px, side 0.5px `outlineVariant`)`
- `ElevatedButtonTheme`: bg `primaryContainer`, fg `onPrimaryContainer`, padding `EdgeInsets.symmetric(vertical: 16)`, shape radius 8px, textStyle `labelLarge`
- `OutlinedButtonTheme`: side 1.5px `primary`, radius 8px
- `TextButtonTheme`: fg `primary`, textStyle `labelLarge`
- `InputDecorationTheme`: filled true, fillColor `surfaceContainerLow`, border radius 8px, focused border 1.5px `primaryContainer`, floatingLabel above field
- `ProgressIndicatorTheme`: `LinearProgressIndicatorThemeData` con trackColor `surfaceContainerHigh`, color `primaryContainer`, `borderRadius` pill
- `NavigationBarTheme`: bg `surfaceContainerLow`, height 64px, indicatorColor `onPrimaryContainer` con opacity, labelBehavior `alwaysShow`
- `ChipTheme`: bg `surfaceContainerHigh`, side `BorderSide.none`, radius 20px
- `DividerTheme`: color `outlineVariant`, thickness 0.5px
- `SnackBarTheme`: bg `surfaceContainerHighest`, radius 8px

### 1.3 lib/main.dart

```dart
MaterialApp(
  theme: AppTheme.dark,
  darkTheme: AppTheme.dark,
  themeMode: ThemeMode.dark, // forzado
)
```

---

## Fase 2 — Home + Onboarding

### home_page.dart → Resumen del día

Referencia Stitch: pantalla "Resumen del día"

- Header: saludo personalizado (`headlineLarge`) + fecha (`bodyMedium`, `onSurfaceVariant`)
- Cards por módulo activo: `VitalityCard` con `ModuleIconBadge` + nombre del módulo + `VitalityProgressBar` + stat principal
- Layout: `CustomScrollView` con `SliverAppBar` colapsable
- Espaciado entre cards: 16px; padding horizontal: 24px

### onboarding_page.dart → Bienvenida

Referencia Stitch: pantalla "Bienvenida"

- Ícono central grande (`Icon` de Material, tamaño 96px, color `primary`)
- Título (`displayLarge`) + subtítulo (`bodyLarge`)
- Stepper de pasos con indicador pill activo en `primaryContainer`
- Botón primario sticky al fondo: `ElevatedButton` full-width

---

## Fase 3 — Nutrición

### nutrition_page.dart → Plan de Alimentación

Referencia Stitch: "Plan de Alimentación"

- AppBar mínima con título + botón de nuevo plan
- Secciones de comidas (desayuno, almuerzo, cena, merienda) como `VitalityCard` expandibles
- Cada ítem de comida: row con `ModuleIconBadge` verde + nombre + chip de calorías opcional
- Acción "No seguí el plan": `OutlinedButton` con ícono
- `FloatingActionButton` para registrar comida

### nutrition_progress_page.dart → Estadísticas + Detalle

Referencia Stitch: "Estadísticas de Nutrición" + "Detalle de Nutrición"

- Toggle Semana/Mes: segmented control con pill deslizante (bg `surfaceContainerHigh`, activo `surfaceContainerHighest`)
- 3 `StatChip`: adherencia %, comidas en plan, fuera de plan
- Bar chart (CustomPainter existente): barras en `primaryContainer`, track en `surfaceContainerHigh`, eje en `outlineVariant`
- Navegador semanal/mensual: `<` fecha `>` en `onSurfaceVariant`

### nutrition_config_page.dart → Config (sin Stitch)

- Heredar theme global; ajustar paddings a 24px; reemplazar any `TextField` ad-hoc por `InputDecorationTheme`

---

## Fase 4 — Ejercicio

### exercise_page.dart → Plan + Dashboard Semanal

Referencia Stitch: "Plan de Ejercicio" + "Ejercicio Semanal"

- Sección rutina: cards de días con expand/collapse, `VitalityProgressBar` días completados
- Sección cardio: progress bar con meta, lista de sesiones
- Sección ejercicio libre
- Botón "▶ Iniciar rutina" sticky: `ElevatedButton` full-width, 16px bottom padding + safe area

### exercise_progress_page.dart → Estadísticas de Ejercicio

Referencia Stitch: "Estadísticas de Ejercicio (Vitality Dark)"

- Mismo patrón toggle Semana/Mes que nutrición
- `StatChip` x3: % rutina, % cardio, total sesiones
- Dos bar charts (CustomPainter): días rutina vs meta, días cardio vs meta
- Colores: rutina en `primary`, cardio en `secondary`

### exercise_session_page.dart → Sesión activa (sin Stitch)

- Header: hora inicio + `VitalityProgressBar` de ítems completados + botón X
- Lista de ítems: `VitalityCard` con estados pending/active/done usando `onSurface` / `primary` / `outlineVariant`
- Panel expandido: historial en tabla, inputs con `InputDecorationTheme`

### exercise_config_page.dart → Config metas (sin Stitch)

- Heredar theme global; layout de 3 metas con stepper +/- en `VitalityCard`

---

## Fase 5 — Agua + Progreso de Peso

### water_page.dart → Seguimiento de Hidratación

Referencia Stitch: "Seguimiento de Hidratación"

- Visualización principal: `VitalityProgressBar` de gran formato (height 24px) con fill animado en `tertiary` (#AFC7FF, azul)
- Meta y progreso: `VitalityProgressBar` en tertiary
- Botones rápidos (vaso/botella): grid de `OutlinedButton` pill-shaped
- `StatChip` con ml consumidos vs meta

### water_config_page.dart → Configuración de Agua

Referencia Stitch: "Configuración de Agua"

- Formulario con `InputDecorationTheme`: capacidad vaso, capacidad botella, meta diaria
- Toggle tipo contenedor con segmented control

### progress_page.dart → Progreso de Peso

Referencia Stitch: "Progreso de Peso"

- Bar chart (CustomPainter, mismo patrón que ejercicio/nutrición) con barras en `primary`
- Cards de registro: `VitalityCard` con fecha + peso + delta (↑↓ con color)
- FAB para agregar nuevo registro

---

## Fase 6 — Historial + Logros + Sin Stitch

### history_page.dart → Historial de Actividad

Referencia Stitch: "Historial de Actividad"

- Calendario mensual con días marcados en `primaryContainer`
- Lista de actividades del día seleccionado: `VitalityCard` con `ModuleIconBadge` + descripción + hora

### achievements_page.dart → Logros y Premios

Referencia Stitch: "Logros y Premios"

- Grid de logros: `VitalityCard` cuadrado con ícono grande tinted + nombre + descripción corta
- Logros obtenidos: color `primaryContainer`; pendientes: `surfaceContainerHigh` + 40% opacity

### settings_page.dart, sleep_page.dart, report_page.dart (sin Stitch)

- El theme global cubre la mayoría del trabajo automáticamente
- Ajuste manual: padding horizontal a 24px, reemplazar componentes ad-hoc por widgets compartidos, `VitalityCard` donde haya contenedores custom

---

## Widgets compartidos nuevos

Ubicación: `lib/shared/widgets/`

| Widget | Props principales | Descripción |
|---|---|---|
| `VitalityProgressBar` | `value`, `color?`, `height?` | `LinearProgressIndicator` pill-shaped, 8px height, color configurable (default `primaryContainer`) |
| `VitalityCard` | `child`, `padding?`, `onTap?` | `Card` con surface, border 0.5px outlineVariant, radius 16px |
| `SectionHeader` | `title`, `action?`, `actionLabel?` | Row título headlineMedium + TextButton opcional a la derecha |
| `ModuleIconBadge` | `icon`, `color` | Icon dentro de Container circular con bg = color al 10% opacity |
| `StatChip` | `value`, `label`, `color?` | Column: valor (`headlineMedium`) + label (`labelSmall`, `onSurfaceVariant`) |

---

## Restricciones

- Funcionalidad y tests no se modifican en ninguna fase
- No se crean nuevos colores fuera de la paleta Vitality Dark
- No se agregan dependencias de UI adicionales (sin flutter_svg, sin lottie, sin cualquier chart lib externa)
- Los CustomPainter existentes se adaptan para usar los colores del `ColorScheme`, no se reescriben desde cero
- Cada fase es un commit independiente y debe compilar sin errores antes de pasar a la siguiente
