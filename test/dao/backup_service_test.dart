import 'dart:io';

import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kiolog/core/database/app_database.dart';
import 'package:kiolog/core/database/backup_service.dart';

void main() {
  late Directory dir;

  setUp(() => dir = Directory.systemTemp.createTempSync('kiolog_backup'));
  tearDown(() => dir.deleteSync(recursive: true));

  test('acepta un archivo de base de Kiolog', () async {
    final path = '${dir.path}/ok.sqlite';
    final database = AppDatabase.forTesting(NativeDatabase(File(path)));
    await database.userProfileDao.createProfile();
    await database.close();

    await expectLater(BackupService.validate(path), completes);
    expect(File('$path.check').existsSync(), isFalse);
  });

  test('rechaza un archivo que no es una base de datos', () async {
    final path = '${dir.path}/foto.jpg';
    File(path).writeAsStringSync('esto no es un respaldo');

    await expectLater(BackupService.validate(path), throwsA(isA<InvalidBackupException>()));
  });
}
