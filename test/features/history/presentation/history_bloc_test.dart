import 'package:bloc_test/bloc_test.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kiolog/features/history/domain/repositories/history_repository.dart';
import 'package:kiolog/features/history/presentation/bloc/history_bloc.dart';
import 'package:kiolog/features/history/presentation/bloc/history_event.dart';
import 'package:kiolog/features/history/presentation/bloc/history_state.dart';
import 'package:mocktail/mocktail.dart';

class MockHistoryRepository extends Mock implements HistoryRepository {}

void main() {
  late MockHistoryRepository repository;

  setUp(() {
    repository = MockHistoryRepository();
  });

  group('HistoryBloc', () {
    final days = [
      DaySummary(
        date: DateTime(2026, 6, 1),
        hasWater: true,
        hasSleep: false,
        hasMeals: true,
        hasExercise: false,
      ),
    ];

    blocTest<HistoryBloc, HistoryState>(
      'emits [loading, success] when month loaded',
      build: () {
        when(() => repository.getMonthSummary(any())).thenAnswer((_) async => days);
        return HistoryBloc(repository)
          ..emit(HistoryState(currentMonth: DateTime(2026, 5, 1)));
      },
      act: (bloc) => bloc.add(HistoryMonthLoaded(month: DateTime(2026, 6))),
      expect: () => [
        HistoryState(
          status: HistoryStatus.loading,
          currentMonth: DateTime(2026, 5, 1),
        ),
        HistoryState(
          status: HistoryStatus.success,
          currentMonth: DateTime(2026, 6),
          days: days,
        ),
      ],
    );
  });
}
