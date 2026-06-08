import 'package:equatable/equatable.dart';
import 'package:kiolog/core/database/app_database.dart';

enum NutritionStatus { initial, loading, success, failure }

class NutritionState extends Equatable {
  final NutritionStatus status;
  final MealPlan? activePlan;
  final List<MealPlan> allPlans;
  final Map<String, List<MealPlanOption>> planOptions;
  final List<DailyMealLog> dailyLogs;
  final String? error;

  const NutritionState({
    this.status = NutritionStatus.initial,
    this.activePlan,
    this.allPlans = const [],
    this.planOptions = const {},
    this.dailyLogs = const [],
    this.error,
  });

  bool isMealLogged(String mealType) =>
      dailyLogs.any((log) => log.mealType == mealType);

  DailyMealLog? getLogForMeal(String mealType) =>
      dailyLogs.where((log) => log.mealType == mealType).firstOrNull;

  NutritionState copyWith({
    NutritionStatus? status,
    MealPlan? activePlan,
    List<MealPlan>? allPlans,
    Map<String, List<MealPlanOption>>? planOptions,
    List<DailyMealLog>? dailyLogs,
    String? error,
  }) =>
      NutritionState(
        status: status ?? this.status,
        activePlan: activePlan,
        allPlans: allPlans ?? this.allPlans,
        planOptions: planOptions ?? this.planOptions,
        dailyLogs: dailyLogs ?? this.dailyLogs,
        error: error,
      );

  @override
  List<Object?> get props =>
      [status, activePlan, allPlans, planOptions, dailyLogs, error];
}
