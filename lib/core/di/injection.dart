// lib/core/di/injection.dart
import 'package:get_it/get_it.dart';
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
}
