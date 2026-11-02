import 'package:equatable/equatable.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:kiolog/core/dao/user_profile_dao.dart';
import 'package:kiolog/core/database/app_database.dart';

import '../../domain/body_calibration.dart';
import '../../domain/repositories/progress_repository.dart';

enum BodyStatus { loading, ready, empty, failure }

class BodyState extends Equatable {
  const BodyState({
    this.status = BodyStatus.loading,
    this.measurement,
    this.sex = BodySex.male,
    this.showFat = true,
  });

  final BodyStatus status;
  final Measurement? measurement;
  final BodySex sex;
  final bool showFat;

  /// Perímetros de la medición, con las claves de [BodyCalibration.sites].
  Map<String, double?> get perimeters {
    final m = measurement;
    if (m == null) return const {};
    return {
      'pecho': m.chestCm,
      'cintura': m.waistCm,
      'abdomen': m.lowerAbdomenCm,
      'cadera': m.hipCm,
      'brazo': m.armRelaxedCm,
      'muslo': m.thighCm,
      'pantorrilla': m.calfCm,
    };
  }

  BodyState copyWith({
    BodyStatus? status,
    Measurement? measurement,
    BodySex? sex,
    bool? showFat,
  }) =>
      BodyState(
        status: status ?? this.status,
        measurement: measurement ?? this.measurement,
        sex: sex ?? this.sex,
        showFat: showFat ?? this.showFat,
      );

  @override
  List<Object?> get props => [status, measurement, sex, showFat];
}

class BodyCubit extends Cubit<BodyState> {
  BodyCubit(this._progress, this._profile) : super(const BodyState());

  final ProgressRepository _progress;
  final UserProfileDao _profile;

  Future<void> load() async {
    try {
      final profile = await _profile.getProfile();
      final sex = BodySex.values.asNameMap()[profile?.bodySex] ?? BodySex.male;
      final measurement = await _progress.getLatestMeasurement();
      final usable = measurement != null && measurement.heightCm > 0;
      emit(state.copyWith(
        status: usable ? BodyStatus.ready : BodyStatus.empty,
        measurement: usable ? measurement : null,
        sex: sex,
      ));
    } catch (_) {
      emit(state.copyWith(status: BodyStatus.failure));
    }
  }

  Future<void> setSex(BodySex sex) async {
    emit(state.copyWith(sex: sex));
    await _profile.updateBodySex(sex.name);
  }

  void toggleFat() => emit(state.copyWith(showFat: !state.showFat));
}
