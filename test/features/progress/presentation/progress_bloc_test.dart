import 'package:bloc_test/bloc_test.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kiolog/core/database/app_database.dart';
import 'package:kiolog/features/progress/domain/repositories/progress_repository.dart';
import 'package:kiolog/features/progress/presentation/bloc/progress_bloc.dart';
import 'package:kiolog/features/progress/presentation/bloc/progress_event.dart';
import 'package:kiolog/features/progress/presentation/bloc/progress_state.dart';
import 'package:mocktail/mocktail.dart';

class MockProgressRepository extends Mock implements ProgressRepository {}

void main() {
  late MockProgressRepository repository;

  setUp(() {
    repository = MockProgressRepository();
  });

  group('ProgressBloc', () {
    final logs = [
      WeightLog(id: 1, date: DateTime(2026, 5, 1), weightKg: 82),
      WeightLog(id: 2, date: DateTime(2026, 6, 1), weightKg: 80),
    ];
    final measurement = Measurement(
      id: 1,
      date: DateTime(2026, 6, 1),
      weightKg: 80,
      heightCm: 175,
      armFlexedCm: null,
      armRelaxedCm: null,
      waistCm: 85,
      hipCm: null,
      calfCm: null,
      lowerAbdomenCm: null,
      thighCm: null,
      midGluteusCm: null,
      chestCm: null,
      bodyFatPct: null,
      leanMassKg: null,
      visceralMass: null,
    );

    blocTest<ProgressBloc, ProgressState>(
      'emits [loading, success] when ProgressLoaded succeeds',
      build: () {
        when(() => repository.getWeightLogs(any(), any())).thenAnswer((_) async => logs);
        when(() => repository.getLatestMeasurement()).thenAnswer((_) async => measurement);
        return ProgressBloc(repository);
      },
      act: (bloc) => bloc.add(const ProgressLoaded()),
      expect: () => [
        const ProgressState(status: ProgressStatus.loading),
        ProgressState(
          status: ProgressStatus.success,
          weightLogs: logs,
          latestMeasurement: measurement,
        ),
      ],
    );

    blocTest<ProgressBloc, ProgressState>(
      'adds weight and refreshes logs',
      build: () {
        final updatedLogs = [
          ...logs,
          WeightLog(id: 3, date: DateTime(2026, 6, 8), weightKg: 79.5),
        ];
        when(() => repository.addWeightLog(any(), any())).thenAnswer((_) async {});
        when(() => repository.getWeightLogs(any(), any())).thenAnswer((_) async => updatedLogs);
        return ProgressBloc(repository)
          ..emit(ProgressState(status: ProgressStatus.success, weightLogs: logs));
      },
      act: (bloc) => bloc.add(ProgressWeightAdded(
        date: DateTime(2026, 6, 8),
        weightKg: 79.5,
      )),
      expect: () => [
        ProgressState(
          status: ProgressStatus.success,
          weightLogs: [
            ...logs,
            WeightLog(id: 3, date: DateTime(2026, 6, 8), weightKg: 79.5),
          ],
        ),
      ],
    );
  });
}
