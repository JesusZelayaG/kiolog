import 'package:kiolog/core/database/app_database.dart';

class MealFrequencyEntry {
  final String mealType;
  final String description;
  final int count;

  const MealFrequencyEntry({
    required this.mealType,
    required this.description,
    required this.count,
  });
}

class WeeklyComplianceEntry {
  final String weekLabel;
  final int daysDone;
  final int daysGoal;

  const WeeklyComplianceEntry({
    required this.weekLabel,
    required this.daysDone,
    required this.daysGoal,
  });
}

class NutritionReportData {
  final String? planName;
  final List<MealFrequencyEntry> mealFrequencies;

  const NutritionReportData({
    required this.planName,
    required this.mealFrequencies,
  });
}

class ExerciseReportData {
  final String? planName;
  final List<WeeklyComplianceEntry> weeklyCompliance;
  final int totalRoutineSessions;
  final int cardioSessionsCount;
  final int freeExerciseCount;

  const ExerciseReportData({
    required this.planName,
    required this.weeklyCompliance,
    required this.totalRoutineSessions,
    required this.cardioSessionsCount,
    required this.freeExerciseCount,
  });
}

class ReportData {
  final DateTime start;
  final DateTime end;
  final int waterGoalDays;
  final int waterTotalDays;
  final int mealsLogged;
  final int mealsTotal;
  final int exerciseDays;
  final int exerciseTotalDays;
  final double? sleepAverage;
  final List<WeightLog> weightLogs;
  final Measurement? latestMeasurement;
  final NutritionReportData? nutritionDetail;
  final ExerciseReportData? exerciseDetail;

  ReportData({
    required this.start,
    required this.end,
    required this.waterGoalDays,
    required this.waterTotalDays,
    required this.mealsLogged,
    required this.mealsTotal,
    required this.exerciseDays,
    required this.exerciseTotalDays,
    this.sleepAverage,
    required this.weightLogs,
    this.latestMeasurement,
    this.nutritionDetail,
    this.exerciseDetail,
  });

  double get waterCompliance =>
      waterTotalDays > 0 ? waterGoalDays / waterTotalDays : 0.0;

  double get nutritionCompliance =>
      mealsTotal > 0 ? mealsLogged / mealsTotal : 0.0;

  double get exerciseCompliance =>
      exerciseTotalDays > 0 ? exerciseDays / exerciseTotalDays : 0.0;
}

abstract class ReportRepository {
  Future<ReportData> generateReport(DateTime start, DateTime end);
}
