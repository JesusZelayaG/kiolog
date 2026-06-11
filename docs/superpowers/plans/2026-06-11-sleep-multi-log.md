# Sleep Multi-Log Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Permitir múltiples registros de sueño por día (sueño principal + siestas) con selector de tipo, fecha y hora, asignando cada registro al día en que el usuario se durmió.

**Architecture:** Se agrega columna `type` a `SleepLogs` (migración v6→v7), se actualizan DAO y Repository para devolver listas, se reemplaza `todayLog: SleepLog?` por `todayLogs: List<SleepLog>` en el estado con getters computados, y se reescribe el diálogo de registro como `StatefulWidget` separado.

**Tech Stack:** Flutter, Dart, Drift ORM, flutter_bloc, flutter_test

---

## Files

| Archivo | Acción |
|---|---|
| `lib/core/database/tables/water_sleep_tables.dart` | Modificar — agregar columna `type` |
| `lib/core/database/app_database.dart` | Modificar — schemaVersion 7, migración |
| `lib/core/dao/water_sleep_dao.dart` | Modificar — `getSleepLogsForDate`, `deleteSleepLog` |
| `lib/features/sleep/domain/repositories/sleep_repository.dart` | Modificar — nuevas firmas |
| `lib/features/sleep/data/repositories/sleep_repository_impl.dart` | Modificar — implementar nuevas firmas |
| `lib/features/sleep/presentation/bloc/sleep_event.dart` | Modificar — `type` en `SleepLogAdded`, nuevo `SleepLogDeleted` |
| `lib/features/sleep/presentation/bloc/sleep_state.dart` | Modificar — `todayLogs`, getters computados |
| `lib/features/sleep/presentation/bloc/sleep_bloc.dart` | Modificar — handlers actualizados |
| `lib/features/sleep/presentation/pages/sleep_page.dart` | Modificar — nueva UI, `_SleepLogDialog`, `_SleepLogTile` |
| `test/unit/sleep_state_test.dart` | Crear — unit tests para getters del estado |

---

### Task 1: Schema migration + build_runner

**Files:**
- Modify: `lib/core/database/tables/water_sleep_tables.dart`
- Modify: `lib/core/database/app_database.dart`

- [ ] **Step 1: Agregar columna `type` a `SleepLogs`**

Reemplazar el contenido de `lib/core/database/tables/water_sleep_tables.dart`:

```dart
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
  TextColumn get type => text().withDefault(const Constant('main'))();
}
```

- [ ] **Step 2: Actualizar `schemaVersion` y migración en `app_database.dart`**

Cambiar `int get schemaVersion => 6;` por `int get schemaVersion => 7;`.

Dentro del bloque `onUpgrade`, agregar al final (después del último `if (from < 6) {...}`):

```dart
if (from < 7) {
  await m.addColumn(sleepLogs, sleepLogs.type);
}
```

- [ ] **Step 3: Regenerar código Drift**

```bash
cd /home/jesuszelaya/Documents/kiolog && dart run build_runner build --delete-conflicting-outputs 2>&1 | tail -5
```

Esperado: `[INFO] build_runner: Succeeded after ...`

- [ ] **Step 4: Verificar que compila**

```bash
cd /home/jesuszelaya/Documents/kiolog && flutter analyze lib/core/database/ 2>&1 | tail -3
```

Esperado: `No issues found!`

- [ ] **Step 5: Commit**

```bash
git add lib/core/database/tables/water_sleep_tables.dart lib/core/database/app_database.dart lib/core/database/app_database.g.dart lib/core/dao/water_sleep_dao.g.dart && git commit -m "feat(sleep): schema v7 — add type column to SleepLogs"
```

---

### Task 2: DAO

**Files:**
- Modify: `lib/core/dao/water_sleep_dao.dart`

- [ ] **Step 1: Reemplazar `getSleepLog` por `getSleepLogsForDate` y agregar `deleteSleepLog`**

Reemplazar el contenido completo de `lib/core/dao/water_sleep_dao.dart`:

```dart
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
    final start = DateTime.utc(date.year, date.month, date.day);
    final end = start.add(const Duration(days: 1));
    return (select(dailyWaterLogs)
          ..where((t) =>
              t.date.isBiggerOrEqualValue(start) &
              t.date.isSmallerThanValue(end)))
        .get();
  }

  Future<int> getDailyWaterTotalMl(DateTime date) async {
    final logs = await getDailyWaterLogs(date);
    return logs.fold<int>(0, (sum, log) => sum + log.amountMl);
  }

  Future<void> insertSleepLog(SleepLogsCompanion log) =>
      into(sleepLogs).insert(log);

  Future<List<SleepLog>> getSleepLogsForDate(DateTime date) {
    final start = DateTime.utc(date.year, date.month, date.day);
    final end = start.add(const Duration(days: 1));
    return (select(sleepLogs)
          ..where((t) =>
              t.date.isBiggerOrEqualValue(start) &
              t.date.isSmallerThanValue(end))
          ..orderBy([(t) => OrderingTerm.asc(t.sleepTime)]))
        .get();
  }

  Future<void> deleteSleepLog(int id) =>
      (delete(sleepLogs)..where((t) => t.id.equals(id))).go();

  Future<List<SleepLog>> getWeeklySleepLogs(
      DateTime startDate, DateTime endDate) {
    final start = DateTime.utc(startDate.year, startDate.month, startDate.day);
    final end = DateTime.utc(endDate.year, endDate.month, endDate.day)
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

- [ ] **Step 2: Regenerar DAO**

```bash
cd /home/jesuszelaya/Documents/kiolog && dart run build_runner build --delete-conflicting-outputs 2>&1 | tail -5
```

- [ ] **Step 3: Verificar analyze**

```bash
cd /home/jesuszelaya/Documents/kiolog && flutter analyze lib/core/dao/water_sleep_dao.dart 2>&1 | tail -3
```

Esperado: `No issues found!`

- [ ] **Step 4: Commit**

```bash
git add lib/core/dao/water_sleep_dao.dart lib/core/dao/water_sleep_dao.g.dart && git commit -m "feat(sleep): DAO — getSleepLogsForDate list + deleteSleepLog"
```

---

### Task 3: Repository

**Files:**
- Modify: `lib/features/sleep/domain/repositories/sleep_repository.dart`
- Modify: `lib/features/sleep/data/repositories/sleep_repository_impl.dart`

- [ ] **Step 1: Actualizar la interfaz del repository**

Reemplazar `lib/features/sleep/domain/repositories/sleep_repository.dart`:

```dart
import 'package:kiolog/core/database/app_database.dart';

abstract class SleepRepository {
  Future<List<SleepLog>> getSleepLogsForDate(DateTime date);
  Future<List<SleepLog>> getSleepLogsInRange(DateTime start, DateTime end);
  Future<void> addSleepLog({
    required DateTime date,
    required DateTime sleepTime,
    required DateTime wakeTime,
    required String type,
  });
  Future<void> deleteSleepLog(int id);
}
```

- [ ] **Step 2: Actualizar la implementación**

Reemplazar `lib/features/sleep/data/repositories/sleep_repository_impl.dart`:

```dart
import 'package:drift/drift.dart';
import 'package:kiolog/core/dao/water_sleep_dao.dart';
import 'package:kiolog/core/database/app_database.dart';
import '../../domain/repositories/sleep_repository.dart';

class SleepRepositoryImpl implements SleepRepository {
  final WaterSleepDao _waterSleepDao;

  SleepRepositoryImpl(this._waterSleepDao);

  DateTime _dateOnly(DateTime date) =>
      DateTime.utc(date.year, date.month, date.day);

  @override
  Future<List<SleepLog>> getSleepLogsForDate(DateTime date) =>
      _waterSleepDao.getSleepLogsForDate(_dateOnly(date));

  @override
  Future<List<SleepLog>> getSleepLogsInRange(DateTime start, DateTime end) =>
      _waterSleepDao.getWeeklySleepLogs(start, end);

  @override
  Future<void> addSleepLog({
    required DateTime date,
    required DateTime sleepTime,
    required DateTime wakeTime,
    required String type,
  }) {
    final hours = wakeTime.difference(sleepTime).inMinutes / 60.0;
    return _waterSleepDao.insertSleepLog(
      SleepLogsCompanion(
        date: Value(_dateOnly(date)),
        sleepTime: Value(sleepTime),
        wakeTime: Value(wakeTime),
        hoursCalculated: Value(hours),
        type: Value(type),
      ),
    );
  }

  @override
  Future<void> deleteSleepLog(int id) => _waterSleepDao.deleteSleepLog(id);
}
```

- [ ] **Step 3: Verificar analyze**

```bash
cd /home/jesuszelaya/Documents/kiolog && flutter analyze lib/features/sleep/data/ lib/features/sleep/domain/ 2>&1 | tail -3
```

Esperado: `No issues found!`

- [ ] **Step 4: Commit**

```bash
git add lib/features/sleep/domain/repositories/sleep_repository.dart lib/features/sleep/data/repositories/sleep_repository_impl.dart && git commit -m "feat(sleep): repository — list-based API + type param + deleteSleepLog"
```

---

### Task 4: SleepState (TDD)

**Files:**
- Create: `test/unit/sleep_state_test.dart`
- Modify: `lib/features/sleep/presentation/bloc/sleep_state.dart`

- [ ] **Step 1: Escribir tests que fallan**

Crear `test/unit/sleep_state_test.dart`:

```dart
import 'package:flutter_test/flutter_test.dart';
import 'package:kiolog/core/database/app_database.dart';
import 'package:kiolog/features/sleep/presentation/bloc/sleep_state.dart';

SleepLog _log({
  int id = 1,
  double hours = 0.0,
  String type = 'main',
}) {
  final now = DateTime(2026, 6, 11);
  return SleepLog(
    id: id,
    date: now,
    sleepTime: now,
    wakeTime: now,
    hoursCalculated: hours,
    type: type,
  );
}

void main() {
  group('SleepState.mainSleepHours', () {
    test('returns 0.0 cuando todayLogs está vacío', () {
      const s = SleepState();
      expect(s.mainSleepHours, 0.0);
    });

    test('suma solo los registros de tipo main', () {
      final s = SleepState(todayLogs: [
        _log(id: 1, hours: 7.0, type: 'main'),
        _log(id: 2, hours: 1.5, type: 'nap'),
      ]);
      expect(s.mainSleepHours, 7.0);
    });
  });

  group('SleepState.napHours', () {
    test('returns 0.0 sin siestas', () {
      final s = SleepState(todayLogs: [_log(hours: 7.0, type: 'main')]);
      expect(s.napHours, 0.0);
    });

    test('suma todas las siestas', () {
      final s = SleepState(todayLogs: [
        _log(id: 1, hours: 0.5, type: 'nap'),
        _log(id: 2, hours: 1.0, type: 'nap'),
      ]);
      expect(s.napHours, closeTo(1.5, 0.001));
    });
  });

  group('SleepState.totalHours', () {
    test('suma main + naps', () {
      final s = SleepState(todayLogs: [
        _log(id: 1, hours: 7.0, type: 'main'),
        _log(id: 2, hours: 0.5, type: 'nap'),
        _log(id: 3, hours: 1.0, type: 'nap'),
      ]);
      expect(s.totalHours, closeTo(8.5, 0.001));
    });
  });

  group('SleepState.weeklyAverage', () {
    test('returns null cuando weeklyLogs está vacío', () {
      const s = SleepState();
      expect(s.weeklyAverage, isNull);
    });

    test('promedia por día, no por entrada', () {
      final day1 = DateTime(2026, 6, 10);
      final day2 = DateTime(2026, 6, 11);
      // día 1: 7h main + 1h nap = 8h; día 2: 6h main = 6h → promedio = 7h
      final s = SleepState(weeklyLogs: [
        SleepLog(id: 1, date: day1, sleepTime: day1, wakeTime: day1, hoursCalculated: 7.0, type: 'main'),
        SleepLog(id: 2, date: day1, sleepTime: day1, wakeTime: day1, hoursCalculated: 1.0, type: 'nap'),
        SleepLog(id: 3, date: day2, sleepTime: day2, wakeTime: day2, hoursCalculated: 6.0, type: 'main'),
      ]);
      expect(s.weeklyAverage, closeTo(7.0, 0.001));
    });
  });
}
```

- [ ] **Step 2: Correr tests para verificar que fallan**

```bash
cd /home/jesuszelaya/Documents/kiolog && flutter test test/unit/sleep_state_test.dart 2>&1 | tail -10
```

Esperado: error de compilación — `todayLogs` no existe aún.

- [ ] **Step 3: Reemplazar `sleep_state.dart`**

Reemplazar `lib/features/sleep/presentation/bloc/sleep_state.dart`:

```dart
import 'package:equatable/equatable.dart';
import 'package:kiolog/core/database/app_database.dart';

enum SleepStatus { initial, loading, success, failure }

class SleepState extends Equatable {
  final SleepStatus status;
  final List<SleepLog> todayLogs;
  final List<SleepLog> weeklyLogs;
  final String? error;

  const SleepState({
    this.status = SleepStatus.initial,
    this.todayLogs = const [],
    this.weeklyLogs = const [],
    this.error,
  });

  double get mainSleepHours => todayLogs
      .where((l) => l.type == 'main')
      .fold(0.0, (s, l) => s + l.hoursCalculated);

  double get napHours => todayLogs
      .where((l) => l.type == 'nap')
      .fold(0.0, (s, l) => s + l.hoursCalculated);

  double get totalHours => mainSleepHours + napHours;

  double? get weeklyAverage {
    if (weeklyLogs.isEmpty) return null;
    final byDay = <String, double>{};
    for (final log in weeklyLogs) {
      final key = '${log.date.year}-${log.date.month}-${log.date.day}';
      byDay[key] = (byDay[key] ?? 0.0) + log.hoursCalculated;
    }
    return byDay.values.reduce((a, b) => a + b) / byDay.length;
  }

  SleepState copyWith({
    SleepStatus? status,
    List<SleepLog>? todayLogs,
    List<SleepLog>? weeklyLogs,
    String? error,
  }) =>
      SleepState(
        status: status ?? this.status,
        todayLogs: todayLogs ?? this.todayLogs,
        weeklyLogs: weeklyLogs ?? this.weeklyLogs,
        error: error,
      );

  @override
  List<Object?> get props => [status, todayLogs, weeklyLogs, error];
}
```

- [ ] **Step 4: Correr tests para verificar que pasan**

```bash
cd /home/jesuszelaya/Documents/kiolog && flutter test test/unit/sleep_state_test.dart 2>&1
```

Esperado: `All tests passed!` (4 tests)

- [ ] **Step 5: Commit**

```bash
git add lib/features/sleep/presentation/bloc/sleep_state.dart test/unit/sleep_state_test.dart && git commit -m "feat(sleep): SleepState — todayLogs list, mainSleepHours/napHours/totalHours/weeklyAverage"
```

---

### Task 5: SleepEvent + SleepBloc

**Files:**
- Modify: `lib/features/sleep/presentation/bloc/sleep_event.dart`
- Modify: `lib/features/sleep/presentation/bloc/sleep_bloc.dart`

- [ ] **Step 1: Actualizar `sleep_event.dart`**

Reemplazar `lib/features/sleep/presentation/bloc/sleep_event.dart`:

```dart
import 'package:equatable/equatable.dart';

abstract class SleepEvent extends Equatable {
  const SleepEvent();

  @override
  List<Object?> get props => [];
}

class SleepLoaded extends SleepEvent {
  final DateTime date;
  const SleepLoaded({required this.date});

  @override
  List<Object?> get props => [date];
}

class SleepWeeklyLoaded extends SleepEvent {
  final DateTime endDate;
  const SleepWeeklyLoaded({required this.endDate});

  @override
  List<Object?> get props => [endDate];
}

class SleepLogAdded extends SleepEvent {
  final DateTime date;
  final DateTime sleepTime;
  final DateTime wakeTime;
  final String type;

  const SleepLogAdded({
    required this.date,
    required this.sleepTime,
    required this.wakeTime,
    required this.type,
  });

  @override
  List<Object?> get props => [date, sleepTime, wakeTime, type];
}

class SleepLogDeleted extends SleepEvent {
  final int id;
  const SleepLogDeleted(this.id);

  @override
  List<Object?> get props => [id];
}
```

- [ ] **Step 2: Actualizar `sleep_bloc.dart`**

Reemplazar `lib/features/sleep/presentation/bloc/sleep_bloc.dart`:

```dart
import 'package:flutter_bloc/flutter_bloc.dart';
import '../../domain/repositories/sleep_repository.dart';
import 'sleep_event.dart';
import 'sleep_state.dart';

class SleepBloc extends Bloc<SleepEvent, SleepState> {
  final SleepRepository _repository;

  SleepBloc(this._repository) : super(const SleepState()) {
    on<SleepLoaded>(_onLoaded);
    on<SleepWeeklyLoaded>(_onWeeklyLoaded);
    on<SleepLogAdded>(_onLogAdded);
    on<SleepLogDeleted>(_onLogDeleted);
  }

  Future<void> _onLoaded(SleepLoaded event, Emitter<SleepState> emit) async {
    emit(state.copyWith(status: SleepStatus.loading));
    try {
      final logs = await _repository.getSleepLogsForDate(event.date);
      emit(state.copyWith(status: SleepStatus.success, todayLogs: logs));
    } catch (e) {
      emit(state.copyWith(status: SleepStatus.failure, error: e.toString()));
    }
  }

  Future<void> _onWeeklyLoaded(
    SleepWeeklyLoaded event,
    Emitter<SleepState> emit,
  ) async {
    emit(state.copyWith(status: SleepStatus.loading));
    try {
      final start = event.endDate.subtract(const Duration(days: 6));
      final logs = await _repository.getSleepLogsInRange(start, event.endDate);
      emit(state.copyWith(status: SleepStatus.success, weeklyLogs: logs));
    } catch (e) {
      emit(state.copyWith(status: SleepStatus.failure, error: e.toString()));
    }
  }

  Future<void> _onLogAdded(SleepLogAdded event, Emitter<SleepState> emit) async {
    try {
      await _repository.addSleepLog(
        date: event.date,
        sleepTime: event.sleepTime,
        wakeTime: event.wakeTime,
        type: event.type,
      );
      final today = DateTime.now();
      final todayLogs = await _repository.getSleepLogsForDate(today);
      final start = today.subtract(const Duration(days: 6));
      final weeklyLogs = await _repository.getSleepLogsInRange(start, today);
      emit(state.copyWith(todayLogs: todayLogs, weeklyLogs: weeklyLogs));
    } catch (e) {
      emit(state.copyWith(status: SleepStatus.failure, error: e.toString()));
    }
  }

  Future<void> _onLogDeleted(SleepLogDeleted event, Emitter<SleepState> emit) async {
    try {
      await _repository.deleteSleepLog(event.id);
      final today = DateTime.now();
      final todayLogs = await _repository.getSleepLogsForDate(today);
      final start = today.subtract(const Duration(days: 6));
      final weeklyLogs = await _repository.getSleepLogsInRange(start, today);
      emit(state.copyWith(todayLogs: todayLogs, weeklyLogs: weeklyLogs));
    } catch (e) {
      emit(state.copyWith(status: SleepStatus.failure, error: e.toString()));
    }
  }
}
```

- [ ] **Step 3: Verificar analyze**

```bash
cd /home/jesuszelaya/Documents/kiolog && flutter analyze lib/features/sleep/presentation/bloc/ 2>&1 | tail -3
```

Esperado: `No issues found!`

- [ ] **Step 4: Commit**

```bash
git add lib/features/sleep/presentation/bloc/sleep_event.dart lib/features/sleep/presentation/bloc/sleep_bloc.dart && git commit -m "feat(sleep): bloc — SleepLogDeleted event, type param, list-based state updates"
```

---

### Task 6: UI — sleep_page.dart

**Files:**
- Modify: `lib/features/sleep/presentation/pages/sleep_page.dart`

- [ ] **Step 1: Reemplazar `sleep_page.dart` completo**

Reemplazar el contenido de `lib/features/sleep/presentation/pages/sleep_page.dart`:

```dart
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import '../../../../core/dao/user_profile_dao.dart';
import '../../../../core/database/app_database.dart';
import '../../../../core/di/injection.dart';
import '../../domain/repositories/sleep_repository.dart';
import '../bloc/sleep_bloc.dart';
import '../bloc/sleep_event.dart';
import '../bloc/sleep_state.dart';

class SleepPage extends StatelessWidget {
  const SleepPage({super.key});

  @override
  Widget build(BuildContext context) {
    return BlocProvider(
      create: (_) => SleepBloc(getIt<SleepRepository>())
        ..add(SleepLoaded(date: DateTime.now()))
        ..add(SleepWeeklyLoaded(endDate: DateTime.now())),
      child: const _SleepView(),
    );
  }
}

class _SleepView extends StatelessWidget {
  const _SleepView();

  static bool _isSameDay(DateTime a, DateTime b) =>
      a.year == b.year && a.month == b.month && a.day == b.day;

  SleepLog? _logForDay(List<SleepLog> logs, DateTime day) {
    final matches = logs.where((l) => _isSameDay(l.date, day));
    return matches.isEmpty ? null : matches.first;
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Sueño'),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new),
          onPressed: () => context.go('/'),
        ),
      ),
      body: BlocBuilder<SleepBloc, SleepState>(
        builder: (context, state) {
          if (state.status == SleepStatus.loading && state.weeklyLogs.isEmpty) {
            return const Center(child: CircularProgressIndicator());
          }
          if (state.status == SleepStatus.failure) {
            return Center(child: Text('Error: ${state.error}'));
          }

          final progress = (state.totalHours / 8.0).clamp(0.0, 1.0);
          final hoursLabel = state.totalHours > 0
              ? state.totalHours.toStringAsFixed(1)
              : '--';

          return SafeArea(
            child: SingleChildScrollView(
              padding: const EdgeInsets.fromLTRB(24, 16, 24, 32),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  Text(
                    'SEGUIMIENTO DE SUEÑO',
                    style: theme.textTheme.labelSmall?.copyWith(
                      color: cs.primary,
                    ),
                  ),
                  const SizedBox(height: 32),

                  // Circular progress
                  SizedBox(
                    height: 200,
                    width: 200,
                    child: Stack(
                      fit: StackFit.expand,
                      children: [
                        CircularProgressIndicator(
                          value: progress,
                          strokeWidth: 14,
                          strokeCap: StrokeCap.round,
                          backgroundColor:
                              cs.primaryContainer.withValues(alpha: 0.25),
                        ),
                        Center(
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(Icons.nightlight_round,
                                  size: 40, color: cs.primary),
                              const SizedBox(height: 6),
                              Text(
                                '$hoursLabel h',
                                style: theme.textTheme.headlineMedium?.copyWith(
                                  fontWeight: FontWeight.bold,
                                  color: cs.onSurface,
                                ),
                              ),
                              if (state.totalHours > 0)
                                Text(
                                  'Sueño ${state.mainSleepHours.toStringAsFixed(1)}h · Siestas ${state.napHours.toStringAsFixed(1)}h',
                                  style: theme.textTheme.bodySmall?.copyWith(
                                    color: cs.onSurfaceVariant,
                                    fontSize: 10,
                                  ),
                                  textAlign: TextAlign.center,
                                )
                              else
                                Text(
                                  'No registrado',
                                  style: theme.textTheme.bodySmall?.copyWith(
                                    color: cs.onSurfaceVariant,
                                  ),
                                ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 12),

                  Text(
                    'OBJETIVO: 8H',
                    style: theme.textTheme.labelSmall?.copyWith(
                      color: cs.primary,
                    ),
                  ),

                  if (state.todayLogs.isEmpty) ...[
                    const SizedBox(height: 16),
                    Text(
                      '"El descanso es la base de la vitalidad.\nComienza tu registro hoy."',
                      textAlign: TextAlign.center,
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: cs.onSurfaceVariant,
                        fontStyle: FontStyle.italic,
                      ),
                    ),
                  ],

                  if (state.todayLogs.isNotEmpty) ...[
                    const SizedBox(height: 16),
                    ...state.todayLogs.map(
                      (log) => _SleepLogTile(log: log),
                    ),
                  ],

                  const SizedBox(height: 32),

                  // Weekly chart card
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(20),
                    decoration: BoxDecoration(
                      color: cs.surfaceContainerHigh,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Text(
                              'Últimos 7 días',
                              style: theme.textTheme.labelLarge?.copyWith(
                                color: cs.onSurface,
                              ),
                            ),
                            const Spacer(),
                            if (state.weeklyAverage != null)
                              Text(
                                'Prom: ${state.weeklyAverage!.toStringAsFixed(1)} h',
                                style: theme.textTheme.bodySmall?.copyWith(
                                  color: cs.primary,
                                ),
                              ),
                          ],
                        ),
                        const SizedBox(height: 20),
                        _WeeklyChart(
                          weeklyLogs: state.weeklyLogs,
                          logForDay: _logForDay,
                        ),
                        if (state.weeklyLogs.isEmpty) ...[
                          const SizedBox(height: 12),
                          Center(
                            child: Text(
                              'Sin registros esta semana',
                              style: theme.textTheme.bodySmall?.copyWith(
                                color: cs.onSurfaceVariant,
                              ),
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),

                  const SizedBox(height: 32),

                  SizedBox(
                    width: double.infinity,
                    height: 52,
                    child: ElevatedButton.icon(
                      style: ElevatedButton.styleFrom(
                        shape: const StadiumBorder(),
                        backgroundColor: cs.primary,
                        foregroundColor: cs.onPrimary,
                      ),
                      onPressed: () => _showAddSleepDialog(context),
                      icon: const Icon(Icons.bedtime_outlined),
                      label: const Text('Registrar sueño'),
                    ),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  Future<void> _showAddSleepDialog(BuildContext context) async {
    final profile = await getIt<UserProfileDao>().getProfile();
    final firstDate = profile?.registrationDate ?? DateTime(2020, 1, 1);
    if (!context.mounted) return;
    showDialog(
      context: context,
      builder: (_) => _SleepLogDialog(
        firstDate: firstDate,
        onSave: (date, sleepTime, wakeTime, type) {
          context.read<SleepBloc>().add(SleepLogAdded(
                date: date,
                sleepTime: sleepTime,
                wakeTime: wakeTime,
                type: type,
              ));
        },
      ),
    );
  }
}

// ── Log tile ────────────────────────────────────────────────────────────────

class _SleepLogTile extends StatelessWidget {
  final SleepLog log;
  const _SleepLogTile({required this.log});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;
    final isMain = log.type == 'main';

    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        decoration: BoxDecoration(
          color: cs.surfaceContainerHigh,
          borderRadius: BorderRadius.circular(10),
        ),
        child: Row(
          children: [
            Container(
              padding:
                  const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
              decoration: BoxDecoration(
                color: isMain
                    ? const Color(0xFFAFC7FF).withValues(alpha: 0.2)
                    : Colors.amber.withValues(alpha: 0.2),
                borderRadius: BorderRadius.circular(4),
              ),
              child: Text(
                isMain ? 'PRINCIPAL' : 'SIESTA',
                style: TextStyle(
                  fontSize: 10,
                  fontWeight: FontWeight.bold,
                  color: isMain ? const Color(0xFFAFC7FF) : Colors.amber,
                ),
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                '${DateFormat.Hm().format(log.sleepTime)} – ${DateFormat.Hm().format(log.wakeTime)}  ·  ${log.hoursCalculated.toStringAsFixed(1)}h',
                style: theme.textTheme.bodySmall
                    ?.copyWith(color: cs.onSurface),
              ),
            ),
            IconButton(
              icon: Icon(Icons.delete_outline,
                  size: 18, color: cs.onSurfaceVariant),
              onPressed: () =>
                  context.read<SleepBloc>().add(SleepLogDeleted(log.id)),
              visualDensity: VisualDensity.compact,
              padding: EdgeInsets.zero,
            ),
          ],
        ),
      ),
    );
  }
}

// ── Add dialog ───────────────────────────────────────────────────────────────

class _SleepLogDialog extends StatefulWidget {
  final DateTime firstDate;
  final void Function(
      DateTime date, DateTime sleepTime, DateTime wakeTime, String type) onSave;

  const _SleepLogDialog({required this.firstDate, required this.onSave});

  @override
  State<_SleepLogDialog> createState() => _SleepLogDialogState();
}

class _SleepLogDialogState extends State<_SleepLogDialog> {
  String _type = 'main';
  DateTime? _date;
  TimeOfDay? _sleepTime;
  TimeOfDay? _wakeTime;

  bool get _canSave =>
      _date != null && _sleepTime != null && _wakeTime != null;

  bool get _isNextDay =>
      _sleepTime != null &&
      _wakeTime != null &&
      (_wakeTime!.hour < _sleepTime!.hour ||
          (_wakeTime!.hour == _sleepTime!.hour &&
              _wakeTime!.minute < _sleepTime!.minute));

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;

    return AlertDialog(
      title: Text(
        'Registrar sueño',
        style: TextStyle(color: cs.onSurface),
      ),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            SegmentedButton<String>(
              segments: const [
                ButtonSegment(
                    value: 'main',
                    label: Text('Principal'),
                    icon: Icon(Icons.nightlight_round, size: 16)),
                ButtonSegment(
                    value: 'nap',
                    label: Text('Siesta'),
                    icon: Icon(Icons.wb_twilight, size: 16)),
              ],
              selected: {_type},
              onSelectionChanged: (s) => setState(() => _type = s.first),
            ),
            const SizedBox(height: 8),
            ListTile(
              contentPadding: EdgeInsets.zero,
              leading: const Icon(Icons.calendar_today_outlined),
              title: const Text('Fecha'),
              subtitle: Text(
                _date != null
                    ? DateFormat('dd/MM/yyyy').format(_date!)
                    : 'Seleccionar',
              ),
              onTap: () async {
                final now = DateTime.now();
                final picked = await showDatePicker(
                  context: context,
                  initialDate: now,
                  firstDate: widget.firstDate,
                  lastDate: now,
                );
                if (picked != null) setState(() => _date = picked);
              },
            ),
            ListTile(
              contentPadding: EdgeInsets.zero,
              leading: const Icon(Icons.bedtime_outlined),
              title: const Text('Hora de dormir'),
              subtitle: Text(_sleepTime?.format(context) ?? 'Seleccionar'),
              onTap: () async {
                final t = await showTimePicker(
                  context: context,
                  initialTime: const TimeOfDay(hour: 22, minute: 0),
                );
                if (t != null) setState(() => _sleepTime = t);
              },
            ),
            ListTile(
              contentPadding: EdgeInsets.zero,
              leading: const Icon(Icons.wb_sunny_outlined),
              title: const Text('Hora de despertar'),
              subtitle: Row(
                children: [
                  Text(_wakeTime?.format(context) ?? 'Seleccionar'),
                  if (_isNextDay) ...[
                    const SizedBox(width: 6),
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 6, vertical: 2),
                      decoration: BoxDecoration(
                        color: cs.primaryContainer,
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: Text(
                        '+1d',
                        style: TextStyle(
                            fontSize: 11,
                            color: cs.onPrimaryContainer),
                      ),
                    ),
                  ],
                ],
              ),
              onTap: () async {
                final t = await showTimePicker(
                  context: context,
                  initialTime: const TimeOfDay(hour: 7, minute: 0),
                );
                if (t != null) setState(() => _wakeTime = t);
              },
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Cancelar'),
        ),
        ElevatedButton(
          onPressed: _canSave
              ? () {
                  final sleepDt = DateTime(
                    _date!.year,
                    _date!.month,
                    _date!.day,
                    _sleepTime!.hour,
                    _sleepTime!.minute,
                  );
                  final rawWake = DateTime(
                    _date!.year,
                    _date!.month,
                    _date!.day,
                    _wakeTime!.hour,
                    _wakeTime!.minute,
                  );
                  final wakeDt = rawWake.isBefore(sleepDt)
                      ? rawWake.add(const Duration(days: 1))
                      : rawWake;
                  widget.onSave(_date!, sleepDt, wakeDt, _type);
                  Navigator.pop(context);
                }
              : null,
          child: const Text('Guardar'),
        ),
      ],
    );
  }
}

// ── Weekly chart ─────────────────────────────────────────────────────────────

class _WeeklyChart extends StatelessWidget {
  final List<SleepLog> weeklyLogs;
  final SleepLog? Function(List<SleepLog>, DateTime) logForDay;

  const _WeeklyChart({
    required this.weeklyLogs,
    required this.logForDay,
  });

  Color _barColor(BuildContext context, double hours) {
    final cs = Theme.of(context).colorScheme;
    if (hours >= 7) return cs.primary;
    if (hours >= 5) return Colors.amber;
    return cs.error;
  }

  double _totalHoursForDay(DateTime day) => weeklyLogs
      .where((l) =>
          l.date.year == day.year &&
          l.date.month == day.month &&
          l.date.day == day.day)
      .fold(0.0, (s, l) => s + l.hoursCalculated);

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;
    final days = List.generate(
      7,
      (i) => DateTime.now().subtract(Duration(days: 6 - i)),
    );
    const maxH = 10.0;
    const chartHeight = 80.0;

    return SizedBox(
      height: chartHeight + 36,
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.end,
        children: days.map((day) {
          final h = _totalHoursForDay(day);
          final hasLog = h > 0;
          final barH = hasLog
              ? ((h / maxH).clamp(0.0, 1.0) * chartHeight)
                  .clamp(4.0, chartHeight)
              : 4.0;
          final dayLabel = DateFormat.E('es')
              .format(day)
              .substring(0, 2)
              .toUpperCase();
          final isToday = _SleepView._isSameDay(day, DateTime.now());

          return Expanded(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                if (hasLog)
                  Text(
                    '${h.toStringAsFixed(0)}h',
                    style: theme.textTheme.labelSmall?.copyWith(
                      color: _barColor(context, h),
                      fontSize: 9,
                    ),
                  )
                else
                  const SizedBox(height: 14),
                const SizedBox(height: 2),
                Container(
                  height: barH,
                  margin: const EdgeInsets.symmetric(horizontal: 3),
                  decoration: BoxDecoration(
                    color: hasLog
                        ? _barColor(context, h)
                        : cs.surfaceContainerHighest,
                    borderRadius: const BorderRadius.vertical(
                      top: Radius.circular(4),
                    ),
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  dayLabel,
                  style: theme.textTheme.labelSmall?.copyWith(
                    color: isToday ? cs.primary : cs.onSurfaceVariant,
                    fontWeight:
                        isToday ? FontWeight.bold : FontWeight.normal,
                    fontSize: 10,
                  ),
                ),
              ],
            ),
          );
        }).toList(),
      ),
    );
  }
}
```

- [ ] **Step 2: Verificar analyze**

```bash
cd /home/jesuszelaya/Documents/kiolog && flutter analyze lib/features/sleep/presentation/pages/sleep_page.dart 2>&1 | tail -3
```

Esperado: `No issues found!`

- [ ] **Step 3: Correr todos los tests**

```bash
cd /home/jesuszelaya/Documents/kiolog && flutter test test/unit/sleep_state_test.dart 2>&1
```

Esperado: `All tests passed!`

- [ ] **Step 4: Commit final**

```bash
git add lib/features/sleep/presentation/pages/sleep_page.dart && git commit -m "feat(sleep): UI — multi-log list, _SleepLogDialog with type/date/time, _SleepLogTile with delete"
```
