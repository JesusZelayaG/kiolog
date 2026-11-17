/// Una opción del formulario de plan. Sin [id] es nueva.
class PlanOptionDraft {
  const PlanOptionDraft({
    this.id,
    required this.mealType,
    required this.optionNumber,
    required this.description,
    this.photoId,
    this.mealIcon,
  });

  final int? id;
  final String mealType;
  final int optionNumber;
  final String description;

  /// La foto de referencia del plato, ya guardada.
  final int? photoId;

  /// El ícono elegido para su tiempo de comida.
  final String? mealIcon;
}
