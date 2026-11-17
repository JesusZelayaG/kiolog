import 'package:equatable/equatable.dart';

abstract class HomeEvent extends Equatable {
  const HomeEvent();

  @override
  List<Object?> get props => [];
}

class HomeLoaded extends HomeEvent {
  final DateTime date;

  const HomeLoaded({required this.date});

  @override
  List<Object?> get props => [date];
}

/// Suma un envase de agua desde el Home y recarga sin pantalla de carga.
class HomeWaterAdded extends HomeEvent {
  const HomeWaterAdded();
}
