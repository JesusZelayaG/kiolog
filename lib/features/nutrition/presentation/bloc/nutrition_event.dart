import 'package:equatable/equatable.dart';

abstract class NutritionEvent extends Equatable {
  const NutritionEvent();

  @override
  List<Object?> get props => [];
}

class NutritionLoaded extends NutritionEvent {
  final DateTime date;

  const NutritionLoaded({required this.date});

  @override
  List<Object?> get props => [date];
}

class NutritionPlanLoaded extends NutritionEvent {
  const NutritionPlanLoaded();
}

class NutritionMealLogged extends NutritionEvent {
  final DateTime date;
  final String mealType;
  final int planOptionId;

  const NutritionMealLogged({
    required this.date,
    required this.mealType,
    required this.planOptionId,
  });

  @override
  List<Object?> get props => [date, mealType, planOptionId];
}

class NutritionOffPlanMealLogged extends NutritionEvent {
  final DateTime date;
  final String mealType;
  final String? description;

  const NutritionOffPlanMealLogged({
    required this.date,
    required this.mealType,
    this.description,
  });

  @override
  List<Object?> get props => [date, mealType, description];
}

class NutritionMealLogRemoved extends NutritionEvent {
  final DateTime date;
  final String mealType;

  const NutritionMealLogRemoved({
    required this.date,
    required this.mealType,
  });

  @override
  List<Object?> get props => [date, mealType];
}

class NutritionPlanActivated extends NutritionEvent {
  final int planId;

  const NutritionPlanActivated({required this.planId});

  @override
  List<Object?> get props => [planId];
}

class NutritionPlanCreated extends NutritionEvent {
  final String name;
  final int dailyMealGoal;

  const NutritionPlanCreated({required this.name, required this.dailyMealGoal});

  @override
  List<Object?> get props => [name, dailyMealGoal];
}

class NutritionOptionAdded extends NutritionEvent {
  final int planId;
  final String mealType;
  final int optionNumber;
  final String description;

  const NutritionOptionAdded({
    required this.planId,
    required this.mealType,
    required this.optionNumber,
    required this.description,
  });

  @override
  List<Object?> get props => [planId, mealType, optionNumber, description];
}
