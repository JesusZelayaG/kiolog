import 'package:drift/drift.dart';

class MealPlans extends Table {
  IntColumn get id => integer().autoIncrement()();
  TextColumn get name => text()();
  DateTimeColumn get createdAt => dateTime()();
  BoolColumn get isActive => boolean().withDefault(const Constant(true))();
  DateTimeColumn get periodStart => dateTime().nullable()();
  DateTimeColumn get periodEnd => dateTime().nullable()();
  IntColumn get dailyMealGoal => integer().withDefault(const Constant(4))();
}

class MealPlanOptions extends Table {
  IntColumn get id => integer().autoIncrement()();
  IntColumn get planId => integer().references(MealPlans, #id)();
  // meal_type: breakfast | lunch | dinner | snack
  TextColumn get mealType => text()();
  // 1, 2 o 3
  IntColumn get optionNumber => integer()();
  TextColumn get description => text()();

  /// Cómo debería verse el plato; ver [MealPhotos].
  IntColumn get photoId => integer().nullable().references(MealPhotos, #id)();

  /// Ícono elegido para el tiempo de comida (MealIcon.name). Todas las
  /// opciones de un tiempo llevan el mismo; null usa el sugerido por el nombre.
  TextColumn get mealIcon => text().nullable()();
}

class DailyMealLogs extends Table {
  IntColumn get id => integer().autoIncrement()();
  DateTimeColumn get date => dateTime()();
  TextColumn get mealType => text()();
  // null indica comida fuera del plan
  IntColumn get planOptionId => integer().nullable().references(MealPlanOptions, #id)();
  TextColumn get freeDescription => text().nullable()();
  TextColumn get photoPath => text().nullable()();

  /// Lo que se comió de verdad; ver [MealPhotos].
  IntColumn get photoId => integer().nullable().references(MealPhotos, #id)();
}

/// Fotos de comida, comprimidas en la base para que el respaldo siga siendo
/// un solo archivo. Van aparte para que leer los registros no cargue imágenes.
/// Nunca salen en el reporte para la nutricionista.
class MealPhotos extends Table {
  IntColumn get id => integer().autoIncrement()();
  BlobColumn get bytes => blob()();
  DateTimeColumn get takenAt => dateTime()();
}
