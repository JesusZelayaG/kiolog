import 'package:drift/drift.dart';

class MealPlans extends Table {
  IntColumn get id => integer().autoIncrement()();
  TextColumn get name => text()();
  DateTimeColumn get createdAt => dateTime()();
  BoolColumn get isActive => boolean().withDefault(const Constant(true))();
}

class MealPlanOptions extends Table {
  IntColumn get id => integer().autoIncrement()();
  IntColumn get planId => integer().references(MealPlans, #id)();
  // meal_type: breakfast | lunch | dinner | snack
  TextColumn get mealType => text()();
  // 1, 2 o 3
  IntColumn get optionNumber => integer()();
  TextColumn get description => text()();
}

class DailyMealLogs extends Table {
  IntColumn get id => integer().autoIncrement()();
  DateTimeColumn get date => dateTime()();
  TextColumn get mealType => text()();
  // null indica comida fuera del plan
  IntColumn get planOptionId => integer().nullable().references(MealPlanOptions, #id)();
  TextColumn get freeDescription => text().nullable()();
  TextColumn get photoPath => text().nullable()();
}
