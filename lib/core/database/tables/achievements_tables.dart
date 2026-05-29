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
