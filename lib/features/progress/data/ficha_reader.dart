import 'package:flutter/services.dart';
import 'package:kiolog/core/database/app_database.dart';

import '../domain/ficha_parser.dart';

const _channel = MethodChannel('kiolog/files');

/// Reconoce una ficha en PDF o foto dentro del teléfono, sin enviarla a ningún lado.
Future<Measurement?> readFicha(String path, DateTime date) async {
  final found = await _channel.invokeListMethod<Map>('readText', {'path': path});
  final lines = [
    for (final line in found ?? const <Map>[])
      OcrLine(
        line['text'] as String,
        (line['left'] as num).toDouble(),
        (line['top'] as num).toDouble(),
        (line['bottom'] as num).toDouble(),
      ),
  ];
  return parseFicha(lines, date);
}
