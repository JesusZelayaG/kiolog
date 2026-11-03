import 'package:flutter/services.dart';

const _channel = MethodChannel('kiolog/files');

/// Abre el selector del sistema y devuelve una copia local, o null si se cancela.
Future<String?> chooseFile({List<String>? mimeTypes}) =>
    _channel.invokeMethod<String>('pick', {'mimeTypes': mimeTypes});

/// Copia [path] a Descargas/Kiolog con el nombre [name] y devuelve la ruta
/// visible. Esa carpeta sobrevive a desinstalar la app.
Future<String?> saveToDownloads(String path, String name) => _channel
    .invokeMethod<String>('saveToDownloads', {'path': path, 'name': name});

/// Borra los archivos más viejos de Descargas/Kiolog que empiezan con
/// [prefix], dejando los [keep] más recientes.
Future<int?> pruneDownloads(String prefix, {required int keep}) =>
    _channel.invokeMethod<int>('pruneDownloads', {'prefix': prefix, 'keep': keep});
