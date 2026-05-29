import 'package:drift/drift.dart';
import '../database/app_database.dart';
import '../database/tables/nutrition_tables.dart';

part 'nutrition_dao.g.dart';

@DriftAccessor(tables: [MealPlans, MealPlanOptions, DailyMealLogs])
class NutritionDao extends DatabaseAccessor<AppDatabase>
    with _$NutritionDaoMixin {
  NutritionDao(super.db);
}
