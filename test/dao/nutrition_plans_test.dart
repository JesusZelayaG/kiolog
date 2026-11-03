import 'package:drift/drift.dart' hide isNull, isNotNull;
import 'package:flutter_test/flutter_test.dart';
import 'package:kiolog/core/database/app_database.dart';
import 'package:kiolog/features/nutrition/data/repositories/nutrition_repository_impl.dart';
import 'package:kiolog/features/nutrition/domain/models/plan_option_draft.dart';

import '../helpers/database_helper.dart';

void main() {
  late AppDatabase db;

  setUp(() => db = createTestDatabase());
  tearDown(() async => db.close());

  Future<int> plan(String name, {int? goal}) => db.nutritionDao.insertMealPlan(
        MealPlansCompanion.insert(
          name: name,
          createdAt: DateTime.now().toUtc(),
          dailyMealGoal: Value(goal ?? 3),
        ),
      );

  Future<int> option(int planId, String type, String text) =>
      db.nutritionDao.insertMealPlanOption(MealPlanOptionsCompanion.insert(
        planId: planId,
        mealType: type,
        optionNumber: 1,
        description: text,
      ));

  Future<void> log(int optionId, String type) =>
      db.nutritionDao.insertDailyMealLog(DailyMealLogsCompanion.insert(
        date: DateTime.utc(2026, 11, 2),
        mealType: type,
        planOptionId: Value(optionId),
      ));

  test('un plan nuevo reemplaza al actual y cierra su periodo', () async {
    final first = await plan('Octubre');
    final second = await plan('Noviembre');

    final plans = await db.nutritionDao.getMealPlans();
    final old = plans.firstWhere((p) => p.id == first);
    final current = await db.nutritionDao.getActiveMealPlan();

    expect(current?.id, second);
    expect(old.isActive, isFalse);
    expect(old.periodEnd, isNotNull);
    expect(current?.periodStart, isNotNull);
  });

  test('editar conserva las comidas registradas', () async {
    final id = await plan('Plan');
    final kept = await option(id, 'Desayuno', 'Avena');
    final removed = await option(id, 'Cena', 'Pollo');
    await log(kept, 'Desayuno');
    await log(removed, 'Cena');

    await db.nutritionDao.updateMealPlan(
      planId: id,
      name: 'Plan corregido',
      dailyMealGoal: 2,
      options: [
        PlanOptionDraft(id: kept, mealType: 'Mañana', optionNumber: 1, description: 'Avena con fruta'),
        const PlanOptionDraft(mealType: 'Merienda', optionNumber: 1, description: 'Yogur'),
      ],
    );

    final options = await db.nutritionDao.getAllPlanOptions(id);
    final logs = await db.nutritionDao.getDailyMealLogs(DateTime.utc(2026, 11, 2));
    final saved = await db.nutritionDao.getActiveMealPlan();

    expect(saved?.name, 'Plan corregido');
    expect(saved?.dailyMealGoal, 2);
    expect(options.map((o) => o.description), containsAll(['Avena con fruta', 'Yogur']));
    expect(options, hasLength(2));
    expect(logs, hasLength(2));
    expect(logs.firstWhere((l) => l.planOptionId == kept).mealType, 'Mañana');
    expect(logs.firstWhere((l) => l.planOptionId == null).freeDescription, 'Pollo');
  });

  test('borrar el plan actual retoma el anterior', () async {
    final first = await plan('Octubre');
    final second = await plan('Noviembre');
    await log(await option(second, 'Cena', 'Pollo'), 'Cena');

    await db.nutritionDao.deleteMealPlan(second);

    final current = await db.nutritionDao.getActiveMealPlan();
    expect(current?.id, first);
    expect(current?.periodEnd, isNull);
    expect(await db.nutritionDao.getAllPlanOptions(second), isEmpty);
    expect(await db.nutritionDao.getDailyMealLogs(DateTime.utc(2026, 11, 2)), isEmpty);
  });

  test('borrar el único plan deja la app sin plan activo', () async {
    await db.nutritionDao.deleteMealPlan(await plan('Único'));
    expect(await db.nutritionDao.getActiveMealPlan(), isNull);
  });

  test('cuenta el apego dentro del periodo del plan', () async {
    final repository = NutritionRepositoryImpl(db.nutritionDao);
    final id = await plan('Plan', goal: 2);
    await log(await option(id, 'Cena', 'Pollo'), 'Cena');
    await (db.update(db.mealPlans)..where((t) => t.id.equals(id))).write(
      MealPlansCompanion(
        periodStart: Value(DateTime.utc(2026, 11, 1)),
        periodEnd: Value(DateTime.utc(2026, 11, 4)),
      ),
    );

    final saved = (await db.nutritionDao.getMealPlans()).single;
    final counts = await repository.getPlanMealCounts(saved);

    expect(counts.logged, 1);
    expect(counts.expected, 6);
  });

  test('meal times keep the order they were written in', () async {
    final id = await plan('Plan');
    for (final type in ['Desayuno', 'Almuerzo', 'Refacción', 'Cena']) {
      await option(id, type, type);
    }

    final options = await db.nutritionDao.getAllPlanOptions(id);

    expect(options.map((o) => o.mealType),
        ['Desayuno', 'Almuerzo', 'Refacción', 'Cena']);
  });
}
