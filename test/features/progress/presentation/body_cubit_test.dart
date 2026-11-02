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

  Future<void> addMeasurement({
    required double heightCm,
    double waistCm = 85.5,
    double? hipCm,
    int day = 1,
  }) =>
      db.measurementsDao.insertMeasurement(MeasurementsCompanion.insert(
        date: DateTime.utc(2026, 10, day),
        weightKg: 74.4,
        heightCm: heightCm,
        waistCm: Value(waistCm),
        hipCm: Value(hipCm),
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

  test('abre en la consulta más reciente, aunque se guardara antes', () async {
    await addMeasurement(heightCm: 160, waistCm: 80, day: 20);
    await addMeasurement(heightCm: 160, waistCm: 90, day: 5);
    await cubit.load();
    expect(cubit.state.sessions.map((m) => m.waistCm), [90, 80]);
    expect(cubit.state.perimeters['cintura'], 80);
  });

  test('elegir una fecha muestra sus medidas y el cambio frente a la anterior', () async {
    await addMeasurement(heightCm: 160, waistCm: 90, day: 1);
    await addMeasurement(heightCm: 160, waistCm: 88, day: 10);
    await addMeasurement(heightCm: 160, waistCm: 85, hipCm: 100, day: 20);
    await cubit.load();

    expect(cubit.state.changeIn('cintura'), -3);
    expect(cubit.state.changeIn('cadera'), isNull);

    cubit.selectSession(0);
    expect(cubit.state.perimeters['cintura'], 90);
    expect(cubit.state.previous, isNull);
    expect(cubit.state.changeIn('cintura'), isNull);
  });

  test('usa el sexo guardado en el onboarding', () async {
    await db.userProfileDao.completeOnboarding(DateTime.utc(2026, 11, 1));
    await db.userProfileDao.updateBodySex('female');
    await cubit.load();
    expect(cubit.state.sex, BodySex.female);
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
