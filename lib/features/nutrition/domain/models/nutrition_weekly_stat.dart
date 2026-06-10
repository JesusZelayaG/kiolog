import 'package:equatable/equatable.dart';

class NutritionWeeklyStat extends Equatable {
  final DateTime weekStart;
  final int mealsLogged;
  final int mealsExpected;
  final int offPlanMeals;

  const NutritionWeeklyStat({
    required this.weekStart,
    required this.mealsLogged,
    required this.mealsExpected,
    required this.offPlanMeals,
  });

  double get adherencePct =>
      mealsExpected == 0 ? 0.0 : mealsLogged / mealsExpected;

  @override
  List<Object?> get props => [weekStart, mealsLogged, mealsExpected, offPlanMeals];
}
