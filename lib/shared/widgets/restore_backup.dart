import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:kiolog/core/database/app_database.dart';
import 'package:kiolog/core/database/backup_service.dart';
import 'package:kiolog/core/database/file_chooser.dart';
import 'package:kiolog/core/di/injection.dart';

/// Elige un respaldo, confirma y reemplaza los datos. La app se cierra al
/// terminar porque la base queda cerrada.
///
/// [keepCopy] guarda antes los datos actuales en Descargas/Kiolog; en una
/// instalación nueva no hay nada que guardar.
Future<void> restoreBackupFlow(BuildContext context, {bool keepCopy = true}) async {
  final messenger = ScaffoldMessenger.of(context);
  final path = await chooseFile();
  if (path == null || !context.mounted) return;
  final confirmed = await showDialog<bool>(
    context: context,
    builder: (dialogContext) => AlertDialog(
      title: const Text('Restaurar respaldo'),
      content: Text(
        keepCopy
            ? 'Los datos actuales de este teléfono se reemplazarán por los del respaldo. '
                'Antes se guardará una copia de ellos en Descargas/Kiolog. '
                'La app se cerrará y deberás abrirla de nuevo.'
            : 'Se cargarán tus planes, consultas y registros del respaldo. '
                'La app se cerrará y deberás abrirla de nuevo.',
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(dialogContext, false),
          child: const Text('Cancelar'),
        ),
        ElevatedButton(
          onPressed: () => Navigator.pop(dialogContext, true),
          child: const Text('Restaurar'),
        ),
      ],
    ),
  );
  if (confirmed != true) return;
  try {
    await BackupService(getIt<AppDatabase>()).restore(path, keepCopy: keepCopy);
    await SystemNavigator.pop();
  } on InvalidBackupException {
    messenger.showSnackBar(
      const SnackBar(content: Text('Ese archivo no es un respaldo de Kiolog')),
    );
  } catch (_) {
    messenger.showSnackBar(
      const SnackBar(content: Text('No se pudo restaurar el respaldo')),
    );
  }
}
