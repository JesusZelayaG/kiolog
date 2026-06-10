import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kiolog/core/dao/user_modules_dao.dart';
import 'package:kiolog/core/database/app_database.dart';

void main() {
  late AppDatabase db;
  late UserModulesDao dao;

  setUp(() {
    db = AppDatabase.forTesting(NativeDatabase.memory());
    dao = db.userModulesDao;
  });

  tearDown(() => db.close());

  group('UserModulesDao', () {
    test('isModuleEnabled returns true when row missing (default)', () async {
      expect(await dao.isModuleEnabled('nutrition'), isTrue);
    });

    test('setModuleEnabled inserts row and reflects enabled state', () async {
      await dao.setModuleEnabled('nutrition', false);
      expect(await dao.isModuleEnabled('nutrition'), isFalse);
    });

    test('setModuleEnabled upserts — second call updates row', () async {
      await dao.setModuleEnabled('water', false);
      await dao.setModuleEnabled('water', true);
      expect(await dao.isModuleEnabled('water'), isTrue);
    });

    test('getAllModuleStatuses returns map of all seeded modules', () async {
      await dao.setModuleEnabled('nutrition', true);
      await dao.setModuleEnabled('water', false);
      await dao.setModuleEnabled('exercise', true);
      final statuses = await dao.getAllModuleStatuses();
      expect(statuses['nutrition'], isTrue);
      expect(statuses['water'], isFalse);
      expect(statuses['exercise'], isTrue);
    });

    test('seedModules inserts all entries in one transaction', () async {
      await dao.seedModules({'nutrition': true, 'water': false, 'exercise': true});
      expect(await dao.isModuleEnabled('nutrition'), isTrue);
      expect(await dao.isModuleEnabled('water'), isFalse);
      expect(await dao.isModuleEnabled('exercise'), isTrue);
    });

    test('seedModules does not overwrite existing user preference', () async {
      // User explicitly disabled water
      await dao.setModuleEnabled('water', false);
      // Seed tries to set water to true — should not overwrite
      await dao.seedModules({'water': true, 'nutrition': true, 'exercise': true});
      expect(await dao.isModuleEnabled('water'), isFalse); // user preference preserved
      expect(await dao.isModuleEnabled('nutrition'), isTrue); // new row inserted
    });
  });
}
