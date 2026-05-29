import 'package:drift/native.dart';
import 'package:kiolog/core/database/app_database.dart';

AppDatabase createTestDatabase() =>
    AppDatabase.forTesting(NativeDatabase.memory());
