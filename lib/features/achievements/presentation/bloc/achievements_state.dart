import 'package:equatable/equatable.dart';
import 'package:kiolog/core/database/app_database.dart';

enum AchievementsStatus { initial, loading, success, failure }

class AchievementsState extends Equatable {
  final AchievementsStatus status;
  final List<Achievement> achievements;
  final String? error;

  const AchievementsState({
    this.status = AchievementsStatus.initial,
    this.achievements = const [],
    this.error,
  });

  List<Achievement> get unlocked =>
      achievements.where((a) => a.isUnlocked).toList();

  List<Achievement> get locked =>
      achievements.where((a) => !a.isUnlocked).toList();

  AchievementsState copyWith({
    AchievementsStatus? status,
    List<Achievement>? achievements,
    String? error,
  }) =>
      AchievementsState(
        status: status ?? this.status,
        achievements: achievements ?? this.achievements,
        error: error,
      );

  @override
  List<Object?> get props => [status, achievements, error];
}
