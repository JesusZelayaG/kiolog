import 'package:bloc_test/bloc_test.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kiolog/core/database/app_database.dart';
import 'package:kiolog/core/dao/achievements_dao.dart';
import 'package:kiolog/features/achievements/presentation/bloc/achievements_bloc.dart';
import 'package:kiolog/features/achievements/presentation/bloc/achievements_event.dart';
import 'package:kiolog/features/achievements/presentation/bloc/achievements_state.dart';
import 'package:mocktail/mocktail.dart';

class MockAchievementsDao extends Mock implements AchievementsDao {}

void main() {
  late MockAchievementsDao dao;

  setUp(() {
    dao = MockAchievementsDao();
  });

  group('AchievementsBloc', () {
    final achievements = [
      Achievement(
        id: 1,
        key: 'first_plan',
        title: 'Primer Plan',
        description: 'Desc',
        module: 'nutrition',
        isUnlocked: true,
        unlockedAt: DateTime.now(),
      ),
      Achievement(
        id: 2,
        key: 'locked_one',
        title: 'Locked',
        description: 'Desc',
        module: 'general',
        isUnlocked: false,
        unlockedAt: null,
      ),
    ];

    blocTest<AchievementsBloc, AchievementsState>(
      'emits [loading, success] when loaded',
      build: () {
        when(() => dao.getAchievements()).thenAnswer((_) async => achievements);
        return AchievementsBloc(dao);
      },
      act: (bloc) => bloc.add(const AchievementsLoaded()),
      expect: () => [
        const AchievementsState(status: AchievementsStatus.loading),
        AchievementsState(
          status: AchievementsStatus.success,
          achievements: achievements,
        ),
      ],
    );
  });
}
