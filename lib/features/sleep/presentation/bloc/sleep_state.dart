import 'package:equatable/equatable.dart';
import 'package:kiolog/core/database/app_database.dart';

enum SleepStatus { initial, loading, success, failure }

class SleepState extends Equatable {
  final SleepStatus status;
  final SleepLog? todayLog;
  final List<SleepLog> weeklyLogs;
  final String? error;

  const SleepState({
    this.status = SleepStatus.initial,
    this.todayLog,
    this.weeklyLogs = const [],
    this.error,
  });

  double? get weeklyAverage {
    if (weeklyLogs.isEmpty) return null;
    final total = weeklyLogs.fold<double>(
      0,
      (sum, log) => sum + log.hoursCalculated,
    );
    return total / weeklyLogs.length;
  }

  SleepState copyWith({
    SleepStatus? status,
    SleepLog? todayLog,
    List<SleepLog>? weeklyLogs,
    String? error,
  }) =>
      SleepState(
        status: status ?? this.status,
        todayLog: todayLog ?? this.todayLog,
        weeklyLogs: weeklyLogs ?? this.weeklyLogs,
        error: error,
      );

  @override
  List<Object?> get props => [status, todayLog, weeklyLogs, error];
}
