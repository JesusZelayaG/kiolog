# Kiolog

Bitácora personal de salud para Android. Kiolog lleva el registro diario del plan alimenticio que indica la nutricionista, el entrenamiento, el agua, el sueño y las medidas corporales, y genera un reporte PDF para llevar a cada consulta.

La app es **offline first**: todos los datos viven en el teléfono, en una base SQLite local. No hay cuentas ni servidor.

## Funciones

- **Nutrición**: plan alimenticio por tiempos de comida (desayuno, almuerzo, refacción, cena) con varias opciones por tiempo. Se registra qué opción se comió, las comidas fuera del plan y los días en que no se siguió el plan. Cada comida puede llevar una foto.
- **Ejercicio**: planes de entrenamiento por días, con series, rangos de repeticiones, series en pirámide y drop sets, notas del entrenador y un video o imagen de referencia por ejercicio. También registra sesiones de cardio.
- **Agua y sueño**: registro en ml o litros contra una meta diaria, y varias tomas de sueño por día.
- **Progreso**: peso y medidas antropométricas, gráficas contra las metas, un álbum de comidas y un álbum diario de progreso (hasta 3 fotos o videos cortos por día).
- **Historial**: vistas por mes y por día, comparadas con las metas.
- **Consultas**: fecha de la próxima consulta, con recordatorios la noche anterior y 2 horas antes.
- **Reporte para la nutricionista**: un PDF con el cumplimiento, gráficas diarias, una tabla semanal, el calendario de ejercicio y cardio, el registro diario y las consultas.
- **Logros**: logros por el progreso personal.
- **Respaldos**: un respaldo automático diario en `Download/Kiolog` (se guardan los últimos 7), más respaldo y restauración manual.
- **Módulos opcionales y temas**: cada módulo se puede activar o desactivar, y la interfaz tiene varios temas a elegir.

## Stack

| Capa | Tecnología |
|---|---|
| Framework | Flutter (Android primero) |
| Estado | `flutter_bloc` |
| Base de datos | Drift sobre SQLite (schema v19) |
| Inyección de dependencias y navegación | `get_it`, `go_router` |
| Notificaciones | `flutter_local_notifications` |
| PDF y compartir | `pdf`, `share_plus` |
| Multimedia | `image_picker`, `video_player`, `youtube_player_iframe` |

La arquitectura sigue BLoC con capas por feature (`data/`, `domain/`, `presentation/`):

```
lib/
├── core/        # base de datos, DAOs, DI, router, tema, notificaciones
├── features/    # nutrition, exercise, water, sleep, progress, history,
│                # reports, achievements, onboarding, settings, home
└── shared/      # widgets compartidos
```

Las especificaciones y planes de diseño están en `docs/superpowers/`.

## Desarrollo

Requisitos: Flutter 3.47 o superior y el SDK de Android.

```bash
flutter pub get
dart run build_runner build --delete-conflicting-outputs   # genera el código de Drift
flutter test
```

Para compilar e instalar en un teléfono arm64:

```bash
flutter build apk --profile --target-platform android-arm64
adb install -r build/app/outputs/flutter-apk/app-profile.apk
```

> **Cuidado con la base de datos**: no instales en el teléfono una versión con un schema más viejo que el que ya tiene. Antes de instalar, respalda la base del teléfono:
> `adb exec-out run-as com.kiolog.kiolog cat app_flutter/kiolog.sqlite > kiolog-backup.sqlite`
