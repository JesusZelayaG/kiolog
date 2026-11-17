import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:intl/intl.dart';
import 'package:kiolog/core/dao/rewards_dao.dart';
import 'package:kiolog/core/dao/user_profile_dao.dart';
import 'package:kiolog/core/database/app_database.dart';
import 'package:kiolog/core/domain/day.dart';
import 'package:kiolog/features/reports/domain/repositories/report_repository.dart';

import '../domain/catalog.dart';
import '../domain/unlocks.dart';
import '../domain/xp.dart';

class RewardsState {
  const RewardsState({
    this.loading = true,
    this.level = const Level(1, 0),
    this.today = const [],
    this.month = const MonthProgress(earned: 0, possible: 0),
    this.monthLabel = '',
    this.rewards = const {},
    this.progress = const RewardProgress(level: 1, monthsKept: 0),
    this.newUnlocks = const [],
  });

  final bool loading;
  final Level level;
  final List<XpItem> today;
  final MonthProgress month;
  final String monthLabel;

  /// Recompensa elegida para cada umbral del mes.
  final Map<int, MonthlyReward> rewards;
  final RewardProgress progress;

  /// Lo desbloqueado desde la última visita, para anunciarlo una vez.
  final List<Trophy> newUnlocks;

  RewardsState copyWith({
    Map<int, MonthlyReward>? rewards,
    List<Trophy>? newUnlocks,
  }) =>
      RewardsState(
        loading: false,
        level: level,
        today: today,
        month: month,
        monthLabel: monthLabel,
        rewards: rewards ?? this.rewards,
        progress: progress,
        newUnlocks: newUnlocks ?? this.newUnlocks,
      );
}

const _seenKey = 'seen.';
const _initKey = 'seen.init';

class RewardsCubit extends Cubit<RewardsState> {
  RewardsCubit(this._reports, this._profile, this._rewards) : super(const RewardsState());

  final ReportRepository _reports;
  final UserProfileDao _profile;
  final RewardsDao _rewards;

  String get _monthKey => DateFormat('yyyy-MM').format(DateTime.now());

  Future<void> load() async {
    final now = DateTime.now();
    final monthStart = DateTime(now.year, now.month);
    final registered = (await _profile.getProfile())?.registrationDate?.toLocal();
    final from = registered != null && registered.isBefore(monthStart) ? registered : monthStart;

    final report = await _reports.generateReport(from, now);
    final goals = report.goals;
    final total = report.days.fold(0, (sum, d) => sum + dayXpTotal(d, goals));
    final today = todayUtcDay();
    final todayRecord = report.days.where((d) => d.date == today).firstOrNull ??
        ReportDay(date: today);
    final monthDays = report.days.where((d) => !d.date.isBefore(utcDayOf(monthStart))).toList();
    final daysInMonth = _daysInMonth(now.year, now.month);

    final level = levelFor(total);
    final progress = rewardProgress(
      days: report.days,
      goals: goals,
      level: level.number,
    );
    final settings = await _rewards.settings();
    final unlocked = trophyCatalog.where(progress.isUnlocked).toList();
    var fresh = <Trophy>[];
    if (!settings.containsKey(_initKey)) {
      // Primera visita: lo de inicio no se anuncia.
      await _rewards.putSettings({
        _initKey: '1',
        for (final item in unlocked) '$_seenKey${item.key}': '1',
      });
    } else {
      fresh = unlocked.where((i) => !settings.containsKey('$_seenKey${i.key}')).toList();
    }

    emit(RewardsState(
      loading: false,
      level: level,
      today: dayXp(todayRecord, goals),
      month: monthProgress(monthDays, goals, daysInMonth),
      monthLabel: DateFormat.MMMM('es').format(now),
      rewards: await _loadRewards(),
      progress: progress,
      newUnlocks: fresh,
    ));
  }

  /// Los desbloqueos ya anunciados no se vuelven a mostrar.
  Future<void> acknowledgeUnlocks() async {
    await _rewards.putSettings({for (final item in state.newUnlocks) '$_seenKey${item.key}': '1'});
    emit(state.copyWith(newUnlocks: const []));
  }

  Future<Map<int, MonthlyReward>> _loadRewards() async => {
        for (final r in await _rewards.rewardsFor(_monthKey)) r.threshold: r,
      };

  Future<void> setReward(int threshold, String title) async {
    await _rewards.setReward(_monthKey, threshold, title);
    emit(state.copyWith(rewards: await _loadRewards()));
  }

  Future<void> setRedeemed(MonthlyReward reward, {required bool redeemed}) async {
    await _rewards.setRedeemed(reward.id, redeemed: redeemed);
    emit(state.copyWith(rewards: await _loadRewards()));
  }
}

int _daysInMonth(int year, int month) => DateTime(year, month + 1, 0).day;
