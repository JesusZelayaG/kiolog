// lib/core/di/injection.dart
import 'package:get_it/get_it.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../features/exercise/data/services/exercise_weight_unit_service.dart';
import '../../features/exercise/data/repositories/exercise_repository_impl.dart';
import '../../features/exercise/domain/repositories/exercise_repository.dart';
import '../../features/history/data/repositories/history_repository_impl.dart';
import '../../features/history/domain/repositories/history_repository.dart';
import '../../features/nutrition/data/repositories/nutrition_repository_impl.dart';
import '../../features/nutrition/domain/repositories/nutrition_repository.dart';
import '../../features/progress/data/repositories/progress_repository_impl.dart';
import '../../features/progress/domain/repositories/progress_repository.dart';
import '../../features/reports/data/repositories/report_repository_impl.dart';
import '../../features/reports/domain/repositories/report_repository.dart';
import '../../features/sleep/data/repositories/sleep_repository_impl.dart';
import '../../features/sleep/domain/repositories/sleep_repository.dart';
import '../../features/water/data/repositories/water_repository_impl.dart';
import '../../features/water/domain/repositories/water_repository.dart';
import '../dao/config_dao.dart';
import '../dao/exercise_dao.dart';
import '../dao/measurements_dao.dart';
import '../dao/nutrition_dao.dart';
import '../dao/user_modules_dao.dart';
import '../dao/user_profile_dao.dart';
import '../dao/water_sleep_dao.dart';
import '../database/app_database.dart';
import '../modules/cubit/modules_cubit.dart';

final getIt = GetIt.instance;

Future<void> setupDependencies() async {
  // Preferences (singleton)
  final prefs = await SharedPreferences.getInstance();
  getIt.registerSingleton<SharedPreferences>(prefs);
  getIt.registerLazySingleton<ExerciseWeightUnitService>(
    () => ExerciseWeightUnitService(getIt<SharedPreferences>()),
  );

  // Database (singleton)
  getIt.registerSingleton<AppDatabase>(AppDatabase());

  // DAOs (derived from DB singleton)
  getIt.registerLazySingleton(() => getIt<AppDatabase>().nutritionDao);
  getIt.registerLazySingleton(() => getIt<AppDatabase>().exerciseDao);
  getIt.registerLazySingleton(() => getIt<AppDatabase>().waterSleepDao);
  getIt.registerLazySingleton(() => getIt<AppDatabase>().measurementsDao);
  getIt.registerLazySingleton(() => getIt<AppDatabase>().configDao);
  getIt.registerLazySingleton(() => getIt<AppDatabase>().achievementsDao);
  getIt.registerLazySingleton(() => getIt<AppDatabase>().userProfileDao);
  getIt.registerLazySingleton(() => getIt<AppDatabase>().userModulesDao);
  getIt.registerLazySingleton(() => getIt<AppDatabase>().rewardsDao);
  getIt.registerLazySingleton<ModulesCubit>(
    () => ModulesCubit(getIt<UserModulesDao>()),
  );

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
  getIt.registerLazySingleton<ReportRepository>(
    () => ReportRepositoryImpl(
      getIt<WaterSleepDao>(),
      getIt<NutritionDao>(),
      getIt<ExerciseDao>(),
      getIt<MeasurementsDao>(),
      getIt<ConfigDao>(),
      profileDao: getIt<UserProfileDao>(),
    ),
  );
  getIt.registerLazySingleton<HistoryRepository>(
    () => HistoryRepositoryImpl(
      getIt<WaterSleepDao>(),
      getIt<NutritionDao>(),
      getIt<ExerciseDao>(),
    ),
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

  // Ensure user profile row exists
  final profileDao = getIt<UserProfileDao>();
  final profile = await profileDao.getProfile();
  if (profile == null) {
    await profileDao.createProfile();
  }

  // Seed exercise config con valores por defecto si no existe
  final exerciseConfig = await getIt<ExerciseRepository>().getExerciseConfig();
  if (exerciseConfig == null) {
    await getIt<ExerciseRepository>().updateExerciseConfig(
      weeklyRoutineDaysGoal: 4,
      weeklyCardioDaysGoal: 3,
      cardioMinutesGoal: 30,
    );
  }

  await getIt<ModulesCubit>().loadModules();
}
