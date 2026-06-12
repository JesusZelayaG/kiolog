import 'package:equatable/equatable.dart';
import '../../domain/repositories/history_repository.dart';

class MonthCompliance extends Equatable {
  final double water;
  final double meals;
  final double exercise;

  const MonthCompliance({
    required this.water,
    required this.meals,
    required this.exercise,
  });

  @override
  List<Object?> get props => [water, meals, exercise];
}

MonthCompliance computeMonthCompliance(List<DaySummary> days) {
  final now = DateTime.now();
  final todayUtc = DateTime.utc(now.year, now.month, now.day);
  final counted = days.where((d) => !d.date.isAfter(todayUtc)).toList();
  if (counted.isEmpty) {
    return const MonthCompliance(water: 0, meals: 0, exercise: 0);
  }
  final n = counted.length;
  return MonthCompliance(
    water: counted.where((d) => d.hasWater).length / n,
    meals: counted.where((d) => d.hasMeals).length / n,
    exercise: counted.where((d) => d.hasExercise).length / n,
  );
}

enum HistoryStatus { initial, loading, success, failure }

class HistoryState extends Equatable {
  final HistoryStatus status;
  final DateTime currentMonth;
  final List<DaySummary> days;
  final MonthCompliance compliance;
  final String? error;

  const HistoryState({
    this.status = HistoryStatus.initial,
    required this.currentMonth,
    this.days = const [],
    this.compliance = const MonthCompliance(water: 0, meals: 0, exercise: 0),
    this.error,
  });

  HistoryState copyWith({
    HistoryStatus? status,
    DateTime? currentMonth,
    List<DaySummary>? days,
    MonthCompliance? compliance,
    String? error,
  }) =>
      HistoryState(
        status: status ?? this.status,
        currentMonth: currentMonth ?? this.currentMonth,
        days: days ?? this.days,
        compliance: compliance ?? this.compliance,
        error: error ?? this.error,
      );

  @override
  List<Object?> get props => [status, currentMonth, days, compliance, error];
}
