import 'package:drift/drift.dart';
import '../database/app_database.dart';
import '../database/tables/rewards_tables.dart';

part 'rewards_dao.g.dart';

@DriftAccessor(tables: [MonthlyRewards])
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
}
