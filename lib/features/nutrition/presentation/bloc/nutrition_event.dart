import 'dart:typed_data';

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

  /// Foto de lo que se comió, ya comprimida.
  final Uint8List? photo;

  const NutritionOffPlanMealLogged({
    required this.date,
    required this.mealType,
    this.description,
    this.photo,
  });

  @override
  List<Object?> get props => [date, mealType, description, photo];
}

/// Pone, cambia o quita (null) la foto de referencia de un plato del plan.
class NutritionOptionPhotoChanged extends NutritionEvent {
  final int optionId;
  final Uint8List? photo;

  const NutritionOptionPhotoChanged({required this.optionId, this.photo});

  @override
  List<Object?> get props => [optionId, photo];
}

/// Cambia el ícono de un tiempo de comida del plan activo.
class NutritionMealIconChanged extends NutritionEvent {
  final String mealType;
  final String icon;

  const NutritionMealIconChanged({required this.mealType, required this.icon});

  @override
  List<Object?> get props => [mealType, icon];
}

/// Pone, cambia o quita (null) la foto de lo que se comió en un registro.
class NutritionLogPhotoChanged extends NutritionEvent {
  final int logId;
  final Uint8List? photo;

  const NutritionLogPhotoChanged({required this.logId, this.photo});

  @override
  List<Object?> get props => [logId, photo];
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

class NutritionPlanDeleted extends NutritionEvent {
  final int planId;

  const NutritionPlanDeleted({required this.planId});

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

class NutritionProgressPlanSelected extends NutritionEvent {
  final int planId;
  const NutritionProgressPlanSelected({required this.planId});
  @override
  List<Object?> get props => [planId];
}
