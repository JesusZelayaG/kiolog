# Sleep Multi-Log — Design Spec

**Date:** 2026-06-11
**Scope:** `lib/features/sleep/` + `lib/core/database/` (schema migration)

---

## Objetivo

Permitir registrar múltiples entradas de sueño por día (sueño nocturno principal + siestas), con selección de fecha y hora, asignando el registro al día en que el usuario se durmió. La fecha mínima seleccionable es `UserProfiles.registrationDate`.

---

## 1. Capa de datos

### 1.1 Schema — `SleepLogs` (migración v6 → v7)

Agregar columna `type TEXT NOT NULL DEFAULT 'main'`:

```dart
class SleepLogs extends Table {
  IntColumn get id => integer().autoIncrement()();
  DateTimeColumn get date => dateTime()();        // día en que se durmió
  DateTimeColumn get sleepTime => dateTime()();
  DateTimeColumn get wakeTime => dateTime()();
  RealColumn get hoursCalculated => real()();
  TextColumn get type => text().withDefault(const Constant('main'))(); // 'main' | 'nap'
}
```

Migración en `app_database.dart`:
```dart
int get schemaVersion => 7;

MigrationStrategy get migration => MigrationStrategy(
  onUpgrade: (m, from, to) async {
    if (from < 7) {
      await m.addColumn(sleepLogs, sleepLogs.type);
    }
  },
);
```

### 1.2 DAO — `WaterSleepDao`

Reemplazar `getSleepLog(date)` → `getSleepLogsForDate(date)` que devuelve `List<SleepLog>`.  
Agregar `deleteSleepLog(int id)`.

```dart
Future<List<SleepLog>> getSleepLogsForDate(DateTime date);
Future<void> deleteSleepLog(int id);
```

### 1.3 Repository — `SleepRepository` / `SleepRepositoryImpl`

```dart
// domain/repositories/sleep_repository.dart
Future<List<SleepLog>> getSleepLogsForDate(DateTime date);
Future<void> deleteSleepLog(int id);
Future<void> addSleepLog({
  required DateTime date,
  required DateTime sleepTime,
  required DateTime wakeTime,
  required String type,   // ← nuevo parámetro
});
```

`addSleepLog` calcula `hoursCalculated = wakeTime.difference(sleepTime).inMinutes / 60.0` (lógica existente, sin cambio).

---

## 2. Bloc / Estado

### 2.1 `SleepState`

```dart
class SleepState extends Equatable {
  final SleepStatus status;
  final List<SleepLog> todayLogs;      // reemplaza todayLog: SleepLog?
  final List<SleepLog> weeklyLogs;
  final String? error;

  // Getters computados
  double get mainSleepHours =>
      todayLogs.where((l) => l.type == 'main')
               .fold(0.0, (s, l) => s + l.hoursCalculated);

  double get napHours =>
      todayLogs.where((l) => l.type == 'nap')
               .fold(0.0, (s, l) => s + l.hoursCalculated);

  double get totalHours => mainSleepHours + napHours;
}
```

`weeklyAverage` se recalcula agrupando `weeklyLogs` por fecha, sumando horas por día, y promediando entre los días que tienen al menos un registro:
```dart
double? get weeklyAverage {
  if (weeklyLogs.isEmpty) return null;
  final byDay = <String, double>{};
  for (final log in weeklyLogs) {
    final key = '${log.date.year}-${log.date.month}-${log.date.day}';
    byDay[key] = (byDay[key] ?? 0.0) + log.hoursCalculated;
  }
  return byDay.values.reduce((a, b) => a + b) / byDay.length;
}
```

### 2.2 `SleepEvent`

```dart
// Sin cambios en SleepLoaded / SleepWeeklyLoaded

class SleepLogAdded extends SleepEvent {
  final DateTime date;
  final DateTime sleepTime;
  final DateTime wakeTime;
  final String type;          // ← nuevo: 'main' | 'nap'
}

class SleepLogDeleted extends SleepEvent {
  final int id;
}
```

### 2.3 `SleepBloc`

- `SleepLoaded` → llama `getSleepLogsForDate`, popula `todayLogs`
- `SleepLogAdded` → llama `addSleepLog`, luego recarga `todayLogs`
- `SleepLogDeleted` → llama `deleteSleepLog(id)`, luego recarga `todayLogs`

---

## 3. UI

### 3.1 Diálogo "Registrar sueño"

Campos en orden:

| Campo | Widget | Detalle |
|---|---|---|
| Tipo | `SegmentedButton<String>` | `'main'` = "Sueño principal" / `'nap'` = "Siesta" |
| Fecha | `showDatePicker` | `firstDate: registrationDate`, `lastDate: hoy`, default: hoy |
| Hora de dormir | `showTimePicker` | default: `now - 8h` |
| Hora de despertar | `showTimePicker` | default: `now`; si es anterior a sleepTime muestra `+1d` |

Botón **Guardar** deshabilitado hasta que fecha + sleepTime + wakeTime estén seleccionados.

El `+1d` indica visualmente que la hora de despertar cae el día siguiente, pero no afecta la fecha asignada al registro (que siempre es la fecha de sleepTime).

`registrationDate` se carga con `await UserProfileDao.getProfile()` justo antes de llamar `showDialog`. Si es `null` (perfil sin fecha), se usa `DateTime(2020, 1, 1)` como fallback.

### 3.2 Sección "Hoy" en `sleep_page.dart`

```
Text "SEGUIMIENTO DE SUEÑO"   ← label verde

Círculo de progreso: totalHours / 8.0
  Centro: luna + "X.Xh" + desglose "Sueño X.Xh · Siestas X.Xh"

Si todayLogs.isEmpty:
  "No registrado" + cita motivacional

Si todayLogs.isNotEmpty:
  Lista de registros del día:
    Cada item:
      Badge: "PRINCIPAL" (azul-índigo) o "SIESTA" (ámbar)
      Texto: "22:30 – 07:00  · X.Xh"
      IconButton(delete) → dispara SleepLogDeleted(id)
```

### 3.3 Gráfica semanal

Sin cambios en estructura. Las barras usan `totalHours` del día, que ya es la suma de todos los registros. La lógica de `weeklyAverage` se recalcula automáticamente desde el estado actualizado.

---

## 4. Archivos afectados

| Archivo | Cambio |
|---|---|
| `lib/core/database/tables/water_sleep_tables.dart` | Agregar columna `type` |
| `lib/core/database/app_database.dart` | `schemaVersion → 7`, agregar migración |
| `lib/core/dao/water_sleep_dao.dart` | `getSleepLogsForDate`, `deleteSleepLog` |
| `lib/features/sleep/domain/repositories/sleep_repository.dart` | Nuevas firmas |
| `lib/features/sleep/data/repositories/sleep_repository_impl.dart` | Implementar nuevas firmas |
| `lib/features/sleep/presentation/bloc/sleep_event.dart` | `type` en `SleepLogAdded`, nuevo `SleepLogDeleted` |
| `lib/features/sleep/presentation/bloc/sleep_state.dart` | `todayLogs`, getters computados |
| `lib/features/sleep/presentation/bloc/sleep_bloc.dart` | Manejar nuevos eventos |
| `lib/features/sleep/presentation/pages/sleep_page.dart` | UI completa |

## 5. Fuera de alcance

- Estadísticas de calidad de sueño
- Notificaciones de recordatorio
- Editar un registro existente (solo crear y eliminar)
