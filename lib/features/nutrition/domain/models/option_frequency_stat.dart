import 'package:equatable/equatable.dart';

class OptionFrequencyStat extends Equatable {
  final int planOptionId;
  final String mealType;
  final int optionNumber;
  final String description;
  final int count;

  const OptionFrequencyStat({
    required this.planOptionId,
    required this.mealType,
    required this.optionNumber,
    required this.description,
    required this.count,
  });

  @override
  List<Object?> get props =>
      [planOptionId, mealType, optionNumber, description, count];
}
