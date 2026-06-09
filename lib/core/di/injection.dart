// lib/core/di/injection.dart
import 'package:get_it/get_it.dart';
import '../../features/exercise/data/repositories/exercise_repository_impl.dart';
import '../../features/exercise/domain/repositories/exercise_repository.dart';
import '../../features/nutrition/data/repositories/nutrition_repository_impl.dart';
import '../../features/nutrition/domain/repositories/nutrition_repository.dart';
import '../../features/progress/data/repositories/progress_repository_impl.dart';
import '../../features/progress/domain/repositories/progress_repository.dart';
import '../../features/sleep/data/repositories/sleep_repository_impl.dart';
import '../../features/sleep/domain/repositories/sleep_repository.dart';
import '../../features/water/data/repositories/water_repository_impl.dart';
import '../../features/water/domain/repositories/water_repository.dart';
import '../dao/config_dao.dart';
import '../dao/exercise_dao.dart';
import '../dao/measurements_dao.dart';
import '../dao/nutrition_dao.dart';
import '../dao/water_sleep_dao.dart';
import '../database/app_database.dart';

final getIt = GetIt.instance;

Future<void> setupDependencies() async {
  // Database (singleton)
  getIt.registerSingleton<AppDatabase>(AppDatabase());

  // DAOs (derived from DB singleton)
  getIt.registerLazySingleton(() => getIt<AppDatabase>().nutritionDao);
  getIt.registerLazySingleton(() => getIt<AppDatabase>().exerciseDao);
  getIt.registerLazySingleton(() => getIt<AppDatabase>().waterSleepDao);
  getIt.registerLazySingleton(() => getIt<AppDatabase>().measurementsDao);
  getIt.registerLazySingleton(() => getIt<AppDatabase>().configDao);
  getIt.registerLazySingleton(() => getIt<AppDatabase>().achievementsDao);

  // Repositories
  getIt.registerLazySingleton<WaterRepository>(
    () => WaterRepositoryImpl(
      getIt<WaterSleepDao>(),
      getIt<ConfigDao>(),
    ),
  );
  getIt.registerLazySingleton<ProgressRepository>(
    () => ProgressRepositoryImpl(getIt<MeasurementsDao>()),
  );
  getIt.registerLazySingleton<ExerciseRepository>(
    () => ExerciseRepositoryImpl(getIt<ExerciseDao>()),
  );
  getIt.registerLazySingleton<NutritionRepository>(
    () => NutritionRepositoryImpl(getIt<NutritionDao>()),
  );
  getIt.registerLazySingleton<SleepRepository>(
    () => SleepRepositoryImpl(getIt<WaterSleepDao>()),
  );

  // Seed default achievements (idempotent — safe to call on every startup)
  await getIt<AppDatabase>().achievementsDao.seedDefaultAchievements();
}
