// lib/core/domain/app_module.dart
enum AppModule {
  nutrition,
  water,
  exercise;

  String get key => name; // 'nutrition', 'water', 'exercise'
}
