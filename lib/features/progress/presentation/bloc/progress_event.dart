import 'package:equatable/equatable.dart';

abstract class ProgressEvent extends Equatable {
  const ProgressEvent();

  @override
  List<Object?> get props => [];
}

class ProgressLoaded extends ProgressEvent {
  const ProgressLoaded();
}

class ProgressWeightAdded extends ProgressEvent {
  final DateTime date;
  final double weightKg;

  const ProgressWeightAdded({required this.date, required this.weightKg});

  @override
  List<Object?> get props => [date, weightKg];
}

class ProgressMeasurementAdded extends ProgressEvent {
  final DateTime date;
  final double weightKg;
  final double heightCm;
  final double? armFlexedCm;
  final double? armRelaxedCm;
  final double? waistCm;
  final double? hipCm;
  final double? calfCm;
  final double? lowerAbdomenCm;
  final double? thighCm;
  final double? midGluteusCm;
  final double? chestCm;
  final double? bodyFatPct;
  final double? leanMassKg;
  final double? visceralMass;

  const ProgressMeasurementAdded({
    required this.date,
    required this.weightKg,
    required this.heightCm,
    this.armFlexedCm,
    this.armRelaxedCm,
    this.waistCm,
    this.hipCm,
    this.calfCm,
    this.lowerAbdomenCm,
    this.thighCm,
    this.midGluteusCm,
    this.chestCm,
    this.bodyFatPct,
    this.leanMassKg,
    this.visceralMass,
  });

  @override
  List<Object?> get props => [date, weightKg, heightCm, waistCm, hipCm, bodyFatPct];
}
