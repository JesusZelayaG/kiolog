import 'package:drift/drift.dart';
import '../database/app_database.dart';
import '../database/tables/user_modules_table.dart';

part 'user_modules_dao.g.dart';

@DriftAccessor(tables: [UserModules])
class UserModulesDao extends DatabaseAccessor<AppDatabase>
    with _$UserModulesDaoMixin {
  UserModulesDao(super.db);

  Future<bool> isModuleEnabled(String module) async {
    final row = await (select(userModules)
          ..where((t) => t.module.equals(module)))
        .getSingleOrNull();
    return row?.enabled ?? true;
  }

  Future<Map<String, bool>> getAllModuleStatuses() async {
    final rows = await select(userModules).get();
    return {for (final r in rows) r.module: r.enabled};
  }

  Future<void> setModuleEnabled(String module, bool enabled) =>
      into(userModules).insertOnConflictUpdate(
        UserModulesCompanion(
          module: Value(module),
          enabled: Value(enabled),
        ),
      );

  Future<void> seedModules(Map<String, bool> modules) =>
      db.transaction(() async {
        for (final entry in modules.entries) {
          await into(userModules).insert(
            UserModulesCompanion(
              module: Value(entry.key),
              enabled: Value(entry.value),
            ),
            mode: InsertMode.insertOrIgnore,
          );
        }
      });
}
