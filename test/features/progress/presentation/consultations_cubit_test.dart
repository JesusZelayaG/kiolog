import 'package:flutter_test/flutter_test.dart';
import 'package:kiolog/core/database/app_database.dart';
import 'package:kiolog/features/progress/data/repositories/progress_repository_impl.dart';
import 'package:kiolog/features/progress/presentation/bloc/consultations_cubit.dart';
import 'package:kiolog/features/progress/presentation/widgets/measurement_form.dart';

import '../../../helpers/database_helper.dart';

void main() {
  late AppDatabase db;
  late ProgressRepositoryImpl repository;
  late ConsultationsCubit cubit;

  Measurement consultation({int id = 0, double weightKg = 74.4, int day = 10}) => Measurement(
        id: id,
        date: DateTime.utc(2026, 10, day),
        weightKg: weightKg,
        heightCm: 160,
      );

  setUp(() {
    db = createTestDatabase();
    repository = ProgressRepositoryImpl(db.measurementsDao);
    cubit = ConsultationsCubit(repository);
  });
  tearDown(() async {
    await cubit.close();
    await db.close();
  });

  test('guarda una consulta nueva y corrige una existente', () async {
    await cubit.save(consultation());
    final saved = cubit.state.consultations.single;

    await cubit.save(consultation(id: saved.id, weightKg: 73));

    expect(cubit.state.consultations.single.weightKg, 73);
  });

  test('borrar una consulta la quita también de la gráfica de peso', () async {
    await cubit.save(consultation());
    final range = [DateTime.utc(2026, 10), DateTime.utc(2026, 11)];
    expect(await repository.getWeightLogs(range[0], range[1]), hasLength(1));

    await cubit.delete(cubit.state.consultations.single.id);

    expect(cubit.state.consultations, isEmpty);
    expect(await repository.getWeightLogs(range[0], range[1]), isEmpty);
  });

  test('el peso de la consulta entra a la gráfica en orden y sin duplicar el día', () async {
    await repository.addWeightLog(DateTime.utc(2026, 10, 5), 75);
    await repository.addWeightLog(DateTime.utc(2026, 10, 10), 74);
    await cubit.save(consultation(day: 10));
    await cubit.save(consultation(day: 7, weightKg: 74.8));

    final logs = await repository.getWeightLogs(DateTime.utc(2026, 10), DateTime.utc(2026, 11));

    expect(logs.map((l) => l.weightKg), [75, 74.8, 74]);
  });

  test('una consulta fuera del rango no entra a la gráfica', () async {
    await cubit.save(consultation(day: 10));
    final logs = await repository.getWeightLogs(DateTime.utc(2026, 11), DateTime.utc(2026, 12));
    expect(logs, isEmpty);
  });

  test('entiende la coma decimal del teclado', () {
    expect(parseMeasure('74,4'), 74.4);
    expect(parseMeasure(' 160 '), 160);
    expect(parseMeasure(''), isNull);
    expect(parseMeasure('0'), isNull);
  });
}
