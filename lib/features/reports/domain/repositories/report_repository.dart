import 'package:equatable/equatable.dart';
import 'package:kiolog/core/database/app_database.dart';

class MealFrequencyEntry extends Equatable {
  final String mealType;
  final String description;
  final int count;

  const MealFrequencyEntry({
    required this.mealType,
    required this.description,
    required this.count,
  });

  @override
  List<Object?> get props => [mealType, description, count];
}

class WeeklyComplianceEntry extends Equatable {
  final String weekLabel;
  final int daysDone;
  final int daysGoal;

  const WeeklyComplianceEntry({
    required this.weekLabel,
    required this.daysDone,
    required this.daysGoal,
  });

  @override
  List<Object?> get props => [weekLabel, daysDone, daysGoal];
}

class NutritionReportData extends Equatable {
  final String? planName;
  final List<MealFrequencyEntry> mealFrequencies;

  const NutritionReportData({
    this.planName,
    required this.mealFrequencies,
  });

  @override
  List<Object?> get props => [planName, mealFrequencies];
}

class ExerciseReportData extends Equatable {
  final String? planName;
  final List<WeeklyComplianceEntry> weeklyCompliance;
  final int totalRoutineSessions;
  final int cardioSessionsCount;
  final int freeExerciseCount;

  const ExerciseReportData({
    this.planName,
    required this.weeklyCompliance,
    required this.totalRoutineSessions,
    required this.cardioSessionsCount,
    required this.freeExerciseCount,
  });

  @override
  List<Object?> get props =>
      [planName, weeklyCompliance, totalRoutineSessions, cardioSessionsCount, freeExerciseCount];
}

/// Lo registrado en un día del periodo.
class ReportDay extends Equatable {
  const ReportDay({
    required this.date,
    this.waterMl = 0,
    this.meals = 0,
    this.mealsFromPlan = 0,
    this.exercised = false,
    this.cardioMinutes = 0,
    this.sleepHours,
    this.weightKg,
  });

  /// Medianoche UTC del día local, como se guardan los registros.
  final DateTime date;
  final int waterMl;
  final int meals;

  /// Comidas registradas eligiendo una opción del plan.
  final int mealsFromPlan;

  /// Rutina, sesión libre o día marcado como hecho.
  final bool exercised;
  final int cardioMinutes;
  final double? sleepHours;

  /// Último peso registrado ese día.
  final double? weightKg;

  @override
  List<Object?> get props =>
      [date, waterMl, meals, mealsFromPlan, exercised, cardioMinutes, sleepHours, weightKg];
}

/// Las metas con que se mide el cumplimiento.
class ReportGoals extends Equatable {
  const ReportGoals({
    this.waterMl = 3000,
    this.mealsPerDay = 4,
    this.routineDaysPerWeek = 4,
    this.cardioDaysPerWeek = 3,
    this.cardioMinutes = 30,
  });

  final int waterMl;
  final int mealsPerDay;
  final int routineDaysPerWeek;
  final int cardioDaysPerWeek;

  /// Minutos por sesión de cardio.
  final int cardioMinutes;

  @override
  List<Object?> get props =>
      [waterMl, mealsPerDay, routineDaysPerWeek, cardioDaysPerWeek, cardioMinutes];
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

  /// Consultas registradas, de la más antigua a la más reciente.
  final List<Measurement> consultations;
  final NutritionReportData? nutritionDetail;
  final ExerciseReportData? exerciseDetail;

  /// Un registro por día, del inicio hasta hoy o el fin del periodo.
  final List<ReportDay> days;
  final ReportGoals goals;
  final List<CardioLog> cardioLogs;
  final String? personName;

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
    this.consultations = const [],
    this.nutritionDetail,
    this.exerciseDetail,
    this.days = const [],
    this.goals = const ReportGoals(),
    this.cardioLogs = const [],
    this.personName,
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
