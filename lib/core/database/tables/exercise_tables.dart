import 'package:drift/drift.dart';

class ExercisePlans extends Table {
  IntColumn get id => integer().autoIncrement()();
  TextColumn get name => text()();
  DateTimeColumn get createdAt => dateTime()();
  BoolColumn get isActive => boolean().withDefault(const Constant(true))();
  DateTimeColumn get periodStart => dateTime().nullable()();
  DateTimeColumn get periodEnd => dateTime().nullable()();
}

class ExerciseRoutines extends Table {
  IntColumn get id => integer().autoIncrement()();
  IntColumn get planId => integer().references(ExercisePlans, #id)();
  IntColumn get dayNumber => integer()();
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
  // tipo de serie — normal | pyramid | drop | pyramid_drop
  TextColumn get setType =>
      text().withDefault(const Constant('normal'))();
  // orden dentro del día de rutina
  IntColumn get orderIndex =>
      integer().withDefault(const Constant(0))();
}

/// Definiciones opcionales por serie de un ítem de rutina.
/// Si existen, la sesión las usa como plantilla pre-llenada.
/// Si no existen, se generan filas vacías según el conteo del ítem.
class ExerciseRoutineSetDefs extends Table {
  IntColumn get id => integer().autoIncrement()();
  IntColumn get routineItemId =>
      integer().references(ExerciseRoutineItems, #id)();
  IntColumn get setNumber => integer()();
  // null = serie normal; valor = número de serie padre (para drops)
  IntColumn get dropOfSetNumber => integer().nullable()();
  IntColumn get reps => integer()();
  RealColumn get weightKg => real().nullable()();

  @override
  List<Set<Column>> get uniqueKeys => [
        {routineItemId, setNumber}
      ];
}

class DailyExerciseLogs extends Table {
  IntColumn get id => integer().autoIncrement()();
  DateTimeColumn get date => dateTime()();
  IntColumn get routineId => integer().references(ExerciseRoutines, #id)();
  BoolColumn get completed =>
      boolean().withDefault(const Constant(false))();
}

class ExerciseSessionLogs extends Table {
  IntColumn get id => integer().autoIncrement()();
  DateTimeColumn get date => dateTime()();
  IntColumn get routineId =>
      integer().nullable().references(ExerciseRoutines, #id)();
  DateTimeColumn get gymArrivedAt => dateTime()();
  DateTimeColumn get gymLeftAt => dateTime().nullable()();
  RealColumn get lat => real().nullable()();
  RealColumn get lng => real().nullable()();
}

class ExerciseSetLogs extends Table {
  IntColumn get id => integer().autoIncrement()();
  IntColumn get sessionId =>
      integer().references(ExerciseSessionLogs, #id)();
  TextColumn get exerciseName => text()();
  IntColumn get setNumber => integer()();
  IntColumn get reps => integer()();
  RealColumn get weightKg => real().nullable()();
  // tipo de esta serie — normal | pyramid | drop
  TextColumn get setType =>
      text().withDefault(const Constant('normal'))();
  // id del ExerciseSetLog padre si es drop set
  IntColumn get dropOfSetId =>
      integer().nullable().references(ExerciseSetLogs, #id)();
}

/// Registro de sesiones de cardio independientes (no parte de rutina).
class CardioLogs extends Table {
  IntColumn get id => integer().autoIncrement()();
  DateTimeColumn get date => dateTime()();
  // treadmill | elliptical | bike | other
  TextColumn get cardioType => text()();
  IntColumn get durationMinutes => integer()();
  TextColumn get notes => text().nullable()();
}

/// Configuración de metas semanales de ejercicio.
class ExerciseConfig extends Table {
  IntColumn get id => integer().autoIncrement()();
  IntColumn get weeklyRoutineDaysGoal =>
      integer().withDefault(const Constant(4))();
  IntColumn get weeklyCardioDaysGoal =>
      integer().withDefault(const Constant(3))();
  IntColumn get cardioMinutesGoal =>
      integer().withDefault(const Constant(30))();
}
