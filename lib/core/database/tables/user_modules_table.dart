import 'package:drift/drift.dart';

class UserModules extends Table {
  TextColumn get module => text()();
  BoolColumn get enabled => boolean().withDefault(const Constant(true))();

  @override
  Set<Column> get primaryKey => {module};
}
