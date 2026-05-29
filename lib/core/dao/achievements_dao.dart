import 'package:drift/drift.dart';
import '../database/app_database.dart';
import '../database/tables/achievements_tables.dart';

part 'achievements_dao.g.dart';

@DriftAccessor(tables: [Achievements])
class AchievementsDao extends DatabaseAccessor<AppDatabase>
    with _$AchievementsDaoMixin {
  AchievementsDao(super.db);

  Future<List<Achievement>> getAchievements() =>
      (select(achievements)
            ..orderBy([(t) => OrderingTerm.asc(t.module)]))
          .get();

  Future<List<Achievement>> getUnlockedAchievements() =>
      (select(achievements)..where((t) => t.isUnlocked.equals(true))).get();

  Future<bool> isUnlocked(String key) async {
    final achievement = await (select(achievements)
          ..where((t) => t.key.equals(key)))
        .getSingleOrNull();
    return achievement?.isUnlocked ?? false;
  }

  Future<void> unlockAchievement(String key) =>
      (update(achievements)..where((t) => t.key.equals(key))).write(
        AchievementsCompanion(
          isUnlocked: const Value(true),
          unlockedAt: Value(DateTime.now()),
        ),
      );

  Future<void> seedDefaultAchievements() async {
    const defaults = [
      (
        key: 'first_plan_imported',
        title: 'Primer Plan',
        description: 'Importaste tu primer plan alimenticio',
        module: 'nutrition'
      ),
      (
        key: 'first_gym_session',
        title: 'Primera Sesión',
        description: 'Registraste tu primera sesión en el gym',
        module: 'exercise'
      ),
      (
        key: 'first_consultation',
        title: 'Primera Consulta',
        description: 'Registraste tus primeras medidas de consulta',
        module: 'general'
      ),
      (
        key: 'water_7_days_total',
        title: 'Hidratado x7',
        description: 'Completaste tu meta de agua 7 días en total',
        module: 'water'
      ),
      (
        key: 'water_30_days_total',
        title: 'Hidratado x30',
        description: 'Completaste tu meta de agua 30 días en total',
        module: 'water'
      ),
      (
        key: 'exercise_10_sessions',
        title: '10 Sesiones',
        description: 'Completaste 10 sesiones de gym',
        module: 'exercise'
      ),
      (
        key: 'exercise_20_sessions',
        title: '20 Sesiones',
        description: 'Completaste 20 sesiones de gym',
        module: 'exercise'
      ),
      (
        key: 'sleep_7_days_good',
        title: 'Buen Descanso',
        description: 'Dormiste 7+ horas en 7 días diferentes',
        module: 'sleep'
      ),
      (
        key: 'first_measurement_improvement',
        title: 'Progresando',
        description: 'Registraste tu primera mejora en medidas',
        module: 'general'
      ),
    ];

    for (final a in defaults) {
      await into(achievements).insertOnConflictUpdate(
        AchievementsCompanion.insert(
          key: a.key,
          title: a.title,
          description: a.description,
          module: a.module,
        ),
      );
    }
  }
}
