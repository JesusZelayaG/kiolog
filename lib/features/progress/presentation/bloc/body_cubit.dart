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
    this.sessions = const [],
    this.selected = 0,
    this.sex = BodySex.male,
    this.showFat = true,
  });

  final BodyStatus status;

  /// Consultas con estatura, de la más antigua a la más reciente.
  final List<Measurement> sessions;
  final int selected;
  final BodySex sex;
  final bool showFat;

  Measurement? get measurement => sessions.isEmpty ? null : sessions[selected];

  Measurement? get previous => selected > 0 ? sessions[selected - 1] : null;

  /// Perímetros de la consulta elegida, con las claves de [BodyCalibration.sites].
  Map<String, double?> get perimeters => _perimetersOf(measurement);

  /// Cambio de un perímetro frente a la consulta anterior, si ambas lo tienen.
  double? changeIn(String site) {
    final now = perimeters[site];
    final before = _perimetersOf(previous)[site];
    return now == null || before == null ? null : now - before;
  }

  double? get fatChange {
    final now = measurement?.bodyFatPct;
    final before = previous?.bodyFatPct;
    return now == null || before == null ? null : now - before;
  }

  static Map<String, double?> _perimetersOf(Measurement? m) {
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
    List<Measurement>? sessions,
    int? selected,
    BodySex? sex,
    bool? showFat,
  }) =>
      BodyState(
        status: status ?? this.status,
        sessions: sessions ?? this.sessions,
        selected: selected ?? this.selected,
        sex: sex ?? this.sex,
        showFat: showFat ?? this.showFat,
      );

  @override
  List<Object?> get props => [status, sessions, selected, sex, showFat];
}

class BodyCubit extends Cubit<BodyState> {
  BodyCubit(this._progress, this._profile) : super(const BodyState());

  final ProgressRepository _progress;
  final UserProfileDao _profile;

  Future<void> load() async {
    try {
      final profile = await _profile.getProfile();
      final sex = BodySex.values.asNameMap()[profile?.bodySex] ?? BodySex.male;
      final measurements = await _progress.getMeasurements();
      final sessions = measurements.where((m) => m.heightCm > 0).toList()
        ..sort((a, b) {
          final byDate = a.date.compareTo(b.date);
          return byDate != 0 ? byDate : a.id.compareTo(b.id);
        });
      emit(state.copyWith(
        status: sessions.isEmpty ? BodyStatus.empty : BodyStatus.ready,
        sessions: sessions,
        selected: sessions.isEmpty ? 0 : sessions.length - 1,
        sex: sex,
      ));
    } catch (_) {
      emit(state.copyWith(status: BodyStatus.failure));
    }
  }

  void selectSession(int index) => emit(state.copyWith(selected: index));

  void toggleFat() => emit(state.copyWith(showFat: !state.showFat));
}
