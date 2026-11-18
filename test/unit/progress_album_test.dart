import 'dart:typed_data';

import 'package:drift/drift.dart' show Value;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kiolog/core/dao/nutrition_dao.dart';
import 'package:kiolog/core/domain/day.dart';
import 'package:kiolog/core/database/app_database.dart';
import 'package:kiolog/features/nutrition/data/repositories/nutrition_repository_impl.dart';
import 'package:kiolog/features/progress/data/repositories/progress_repository_impl.dart';
import 'package:kiolog/features/progress/domain/repositories/progress_repository.dart';

void main() {
  late AppDatabase db;
  late ProgressRepositoryImpl repo;

  setUp(() {
    db = AppDatabase.forTesting(NativeDatabase.memory());
    repo = ProgressRepositoryImpl(db.measurementsDao);
  });
  tearDown(() => db.close());

  Future<int> add(DateTime day, {bool video = false}) => repo.addProgressMedia(
        day: day,
        isVideo: video,
        extension: video ? 'mp4' : 'jpg',
        bytes: Uint8List.fromList([1, 2, 3]),
      );

  test('un día acepta hasta 3 fotos o videos', () async {
    final day = DateTime.utc(2026, 11, 17);
    await add(day);
    await add(day, video: true);
    await add(day);

    expect(() => add(day), throwsA(isA<ProgressAlbumFull>()));
    // Otro día tiene su propio límite.
    await add(DateTime.utc(2026, 11, 18));
  });

  test('borrar libera un lugar del día', () async {
    final day = DateTime.utc(2026, 11, 17);
    final first = await add(day);
    await add(day);
    await add(day);

    await repo.deleteProgressMedia(first);
    await add(day);
    expect((await repo.getProgressMediaInfo()).length, 3);
  });

  test('el álbum va del día más reciente al más antiguo, sin cargar archivos', () async {
    await add(DateTime.utc(2026, 11, 15));
    await add(DateTime.utc(2026, 11, 17), video: true);

    final album = await repo.getProgressMediaInfo();
    expect(album.map((m) => storedDay(m.day).day), [17, 15]);
    expect(album.first.isVideo, isTrue);
    expect((await repo.getProgressMedia(album.first.id))!.bytes, [1, 2, 3]);
  });

  test('el álbum de comidas trae los registros con foto y su estado', () async {
    final nutrition = NutritionRepositoryImpl(db.nutritionDao);
    final planId = await db.nutritionDao.insertMealPlan(MealPlansCompanion.insert(name: 'Plan', createdAt: DateTime.utc(2026)));
    final optionId = await db.into(db.mealPlanOptions).insert(MealPlanOptionsCompanion.insert(
          planId: planId,
          mealType: 'Desayuno',
          optionNumber: 1,
          description: 'Avena con fruta',
        ));
    final day = DateTime.utc(2026, 11, 17);
    final planLog = await db.into(db.dailyMealLogs).insert(
        DailyMealLogsCompanion.insert(date: day, mealType: 'Desayuno', planOptionId: Value(optionId)));
    final offLog = await db.into(db.dailyMealLogs).insert(
        DailyMealLogsCompanion.insert(date: day, mealType: 'Cena', freeDescription: const Value('Pizza')));
    await db.into(db.dailyMealLogs).insert(DailyMealLogsCompanion.insert(date: day, mealType: 'Almuerzo'));
    await nutrition.setLogPhoto(planLog, Uint8List.fromList([1]));
    await nutrition.setLogPhoto(offLog, Uint8List.fromList([2]));

    final album = await nutrition.getMealPhotoEntries();
    expect(album.map((e) => e.mealType), ['Cena', 'Desayuno']);
    expect(album.map((e) => e.status), [MealPhotoStatus.offPlan, MealPhotoStatus.plan]);
    expect(album.map((e) => e.description), ['Pizza', 'Avena con fruta']);
  });
}
