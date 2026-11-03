import 'dart:io';

import 'package:drift/native.dart';
import 'package:intl/intl.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'app_database.dart';
import 'file_chooser.dart';

const _sqliteHeader = 'SQLite format 3';
const _autoPrefix = 'kiolog_auto_';
const _lastAutoKey = 'last_auto_backup';

/// Cuántos respaldos automáticos diarios se conservan en Descargas/Kiolog.
const autoBackupsKept = 7;

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
    await for (final old in dir.list()) {
      if (p.basename(old.path).startsWith('kiolog_respaldo_')) await old.delete();
    }
    await _db.customStatement('VACUUM INTO ?', [file.path]);
    return file;
  }

  /// Guarda un respaldo en Descargas/Kiolog y devuelve la ruta visible.
  Future<String> saveToPhone({String prefix = 'kiolog_respaldo_'}) async {
    final file = await export();
    final stamp = DateFormat('yyyyMMdd_HHmm').format(DateTime.now());
    final saved = await saveToDownloads(file.path, '$prefix$stamp.sqlite');
    return saved!;
  }

  /// Hace el respaldo automático del día si todavía no existe.
  ///
  /// Nunca lanza: un respaldo fallido no debe impedir abrir la app.
  Future<void> autoBackupIfDue() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final today = DateFormat('yyyy-MM-dd').format(DateTime.now());
      if (prefs.getString(_lastAutoKey) == today) return;
      await saveToPhone(prefix: _autoPrefix);
      await pruneDownloads(_autoPrefix, keep: autoBackupsKept);
      await prefs.setString(_lastAutoKey, today);
    } catch (_) {}
  }

  /// Fecha del último respaldo automático, o null si no hay.
  static Future<DateTime?> lastAutoBackup() async {
    final prefs = await SharedPreferences.getInstance();
    final value = prefs.getString(_lastAutoKey);
    return value == null ? null : DateTime.tryParse(value);
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
  Future<void> restore(String path, {bool keepCopy = true}) async {
    await validate(path);
    // Por si el respaldo elegido era el equivocado.
    if (keepCopy) await saveToPhone(prefix: 'kiolog_antes_de_restaurar_');
    final target = await _databaseFile();
    await _db.close();
    await File(path).copy(target.path);
  }
}
