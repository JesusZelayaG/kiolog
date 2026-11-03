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

class UserProfiles extends Table {
  IntColumn get id => integer().autoIncrement()();
  BoolColumn get onboardingCompleted =>
      boolean().withDefault(const Constant(false))();
  DateTimeColumn get registrationDate => dateTime().nullable()();
  TextColumn get name => text().nullable()();
  // male | female, elige la forma del modelo corporal
  TextColumn get bodySex => text().nullable()();

  /// Fecha y hora de la próxima cita con la nutricionista.
  DateTimeColumn get nextConsultationAt => dateTime().nullable()();
}
