import 'package:equatable/equatable.dart';

abstract class AchievementsEvent extends Equatable {
  const AchievementsEvent();

  @override
  List<Object?> get props => [];
}

class AchievementsLoaded extends AchievementsEvent {
  const AchievementsLoaded();
}
