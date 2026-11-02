import 'package:equatable/equatable.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:kiolog/core/database/app_database.dart';

import '../../domain/repositories/progress_repository.dart';

enum ConsultationsStatus { loading, ready, failure }

class ConsultationsState extends Equatable {
  const ConsultationsState({
    this.status = ConsultationsStatus.loading,
    this.consultations = const [],
  });

  final ConsultationsStatus status;

  /// De la más reciente a la más antigua.
  final List<Measurement> consultations;

  @override
  List<Object?> get props => [status, consultations];
}

/// Lista, corrige y borra las consultas registradas.
class ConsultationsCubit extends Cubit<ConsultationsState> {
  ConsultationsCubit(this._repository) : super(const ConsultationsState());

  final ProgressRepository _repository;

  Future<void> load() => _run(() async {});

  /// Una medición con id 0 es nueva; cualquier otra reemplaza a la existente.
  Future<void> save(Measurement m) => _run(() async {
        if (m.id != 0) {
          await _repository.updateMeasurement(m);
          return;
        }
        await _repository.addMeasurement(
          date: m.date,
          weightKg: m.weightKg,
          heightCm: m.heightCm,
          armFlexedCm: m.armFlexedCm,
          armRelaxedCm: m.armRelaxedCm,
          waistCm: m.waistCm,
          hipCm: m.hipCm,
          calfCm: m.calfCm,
          lowerAbdomenCm: m.lowerAbdomenCm,
          thighCm: m.thighCm,
          midGluteusCm: m.midGluteusCm,
          chestCm: m.chestCm,
          bodyFatPct: m.bodyFatPct,
          leanMassKg: m.leanMassKg,
          visceralMass: m.visceralMass,
        );
      });

  Future<void> delete(int id) => _run(() => _repository.deleteMeasurement(id));

  Future<void> _run(Future<void> Function() change) async {
    try {
      await change();
      emit(ConsultationsState(
        status: ConsultationsStatus.ready,
        consultations: await _repository.getMeasurements(),
      ));
    } catch (_) {
      emit(const ConsultationsState(status: ConsultationsStatus.failure));
    }
  }
}
