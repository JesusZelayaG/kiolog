import 'package:bloc_test/bloc_test.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kiolog/core/database/app_database.dart';
import 'package:kiolog/features/sleep/domain/repositories/sleep_repository.dart';
import 'package:kiolog/features/sleep/presentation/bloc/sleep_bloc.dart';
import 'package:kiolog/features/sleep/presentation/bloc/sleep_event.dart';
import 'package:kiolog/features/sleep/presentation/bloc/sleep_state.dart';
import 'package:mocktail/mocktail.dart';

class MockSleepRepository extends Mock implements SleepRepository {}

void main() {
  late MockSleepRepository repository;

  setUp(() {
    repository = MockSleepRepository();
  });

  group('SleepBloc', () {
    blocTest<SleepBloc, SleepState>(
      'emits [loading, success] when SleepLoaded succeeds',
      build: () {
        when(() => repository.getSleepLogForDate(any())).thenAnswer((_) async => null);
        return SleepBloc(repository);
      },
      act: (bloc) => bloc.add(SleepLoaded(date: DateTime(2026, 6, 8))),
      expect: () => [
        const SleepState(status: SleepStatus.loading),
        const SleepState(status: SleepStatus.success),
      ],
    );

    blocTest<SleepBloc, SleepState>(
      'adds sleep log and refreshes state',
      build: () {
        when(() => repository.addSleepLog(
          date: any(named: 'date'),
          sleepTime: any(named: 'sleepTime'),
          wakeTime: any(named: 'wakeTime'),
        )).thenAnswer((_) async {});
        when(() => repository.getSleepLogForDate(any())).thenAnswer(
          (_) async => SleepLog(
            id: 1,
            date: DateTime(2026, 6, 8),
            sleepTime: DateTime(2026, 6, 7, 22, 0),
            wakeTime: DateTime(2026, 6, 8, 6, 0),
            hoursCalculated: 8.0,
          ),
        );
        when(() => repository.getSleepLogsInRange(any(), any())).thenAnswer(
          (_) async => [
            SleepLog(
              id: 1,
              date: DateTime(2026, 6, 8),
              sleepTime: DateTime(2026, 6, 7, 22, 0),
              wakeTime: DateTime(2026, 6, 8, 6, 0),
              hoursCalculated: 8.0,
            ),
          ],
        );
        return SleepBloc(repository)
          ..emit(const SleepState(status: SleepStatus.success));
      },
      act: (bloc) => bloc.add(SleepLogAdded(
        date: DateTime(2026, 6, 8),
        sleepTime: DateTime(2026, 6, 7, 22, 0),
        wakeTime: DateTime(2026, 6, 8, 6, 0),
      )),
      expect: () => [
        SleepState(
          status: SleepStatus.success,
          todayLog: SleepLog(
            id: 1,
            date: DateTime(2026, 6, 8),
            sleepTime: DateTime(2026, 6, 7, 22, 0),
            wakeTime: DateTime(2026, 6, 8, 6, 0),
            hoursCalculated: 8.0,
          ),
          weeklyLogs: [
            SleepLog(
              id: 1,
              date: DateTime(2026, 6, 8),
              sleepTime: DateTime(2026, 6, 7, 22, 0),
              wakeTime: DateTime(2026, 6, 8, 6, 0),
              hoursCalculated: 8.0,
            ),
          ],
        ),
      ],
    );
  });
}
