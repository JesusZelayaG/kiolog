import 'package:drift/drift.dart';
import '../database/app_database.dart';
import '../database/tables/achievements_tables.dart';

part 'achievements_dao.g.dart';

@DriftAccessor(tables: [Achievements])
class AchievementsDao extends DatabaseAccessor<AppDatabase>
    with _$AchievementsDaoMixin {
  AchievementsDao(super.db);
}
