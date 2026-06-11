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
