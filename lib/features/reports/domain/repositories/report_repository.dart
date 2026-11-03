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

/// Una opción del plan y cuántas veces se eligió en el periodo.
class OptionCount extends Equatable {
  const OptionCount(this.optionNumber, this.description, this.count);

  final int optionNumber;
  final String description;
  final int count;

  @override
  List<Object?> get props => [optionNumber, description, count];
}

/// Lo que se comió en un tiempo de comida durante el periodo.
class MealTimeBreakdown extends Equatable {
  const MealTimeBreakdown({
    required this.mealType,
    required this.options,
    this.offPlan = 0,
    this.skipped = 0,
    this.offPlanTop = const [],
  });

  final String mealType;

  /// Todas las opciones del plan, también las que nunca se eligieron.
  final List<OptionCount> options;

  /// Registradas como "Fuera de plan" (con lo que se comió).
  final int offPlan;

  /// Registradas como "No seguí el plan".
  final int skipped;

  /// Lo más repetido fuera del plan, de más a menos.
  final List<(String, int)> offPlanTop;

  int get fromPlan => options.fold(0, (sum, o) => sum + o.count);
  int get logged => fromPlan + offPlan + skipped;

  /// La opción más elegida, o null si no se eligió ninguna.
  OptionCount? get favorite {
    OptionCount? best;
    for (final o in options) {
      if (o.count > 0 && (best == null || o.count > best.count)) best = o;
    }
    return best;
  }

  @override
  List<Object?> get props => [mealType, options, offPlan, skipped, offPlanTop];
}

/// Una comida fuera del plan, para la tabla del reporte.
class OffPlanMeal extends Equatable {
  const OffPlanMeal(this.date, this.mealType, this.description);

  final DateTime date;
  final String mealType;
  final String description;

  @override
  List<Object?> get props => [date, mealType, description];
}

class NutritionReportData extends Equatable {
  final String? planName;
  final List<MealFrequencyEntry> mealFrequencies;

  /// Un desglose por tiempo de comida, en el orden del plan.
  final List<MealTimeBreakdown> mealTimes;
  final List<OffPlanMeal> offPlanMeals;

  const NutritionReportData({
    this.planName,
    required this.mealFrequencies,
    this.mealTimes = const [],
    this.offPlanMeals = const [],
  });

  @override
  List<Object?> get props => [planName, mealFrequencies, mealTimes, offPlanMeals];
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
    this.mealsOffPlan = 0,
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

  /// Comidas registradas como "Fuera de plan". El resto de [meals] son
  /// "No seguí el plan".
  final int mealsOffPlan;

  int get mealsSkipped => meals - mealsFromPlan - mealsOffPlan;

  /// Rutina, sesión libre o día marcado como hecho.
  final bool exercised;
  final int cardioMinutes;
  final double? sleepHours;

  /// Último peso registrado ese día.
  final double? weightKg;

  @override
  List<Object?> get props =>
      [date, waterMl, meals, mealsFromPlan, mealsOffPlan, exercised, cardioMinutes, sleepHours, weightKg];
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
