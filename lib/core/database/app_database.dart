import 'dart:io';

import 'package:drift/drift.dart';
import 'package:drift/native.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

import 'tables/nutrition_tables.dart';
import 'tables/exercise_tables.dart';
import 'tables/water_sleep_tables.dart';
import 'tables/measurements_tables.dart';
import 'tables/achievements_tables.dart';
import 'tables/config_tables.dart';

import '../dao/nutrition_dao.dart';
import '../dao/exercise_dao.dart';
import '../dao/water_sleep_dao.dart';
import '../dao/measurements_dao.dart';
import '../dao/config_dao.dart';
import '../dao/achievements_dao.dart';
import '../dao/user_profile_dao.dart';

part 'app_database.g.dart';

@DriftDatabase(
  tables: [
    // Nutrition
    MealPlans,
    MealPlanOptions,
    DailyMealLogs,
    // Exercise
    ExercisePlans,
    ExerciseRoutines,
    ExerciseRoutineItems,
    DailyExerciseLogs,
    ExerciseSessionLogs,
    ExerciseSetLogs,
    // Water & Sleep
    DailyWaterLogs,
    SleepLogs,
    // Measurements
    WeightLogs,
    Measurements,
    Achievements,
    // Config
    WaterConfig,
    GymConfig,
    NotificationSettings,
    AiConfig,
    UserProfiles,
  ],
  daos: [
    NutritionDao,
    ExerciseDao,
    WaterSleepDao,
    MeasurementsDao,
    ConfigDao,
    AchievementsDao,
    UserProfileDao,
  ],
)
class AppDatabase extends _$AppDatabase {
  AppDatabase() : super(_openConnection());

  // Constructor para tests — usa base de datos en memoria
  AppDatabase.forTesting(super.executor);

  @override
  int get schemaVersion => 3;

  @override
  MigrationStrategy get migration {
    return MigrationStrategy(
      onCreate: (m) async {
        await m.createAll();
      },
      onUpgrade: (m, from, to) async {
        if (from < 2) {
          await m.createTable(userProfiles);
        }
        if (from < 3) {
          // Rutinas pasan de día de la semana a día de rutina numerado.
          // Se recrean las tablas de ejercicio para el nuevo modelo.
          await m.deleteTable('exercise_set_logs');
          await m.deleteTable('exercise_session_logs');
          await m.deleteTable('daily_exercise_logs');
          await m.deleteTable('exercise_routine_items');
          await m.deleteTable('exercise_routines');
          await m.createTable(exerciseRoutines);
          await m.createTable(exerciseRoutineItems);
          await m.createTable(dailyExerciseLogs);
          await m.createTable(exerciseSessionLogs);
          await m.createTable(exerciseSetLogs);
        }
      },
    );
  }
}

LazyDatabase _openConnection() {
  return LazyDatabase(() async {
    final dir = await getApplicationDocumentsDirectory();
    final file = File(p.join(dir.path, 'kiolog.sqlite'));
    return NativeDatabase.createInBackground(file);
  });
}
