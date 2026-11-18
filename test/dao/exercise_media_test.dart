import 'dart:typed_data';

import 'package:drift/drift.dart' hide isNull, isNotNull;
import 'package:flutter_test/flutter_test.dart';
import 'package:kiolog/core/database/app_database.dart';
import '../helpers/database_helper.dart';

void main() {
  late AppDatabase db;
  late int routineId;

  Future<int> item(String name, {int? mediaId}) => db.exerciseDao.insertExerciseRoutineItem(
        ExerciseRoutineItemsCompanion(
          routineId: Value(routineId),
          exerciseName: Value(name),
          sets: const Value(3),
          reps: const Value(10),
          mediaId: Value(mediaId),
        ),
      );

  Future<int> media() =>
      db.exerciseDao.insertMedia(bytes: Uint8List.fromList([1, 2, 3]), kind: 'video', extension: 'mp4');

  setUp(() async {
    db = createTestDatabase();
    final planId = await db.exerciseDao.insertExercisePlan(const ExercisePlansCompanion(name: Value('Plan')));
    routineId = await db.exerciseDao.insertExerciseRoutine(ExerciseRoutinesCompanion(
      planId: Value(planId),
      dayNumber: const Value(1),
      routineName: const Value('Espalda'),
    ));
  });
  tearDown(() async => db.close());

  test('el video de un ejercicio se guarda y se lee', () async {
    final id = await media();
    final itemId = await item('Jalones', mediaId: id);

    final stored = (await db.exerciseDao.getRoutineItems(routineId)).single;
    expect(stored.id, itemId);
    final m = await db.exerciseDao.getMedia(stored.mediaId!);
    expect(m!.kind, 'video');
    expect(m.extension, 'mp4');
  });

  test('quitar el video de un ejercicio lo borra', () async {
    final id = await media();
    final itemId = await item('Jalones', mediaId: id);

    await db.exerciseDao.updateRoutineItem(itemId, const ExerciseRoutineItemsCompanion(mediaId: Value(null)));

    expect(await db.exerciseDao.getMedia(id), isNull);
  });

  test('un video que usan dos ejercicios sigue al borrar uno', () async {
    final id = await media();
    final first = await item('Jalones', mediaId: id);
    await item('Jalones (copia del plan)', mediaId: id);

    await db.exerciseDao.deleteRoutineItem(first);

    expect(await db.exerciseDao.getMedia(id), isNotNull);
  });
}
