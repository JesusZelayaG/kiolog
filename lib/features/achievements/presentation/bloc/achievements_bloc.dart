import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:kiolog/core/dao/achievements_dao.dart';
import 'achievements_event.dart';
import 'achievements_state.dart';

class AchievementsBloc extends Bloc<AchievementsEvent, AchievementsState> {
  final AchievementsDao _achievementsDao;

  AchievementsBloc(this._achievementsDao) : super(const AchievementsState()) {
    on<AchievementsLoaded>(_onLoaded);
  }

  Future<void> _onLoaded(
    AchievementsLoaded event,
    Emitter<AchievementsState> emit,
  ) async {
    emit(state.copyWith(status: AchievementsStatus.loading));
    try {
      final achievements = await _achievementsDao.getAchievements();
      emit(state.copyWith(
        status: AchievementsStatus.success,
        achievements: achievements,
      ));
    } catch (e) {
      emit(state.copyWith(
        status: AchievementsStatus.failure,
        error: e.toString(),
      ));
    }
  }
}
