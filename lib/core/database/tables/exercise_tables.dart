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
