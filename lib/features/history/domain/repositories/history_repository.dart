import 'package:kiolog/core/database/app_database.dart';

class DaySummary {
  final DateTime date;
  final bool hasWater;
  final bool hasSleep;
  final bool hasMeals;
  final bool hasExercise;

  const DaySummary({
    required this.date,
    required this.hasWater,
    required this.hasSleep,
    required this.hasMeals,
    required this.hasExercise,
  });

  int get completedCount =>
      (hasWater ? 1 : 0) +
      (hasSleep ? 1 : 0) +
      (hasMeals ? 1 : 0) +
      (hasExercise ? 1 : 0);
}

abstract class HistoryRepository {
  Future<List<DaySummary>> getMonthSummary(DateTime month);
}
