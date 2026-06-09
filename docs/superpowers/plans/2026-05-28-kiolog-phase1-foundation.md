# Kiolog — Phase 1: Foundation & Project Setup

> **⚠️ NOTA DE ACTUALIZACIÓN (2026-06-08):** Este documento describe la fase inicial del proyecto. Varios elementos han evolucionado desde entonces. Para el estado actual completo, ver `docs/superpowers/CONTEXT.md`.
>
> Cambios relevantes post-fase 1:
> - Schema DB: v1 → v3 (tabla `user_profiles` agregada en v2; tablas de ejercicio recreadas en v3)
> - `dayOfWeek` → `dayNumber` en rutinas de ejercicio
> - Router: `appRouter` global → `createRouter({initialLocation})` función
> - Onboarding obligatorio de 5 pasos antes de usar la app
> - `main.dart` verifica `UserProfileDao.isOnboardingComplete()` para decidir ruta inicial

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Crear el proyecto Flutter, configurar dependencias, definir el esquema completo de base de datos Drift con DAOs testeados, inyección de dependencias, tema, router y scaffold de navegación principal.

**Architecture:** BLoC + Clean Architecture por features. Esta fase no implementa ninguna feature visible — establece la fundación. Drift genera código tipado desde definiciones de tablas. get_it provee DI. go_router maneja navegación con ShellRoute para el BottomNavigationBar.

**Tech Stack:** Flutter 3.x, flutter_bloc ^8.1.6, drift ^2.18.0, sqlite3_flutter_libs, get_it ^7.7.0, go_router ^13.0.0, flutter_secure_storage ^9.0.0, equatable ^2.0.5, mocktail ^1.0.4, bloc_test ^9.1.7

---

## Fases del Proyecto (resumen)

| Fase | Contenido |
|------|-----------|
| **1 (este plan)** | Fundación: proyecto, DB schema, DAOs, DI, tema, navegación |
| 2 | Módulos Water + Sleep |
| 3 | Módulo Nutrition (plan, logging, off-plan) |
| 4 | Módulo Exercise (plan, sesiones, geo) |
| 5 | Módulo Measurements + Weight |
| 6 | Home dashboard + History + Achievements |
| 7 | Reports (PDF) + AI Integration + Notifications |

---

## Estructura de Archivos (Phase 1)

```
kiolog/
├── lib/
│   ├── core/
│   │   ├── database/
│   │   │   ├── app_database.dart
│   │   │   ├── app_database.g.dart          (generado)
│   │   │   └── tables/
│   │   │       ├── nutrition_tables.dart
│   │   │       ├── exercise_tables.dart
│   │   │       ├── water_sleep_tables.dart
│   │   │       ├── measurements_tables.dart
│   │   │       ├── achievements_tables.dart
│   │   │       └── config_tables.dart
│   │   ├── dao/
│   │   │   ├── nutrition_dao.dart
│   │   │   ├── nutrition_dao.g.dart         (generado)
│   │   │   ├── exercise_dao.dart
│   │   │   ├── exercise_dao.g.dart          (generado)
│   │   │   ├── water_sleep_dao.dart
│   │   │   ├── water_sleep_dao.g.dart       (generado)
│   │   │   ├── measurements_dao.dart
│   │   │   ├── measurements_dao.g.dart      (generado)
│   │   │   ├── config_dao.dart
│   │   │   ├── config_dao.g.dart            (generado)
│   │   │   ├── achievements_dao.dart
│   │   │   └── achievements_dao.g.dart      (generado)
│   │   ├── di/
│   │   │   └── injection.dart
│   │   ├── router/
│   │   │   └── app_router.dart
│   │   └── theme/
│   │       └── app_theme.dart
│   ├── features/
│   │   ├── home/presentation/pages/home_page.dart
│   │   ├── nutrition/presentation/pages/nutrition_page.dart
│   │   ├── exercise/presentation/pages/exercise_page.dart
│   │   ├── progress/presentation/pages/progress_page.dart
│   │   └── settings/presentation/pages/settings_page.dart
│   ├── shared/
│   │   └── widgets/
│   │       └── app_scaffold.dart
│   └── main.dart
├── test/
│   ├── helpers/
│   │   └── database_helper.dart
│   ├── dao/
│   │   ├── nutrition_dao_test.dart
│   │   ├── exercise_dao_test.dart
│   │   ├── water_sleep_dao_test.dart
│   │   ├── measurements_dao_test.dart
│   │   ├── config_dao_test.dart
│   │   └── achievements_dao_test.dart
│   └── widget/
│       └── app_scaffold_test.dart
├── pubspec.yaml
└── analysis_options.yaml
```

---

## Task 1: Crear proyecto Flutter y configurar pubspec.yaml

**Files:**
- Create: `pubspec.yaml`
- Create: `analysis_options.yaml`

- [ ] **Step 1: Crear el proyecto Flutter**

```bash
cd /home/jesuszelaya/Documents/kiolog
flutter create . --org com.kiolog --project-name kiolog --platforms android
```

Expected: `All done! Your project is ready.`

- [ ] **Step 2: Reemplazar pubspec.yaml con las dependencias completas**

```yaml
name: kiolog
description: Bitácora personal de salud — plan alimenticio, ejercicio, agua y sueño.
publish_to: 'none'
version: 1.0.0+1

environment:
  sdk: '>=3.0.0 <4.0.0'

dependencies:
  flutter:
    sdk: flutter

  # State management
  flutter_bloc: ^8.1.6
  equatable: ^2.0.5

  # Database
  drift: ^2.18.0
  sqlite3_flutter_libs: ^0.5.24
  path_provider: ^2.1.4
  path: ^1.9.0

  # DI & Navigation
  get_it: ^7.7.0
  go_router: ^13.0.0

  # Security
  flutter_secure_storage: ^9.0.0

  # Notifications
  flutter_local_notifications: ^17.0.0

  # Geolocation & Maps
  geolocator: ^12.0.0
  flutter_map: ^6.0.0
  latlong2: ^0.9.1

  # Files & Media
  file_picker: ^8.0.0
  image_picker: ^1.0.7

  # PDF & Share
  pdf: ^3.10.7
  share_plus: ^9.0.0

  # HTTP (AI providers)
  http: ^1.2.1

dev_dependencies:
  flutter_test:
    sdk: flutter
  drift_dev: ^2.18.0
  build_runner: ^2.4.9
  flutter_lints: ^4.0.0
  bloc_test: ^9.1.7
  mocktail: ^1.0.4

flutter:
  uses-material-design: true
```

- [ ] **Step 3: Instalar dependencias**

```bash
flutter pub get
```

Expected: `Got dependencies!` sin errores.

- [ ] **Step 4: Configurar minSdkVersion en Android**

En `android/app/build.gradle`, verificar que `minSdkVersion` sea al menos 21:

```gradle
android {
    defaultConfig {
        minSdkVersion 21
        targetSdkVersion 34
    }
}
```

- [ ] **Step 5: Agregar permisos de geolocalización al AndroidManifest**

En `android/app/src/main/AndroidManifest.xml`, dentro de `<manifest>`:

```xml
<uses-permission android:name="android.permission.ACCESS_FINE_LOCATION" />
<uses-permission android:name="android.permission.ACCESS_COARSE_LOCATION" />
<uses-permission android:name="android.permission.RECEIVE_BOOT_COMPLETED"/>
<uses-permission android:name="android.permission.VIBRATE" />
```

- [ ] **Step 6: Commit**

```bash
git init
git add pubspec.yaml pubspec.lock android/app/build.gradle android/app/src/main/AndroidManifest.xml
git commit -m "chore: initial Flutter project setup with all dependencies"
```

---

## Task 2: Crear estructura de carpetas y .gitignore

**Files:**
- Create: `.gitignore`
- Create: todos los directorios del proyecto

- [ ] **Step 1: Crear estructura de carpetas**

```bash
mkdir -p lib/core/database/tables
mkdir -p lib/core/dao
mkdir -p lib/core/di
mkdir -p lib/core/router
mkdir -p lib/core/theme
mkdir -p lib/features/home/presentation/pages
mkdir -p lib/features/nutrition/presentation/pages
mkdir -p lib/features/exercise/presentation/pages
mkdir -p lib/features/progress/presentation/pages
mkdir -p lib/features/settings/presentation/pages
mkdir -p lib/shared/widgets
mkdir -p test/helpers
mkdir -p test/dao
mkdir -p test/widget
```

- [ ] **Step 2: Actualizar .gitignore para excluir archivos sensibles y de build**

Agregar al `.gitignore` existente:

```gitignore
# Flutter/Dart
*.g.dart
*.freezed.dart
.dart_tool/
.flutter-plugins
.flutter-plugins-dependencies
build/
.packages

# Android
android/.gradle
android/local.properties
android/captures/
*.keystore
*.jks

# IDE
.vscode/
.idea/
*.iml

# Env / secretos
.env
*.env.local
```

- [ ] **Step 3: Commit**

```bash
git add .gitignore
git commit -m "chore: project folder structure and gitignore"
```

---

## Task 3: Definir tablas Drift — Nutrition

**Files:**
- Create: `lib/core/database/tables/nutrition_tables.dart`

- [ ] **Step 1: Crear las tablas de nutrición**

```dart
// lib/core/database/tables/nutrition_tables.dart
import 'package:drift/drift.dart';

class MealPlans extends Table {
  IntColumn get id => integer().autoIncrement()();
  TextColumn get name => text()();
  DateTimeColumn get createdAt => dateTime()();
  BoolColumn get isActive => boolean().withDefault(const Constant(true))();
}

class MealPlanOptions extends Table {
  IntColumn get id => integer().autoIncrement()();
  IntColumn get planId => integer().references(MealPlans, #id)();
  // meal_type: breakfast | lunch | dinner | snack
  TextColumn get mealType => text()();
  // 1, 2 o 3
  IntColumn get optionNumber => integer()();
  TextColumn get description => text()();
}

class DailyMealLogs extends Table {
  IntColumn get id => integer().autoIncrement()();
  DateTimeColumn get date => dateTime()();
  TextColumn get mealType => text()();
  // null indica comida fuera del plan
  IntColumn get planOptionId => integer().nullable().references(MealPlanOptions, #id)();
  TextColumn get freeDescription => text().nullable()();
  TextColumn get photoPath => text().nullable()();
}
```

- [ ] **Step 2: Commit**

```bash
git add lib/core/database/tables/nutrition_tables.dart
git commit -m "feat: define Drift nutrition tables"
```

---

## Task 4: Definir tablas Drift — Exercise

**Files:**
- Create: `lib/core/database/tables/exercise_tables.dart`

- [ ] **Step 1: Crear las tablas de ejercicio**

```dart
// lib/core/database/tables/exercise_tables.dart
import 'package:drift/drift.dart';

class ExercisePlans extends Table {
  IntColumn get id => integer().autoIncrement()();
  TextColumn get name => text()();
  DateTimeColumn get createdAt => dateTime()();
  BoolColumn get isActive => boolean().withDefault(const Constant(true))();
}

class ExerciseRoutines extends Table {
  IntColumn get id => integer().autoIncrement()();
  IntColumn get planId => integer().references(ExercisePlans, #id)();
  // 1=Lunes, 7=Domingo
  IntColumn get dayOfWeek => integer()();
  TextColumn get routineName => text()();
  TextColumn get notes => text().nullable()();
}

class ExerciseRoutineItems extends Table {
  IntColumn get id => integer().autoIncrement()();
  IntColumn get routineId => integer().references(ExerciseRoutines, #id)();
  TextColumn get exerciseName => text()();
  IntColumn get sets => integer()();
  IntColumn get reps => integer()();
  RealColumn get weightKg => real().nullable()();
}

class DailyExerciseLogs extends Table {
  IntColumn get id => integer().autoIncrement()();
  DateTimeColumn get date => dateTime()();
  IntColumn get routineId => integer().references(ExerciseRoutines, #id)();
  BoolColumn get completed => boolean().withDefault(const Constant(false))();
}

class ExerciseSessionLogs extends Table {
  IntColumn get id => integer().autoIncrement()();
  DateTimeColumn get date => dateTime()();
  DateTimeColumn get gymArrivedAt => dateTime()();
  DateTimeColumn get gymLeftAt => dateTime().nullable()();
  RealColumn get lat => real().nullable()();
  RealColumn get lng => real().nullable()();
}

class ExerciseSetLogs extends Table {
  IntColumn get id => integer().autoIncrement()();
  IntColumn get sessionId => integer().references(ExerciseSessionLogs, #id)();
  TextColumn get exerciseName => text()();
  IntColumn get setNumber => integer()();
  IntColumn get reps => integer()();
  RealColumn get weightKg => real()();
}
```

- [ ] **Step 2: Commit**

```bash
git add lib/core/database/tables/exercise_tables.dart
git commit -m "feat: define Drift exercise tables"
```

---

## Task 5: Definir tablas Drift — Water, Sleep

**Files:**
- Create: `lib/core/database/tables/water_sleep_tables.dart`

- [ ] **Step 1: Crear las tablas de agua y sueño**

```dart
// lib/core/database/tables/water_sleep_tables.dart
import 'package:drift/drift.dart';

class DailyWaterLogs extends Table {
  IntColumn get id => integer().autoIncrement()();
  DateTimeColumn get date => dateTime()();
  DateTimeColumn get timestamp => dateTime()();
  IntColumn get amountMl => integer()();
}

class SleepLogs extends Table {
  IntColumn get id => integer().autoIncrement()();
  DateTimeColumn get date => dateTime()();
  DateTimeColumn get sleepTime => dateTime()();
  DateTimeColumn get wakeTime => dateTime()();
  RealColumn get hoursCalculated => real()();
}
```

- [ ] **Step 2: Commit**

```bash
git add lib/core/database/tables/water_sleep_tables.dart
git commit -m "feat: define Drift water and sleep tables"
```

---

## Task 6: Definir tablas Drift — Measurements, Weight, Achievements, Config

**Files:**
- Create: `lib/core/database/tables/measurements_tables.dart`
- Create: `lib/core/database/tables/achievements_tables.dart`
- Create: `lib/core/database/tables/config_tables.dart`

- [ ] **Step 1: Crear tablas de medidas y peso**

```dart
// lib/core/database/tables/measurements_tables.dart
import 'package:drift/drift.dart';

class WeightLogs extends Table {
  IntColumn get id => integer().autoIncrement()();
  DateTimeColumn get date => dateTime()();
  RealColumn get weightKg => real()();
}

// Append-only: cada consulta agrega un registro nuevo
class Measurements extends Table {
  IntColumn get id => integer().autoIncrement()();
  DateTimeColumn get date => dateTime()();
  RealColumn get weightKg => real()();
  RealColumn get heightCm => real()();
  RealColumn get armFlexedCm => real().nullable()();
  RealColumn get armRelaxedCm => real().nullable()();
  RealColumn get waistCm => real().nullable()();
  RealColumn get hipCm => real().nullable()();
  RealColumn get calfCm => real().nullable()();
  RealColumn get lowerAbdomenCm => real().nullable()();
  RealColumn get thighCm => real().nullable()();
  RealColumn get midGluteusCm => real().nullable()();
  RealColumn get chestCm => real().nullable()();
  RealColumn get bodyFatPct => real().nullable()();
  RealColumn get leanMassKg => real().nullable()();
  RealColumn get visceralMass => real().nullable()();
}
```

- [ ] **Step 1b: Crear tabla de logros en su propio archivo**

```dart
// lib/core/database/tables/achievements_tables.dart
import 'package:drift/drift.dart';

class Achievements extends Table {
  IntColumn get id => integer().autoIncrement()();
  // Identificador único, ej: 'water_30_days_total'
  TextColumn get key => text().unique()();
  TextColumn get title => text()();
  TextColumn get description => text()();
  // nutrition | exercise | water | sleep | general
  TextColumn get module => text()();
  BoolColumn get isUnlocked => boolean().withDefault(const Constant(false))();
  DateTimeColumn get unlockedAt => dateTime().nullable()();
}
```

- [ ] **Step 2: Crear tablas de configuración**

```dart
// lib/core/database/tables/config_tables.dart
import 'package:drift/drift.dart';

class WaterConfig extends Table {
  IntColumn get id => integer().autoIncrement()();
  // bottle | glass
  TextColumn get unitType => text().withDefault(const Constant('bottle'))();
  IntColumn get containerMl => integer().withDefault(const Constant(1000))();
  IntColumn get dailyGoalMl => integer().withDefault(const Constant(3000))();
}

class GymConfig extends Table {
  IntColumn get id => integer().autoIncrement()();
  TextColumn get name => text()();
  RealColumn get lat => real()();
  RealColumn get lng => real()();
  IntColumn get proximityRadiusM => integer().withDefault(const Constant(100))();
  BoolColumn get proximityEnabled => boolean().withDefault(const Constant(false))();
}

class NotificationSettings extends Table {
  IntColumn get id => integer().autoIncrement()();
  // nutrition | water | sleep | exercise
  TextColumn get module => text()();
  BoolColumn get enabled => boolean().withDefault(const Constant(false))();
  IntColumn get hour => integer()();
  IntColumn get minute => integer()();
  // fixed_time | interval
  // agua usa interval, los demás usan fixed_time
  TextColumn get reminderType =>
      text().withDefault(const Constant('fixed_time'))();
  IntColumn get intervalMinutes => integer().nullable()();
}

class AiConfig extends Table {
  IntColumn get id => integer().autoIncrement()();
  // claude | gemini | openai | manual
  TextColumn get provider => text().withDefault(const Constant('manual'))();
  // Guardado cifrado vía flutter_secure_storage (el campo aquí es solo referencia)
  TextColumn get providerModel => text().nullable()();
}
```

- [ ] **Step 3: Commit**

```bash
git add lib/core/database/tables/measurements_tables.dart lib/core/database/tables/achievements_tables.dart lib/core/database/tables/config_tables.dart
git commit -m "feat: define Drift measurements, achievements, and config tables"
```

---

## Task 7: Crear AppDatabase y generar código Drift

**Files:**
- Create: `lib/core/database/app_database.dart`

- [ ] **Step 1: Crear AppDatabase con todas las tablas**

```dart
// lib/core/database/app_database.dart
import 'dart:io';

import 'package:drift/drift.dart';
import 'package:drift/native.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

import 'tables/nutrition_tables.dart';
import 'tables/exercise_tables.dart';
import 'tables/water_sleep_tables.dart';
import 'tables/measurements_tables.dart';
import 'tables/achievements_tables.dart';
import 'tables/config_tables.dart';

import '../dao/nutrition_dao.dart';
import '../dao/exercise_dao.dart';
import '../dao/water_sleep_dao.dart';
import '../dao/measurements_dao.dart';
import '../dao/config_dao.dart';
import '../dao/achievements_dao.dart';

part 'app_database.g.dart';

@DriftDatabase(
  tables: [
    // Nutrition
    MealPlans,
    MealPlanOptions,
    DailyMealLogs,
    // Exercise
    ExercisePlans,
    ExerciseRoutines,
    ExerciseRoutineItems,
    DailyExerciseLogs,
    ExerciseSessionLogs,
    ExerciseSetLogs,
    // Water & Sleep
    DailyWaterLogs,
    SleepLogs,
    // Measurements
    WeightLogs,
    Measurements,
    Achievements,
    // Config
    WaterConfig,
    GymConfig,
    NotificationSettings,
    AiConfig,
  ],
  daos: [
    NutritionDao,
    ExerciseDao,
    WaterSleepDao,
    MeasurementsDao,
    ConfigDao,
    AchievementsDao,
  ],
)
class AppDatabase extends _$AppDatabase {
  AppDatabase() : super(_openConnection());

  // Constructor para tests — usa base de datos en memoria
  AppDatabase.forTesting(super.executor);

  @override
  int get schemaVersion => 1;
}

LazyDatabase _openConnection() {
  return LazyDatabase(() async {
    final dir = await getApplicationDocumentsDirectory();
    final file = File(p.join(dir.path, 'kiolog.sqlite'));
    return NativeDatabase.createInBackground(file);
  });
}
```

- [ ] **Step 2: Crear archivos DAO vacíos para que compile antes de la generación**

```dart
// lib/core/dao/nutrition_dao.dart
import 'package:drift/drift.dart';
import '../database/app_database.dart';
import '../database/tables/nutrition_tables.dart';

part 'nutrition_dao.g.dart';

@DriftAccessor(tables: [MealPlans, MealPlanOptions, DailyMealLogs])
class NutritionDao extends DatabaseAccessor<AppDatabase>
    with _$NutritionDaoMixin {
  NutritionDao(super.db);
}
```

```dart
// lib/core/dao/exercise_dao.dart
import 'package:drift/drift.dart';
import '../database/app_database.dart';
import '../database/tables/exercise_tables.dart';

part 'exercise_dao.g.dart';

@DriftAccessor(tables: [
  ExercisePlans,
  ExerciseRoutines,
  ExerciseRoutineItems,
  DailyExerciseLogs,
  ExerciseSessionLogs,
  ExerciseSetLogs,
])
class ExerciseDao extends DatabaseAccessor<AppDatabase>
    with _$ExerciseDaoMixin {
  ExerciseDao(super.db);
}
```

```dart
// lib/core/dao/water_sleep_dao.dart
import 'package:drift/drift.dart';
import '../database/app_database.dart';
import '../database/tables/water_sleep_tables.dart';

part 'water_sleep_dao.g.dart';

@DriftAccessor(tables: [DailyWaterLogs, SleepLogs])
class WaterSleepDao extends DatabaseAccessor<AppDatabase>
    with _$WaterSleepDaoMixin {
  WaterSleepDao(super.db);
}
```

```dart
// lib/core/dao/measurements_dao.dart
import 'package:drift/drift.dart';
import '../database/app_database.dart';
import '../database/tables/measurements_tables.dart';

part 'measurements_dao.g.dart';

@DriftAccessor(tables: [WeightLogs, Measurements])
class MeasurementsDao extends DatabaseAccessor<AppDatabase>
    with _$MeasurementsDaoMixin {
  MeasurementsDao(super.db);
}
```

```dart
// lib/core/dao/config_dao.dart
import 'package:drift/drift.dart';
import '../database/app_database.dart';
import '../database/tables/config_tables.dart';

part 'config_dao.g.dart';

@DriftAccessor(tables: [WaterConfig, GymConfig, NotificationSettings, AiConfig])
class ConfigDao extends DatabaseAccessor<AppDatabase> with _$ConfigDaoMixin {
  ConfigDao(super.db);
}
```

```dart
// lib/core/dao/achievements_dao.dart
import 'package:drift/drift.dart';
import '../database/app_database.dart';
import '../database/tables/achievements_tables.dart';

part 'achievements_dao.g.dart';

@DriftAccessor(tables: [Achievements])
class AchievementsDao extends DatabaseAccessor<AppDatabase>
    with _$AchievementsDaoMixin {
  AchievementsDao(super.db);
}
```

- [ ] **Step 3: Ejecutar generación de código Drift**

```bash
dart run build_runner build --delete-conflicting-outputs
```

Expected: `[INFO] build_runner Succeeded after ...` sin errores. Verifica que existan los archivos `.g.dart`:

```bash
ls lib/core/database/app_database.g.dart lib/core/dao/*.g.dart
```

- [ ] **Step 4: Verificar que el proyecto compila**

```bash
flutter build apk --debug 2>&1 | tail -5
```

Expected: `✓ Built build/app/outputs/flutter-apk/app-debug.apk`

- [ ] **Step 5: Commit**

```bash
git add lib/core/database/ lib/core/dao/
git commit -m "feat: AppDatabase with all Drift tables and DAO stubs — code generated"
```

---

## Task 8: Helper de base de datos para tests

**Files:**
- Create: `test/helpers/database_helper.dart`

- [ ] **Step 1: Crear helper de DB en memoria**

```dart
// test/helpers/database_helper.dart
import 'package:drift/native.dart';
import 'package:kiolog/core/database/app_database.dart';

AppDatabase createTestDatabase() =>
    AppDatabase.forTesting(NativeDatabase.memory());
```

- [ ] **Step 2: Verificar que el helper importa correctamente**

```bash
dart analyze test/helpers/database_helper.dart
```

Expected: `No issues found!`

- [ ] **Step 3: Commit**

```bash
git add test/helpers/database_helper.dart
git commit -m "test: add in-memory database helper for DAO tests"
```

---

## Task 9: NutritionDao — métodos y tests

**Files:**
- Modify: `lib/core/dao/nutrition_dao.dart`
- Create: `test/dao/nutrition_dao_test.dart`

- [ ] **Step 1: Escribir tests que fallan**

```dart
// test/dao/nutrition_dao_test.dart
import 'package:flutter_test/flutter_test.dart';
import 'package:drift/drift.dart';
import 'package:kiolog/core/database/app_database.dart';
import '../helpers/database_helper.dart';

void main() {
  late AppDatabase db;

  setUp(() => db = createTestDatabase());
  tearDown(() async => db.close());

  group('NutritionDao - MealPlans', () {
    test('inserta y recupera un plan', () async {
      final id = await db.nutritionDao.insertMealPlan(
        const MealPlansCompanion(
          name: Value('Plan Enero'),
          createdAt: Value(DateTime(2026, 1, 1)),
        ),
      );

      final plans = await db.nutritionDao.getMealPlans();
      expect(plans.length, 1);
      expect(plans.first.id, id);
      expect(plans.first.name, 'Plan Enero');
      expect(plans.first.isActive, true);
    });

    test('setActivePlan desactiva los planes anteriores', () async {
      final id1 = await db.nutritionDao.insertMealPlan(
        const MealPlansCompanion(
          name: Value('Plan A'),
          createdAt: Value(DateTime(2026, 1, 1)),
        ),
      );
      final id2 = await db.nutritionDao.insertMealPlan(
        const MealPlansCompanion(
          name: Value('Plan B'),
          createdAt: Value(DateTime(2026, 2, 1)),
        ),
      );

      await db.nutritionDao.setActivePlan(id2);

      final plans = await db.nutritionDao.getMealPlans();
      final planA = plans.firstWhere((p) => p.id == id1);
      final planB = plans.firstWhere((p) => p.id == id2);
      expect(planA.isActive, false);
      expect(planB.isActive, true);
    });
  });

  group('NutritionDao - MealPlanOptions', () {
    test('inserta y recupera opciones del plan', () async {
      final planId = await db.nutritionDao.insertMealPlan(
        const MealPlansCompanion(
          name: Value('Plan Test'),
          createdAt: Value(DateTime(2026, 1, 1)),
        ),
      );

      await db.nutritionDao.insertMealPlanOption(
        MealPlanOptionsCompanion(
          planId: Value(planId),
          mealType: const Value('breakfast'),
          optionNumber: const Value(1),
          description: const Value('Avena con frutas'),
        ),
      );

      final options =
          await db.nutritionDao.getMealPlanOptions(planId, 'breakfast');
      expect(options.length, 1);
      expect(options.first.description, 'Avena con frutas');
    });
  });

  group('NutritionDao - DailyMealLogs', () {
    test('registra comida del plan', () async {
      final planId = await db.nutritionDao.insertMealPlan(
        const MealPlansCompanion(
          name: Value('Plan'),
          createdAt: Value(DateTime(2026, 1, 1)),
        ),
      );
      final optionId = await db.nutritionDao.insertMealPlanOption(
        MealPlanOptionsCompanion(
          planId: Value(planId),
          mealType: const Value('lunch'),
          optionNumber: const Value(2),
          description: const Value('Pollo con arroz'),
        ),
      );

      await db.nutritionDao.insertDailyMealLog(
        DailyMealLogsCompanion(
          date: Value(DateTime(2026, 5, 28)),
          mealType: const Value('lunch'),
          planOptionId: Value(optionId),
        ),
      );

      final logs =
          await db.nutritionDao.getDailyMealLogs(DateTime(2026, 5, 28));
      expect(logs.length, 1);
      expect(logs.first.planOptionId, optionId);
      expect(logs.first.freeDescription, null);
    });

    test('registra comida fuera del plan con descripción', () async {
      await db.nutritionDao.insertDailyMealLog(
        const DailyMealLogsCompanion(
          date: Value(DateTime(2026, 5, 28)),
          mealType: Value('dinner'),
          freeDescription: Value('Pizza con amigos'),
        ),
      );

      final logs =
          await db.nutritionDao.getDailyMealLogs(DateTime(2026, 5, 28));
      expect(logs.first.planOptionId, null);
      expect(logs.first.freeDescription, 'Pizza con amigos');
    });
  });
}
```

- [ ] **Step 2: Ejecutar tests para verificar que fallan**

```bash
flutter test test/dao/nutrition_dao_test.dart
```

Expected: FAIL — métodos no existen en NutritionDao.

- [ ] **Step 3: Implementar NutritionDao**

```dart
// lib/core/dao/nutrition_dao.dart
import 'package:drift/drift.dart';
import '../database/app_database.dart';
import '../database/tables/nutrition_tables.dart';

part 'nutrition_dao.g.dart';

@DriftAccessor(tables: [MealPlans, MealPlanOptions, DailyMealLogs])
class NutritionDao extends DatabaseAccessor<AppDatabase>
    with _$NutritionDaoMixin {
  NutritionDao(super.db);

  Future<int> insertMealPlan(MealPlansCompanion plan) =>
      into(mealPlans).insert(plan.copyWith(
        createdAt: plan.createdAt.present
            ? plan.createdAt
            : Value(DateTime.now()),
        isActive: const Value(true),
      ));

  Future<List<MealPlan>> getMealPlans() =>
      (select(mealPlans)..orderBy([(t) => OrderingTerm.desc(t.createdAt)]))
          .get();

  Future<MealPlan?> getActiveMealPlan() =>
      (select(mealPlans)..where((t) => t.isActive.equals(true)))
          .getSingleOrNull();

  Future<void> setActivePlan(int planId) async {
    await (update(mealPlans)).write(const MealPlansCompanion(
      isActive: Value(false),
    ));
    await (update(mealPlans)..where((t) => t.id.equals(planId)))
        .write(const MealPlansCompanion(isActive: Value(true)));
  }

  Future<int> insertMealPlanOption(MealPlanOptionsCompanion option) =>
      into(mealPlanOptions).insert(option);

  Future<List<MealPlanOption>> getMealPlanOptions(
          int planId, String mealType) =>
      (select(mealPlanOptions)
            ..where((t) =>
                t.planId.equals(planId) & t.mealType.equals(mealType))
            ..orderBy([(t) => OrderingTerm.asc(t.optionNumber)]))
          .get();

  Future<int> insertDailyMealLog(DailyMealLogsCompanion log) =>
      into(dailyMealLogs).insert(log);

  Future<List<DailyMealLog>> getDailyMealLogs(DateTime date) {
    final start = DateTime(date.year, date.month, date.day);
    final end = start.add(const Duration(days: 1));
    return (select(dailyMealLogs)
          ..where((t) =>
              t.date.isBiggerOrEqualValue(start) &
              t.date.isSmallerThanValue(end)))
        .get();
  }
}
```

- [ ] **Step 4: Regenerar código y ejecutar tests**

```bash
dart run build_runner build --delete-conflicting-outputs
flutter test test/dao/nutrition_dao_test.dart
```

Expected: All tests PASS.

- [ ] **Step 5: Commit**

```bash
git add lib/core/dao/nutrition_dao.dart lib/core/dao/nutrition_dao.g.dart test/dao/nutrition_dao_test.dart
git commit -m "feat: NutritionDao with meal plan versioning and daily meal logging"
```

---

## Task 10: ExerciseDao — métodos y tests

**Files:**
- Modify: `lib/core/dao/exercise_dao.dart`
- Create: `test/dao/exercise_dao_test.dart`

- [ ] **Step 1: Escribir tests que fallan**

```dart
// test/dao/exercise_dao_test.dart
import 'package:flutter_test/flutter_test.dart';
import 'package:drift/drift.dart';
import 'package:kiolog/core/database/app_database.dart';
import '../helpers/database_helper.dart';

void main() {
  late AppDatabase db;

  setUp(() => db = createTestDatabase());
  tearDown(() async => db.close());

  group('ExerciseDao - Plans', () {
    test('inserta plan y obtiene el activo', () async {
      await db.exerciseDao.insertExercisePlan(
        const ExercisePlansCompanion(name: Value('Plan Gym Enero')),
      );

      final active = await db.exerciseDao.getActiveExercisePlan();
      expect(active?.name, 'Plan Gym Enero');
      expect(active?.isActive, true);
    });

    test('setActivePlan desactiva planes anteriores', () async {
      final id1 = await db.exerciseDao.insertExercisePlan(
        const ExercisePlansCompanion(name: Value('Plan A')),
      );
      final id2 = await db.exerciseDao.insertExercisePlan(
        const ExercisePlansCompanion(name: Value('Plan B')),
      );

      await db.exerciseDao.setActiveExercisePlan(id2);

      final plans = await db.exerciseDao.getExercisePlans();
      expect(plans.firstWhere((p) => p.id == id1).isActive, false);
      expect(plans.firstWhere((p) => p.id == id2).isActive, true);
    });
  });

  group('ExerciseDao - Routines & Items', () {
    test('inserta rutina e items, recupera por día', () async {
      final planId = await db.exerciseDao.insertExercisePlan(
        const ExercisePlansCompanion(name: Value('Plan')),
      );
      final routineId = await db.exerciseDao.insertExerciseRoutine(
        ExerciseRoutinesCompanion(
          planId: Value(planId),
          dayOfWeek: const Value(1), // Lunes
          routineName: const Value('Pecho y Tríceps'),
        ),
      );
      await db.exerciseDao.insertExerciseRoutineItem(
        ExerciseRoutineItemsCompanion(
          routineId: Value(routineId),
          exerciseName: const Value('Press de Banca'),
          sets: const Value(4),
          reps: const Value(10),
          weightKg: const Value(60.0),
        ),
      );

      final routine =
          await db.exerciseDao.getRoutineForDay(planId, 1);
      expect(routine?.routineName, 'Pecho y Tríceps');

      final items = await db.exerciseDao.getRoutineItems(routineId);
      expect(items.length, 1);
      expect(items.first.exerciseName, 'Press de Banca');
      expect(items.first.sets, 4);
    });
  });

  group('ExerciseDao - Sessions & Sets', () {
    test('crea sesión y registra series', () async {
      final sessionId = await db.exerciseDao.insertExerciseSession(
        ExerciseSessionLogsCompanion(
          date: Value(DateTime(2026, 5, 28)),
          gymArrivedAt: Value(DateTime(2026, 5, 28, 8, 0)),
        ),
      );

      await db.exerciseDao.insertExerciseSetLog(
        ExerciseSetLogsCompanion(
          sessionId: Value(sessionId),
          exerciseName: const Value('Sentadillas'),
          setNumber: const Value(1),
          reps: const Value(12),
          weightKg: const Value(80.0),
        ),
      );

      final sets = await db.exerciseDao.getSessionSets(sessionId);
      expect(sets.length, 1);
      expect(sets.first.weightKg, 80.0);
    });

    test('actualiza hora de salida de la sesión', () async {
      final sessionId = await db.exerciseDao.insertExerciseSession(
        ExerciseSessionLogsCompanion(
          date: Value(DateTime(2026, 5, 28)),
          gymArrivedAt: Value(DateTime(2026, 5, 28, 8, 0)),
        ),
      );

      await db.exerciseDao.updateSessionEndTime(
          sessionId, DateTime(2026, 5, 28, 9, 30));

      final session =
          await db.exerciseDao.getSession(sessionId);
      expect(session?.gymLeftAt, DateTime(2026, 5, 28, 9, 30));
    });
  });
}
```

- [ ] **Step 2: Ejecutar para verificar que fallan**

```bash
flutter test test/dao/exercise_dao_test.dart
```

Expected: FAIL.

- [ ] **Step 3: Implementar ExerciseDao**

```dart
// lib/core/dao/exercise_dao.dart
import 'package:drift/drift.dart';
import '../database/app_database.dart';
import '../database/tables/exercise_tables.dart';

part 'exercise_dao.g.dart';

@DriftAccessor(tables: [
  ExercisePlans,
  ExerciseRoutines,
  ExerciseRoutineItems,
  DailyExerciseLogs,
  ExerciseSessionLogs,
  ExerciseSetLogs,
])
class ExerciseDao extends DatabaseAccessor<AppDatabase>
    with _$ExerciseDaoMixin {
  ExerciseDao(super.db);

  Future<int> insertExercisePlan(ExercisePlansCompanion plan) =>
      into(exercisePlans).insert(plan.copyWith(
        createdAt: plan.createdAt.present
            ? plan.createdAt
            : Value(DateTime.now()),
        isActive: const Value(true),
      ));

  Future<List<ExercisePlan>> getExercisePlans() =>
      (select(exercisePlans)
            ..orderBy([(t) => OrderingTerm.desc(t.createdAt)]))
          .get();

  Future<ExercisePlan?> getActiveExercisePlan() =>
      (select(exercisePlans)..where((t) => t.isActive.equals(true)))
          .getSingleOrNull();

  Future<void> setActiveExercisePlan(int planId) async {
    await (update(exercisePlans))
        .write(const ExercisePlansCompanion(isActive: Value(false)));
    await (update(exercisePlans)..where((t) => t.id.equals(planId)))
        .write(const ExercisePlansCompanion(isActive: Value(true)));
  }

  Future<int> insertExerciseRoutine(ExerciseRoutinesCompanion routine) =>
      into(exerciseRoutines).insert(routine);

  Future<ExerciseRoutine?> getRoutineForDay(int planId, int dayOfWeek) =>
      (select(exerciseRoutines)
            ..where((t) =>
                t.planId.equals(planId) & t.dayOfWeek.equals(dayOfWeek)))
          .getSingleOrNull();

  Future<int> insertExerciseRoutineItem(
          ExerciseRoutineItemsCompanion item) =>
      into(exerciseRoutineItems).insert(item);

  Future<List<ExerciseRoutineItem>> getRoutineItems(int routineId) =>
      (select(exerciseRoutineItems)
            ..where((t) => t.routineId.equals(routineId)))
          .get();

  Future<int> insertExerciseSession(ExerciseSessionLogsCompanion session) =>
      into(exerciseSessionLogs).insert(session);

  Future<ExerciseSessionLog?> getSession(int sessionId) =>
      (select(exerciseSessionLogs)..where((t) => t.id.equals(sessionId)))
          .getSingleOrNull();

  Future<void> updateSessionEndTime(int sessionId, DateTime endTime) =>
      (update(exerciseSessionLogs)..where((t) => t.id.equals(sessionId)))
          .write(ExerciseSessionLogsCompanion(gymLeftAt: Value(endTime)));

  Future<int> insertExerciseSetLog(ExerciseSetLogsCompanion setLog) =>
      into(exerciseSetLogs).insert(setLog);

  Future<List<ExerciseSetLog>> getSessionSets(int sessionId) =>
      (select(exerciseSetLogs)
            ..where((t) => t.sessionId.equals(sessionId))
            ..orderBy([(t) => OrderingTerm.asc(t.setNumber)]))
          .get();

  Future<int> insertDailyExerciseLog(DailyExerciseLogsCompanion log) =>
      into(dailyExerciseLogs).insert(log);
}
```

- [ ] **Step 4: Regenerar y ejecutar tests**

```bash
dart run build_runner build --delete-conflicting-outputs
flutter test test/dao/exercise_dao_test.dart
```

Expected: All PASS.

- [ ] **Step 5: Commit**

```bash
git add lib/core/dao/exercise_dao.dart lib/core/dao/exercise_dao.g.dart test/dao/exercise_dao_test.dart
git commit -m "feat: ExerciseDao with plan versioning, routines, sessions and set tracking"
```

---

## Task 11: WaterSleepDao — métodos y tests

**Files:**
- Modify: `lib/core/dao/water_sleep_dao.dart`
- Create: `test/dao/water_sleep_dao_test.dart`

- [ ] **Step 1: Escribir tests que fallan**

```dart
// test/dao/water_sleep_dao_test.dart
import 'package:flutter_test/flutter_test.dart';
import 'package:drift/drift.dart';
import 'package:kiolog/core/database/app_database.dart';
import '../helpers/database_helper.dart';

void main() {
  late AppDatabase db;

  setUp(() => db = createTestDatabase());
  tearDown(() async => db.close());

  group('WaterSleepDao - Water', () {
    test('registra ingesta y calcula total diario', () async {
      final date = DateTime(2026, 5, 28);
      await db.waterSleepDao.insertWaterLog(DailyWaterLogsCompanion(
        date: Value(date),
        timestamp: Value(DateTime(2026, 5, 28, 9, 0)),
        amountMl: const Value(1000),
      ));
      await db.waterSleepDao.insertWaterLog(DailyWaterLogsCompanion(
        date: Value(date),
        timestamp: Value(DateTime(2026, 5, 28, 13, 0)),
        amountMl: const Value(1000),
      ));

      final total = await db.waterSleepDao.getDailyWaterTotalMl(date);
      expect(total, 2000);
    });

    test('total es 0 si no hay logs', () async {
      final total =
          await db.waterSleepDao.getDailyWaterTotalMl(DateTime(2026, 5, 28));
      expect(total, 0);
    });
  });

  group('WaterSleepDao - Sleep', () {
    test('registra sueño y calcula horas', () async {
      final sleepTime = DateTime(2026, 5, 27, 22, 30);
      final wakeTime = DateTime(2026, 5, 28, 6, 30);
      final hours = wakeTime.difference(sleepTime).inMinutes / 60;

      await db.waterSleepDao.insertSleepLog(SleepLogsCompanion(
        date: Value(DateTime(2026, 5, 28)),
        sleepTime: Value(sleepTime),
        wakeTime: Value(wakeTime),
        hoursCalculated: Value(hours),
      ));

      final log =
          await db.waterSleepDao.getSleepLog(DateTime(2026, 5, 28));
      expect(log?.hoursCalculated, 8.0);
    });

    test('getWeeklySleepLogs retorna logs del rango', () async {
      for (int i = 0; i < 7; i++) {
        final date = DateTime(2026, 5, 22 + i);
        await db.waterSleepDao.insertSleepLog(SleepLogsCompanion(
          date: Value(date),
          sleepTime: Value(date.subtract(const Duration(hours: 8))),
          wakeTime: Value(date),
          hoursCalculated: const Value(8.0),
        ));
      }

      final logs = await db.waterSleepDao.getWeeklySleepLogs(
        DateTime(2026, 5, 22),
        DateTime(2026, 5, 28),
      );
      expect(logs.length, 7);
    });
  });
}
```

- [ ] **Step 2: Ejecutar para verificar que fallan**

```bash
flutter test test/dao/water_sleep_dao_test.dart
```

Expected: FAIL.

- [ ] **Step 3: Implementar WaterSleepDao**

```dart
// lib/core/dao/water_sleep_dao.dart
import 'package:drift/drift.dart';
import '../database/app_database.dart';
import '../database/tables/water_sleep_tables.dart';

part 'water_sleep_dao.g.dart';

@DriftAccessor(tables: [DailyWaterLogs, SleepLogs])
class WaterSleepDao extends DatabaseAccessor<AppDatabase>
    with _$WaterSleepDaoMixin {
  WaterSleepDao(super.db);

  Future<void> insertWaterLog(DailyWaterLogsCompanion log) =>
      into(dailyWaterLogs).insert(log);

  Future<List<DailyWaterLog>> getDailyWaterLogs(DateTime date) {
    final start = DateTime(date.year, date.month, date.day);
    final end = start.add(const Duration(days: 1));
    return (select(dailyWaterLogs)
          ..where((t) =>
              t.date.isBiggerOrEqualValue(start) &
              t.date.isSmallerThanValue(end)))
        .get();
  }

  Future<int> getDailyWaterTotalMl(DateTime date) async {
    final logs = await getDailyWaterLogs(date);
    return logs.fold(0, (sum, log) => sum + log.amountMl);
  }

  Future<void> insertSleepLog(SleepLogsCompanion log) =>
      into(sleepLogs).insert(log);

  Future<SleepLog?> getSleepLog(DateTime date) {
    final start = DateTime(date.year, date.month, date.day);
    final end = start.add(const Duration(days: 1));
    return (select(sleepLogs)
          ..where((t) =>
              t.date.isBiggerOrEqualValue(start) &
              t.date.isSmallerThanValue(end)))
        .getSingleOrNull();
  }

  Future<List<SleepLog>> getWeeklySleepLogs(
      DateTime startDate, DateTime endDate) {
    final start = DateTime(startDate.year, startDate.month, startDate.day);
    final end = DateTime(endDate.year, endDate.month, endDate.day)
        .add(const Duration(days: 1));
    return (select(sleepLogs)
          ..where((t) =>
              t.date.isBiggerOrEqualValue(start) &
              t.date.isSmallerThanValue(end))
          ..orderBy([(t) => OrderingTerm.asc(t.date)]))
        .get();
  }
}
```

- [ ] **Step 4: Regenerar y ejecutar tests**

```bash
dart run build_runner build --delete-conflicting-outputs
flutter test test/dao/water_sleep_dao_test.dart
```

Expected: All PASS.

- [ ] **Step 5: Commit**

```bash
git add lib/core/dao/water_sleep_dao.dart lib/core/dao/water_sleep_dao.g.dart test/dao/water_sleep_dao_test.dart
git commit -m "feat: WaterSleepDao with daily water totals and sleep log queries"
```

---

## Task 12: MeasurementsDao — métodos y tests

**Files:**
- Modify: `lib/core/dao/measurements_dao.dart`
- Create: `test/dao/measurements_dao_test.dart`

- [ ] **Step 1: Escribir tests que fallan**

```dart
// test/dao/measurements_dao_test.dart
import 'package:flutter_test/flutter_test.dart';
import 'package:drift/drift.dart';
import 'package:kiolog/core/database/app_database.dart';
import '../helpers/database_helper.dart';

void main() {
  late AppDatabase db;

  setUp(() => db = createTestDatabase());
  tearDown(() async => db.close());

  group('MeasurementsDao - Weight', () {
    test('registra pesos y los recupera en orden', () async {
      await db.measurementsDao.insertWeightLog(WeightLogsCompanion(
        date: Value(DateTime(2026, 5, 1)),
        weightKg: const Value(80.0),
      ));
      await db.measurementsDao.insertWeightLog(WeightLogsCompanion(
        date: Value(DateTime(2026, 5, 8)),
        weightKg: const Value(79.2),
      ));

      final logs = await db.measurementsDao.getWeightLogs(
        DateTime(2026, 5, 1),
        DateTime(2026, 5, 31),
      );
      expect(logs.length, 2);
      expect(logs.first.weightKg, 80.0);
    });
  });

  group('MeasurementsDao - Anthropometric', () {
    test('inserta medidas y getLatest retorna la más reciente', () async {
      await db.measurementsDao.insertMeasurement(MeasurementsCompanion(
        date: Value(DateTime(2026, 4, 1)),
        weightKg: const Value(82.0),
        heightCm: const Value(175.0),
        waistCm: const Value(88.0),
      ));
      await db.measurementsDao.insertMeasurement(MeasurementsCompanion(
        date: Value(DateTime(2026, 5, 1)),
        weightKg: const Value(80.0),
        heightCm: const Value(175.0),
        waistCm: const Value(85.0),
      ));

      final latest = await db.measurementsDao.getLatestMeasurement();
      expect(latest?.weightKg, 80.0);
      expect(latest?.waistCm, 85.0);
    });

    test('getMeasurements retorna todos ordenados por fecha desc', () async {
      for (int i = 1; i <= 3; i++) {
        await db.measurementsDao.insertMeasurement(MeasurementsCompanion(
          date: Value(DateTime(2026, i, 1)),
          weightKg: Value(80.0 + i),
          heightCm: const Value(175.0),
        ));
      }

      final all = await db.measurementsDao.getMeasurements();
      expect(all.length, 3);
      expect(all.first.date.month, 3); // más reciente primero
    });
  });
}
```

- [ ] **Step 2: Ejecutar para verificar que fallan**

```bash
flutter test test/dao/measurements_dao_test.dart
```

Expected: FAIL.

- [ ] **Step 3: Implementar MeasurementsDao**

```dart
// lib/core/dao/measurements_dao.dart
import 'package:drift/drift.dart';
import '../database/app_database.dart';
import '../database/tables/measurements_tables.dart';

part 'measurements_dao.g.dart';

@DriftAccessor(tables: [WeightLogs, Measurements])
class MeasurementsDao extends DatabaseAccessor<AppDatabase>
    with _$MeasurementsDaoMixin {
  MeasurementsDao(super.db);

  Future<void> insertWeightLog(WeightLogsCompanion log) =>
      into(weightLogs).insert(log);

  Future<List<WeightLog>> getWeightLogs(
      DateTime startDate, DateTime endDate) {
    final start = DateTime(startDate.year, startDate.month, startDate.day);
    final end = DateTime(endDate.year, endDate.month, endDate.day)
        .add(const Duration(days: 1));
    return (select(weightLogs)
          ..where((t) =>
              t.date.isBiggerOrEqualValue(start) &
              t.date.isSmallerThanValue(end))
          ..orderBy([(t) => OrderingTerm.asc(t.date)]))
        .get();
  }

  Future<void> insertMeasurement(MeasurementsCompanion measurement) =>
      into(measurements).insert(measurement);

  Future<List<Measurement>> getMeasurements() =>
      (select(measurements)
            ..orderBy([(t) => OrderingTerm.desc(t.date)]))
          .get();

  Future<Measurement?> getLatestMeasurement() =>
      (select(measurements)
            ..orderBy([(t) => OrderingTerm.desc(t.date)])
            ..limit(1))
          .getSingleOrNull();
}
```

- [ ] **Step 4: Regenerar y ejecutar tests**

```bash
dart run build_runner build --delete-conflicting-outputs
flutter test test/dao/measurements_dao_test.dart
```

Expected: All PASS.

- [ ] **Step 5: Commit**

```bash
git add lib/core/dao/measurements_dao.dart lib/core/dao/measurements_dao.g.dart test/dao/measurements_dao_test.dart
git commit -m "feat: MeasurementsDao with weight logs and anthropometric history"
```

---

## Task 13: ConfigDao y AchievementsDao — métodos y tests

**Files:**
- Modify: `lib/core/dao/config_dao.dart`
- Modify: `lib/core/dao/achievements_dao.dart`
- Create: `test/dao/config_dao_test.dart`
- Create: `test/dao/achievements_dao_test.dart`

- [ ] **Step 1: Escribir tests de ConfigDao que fallan**

```dart
// test/dao/config_dao_test.dart
import 'package:flutter_test/flutter_test.dart';
import 'package:drift/drift.dart';
import 'package:kiolog/core/database/app_database.dart';
import '../helpers/database_helper.dart';

void main() {
  late AppDatabase db;

  setUp(() => db = createTestDatabase());
  tearDown(() async => db.close());

  group('ConfigDao - WaterConfig', () {
    test('upsert crea config si no existe', () async {
      await db.configDao.upsertWaterConfig(
        const WaterConfigCompanion(
          unitType: Value('bottle'),
          containerMl: Value(1000),
          dailyGoalMl: Value(3000),
        ),
      );

      final config = await db.configDao.getWaterConfig();
      expect(config?.unitType, 'bottle');
      expect(config?.dailyGoalMl, 3000);
    });

    test('upsert actualiza config existente', () async {
      await db.configDao.upsertWaterConfig(
        const WaterConfigCompanion(
          unitType: Value('bottle'),
          containerMl: Value(1000),
          dailyGoalMl: Value(3000),
        ),
      );
      await db.configDao.upsertWaterConfig(
        const WaterConfigCompanion(
          unitType: Value('glass'),
          containerMl: Value(250),
          dailyGoalMl: Value(2500),
        ),
      );

      final config = await db.configDao.getWaterConfig();
      expect(config?.unitType, 'glass');
      expect(config?.containerMl, 250);
    });
  });

  group('ConfigDao - NotificationSettings', () {
    test('upsert y recupera configuración de notificación', () async {
      await db.configDao.upsertNotificationSettings(
        const NotificationSettingsCompanion(
          module: Value('water'),
          enabled: Value(true),
          hour: Value(0),
          minute: Value(0),
          reminderType: Value('interval'),
          intervalMinutes: Value(120),
        ),
      );

      final settings =
          await db.configDao.getNotificationSettings('water');
      expect(settings?.enabled, true);
      expect(settings?.intervalMinutes, 120);
    });
  });
}
```

- [ ] **Step 2: Escribir tests de AchievementsDao que fallan**

```dart
// test/dao/achievements_dao_test.dart
import 'package:flutter_test/flutter_test.dart';
import 'package:drift/drift.dart';
import 'package:kiolog/core/database/app_database.dart';
import '../helpers/database_helper.dart';

void main() {
  late AppDatabase db;

  setUp(() => db = createTestDatabase());
  tearDown(() async => db.close());

  test('seed inserta logros por defecto', () async {
    await db.achievementsDao.seedDefaultAchievements();

    final all = await db.achievementsDao.getAchievements();
    expect(all.isNotEmpty, true);
    expect(all.every((a) => !a.isUnlocked), true);
  });

  test('unlockAchievement marca el logro como desbloqueado', () async {
    await db.achievementsDao.seedDefaultAchievements();

    await db.achievementsDao.unlockAchievement('first_plan_imported');

    final unlocked = await db.achievementsDao.getUnlockedAchievements();
    expect(unlocked.length, 1);
    expect(unlocked.first.key, 'first_plan_imported');
    expect(unlocked.first.isUnlocked, true);
    expect(unlocked.first.unlockedAt, isNotNull);
  });

  test('isUnlocked retorna false si no desbloqueado', () async {
    await db.achievementsDao.seedDefaultAchievements();

    final result =
        await db.achievementsDao.isUnlocked('water_30_days_total');
    expect(result, false);
  });
}
```

- [ ] **Step 3: Ejecutar para verificar que fallan**

```bash
flutter test test/dao/config_dao_test.dart test/dao/achievements_dao_test.dart
```

Expected: FAIL.

- [ ] **Step 4: Implementar ConfigDao**

```dart
// lib/core/dao/config_dao.dart
import 'package:drift/drift.dart';
import '../database/app_database.dart';
import '../database/tables/config_tables.dart';

part 'config_dao.g.dart';

@DriftAccessor(tables: [WaterConfig, GymConfig, NotificationSettings, AiConfig])
class ConfigDao extends DatabaseAccessor<AppDatabase> with _$ConfigDaoMixin {
  ConfigDao(super.db);

  Future<WaterConfigData?> getWaterConfig() =>
      select(waterConfig).getSingleOrNull();

  Future<void> upsertWaterConfig(WaterConfigCompanion config) async {
    final existing = await getWaterConfig();
    if (existing == null) {
      await into(waterConfig).insert(config);
    } else {
      await (update(waterConfig)).write(config);
    }
  }

  Future<GymConfigData?> getGymConfig() =>
      select(gymConfig).getSingleOrNull();

  Future<void> upsertGymConfig(GymConfigCompanion config) async {
    final existing = await getGymConfig();
    if (existing == null) {
      await into(gymConfig).insert(config);
    } else {
      await (update(gymConfig)).write(config);
    }
  }

  Future<NotificationSetting?> getNotificationSettings(String module) =>
      (select(notificationSettings)
            ..where((t) => t.module.equals(module)))
          .getSingleOrNull();

  Future<void> upsertNotificationSettings(
      NotificationSettingsCompanion settings) async {
    final existing = settings.module.present
        ? await getNotificationSettings(settings.module.value)
        : null;
    if (existing == null) {
      await into(notificationSettings).insert(settings);
    } else {
      await (update(notificationSettings)
            ..where((t) => t.module.equals(existing.module)))
          .write(settings);
    }
  }

  Future<AiConfigData?> getAiConfig() =>
      select(aiConfig).getSingleOrNull();

  Future<void> upsertAiConfig(AiConfigCompanion config) async {
    final existing = await getAiConfig();
    if (existing == null) {
      await into(aiConfig).insert(config);
    } else {
      await (update(aiConfig)).write(config);
    }
  }
}
```

- [ ] **Step 5: Implementar AchievementsDao**

```dart
// lib/core/dao/achievements_dao.dart
import 'package:drift/drift.dart';
import '../database/app_database.dart';
import '../database/tables/achievements_tables.dart';

part 'achievements_dao.g.dart';

@DriftAccessor(tables: [Achievements])
class AchievementsDao extends DatabaseAccessor<AppDatabase>
    with _$AchievementsDaoMixin {
  AchievementsDao(super.db);

  Future<List<Achievement>> getAchievements() =>
      (select(achievements)
            ..orderBy([(t) => OrderingTerm.asc(t.module)]))
          .get();

  Future<List<Achievement>> getUnlockedAchievements() =>
      (select(achievements)..where((t) => t.isUnlocked.equals(true))).get();

  Future<bool> isUnlocked(String key) async {
    final achievement = await (select(achievements)
          ..where((t) => t.key.equals(key)))
        .getSingleOrNull();
    return achievement?.isUnlocked ?? false;
  }

  Future<void> unlockAchievement(String key) =>
      (update(achievements)..where((t) => t.key.equals(key))).write(
        AchievementsCompanion(
          isUnlocked: const Value(true),
          unlockedAt: Value(DateTime.now()),
        ),
      );

  Future<void> seedDefaultAchievements() async {
    const defaults = [
      // Primeras veces
      (
        key: 'first_plan_imported',
        title: 'Primer Plan',
        description: 'Importaste tu primer plan alimenticio',
        module: 'nutrition'
      ),
      (
        key: 'first_gym_session',
        title: 'Primera Sesión',
        description: 'Registraste tu primera sesión en el gym',
        module: 'exercise'
      ),
      (
        key: 'first_consultation',
        title: 'Primera Consulta',
        description: 'Registraste tus primeras medidas de consulta',
        module: 'general'
      ),
      // Agua acumulativa
      (
        key: 'water_7_days_total',
        title: 'Hidratado x7',
        description: 'Completaste tu meta de agua 7 días en total',
        module: 'water'
      ),
      (
        key: 'water_30_days_total',
        title: 'Hidratado x30',
        description: 'Completaste tu meta de agua 30 días en total',
        module: 'water'
      ),
      // Ejercicio acumulativo
      (
        key: 'exercise_10_sessions',
        title: '10 Sesiones',
        description: 'Completaste 10 sesiones de gym',
        module: 'exercise'
      ),
      (
        key: 'exercise_20_sessions',
        title: '20 Sesiones',
        description: 'Completaste 20 sesiones de gym',
        module: 'exercise'
      ),
      // Sueño
      (
        key: 'sleep_7_days_good',
        title: 'Buen Descanso',
        description: 'Dormiste 7+ horas en 7 días diferentes',
        module: 'sleep'
      ),
      // Progreso
      (
        key: 'first_measurement_improvement',
        title: 'Progresando',
        description: 'Registraste tu primera mejora en medidas',
        module: 'general'
      ),
    ];

    for (final a in defaults) {
      await into(achievements).insertOnConflictUpdate(
        AchievementsCompanion.insert(
          key: a.key,
          title: a.title,
          description: a.description,
          module: a.module,
        ),
      );
    }
  }
}
```

- [ ] **Step 6: Regenerar y ejecutar todos los tests**

```bash
dart run build_runner build --delete-conflicting-outputs
flutter test test/dao/
```

Expected: All PASS.

- [ ] **Step 7: Commit**

```bash
git add lib/core/dao/ test/dao/
git commit -m "feat: ConfigDao, AchievementsDao with default achievements seed"
```

---

## Task 14: Configurar get_it (Inyección de Dependencias)

**Files:**
- Create: `lib/core/di/injection.dart`

- [ ] **Step 1: Crear el archivo de inyección**

```dart
// lib/core/di/injection.dart
import 'package:get_it/get_it.dart';
import '../database/app_database.dart';

final getIt = GetIt.instance;

Future<void> setupDependencies() async {
  // Database (singleton)
  getIt.registerSingleton<AppDatabase>(AppDatabase());

  // DAOs (derivados del singleton de DB)
  getIt.registerLazySingleton(() => getIt<AppDatabase>().nutritionDao);
  getIt.registerLazySingleton(() => getIt<AppDatabase>().exerciseDao);
  getIt.registerLazySingleton(() => getIt<AppDatabase>().waterSleepDao);
  getIt.registerLazySingleton(() => getIt<AppDatabase>().measurementsDao);
  getIt.registerLazySingleton(() => getIt<AppDatabase>().configDao);
  getIt.registerLazySingleton(() => getIt<AppDatabase>().achievementsDao);
}
```

- [ ] **Step 2: Verificar que compila**

```bash
dart analyze lib/core/di/injection.dart
```

Expected: `No issues found!`

- [ ] **Step 3: Commit**

```bash
git add lib/core/di/injection.dart
git commit -m "feat: get_it dependency injection setup"
```

---

## Task 15: AppTheme

**Files:**
- Create: `lib/core/theme/app_theme.dart`

- [ ] **Step 1: Crear tema Material 3**

```dart
// lib/core/theme/app_theme.dart
import 'package:flutter/material.dart';

class AppTheme {
  AppTheme._();

  static const _primaryColor = Color(0xFF2E7D32); // Green 800

  static ThemeData get light => ThemeData(
        useMaterial3: true,
        colorScheme: ColorScheme.fromSeed(
          seedColor: _primaryColor,
          brightness: Brightness.light,
        ),
        appBarTheme: const AppBarTheme(centerTitle: true),
        cardTheme: CardTheme(
          elevation: 0,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
            side: BorderSide(color: Colors.grey.shade200),
          ),
        ),
        navigationBarTheme: NavigationBarThemeData(
          labelBehavior: NavigationDestinationLabelBehavior.alwaysShow,
          indicatorShape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
        ),
      );

  static ThemeData get dark => ThemeData(
        useMaterial3: true,
        colorScheme: ColorScheme.fromSeed(
          seedColor: _primaryColor,
          brightness: Brightness.dark,
        ),
        appBarTheme: const AppBarTheme(centerTitle: true),
      );
}
```

> **Nota:** Los colores se pueden ajustar libremente. `_primaryColor` es el único valor a cambiar para redefinir toda la paleta de la app.

- [ ] **Step 2: Commit**

```bash
git add lib/core/theme/app_theme.dart
git commit -m "feat: Material 3 app theme with green health palette"
```

---

## Task 16: Placeholder screens y go_router

**Files:**
- Create: `lib/features/home/presentation/pages/home_page.dart`
- Create: `lib/features/nutrition/presentation/pages/nutrition_page.dart`
- Create: `lib/features/exercise/presentation/pages/exercise_page.dart`
- Create: `lib/features/progress/presentation/pages/progress_page.dart`
- Create: `lib/features/settings/presentation/pages/settings_page.dart`
- Create: `lib/core/router/app_router.dart`

- [ ] **Step 1: Crear páginas placeholder**

```dart
// lib/features/home/presentation/pages/home_page.dart
import 'package:flutter/material.dart';

class HomePage extends StatelessWidget {
  const HomePage({super.key});

  @override
  Widget build(BuildContext context) => const Center(
        child: Text('Inicio — Próximamente'),
      );
}
```

```dart
// lib/features/nutrition/presentation/pages/nutrition_page.dart
import 'package:flutter/material.dart';

class NutritionPage extends StatelessWidget {
  const NutritionPage({super.key});

  @override
  Widget build(BuildContext context) => const Center(
        child: Text('Nutrición — Próximamente'),
      );
}
```

```dart
// lib/features/exercise/presentation/pages/exercise_page.dart
import 'package:flutter/material.dart';

class ExercisePage extends StatelessWidget {
  const ExercisePage({super.key});

  @override
  Widget build(BuildContext context) => const Center(
        child: Text('Ejercicio — Próximamente'),
      );
}
```

```dart
// lib/features/progress/presentation/pages/progress_page.dart
import 'package:flutter/material.dart';

class ProgressPage extends StatelessWidget {
  const ProgressPage({super.key});

  @override
  Widget build(BuildContext context) => const Center(
        child: Text('Progreso — Próximamente'),
      );
}
```

```dart
// lib/features/settings/presentation/pages/settings_page.dart
import 'package:flutter/material.dart';

class SettingsPage extends StatelessWidget {
  const SettingsPage({super.key});

  @override
  Widget build(BuildContext context) => const Center(
        child: Text('Ajustes — Próximamente'),
      );
}
```

- [ ] **Step 2: Crear app_router.dart**

```dart
// lib/core/router/app_router.dart
import 'package:go_router/go_router.dart';
import '../../features/home/presentation/pages/home_page.dart';
import '../../features/nutrition/presentation/pages/nutrition_page.dart';
import '../../features/exercise/presentation/pages/exercise_page.dart';
import '../../features/progress/presentation/pages/progress_page.dart';
import '../../features/settings/presentation/pages/settings_page.dart';
import '../../shared/widgets/app_scaffold.dart';

final appRouter = GoRouter(
  initialLocation: '/',
  routes: [
    ShellRoute(
      builder: (context, state, child) => AppScaffold(child: child),
      routes: [
        GoRoute(
          path: '/',
          builder: (context, state) => const HomePage(),
        ),
        GoRoute(
          path: '/nutrition',
          builder: (context, state) => const NutritionPage(),
        ),
        GoRoute(
          path: '/exercise',
          builder: (context, state) => const ExercisePage(),
        ),
        GoRoute(
          path: '/progress',
          builder: (context, state) => const ProgressPage(),
        ),
        GoRoute(
          path: '/settings',
          builder: (context, state) => const SettingsPage(),
        ),
      ],
    ),
  ],
);
```

- [ ] **Step 3: Commit**

```bash
git add lib/features/ lib/core/router/app_router.dart
git commit -m "feat: placeholder screens and go_router ShellRoute configuration"
```

---

## Task 17: AppScaffold con NavigationBar

**Files:**
- Create: `lib/shared/widgets/app_scaffold.dart`
- Create: `test/widget/app_scaffold_test.dart`

- [ ] **Step 1: Escribir widget test que falla**

```dart
// test/widget/app_scaffold_test.dart
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:kiolog/core/router/app_router.dart';
import 'package:kiolog/core/theme/app_theme.dart';

void main() {
  testWidgets('AppScaffold muestra NavigationBar con 5 destinos',
      (tester) async {
    await tester.pumpWidget(
      MaterialApp.router(
        routerConfig: appRouter,
        theme: AppTheme.light,
      ),
    );

    expect(find.byType(NavigationBar), findsOneWidget);
    expect(find.text('Inicio'), findsOneWidget);
    expect(find.text('Nutrición'), findsOneWidget);
    expect(find.text('Ejercicio'), findsOneWidget);
    expect(find.text('Progreso'), findsOneWidget);
    expect(find.text('Ajustes'), findsOneWidget);
  });

  testWidgets('tap en Nutrición navega a la página correcta', (tester) async {
    await tester.pumpWidget(
      MaterialApp.router(
        routerConfig: appRouter,
        theme: AppTheme.light,
      ),
    );

    await tester.tap(find.text('Nutrición'));
    await tester.pumpAndSettle();

    expect(find.text('Nutrición — Próximamente'), findsOneWidget);
  });
}
```

- [ ] **Step 2: Ejecutar para verificar que falla**

```bash
flutter test test/widget/app_scaffold_test.dart
```

Expected: FAIL — `AppScaffold` no existe.

- [ ] **Step 3: Implementar AppScaffold**

```dart
// lib/shared/widgets/app_scaffold.dart
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

class AppScaffold extends StatelessWidget {
  final Widget child;

  const AppScaffold({super.key, required this.child});

  int _locationToIndex(String location) {
    if (location.startsWith('/nutrition')) return 1;
    if (location.startsWith('/exercise')) return 2;
    if (location.startsWith('/progress')) return 3;
    if (location.startsWith('/settings')) return 4;
    return 0;
  }

  @override
  Widget build(BuildContext context) {
    final location = GoRouterState.of(context).uri.toString();
    final currentIndex = _locationToIndex(location);

    return Scaffold(
      body: child,
      bottomNavigationBar: NavigationBar(
        selectedIndex: currentIndex,
        onDestinationSelected: (index) {
          switch (index) {
            case 0:
              context.go('/');
            case 1:
              context.go('/nutrition');
            case 2:
              context.go('/exercise');
            case 3:
              context.go('/progress');
            case 4:
              context.go('/settings');
          }
        },
        destinations: const [
          NavigationDestination(
            icon: Icon(Icons.home_outlined),
            selectedIcon: Icon(Icons.home),
            label: 'Inicio',
          ),
          NavigationDestination(
            icon: Icon(Icons.restaurant_outlined),
            selectedIcon: Icon(Icons.restaurant),
            label: 'Nutrición',
          ),
          NavigationDestination(
            icon: Icon(Icons.fitness_center_outlined),
            selectedIcon: Icon(Icons.fitness_center),
            label: 'Ejercicio',
          ),
          NavigationDestination(
            icon: Icon(Icons.bar_chart_outlined),
            selectedIcon: Icon(Icons.bar_chart),
            label: 'Progreso',
          ),
          NavigationDestination(
            icon: Icon(Icons.settings_outlined),
            selectedIcon: Icon(Icons.settings),
            label: 'Ajustes',
          ),
        ],
      ),
    );
  }
}
```

- [ ] **Step 4: Ejecutar widget tests**

```bash
flutter test test/widget/app_scaffold_test.dart
```

Expected: All PASS.

- [ ] **Step 5: Commit**

```bash
git add lib/shared/widgets/app_scaffold.dart test/widget/app_scaffold_test.dart
git commit -m "feat: AppScaffold with Material 3 NavigationBar and go_router integration"
```

---

## Task 18: Conectar main.dart y smoke test final

**Files:**
- Modify: `lib/main.dart`

- [ ] **Step 1: Implementar main.dart**

```dart
// lib/main.dart
import 'package:flutter/material.dart';
import 'core/di/injection.dart';
import 'core/router/app_router.dart';
import 'core/theme/app_theme.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await setupDependencies();
  runApp(const KiologApp());
}

class KiologApp extends StatelessWidget {
  const KiologApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp.router(
      title: 'Kiolog',
      theme: AppTheme.light,
      darkTheme: AppTheme.dark,
      themeMode: ThemeMode.system,
      routerConfig: appRouter,
      debugShowCheckedModeBanner: false,
    );
  }
}
```

- [ ] **Step 2: Ejecutar toda la suite de tests**

```bash
flutter test
```

Expected: All PASS (DAO tests + widget test).

- [ ] **Step 3: Verificar que la app compila y corre en Android**

```bash
flutter build apk --debug
```

Expected: `✓ Built build/app/outputs/flutter-apk/app-debug.apk`

- [ ] **Step 4: Commit final de Phase 1**

```bash
git add lib/main.dart
git commit -m "feat: wire up main.dart — Phase 1 Foundation complete"
```

---

## Verificación Final de Phase 1

Al completar esta fase, el proyecto debe cumplir:

- [ ] `flutter test` → todos los tests pasan
- [ ] `flutter build apk --debug` → compila sin errores
- [ ] La app muestra 5 tabs con NavigationBar funcional
- [ ] Todos los archivos `.g.dart` de Drift existen y están actualizados
- [ ] No hay archivos de secretos en el repositorio (`.keystore`, `.env`)
