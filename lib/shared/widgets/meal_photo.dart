import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:iconsax_plus/iconsax_plus.dart';
import 'package:image_picker/image_picker.dart';
import 'package:kiolog/core/di/injection.dart';
import 'package:kiolog/features/nutrition/domain/repositories/nutrition_repository.dart';

/// Lo que eligió el usuario en la hoja de foto.
sealed class PhotoChoice {
  const PhotoChoice();
}

class PhotoPicked extends PhotoChoice {
  const PhotoPicked(this.bytes);
  final Uint8List bytes;
}

class PhotoRemoved extends PhotoChoice {
  const PhotoRemoved();
}

/// Hasta 1080 px y calidad 70: unos 100 a 200 KB por foto, suficiente para
/// verla en el teléfono sin inflar el respaldo.
const _maxSide = 1080.0;
const _quality = 70;

/// Pide una foto de la cámara o la galería. Devuelve null si se canceló.
Future<PhotoChoice?> pickMealPhoto(
  BuildContext context, {
  required String title,
  bool canRemove = false,
}) async {
  final source = await showModalBottomSheet<Object>(
    context: context,
    showDragHandle: true,
    builder: (sheetContext) => SafeArea(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(24, 0, 24, 8),
            child: Text(title, style: Theme.of(sheetContext).textTheme.titleLarge),
          ),
          ListTile(
            leading: const Icon(IconsaxPlusLinear.camera),
            title: const Text('Tomar foto'),
            onTap: () => Navigator.pop(sheetContext, ImageSource.camera),
          ),
          ListTile(
            leading: const Icon(IconsaxPlusLinear.gallery),
            title: const Text('Elegir de la galería'),
            onTap: () => Navigator.pop(sheetContext, ImageSource.gallery),
          ),
          if (canRemove)
            ListTile(
              leading: Icon(IconsaxPlusLinear.trash, color: Theme.of(sheetContext).colorScheme.error),
              title: Text('Quitar foto', style: TextStyle(color: Theme.of(sheetContext).colorScheme.error)),
              onTap: () => Navigator.pop(sheetContext, const PhotoRemoved()),
            ),
          const SizedBox(height: 8),
        ],
      ),
    ),
  );
  if (source is PhotoRemoved) return source;
  if (source is! ImageSource) return null;
  final file = await ImagePicker().pickImage(
    source: source,
    maxWidth: _maxSide,
    maxHeight: _maxSide,
    imageQuality: _quality,
  );
  if (file == null) return null;
  return PhotoPicked(await file.readAsBytes());
}

/// Las fotos ya leídas de la base, para no volver a pedirlas al hacer scroll.
final _cache = <int, Uint8List>{};

Future<Uint8List?> _load(int photoId) async {
  final cached = _cache[photoId];
  if (cached != null) return cached;
  final bytes = await getIt<NutritionRepository>().getPhoto(photoId);
  if (bytes != null) {
    if (_cache.length > 40) _cache.remove(_cache.keys.first);
    _cache[photoId] = bytes;
  }
  return bytes;
}

/// La foto [photoId] de la base, recortada a [width] × [height].
class MealPhotoImage extends StatelessWidget {
  const MealPhotoImage({
    super.key,
    required this.photoId,
    required this.width,
    required this.height,
    this.radius = 14,
  });

  final int photoId;
  final double width;
  final double height;
  final double radius;

  @override
  Widget build(BuildContext context) {
    final placeholder = Container(
      width: width,
      height: height,
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surfaceContainerHigh,
        borderRadius: BorderRadius.circular(radius),
      ),
    );
    return FutureBuilder<Uint8List?>(
      future: _load(photoId),
      initialData: _cache[photoId],
      builder: (context, snapshot) {
        final bytes = snapshot.data;
        if (bytes == null) return placeholder;
        final dpr = MediaQuery.devicePixelRatioOf(context);
        return ClipRRect(
          borderRadius: BorderRadius.circular(radius),
          child: Image.memory(
            bytes,
            width: width,
            height: height,
            fit: BoxFit.cover,
            gaplessPlayback: true,
            // Decodifica al tamaño mostrado, no a 1080 px.
            cacheWidth: width.isFinite ? (width * dpr).round() : null,
          ),
        );
      },
    );
  }
}

/// Abre la foto a pantalla completa, con zoom. [onChange] muestra el botón
/// para cambiarla o quitarla.
Future<void> showMealPhoto(
  BuildContext context, {
  required int photoId,
  required String title,
  VoidCallback? onChange,
}) =>
    Navigator.of(context).push(
      MaterialPageRoute<void>(
        fullscreenDialog: true,
        builder: (pageContext) => Scaffold(
          backgroundColor: Colors.black,
          appBar: AppBar(
            backgroundColor: Colors.black,
            foregroundColor: Colors.white,
            title: Text(title, style: const TextStyle(color: Colors.white)),
            actions: [
              if (onChange != null)
                TextButton.icon(
                  onPressed: () {
                    Navigator.pop(pageContext);
                    onChange();
                  },
                  icon: const Icon(IconsaxPlusLinear.edit_2, color: Colors.white),
                  label: const Text('Cambiar', style: TextStyle(color: Colors.white)),
                ),
            ],
          ),
          body: Center(
            child: FutureBuilder<Uint8List?>(
              future: _load(photoId),
              initialData: _cache[photoId],
              builder: (context, snapshot) => snapshot.data == null
                  ? const CircularProgressIndicator()
                  : InteractiveViewer(maxScale: 4, child: Image.memory(snapshot.data!)),
            ),
          ),
        ),
      ),
    );
