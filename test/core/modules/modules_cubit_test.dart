import 'package:bloc_test/bloc_test.dart';
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kiolog/core/dao/user_modules_dao.dart';
import 'package:kiolog/core/database/app_database.dart';
import 'package:kiolog/core/domain/app_module.dart';
import 'package:kiolog/core/modules/cubit/modules_cubit.dart';
import 'package:kiolog/core/modules/cubit/modules_state.dart';

void main() {
  late AppDatabase db;
  late UserModulesDao dao;

  setUp(() {
    db = AppDatabase.forTesting(NativeDatabase.memory());
    dao = db.userModulesDao;
  });

  tearDown(() => db.close());

  group('ModulesCubit', () {
    test('initial state has all modules enabled (default)', () {
      final cubit = ModulesCubit(dao);
      expect(cubit.state.isEnabled(AppModule.nutrition), isTrue);
      expect(cubit.state.isEnabled(AppModule.water), isTrue);
      expect(cubit.state.isEnabled(AppModule.exercise), isTrue);
    });

    blocTest<ModulesCubit, ModulesState>(
      'loadModules emits all-true when DB is empty',
      build: () => ModulesCubit(dao),
      act: (c) => c.loadModules(),
      expect: () => [
        predicate<ModulesState>((s) =>
            s.isEnabled(AppModule.nutrition) &&
            s.isEnabled(AppModule.water) &&
            s.isEnabled(AppModule.exercise)),
      ],
    );

    blocTest<ModulesCubit, ModulesState>(
      'loadModules reflects seeded DB state',
      setUp: () async {
        await dao.seedModules({
          'nutrition': false,
          'water': true,
          'exercise': true,
        });
      },
      build: () => ModulesCubit(dao),
      act: (c) => c.loadModules(),
      expect: () => [
        predicate<ModulesState>((s) =>
            !s.isEnabled(AppModule.nutrition) &&
            s.isEnabled(AppModule.water) &&
            s.isEnabled(AppModule.exercise)),
      ],
    );

    blocTest<ModulesCubit, ModulesState>(
      'setModuleEnabled updates DB and emits new state',
      build: () => ModulesCubit(dao),
      act: (c) async {
        await c.loadModules();
        await c.setModuleEnabled(AppModule.exercise, false);
      },
      expect: () => [
        isA<ModulesState>(), // from loadModules
        predicate<ModulesState>((s) => !s.isEnabled(AppModule.exercise)),
      ],
    );
  });
}
