import 'package:bloc_test/bloc_test.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kiolog/core/database/app_database.dart';
import 'package:kiolog/features/water/domain/repositories/water_repository.dart';
import 'package:kiolog/features/water/presentation/bloc/water_bloc.dart';
import 'package:kiolog/features/water/presentation/bloc/water_event.dart';
import 'package:kiolog/features/water/presentation/bloc/water_state.dart';
import 'package:mocktail/mocktail.dart';

class MockWaterRepository extends Mock implements WaterRepository {}

void main() {
  late MockWaterRepository repository;

  setUp(() {
    repository = MockWaterRepository();
  });

  group('WaterBloc', () {
    blocTest<WaterBloc, WaterState>(
      'emits [loading, success] when WaterLoaded succeeds',
      build: () {
        when(() => repository.getDailyTotalMl(any())).thenAnswer((_) async => 1500);
        when(() => repository.getConfig()).thenAnswer((_) async => null);
        return WaterBloc(repository);
      },
      act: (bloc) => bloc.add(WaterLoaded(date: DateTime(2026, 6, 8))),
      expect: () => [
        const WaterState(status: WaterStatus.loading),
        const WaterState(
          status: WaterStatus.success,
          dailyTotalMl: 1500,
          dailyGoalMl: 3000,
          unitType: 'bottle',
          containerMl: 1000,
        ),
      ],
    );

    blocTest<WaterBloc, WaterState>(
      'adds water and updates total',
      build: () {
        when(() => repository.getDailyTotalMl(any())).thenAnswer((_) async => 1000);
        when(() => repository.addWater(any(), any())).thenAnswer((_) async {});
        return WaterBloc(repository)
          ..emit(const WaterState(
            status: WaterStatus.success,
            dailyTotalMl: 500,
            dailyGoalMl: 3000,
          ));
      },
      act: (bloc) => bloc.add(WaterAdded(date: DateTime(2026, 6, 8), amountMl: 500)),
      expect: () => [
        const WaterState(
          status: WaterStatus.success,
          dailyTotalMl: 1000,
          dailyGoalMl: 3000,
        ),
      ],
    );
  });
}
