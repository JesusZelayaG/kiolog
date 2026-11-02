import 'package:flutter/services.dart';

const _channel = MethodChannel('kiolog/files');

/// Abre el selector del sistema y devuelve una copia local, o null si se cancela.
Future<String?> chooseFile({List<String>? mimeTypes}) =>
    _channel.invokeMethod<String>('pick', {'mimeTypes': mimeTypes});
