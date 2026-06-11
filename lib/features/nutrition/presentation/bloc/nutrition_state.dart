import 'package:collection/collection.dart';
import 'package:equatable/equatable.dart';
import 'package:kiolog/core/database/app_database.dart';
import 'package:kiolog/features/nutrition/domain/models/nutrition_weekly_stat.dart';
import 'package:kiolog/features/nutrition/domain/models/option_frequency_stat.dart';

enum NutritionStatus { initial, loading, success, failure }

class NutritionState extends Equatable {
  final NutritionStatus status;
  final MealPlan? activePlan;
  final List<MealPlan> allPlans;
  final Map<String, List<MealPlanOption>> planOptions;
  final List<DailyMealLog> dailyLogs;
  final List<NutritionWeeklyStat> weeklyAdherence;
  final List<OptionFrequencyStat> optionFrequencies;
  final int? viewingPlanId;
  final String? error;

  const NutritionState({
    this.status = NutritionStatus.initial,
    this.activePlan,
    this.allPlans = const [],
    this.planOptions = const {},
    this.dailyLogs = const [],
    this.weeklyAdherence = const [],
    this.optionFrequencies = const [],
    this.viewingPlanId,
    this.error,
  });

  bool get hasPendingPlan {
    if (activePlan == null) return false;
    return allPlans.any(
        (p) => !p.isActive && p.createdAt.isAfter(activePlan!.createdAt));
  }

  MealPlan? get pendingPlan {
    if (activePlan == null) return null;
    return allPlans
        .where(
            (p) => !p.isActive && p.createdAt.isAfter(activePlan!.createdAt))
        .firstOrNull;
  }

  MealPlan? get viewingPlan => viewingPlanId == null
      ? activePlan
      : allPlans.firstWhereOrNull((p) => p.id == viewingPlanId);

  bool isMealLogged(String mealType) =>
      dailyLogs.any((log) => log.mealType == mealType);

  DailyMealLog? getLogForMeal(String mealType) =>
      dailyLogs.where((log) => log.mealType == mealType).firstOrNull;

  static const _unset = Object();

  NutritionState copyWith({
    NutritionStatus? status,
    MealPlan? activePlan,
    List<MealPlan>? allPlans,
    Map<String, List<MealPlanOption>>? planOptions,
    List<DailyMealLog>? dailyLogs,
    List<NutritionWeeklyStat>? weeklyAdherence,
    List<OptionFrequencyStat>? optionFrequencies,
    Object? viewingPlanId = _unset,
    String? error,
  }) =>
      NutritionState(
        status: status ?? this.status,
        activePlan: activePlan ?? this.activePlan,
        allPlans: allPlans ?? this.allPlans,
        planOptions: planOptions ?? this.planOptions,
        dailyLogs: dailyLogs ?? this.dailyLogs,
        weeklyAdherence: weeklyAdherence ?? this.weeklyAdherence,
        optionFrequencies: optionFrequencies ?? this.optionFrequencies,
        viewingPlanId:
            viewingPlanId == _unset ? this.viewingPlanId : viewingPlanId as int?,
        error: error,
      );

  @override
  List<Object?> get props => [
        status,
        activePlan,
        allPlans,
        planOptions,
        dailyLogs,
        weeklyAdherence,
        optionFrequencies,
        viewingPlanId,
        error,
      ];
}
