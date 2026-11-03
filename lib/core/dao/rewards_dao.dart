import 'package:drift/drift.dart';
import '../database/app_database.dart';
import '../database/tables/rewards_tables.dart';

part 'rewards_dao.g.dart';

@DriftAccessor(tables: [MonthlyRewards, RewardSettings])
class RewardsDao extends DatabaseAccessor<AppDatabase> with _$RewardsDaoMixin {
  RewardsDao(super.db);

  Future<List<MonthlyReward>> rewardsFor(String month) =>
      (select(monthlyRewards)
            ..where((t) => t.month.equals(month))
            ..orderBy([(t) => OrderingTerm.asc(t.threshold)]))
          .get();

  /// Crea o cambia la recompensa de un umbral; un título vacío la borra.
  Future<void> setReward(String month, int threshold, String title) async {
    final text = title.trim();
    if (text.isEmpty) {
      await (delete(monthlyRewards)
            ..where((t) => t.month.equals(month) & t.threshold.equals(threshold)))
          .go();
      return;
    }
    await into(monthlyRewards).insert(
      MonthlyRewardsCompanion.insert(month: month, threshold: threshold, title: text),
      onConflict: DoUpdate(
        (_) => MonthlyRewardsCompanion(title: Value(text)),
        target: [monthlyRewards.month, monthlyRewards.threshold],
      ),
    );
  }

  Future<void> setRedeemed(int id, {required bool redeemed}) =>
      (update(monthlyRewards)..where((t) => t.id.equals(id))).write(
        MonthlyRewardsCompanion(
          redeemedAt: Value(redeemed ? DateTime.now().toUtc() : null),
        ),
      );

  Future<Map<String, String>> settings() async => {
        for (final row in await select(rewardSettings).get()) row.key: row.value,
      };

  Future<void> putSetting(String key, String value) =>
      into(rewardSettings).insertOnConflictUpdate(
        RewardSettingsCompanion.insert(key: key, value: value),
      );

  Future<void> removeSetting(String key) =>
      (delete(rewardSettings)..where((t) => t.key.equals(key))).go();

  Future<void> putSettings(Map<String, String> values) => batch((b) {
        for (final MapEntry(:key, :value) in values.entries) {
          b.insert(rewardSettings, RewardSettingsCompanion.insert(key: key, value: value),
              mode: InsertMode.insertOrReplace);
        }
      });
}
