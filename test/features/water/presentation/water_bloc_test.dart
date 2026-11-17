import 'package:bloc_test/bloc_test.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kiolog/core/database/app_database.dart';
import 'package:kiolog/features/water/domain/repositories/water_repository.dart';
import 'package:kiolog/features/water/presentation/bloc/water_bloc.dart';
import 'package:kiolog/features/water/presentation/bloc/water_event.dart';
import 'package:kiolog/features/water/presentation/bloc/water_state.dart';
import 'package:mocktail/mocktail.dart';

class MockWaterRepository extends Mock implements WaterRepository {}

DailyWaterLog intake(int id, int ml) => DailyWaterLog(
      id: id,
      date: DateTime.utc(2026, 6, 8),
      timestamp: DateTime(2026, 6, 8, 9 + id),
      amountMl: ml,
    );

void main() {
  late MockWaterRepository repository;

  setUpAll(() => registerFallbackValue(DateTime(2026)));
  setUp(() => repository = MockWaterRepository());

  group('WaterBloc', () {
    blocTest<WaterBloc, WaterState>(
      'carga las tomas de hoy y la meta',
      build: () {
        when(() => repository.getDailyLogs(any())).thenAnswer((_) async => [intake(1, 1000), intake(2, 500)]);
        when(() => repository.getConfig()).thenAnswer((_) async => null);
        return WaterBloc(repository);
      },
      act: (bloc) => bloc.add(WaterLoaded(date: DateTime(2026, 6, 8))),
      expect: () => [
        const WaterState(status: WaterStatus.loading),
        WaterState(
          status: WaterStatus.success,
          dailyTotalMl: 1500,
          dailyGoalMl: 3000,
          logs: [intake(1, 1000), intake(2, 500)],
        ),
      ],
    );

    blocTest<WaterBloc, WaterState>(
      'agrega la cantidad escrita y recalcula el total',
      build: () {
        when(() => repository.addWater(any(), any())).thenAnswer((_) async {});
        when(() => repository.getDailyLogs(any())).thenAnswer((_) async => [intake(1, 500), intake(2, 350)]);
        return WaterBloc(repository)..emit(const WaterState(status: WaterStatus.success, dailyTotalMl: 500));
      },
      act: (bloc) => bloc.add(WaterAdded(date: DateTime(2026, 6, 8), amountMl: 350)),
      verify: (_) => verify(() => repository.addWater(any(), 350)).called(1),
      expect: () => [
        WaterState(status: WaterStatus.success, dailyTotalMl: 850, logs: [intake(1, 500), intake(2, 350)]),
      ],
    );

    blocTest<WaterBloc, WaterState>(
      'borrar una toma la descuenta',
      build: () {
        when(() => repository.deleteWaterLog(any())).thenAnswer((_) async {});
        when(() => repository.getDailyLogs(any())).thenAnswer((_) async => [intake(1, 500)]);
        return WaterBloc(repository)..emit(const WaterState(status: WaterStatus.success, dailyTotalMl: 850));
      },
      act: (bloc) => bloc.add(const WaterLogDeleted(2)),
      expect: () => [
        WaterState(status: WaterStatus.success, dailyTotalMl: 500, logs: [intake(1, 500)]),
      ],
    );
  });
}
