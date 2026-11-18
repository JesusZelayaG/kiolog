import 'dart:io';
import 'package:flutter/material.dart';
import 'package:iconsax_plus/iconsax_plus.dart';
import 'package:image_picker/image_picker.dart';
import 'package:path_provider/path_provider.dart';
import 'package:video_player/video_player.dart';
import 'package:kiolog/core/database/app_database.dart';
import 'package:kiolog/core/di/injection.dart';
import 'package:kiolog/core/domain/day.dart';

import '../../domain/repositories/progress_repository.dart';

/// Máximo de un video del álbum: unos 30 segundos de cámara.
const maxAlbumVideoBytes = 30 * 1024 * 1024;
const maxAlbumVideoDuration = Duration(seconds: 30);

/// Los archivos del álbum ya leídos de la base, para no pedirlos al hacer scroll.
final _cache = <int, ProgressMediaData>{};

Future<ProgressMediaData?> loadAlbumMedia(int id) async {
  final cached = _cache[id];
  if (cached != null) return cached;
  final media = await getIt<ProgressRepository>().getProgressMedia(id);
  if (media != null) {
    // Los videos pesan; se guardan pocos en memoria.
    if (_cache.length > 30) _cache.remove(_cache.keys.first);
    _cache[id] = media;
  }
  return media;
}

void forgetAlbumMedia(int id) => _cache.remove(id);

/// El reproductor necesita un archivo: el video se escribe una vez.
Future<File> albumVideoFile(ProgressMediaData media) async {
  final dir = await getTemporaryDirectory();
  final file = File('${dir.path}/progress_media_${media.id}.${media.extension}');
  if (!await file.exists() || await file.length() != media.bytes.length) {
    await file.writeAsBytes(media.bytes, flush: true);
  }
  return file;
}

String _extensionOf(String name, String fallback) {
  final dot = name.lastIndexOf('.');
  if (dot < 0 || dot == name.length - 1) return fallback;
  return name.substring(dot + 1).toLowerCase();
}

/// Pide una foto o un video corto para hoy y lo guarda. Devuelve true si se
/// agregó algo.
Future<bool> addTodayAlbumMedia(BuildContext context) async {
  final choice = await showModalBottomSheet<String>(
    context: context,
    showDragHandle: true,
    builder: (sheetContext) {
      final theme = Theme.of(sheetContext);
      return SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(24, 0, 24, 4),
              child: Text('Agregar a hoy', style: theme.textTheme.titleLarge),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(24, 0, 24, 8),
              child: Text('Hasta $maxProgressMediaPerDay por día. Solo se guardan en tu teléfono.',
                  style: theme.textTheme.bodySmall),
            ),
            ListTile(
              leading: const Icon(IconsaxPlusLinear.camera),
              title: const Text('Tomar foto'),
              onTap: () => Navigator.pop(sheetContext, 'photo-camera'),
            ),
            ListTile(
              leading: const Icon(IconsaxPlusLinear.video),
              title: const Text('Grabar video'),
              subtitle: const Text('Hasta 30 segundos'),
              onTap: () => Navigator.pop(sheetContext, 'video-camera'),
            ),
            ListTile(
              leading: const Icon(IconsaxPlusLinear.gallery),
              title: const Text('Foto de la galería'),
              onTap: () => Navigator.pop(sheetContext, 'photo-gallery'),
            ),
            ListTile(
              leading: const Icon(IconsaxPlusLinear.video_play),
              title: const Text('Video de la galería'),
              subtitle: const Text('Hasta 30 MB'),
              onTap: () => Navigator.pop(sheetContext, 'video-gallery'),
            ),
            const SizedBox(height: 8),
          ],
        ),
      );
    },
  );
  if (choice == null) return false;
  final picker = ImagePicker();
  final source = choice.endsWith('camera') ? ImageSource.camera : ImageSource.gallery;
  final isVideo = choice.startsWith('video');
  final XFile? file = isVideo
      ? await picker.pickVideo(source: source, maxDuration: maxAlbumVideoDuration)
      : await picker.pickImage(source: source, maxWidth: 1440, maxHeight: 1440, imageQuality: 80);
  if (file == null) return false;

  void tell(String message) {
    if (!context.mounted) return;
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(message)));
  }

  final size = await file.length();
  if (isVideo && size > maxAlbumVideoBytes) {
    tell('El video pesa ${(size / 1048576).toStringAsFixed(0)} MB; el máximo es 30 MB. Recórtalo e inténtalo de nuevo.');
    return false;
  }
  try {
    await getIt<ProgressRepository>().addProgressMedia(
      day: todayUtcDay(),
      isVideo: isVideo,
      extension: _extensionOf(file.name, isVideo ? 'mp4' : 'jpg'),
      bytes: await file.readAsBytes(),
    );
    return true;
  } on ProgressAlbumFull {
    tell('Hoy ya tienes $maxProgressMediaPerDay. Borra una para agregar otra.');
    return false;
  }
}

/// Miniatura de una foto o video del álbum de progreso.
class AlbumThumb extends StatelessWidget {
  const AlbumThumb({super.key, required this.id, required this.isVideo, this.radius = 16});

  final int id;
  final bool isVideo;
  final double radius;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final placeholder = ColoredBox(color: cs.surfaceContainerHigh);
    return ClipRRect(
      borderRadius: BorderRadius.circular(radius),
      child: FutureBuilder<ProgressMediaData?>(
        future: loadAlbumMedia(id),
        initialData: _cache[id],
        builder: (context, snap) {
          final media = snap.data;
          if (media == null) return placeholder;
          if (isVideo) return _VideoThumb(media: media);
          return LayoutBuilder(
            builder: (context, c) => Image.memory(
              media.bytes,
              fit: BoxFit.cover,
              width: double.infinity,
              height: double.infinity,
              gaplessPlayback: true,
              cacheWidth: c.maxWidth.isFinite ? (c.maxWidth * MediaQuery.devicePixelRatioOf(context)).round() : null,
            ),
          );
        },
      ),
    );
  }
}

/// El primer cuadro del video, con el ícono de reproducir y su duración.
class _VideoThumb extends StatefulWidget {
  const _VideoThumb({required this.media});

  final ProgressMediaData media;

  @override
  State<_VideoThumb> createState() => _VideoThumbState();
}

class _VideoThumbState extends State<_VideoThumb> {
  VideoPlayerController? _c;

  @override
  void initState() {
    super.initState();
    _open();
  }

  Future<void> _open() async {
    try {
      final c = VideoPlayerController.file(await albumVideoFile(widget.media));
      await c.initialize();
      await c.setVolume(0);
      if (!mounted) {
        await c.dispose();
        return;
      }
      setState(() => _c = c);
    } catch (_) {}
  }

  @override
  void dispose() {
    _c?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final c = _c;
    final seconds = c?.value.duration.inSeconds;
    return Stack(
      fit: StackFit.expand,
      children: [
        const ColoredBox(color: Colors.black),
        if (c != null)
          FittedBox(
            fit: BoxFit.cover,
            clipBehavior: Clip.hardEdge,
            child: SizedBox(width: c.value.size.width, height: c.value.size.height, child: VideoPlayer(c)),
          ),
        const Center(child: Icon(IconsaxPlusBold.play_circle, color: Colors.white, size: 32)),
        if (seconds != null)
          Positioned(
            right: 6,
            bottom: 6,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
              decoration: BoxDecoration(color: Colors.black54, borderRadius: BorderRadius.circular(8)),
              child: Text('0:${seconds.toString().padLeft(2, '0')}',
                  style: const TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.w700)),
            ),
          ),
      ],
    );
  }
}

/// Una foto o video del álbum a pantalla completa.
class AlbumMediaView extends StatelessWidget {
  const AlbumMediaView({super.key, required this.id, required this.isVideo, required this.active});

  final int id;
  final bool isVideo;

  /// Solo el video de la página visible se reproduce.
  final bool active;

  @override
  Widget build(BuildContext context) => FutureBuilder<ProgressMediaData?>(
        future: loadAlbumMedia(id),
        initialData: _cache[id],
        builder: (context, snap) {
          final media = snap.data;
          if (media == null) return const Center(child: CircularProgressIndicator(color: Colors.white));
          if (isVideo) return _FullVideo(media: media, active: active);
          return InteractiveViewer(maxScale: 4, child: Center(child: Image.memory(media.bytes)));
        },
      );
}

class _FullVideo extends StatefulWidget {
  const _FullVideo({required this.media, required this.active});

  final ProgressMediaData media;
  final bool active;

  @override
  State<_FullVideo> createState() => _FullVideoState();
}

class _FullVideoState extends State<_FullVideo> {
  VideoPlayerController? _c;

  @override
  void initState() {
    super.initState();
    _open();
  }

  Future<void> _open() async {
    final c = VideoPlayerController.file(await albumVideoFile(widget.media));
    await c.initialize();
    await c.setLooping(true);
    if (!mounted) return c.dispose();
    c.addListener(() {
      if (mounted) setState(() {});
    });
    setState(() => _c = c);
    if (widget.active) await c.play();
  }

  @override
  void didUpdateWidget(_FullVideo old) {
    super.didUpdateWidget(old);
    if (widget.active != old.active) widget.active ? _c?.play() : _c?.pause();
  }

  @override
  void dispose() {
    _c?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final c = _c;
    if (c == null) return const Center(child: CircularProgressIndicator(color: Colors.white));
    return GestureDetector(
      onTap: () => c.value.isPlaying ? c.pause() : c.play(),
      child: Stack(
        children: [
          Center(child: AspectRatio(aspectRatio: c.value.aspectRatio, child: VideoPlayer(c))),
          if (!c.value.isPlaying)
            const Center(child: Icon(IconsaxPlusBold.play_circle, color: Colors.white70, size: 72)),
          Positioned(
            left: 16,
            right: 16,
            bottom: 24,
            child: VideoProgressIndicator(
              c,
              allowScrubbing: true,
              colors: VideoProgressColors(
                playedColor: Theme.of(context).colorScheme.primary,
                backgroundColor: Colors.white24,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
