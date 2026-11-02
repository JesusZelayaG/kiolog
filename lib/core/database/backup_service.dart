import 'dart:io';

import 'package:drift/native.dart';
import 'package:intl/intl.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

import 'app_database.dart';

const _sqliteHeader = 'SQLite format 3';

class InvalidBackupException implements Exception {}

/// Copia y restaura la base de datos local como un solo archivo.
class BackupService {
  BackupService(this._db);

  final AppDatabase _db;

  Future<File> _databaseFile() async {
    final dir = await getApplicationDocumentsDirectory();
    return File(p.join(dir.path, 'kiolog.sqlite'));
  }

  /// Escribe una copia consistente y devuelve su archivo temporal.
  Future<File> export() async {
    final dir = await getTemporaryDirectory();
    final stamp = DateFormat('yyyyMMdd_HHmm').format(DateTime.now());
    final file = File(p.join(dir.path, 'kiolog_respaldo_$stamp.sqlite'));
    if (await file.exists()) await file.delete();
    await _db.customStatement('VACUUM INTO ?', [file.path]);
    return file;
  }

  /// Comprueba que [path] sea un respaldo de Kiolog sin tocar los datos actuales.
  static Future<void> validate(String path) async {
    final source = File(path);
    final bytes = await source.openRead(0, _sqliteHeader.length).expand((b) => b).toList();
    if (String.fromCharCodes(bytes) != _sqliteHeader) {
      throw InvalidBackupException();
    }
    final probe = File('$path.check');
    await source.copy(probe.path);
    final database = AppDatabase.forTesting(NativeDatabase(probe));
    try {
      await database.measurementsDao.getMeasurements();
      await database.userProfileDao.getProfile();
    } catch (_) {
      throw InvalidBackupException();
    } finally {
      await database.close();
      await probe.delete();
    }
  }

  /// Reemplaza los datos actuales. La base queda cerrada: hay que reabrir la app.
  Future<void> restore(String path) async {
    await validate(path);
    final target = await _databaseFile();
    await _db.close();
    await File(path).copy(target.path);
  }
}
