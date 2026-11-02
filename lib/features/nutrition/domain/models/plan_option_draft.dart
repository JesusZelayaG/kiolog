/// Una opción del formulario de plan. Sin [id] es nueva.
class PlanOptionDraft {
  const PlanOptionDraft({
    this.id,
    required this.mealType,
    required this.optionNumber,
    required this.description,
  });

  final int? id;
  final String mealType;
  final int optionNumber;
  final String description;
}
