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
        when(() => repository.getMonthSummary(any()))
            .thenAnswer((_) async => days);
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
          compliance: computeMonthCompliance(days),
        ),
      ],
    );

    group('computeMonthCompliance', () {
      test('returns zeros when no days', () {
        final result = computeMonthCompliance([]);
        expect(result.water, 0.0);
        expect(result.meals, 0.0);
        expect(result.exercise, 0.0);
      });

      test('returns zeros when all days are in the future', () {
        final future = DateTime.now().add(const Duration(days: 30));
        final futureDays = [
          DaySummary(
            date: DateTime.utc(future.year, future.month, future.day),
            hasWater: true,
            hasSleep: false,
            hasMeals: true,
            hasExercise: true,
          ),
        ];
        final result = computeMonthCompliance(futureDays);
        expect(result.water, 0.0);
        expect(result.meals, 0.0);
        expect(result.exercise, 0.0);
      });

      test('counts past days only and computes correct ratios', () {
        final yesterday = DateTime.now().subtract(const Duration(days: 1));
        final pastDay = DateTime.utc(
            yesterday.year, yesterday.month, yesterday.day);
        final pastDays = [
          DaySummary(
            date: pastDay,
            hasWater: true,
            hasSleep: false,
            hasMeals: false,
            hasExercise: true,
          ),
        ];
        final result = computeMonthCompliance(pastDays);
        expect(result.water, 1.0);
        expect(result.meals, 0.0);
        expect(result.exercise, 1.0);
      });
    });
  });
}
