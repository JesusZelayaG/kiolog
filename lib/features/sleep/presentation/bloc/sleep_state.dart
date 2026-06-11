import 'package:equatable/equatable.dart';
import 'package:kiolog/core/database/app_database.dart';

enum SleepStatus { initial, loading, success, failure }

class SleepState extends Equatable {
  final SleepStatus status;
  final List<SleepLog> todayLogs;
  final List<SleepLog> weeklyLogs;
  final String? error;

  const SleepState({
    this.status = SleepStatus.initial,
    this.todayLogs = const [],
    this.weeklyLogs = const [],
    this.error,
  });

  double get mainSleepHours => todayLogs
      .where((l) => l.type == 'main')
      .fold(0.0, (s, l) => s + l.hoursCalculated);

  double get napHours => todayLogs
      .where((l) => l.type == 'nap')
      .fold(0.0, (s, l) => s + l.hoursCalculated);

  double get totalHours => mainSleepHours + napHours;

  double? get weeklyAverage {
    if (weeklyLogs.isEmpty) return null;
    final byDay = <String, double>{};
    for (final log in weeklyLogs) {
      final key = '${log.date.year}-${log.date.month}-${log.date.day}';
      byDay[key] = (byDay[key] ?? 0.0) + log.hoursCalculated;
    }
    return byDay.values.reduce((a, b) => a + b) / byDay.length;
  }

  SleepState copyWith({
    SleepStatus? status,
    List<SleepLog>? todayLogs,
    List<SleepLog>? weeklyLogs,
    String? error,
  }) =>
      SleepState(
        status: status ?? this.status,
        todayLogs: todayLogs ?? this.todayLogs,
        weeklyLogs: weeklyLogs ?? this.weeklyLogs,
        error: error ?? this.error,
      );

  @override
  List<Object?> get props => [status, todayLogs, weeklyLogs, error];
}
