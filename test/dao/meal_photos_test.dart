import 'dart:typed_data';

import 'package:drift/drift.dart' hide isNull;
import 'package:flutter_test/flutter_test.dart';
import 'package:kiolog/core/database/app_database.dart';
import '../helpers/database_helper.dart';

void main() {
  late AppDatabase db;
  late int optionId;

  final photoA = Uint8List.fromList([1, 2, 3]);
  final photoB = Uint8List.fromList([4, 5, 6]);

  Future<int> photoCount() async => (await db.select(db.mealPhotos).get()).length;

  Future<int> logMeal({int? option}) => db.nutritionDao.insertDailyMealLog(DailyMealLogsCompanion(
        date: Value(DateTime.utc(2026, 11, 17)),
        mealType: const Value('Desayuno'),
        planOptionId: Value(option),
        freeDescription: Value(option == null ? 'Pizza' : null),
      ));

  setUp(() async {
    db = createTestDatabase();
    final planId = await db.nutritionDao.insertMealPlan(const MealPlansCompanion(name: Value('Plan')));
    optionId = await db.nutritionDao.insertMealPlanOption(const MealPlanOptionsCompanion(
      planId: Value(1),
      mealType: Value('Desayuno'),
      optionNumber: Value(1),
      description: Value('Avena con fruta'),
    ));
    expect(planId, 1);
  });
  tearDown(() async => db.close());

  test('la foto de referencia de un plato se guarda y se lee', () async {
    final id = await db.nutritionDao.insertPhoto(photoA);
    await db.nutritionDao.setOptionPhoto(optionId, id);

    final option = (await db.nutritionDao.getAllPlanOptions(1)).single;
    expect(option.photoId, id);
    expect(await db.nutritionDao.getPhoto(id), photoA);
  });

  test('cambiar la foto borra la anterior', () async {
    final first = await db.nutritionDao.insertPhoto(photoA);
    await db.nutritionDao.setOptionPhoto(optionId, first);
    final second = await db.nutritionDao.insertPhoto(photoB);
    await db.nutritionDao.setOptionPhoto(optionId, second);

    expect(await db.nutritionDao.getPhoto(first), isNull);
    expect(await photoCount(), 1);
  });

  test('quitar el registro de una comida borra su foto', () async {
    final logId = await logMeal();
    final id = await db.nutritionDao.insertPhoto(photoA);
    await db.nutritionDao.setLogPhoto(logId, id);

    await db.nutritionDao.deleteDailyMealLog(DateTime.utc(2026, 11, 17), 'Desayuno');

    expect(await photoCount(), 0);
  });

  test('una foto que usan el plato y otro registro no se borra antes de tiempo', () async {
    final logId = await logMeal(option: optionId);
    final shared = await db.nutritionDao.insertPhoto(photoA);
    await db.nutritionDao.setOptionPhoto(optionId, shared);
    await db.nutritionDao.setLogPhoto(logId, shared);

    await db.nutritionDao.setLogPhoto(logId, null);

    expect(await db.nutritionDao.getPhoto(shared), photoA);
  });

  test('el ícono se guarda en todas las opciones del tiempo de comida', () async {
    await db.nutritionDao.insertMealPlanOption(const MealPlanOptionsCompanion(
      planId: Value(1),
      mealType: Value('Desayuno'),
      optionNumber: Value(2),
      description: Value('Huevos'),
    ));

    await db.nutritionDao.setMealIcon(1, 'Desayuno', 'coffee');

    final options = await db.nutritionDao.getAllPlanOptions(1);
    expect(options.map((o) => o.mealIcon), everyElement('coffee'));
  });
}
