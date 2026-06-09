import 'package:bloc_test/bloc_test.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kiolog/features/reports/domain/repositories/report_repository.dart';
import 'package:kiolog/features/reports/presentation/bloc/report_bloc.dart';
import 'package:kiolog/features/reports/presentation/bloc/report_event.dart';
import 'package:kiolog/features/reports/presentation/bloc/report_state.dart';
import 'package:mocktail/mocktail.dart';

class MockReportRepository extends Mock implements ReportRepository {}

void main() {
  late MockReportRepository repository;

  setUp(() {
    repository = MockReportRepository();
  });

  group('ReportBloc', () {
    final data = ReportData(
      start: DateTime(2026, 6, 1),
      end: DateTime(2026, 6, 7),
      waterGoalDays: 5,
      waterTotalDays: 7,
      mealsLogged: 20,
      mealsTotal: 28,
      exerciseDays: 4,
      exerciseTotalDays: 5,
      sleepAverage: 7.5,
      weightLogs: const [],
    );

    blocTest<ReportBloc, ReportState>(
      'emits [loading, success] when report generated',
      build: () {
        when(() => repository.generateReport(any(), any()))
            .thenAnswer((_) async => data);
        return ReportBloc(repository);
      },
      act: (bloc) => bloc.add(ReportGenerated(
        start: DateTime(2026, 6, 1),
        end: DateTime(2026, 6, 7),
      )),
      expect: () => [
        const ReportState(status: ReportStatus.loading),
        ReportState(status: ReportStatus.success, data: data),
      ],
    );
  });
}
