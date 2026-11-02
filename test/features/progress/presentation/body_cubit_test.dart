import 'package:drift/drift.dart' show Value;
import 'package:flutter_test/flutter_test.dart';
import 'package:kiolog/core/database/app_database.dart';
import 'package:kiolog/features/progress/data/repositories/progress_repository_impl.dart';
import 'package:kiolog/features/progress/domain/body_calibration.dart';
import 'package:kiolog/features/progress/presentation/bloc/body_cubit.dart';
import 'package:kiolog/features/progress/presentation/bloc/progress_state.dart';

import '../../../helpers/database_helper.dart';

void main() {
  late AppDatabase db;
  late BodyCubit cubit;

  setUp(() {
    db = createTestDatabase();
    cubit = BodyCubit(ProgressRepositoryImpl(db.measurementsDao), db.userProfileDao);
  });
  tearDown(() async {
    await cubit.close();
    await db.close();
  });

  Future<void> addMeasurement({required double heightCm}) =>
      db.measurementsDao.insertMeasurement(MeasurementsCompanion.insert(
        date: DateTime.utc(2026, 10, 1),
        weightKg: 74.4,
        heightCm: heightCm,
        waistCm: const Value(85.5),
      ));

  test('sin medición queda vacío', () async {
    await cubit.load();
    expect(cubit.state.status, BodyStatus.empty);
  });

  test('una medición sin estatura no sirve para el modelo', () async {
    await addMeasurement(heightCm: 0);
    await cubit.load();
    expect(cubit.state.status, BodyStatus.empty);
  });

  test('lleva la última medición a los sitios del modelo', () async {
    await addMeasurement(heightCm: 160);
    await cubit.load();
    expect(cubit.state.status, BodyStatus.ready);
    expect(cubit.state.perimeters['cintura'], 85.5);
    expect(cubit.state.perimeters['cadera'], isNull);
  });

  test('el sexo elegido persiste entre aperturas', () async {
    await cubit.setSex(BodySex.female);
    final reopened = BodyCubit(ProgressRepositoryImpl(db.measurementsDao), db.userProfileDao);
    await reopened.load();
    expect(reopened.state.sex, BodySex.female);
    await reopened.close();
  });

  test('registrar otro dato no borra la medición del estado de Progreso', () {
    final measurement = Measurement(
      id: 1,
      date: DateTime.utc(2026, 10, 1),
      weightKg: 74.4,
      heightCm: 160,
    );
    final state = ProgressState(latestMeasurement: measurement);
    expect(state.copyWith(status: ProgressStatus.loading).latestMeasurement, measurement);
  });
}
