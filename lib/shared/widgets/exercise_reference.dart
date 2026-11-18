import 'dart:io';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:iconsax_plus/iconsax_plus.dart';
import 'package:image_picker/image_picker.dart';
import 'package:kiolog/core/database/app_database.dart';
import 'package:kiolog/core/di/injection.dart';
import 'package:kiolog/core/theme/app_theme.dart';
import 'package:kiolog/features/exercise/domain/repositories/exercise_repository.dart';
import 'package:path_provider/path_provider.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:video_player/video_player.dart';
import 'package:webview_flutter/webview_flutter.dart';
import 'package:youtube_player_iframe/youtube_player_iframe.dart';

// ── Enlaces ─────────────────────────────────────────────────────────────────

/// Lo que escribió el usuario como enlace válido; null si está vacío o no
/// parece un enlace. Sin esquema se asume https.
String? normalizeReferenceUrl(String input) {
  final text = input.trim();
  if (text.isEmpty) return null;
  final withScheme = text.contains('://') ? text : 'https://$text';
  final uri = Uri.tryParse(withScheme);
  if (uri == null || !uri.hasScheme || !uri.host.contains('.')) return null;
  if (uri.scheme != 'https' && uri.scheme != 'http') return null;
  return uri.toString();
}

/// El id de un video de YouTube (normal, corto, Shorts o embebido).
String? youtubeId(String url) {
  final uri = Uri.tryParse(url);
  if (uri == null) return null;
  final host = uri.host.replaceFirst('www.', '').replaceFirst('m.', '');
  final segments = uri.pathSegments;
  String? id;
  if (host == 'youtu.be' && segments.isNotEmpty) {
    id = segments.first;
  } else if (host == 'youtube.com' || host == 'music.youtube.com') {
    if (segments.isNotEmpty && ['shorts', 'embed', 'live', 'v'].contains(segments.first) && segments.length > 1) {
      id = segments[1];
    } else {
      id = uri.queryParameters['v'];
    }
  }
  return id != null && RegExp(r'^[\w-]{6,}$').hasMatch(id) ? id : null;
}

/// El id numérico de un video de Vimeo.
String? vimeoId(String url) {
  final uri = Uri.tryParse(url);
  if (uri == null || !uri.host.endsWith('vimeo.com')) return null;
  return uri.pathSegments.where((s) => RegExp(r'^\d{5,}$').hasMatch(s)).firstOrNull;
}

String _pathOf(String url) => Uri.tryParse(url)?.path.toLowerCase() ?? '';

/// Si el enlace apunta directo a una imagen o GIF.
bool isImageUrl(String url) => ['.jpg', '.jpeg', '.png', '.gif', '.webp'].any(_pathOf(url).endsWith);

/// Si el enlace apunta directo a un archivo de video.
bool isVideoUrl(String url) => ['.mp4', '.mov', '.webm', '.m4v'].any(_pathOf(url).endsWith);

Future<void> openReference(BuildContext context, String url) async {
  final ok = await launchUrl(Uri.parse(url), mode: LaunchMode.externalApplication);
  if (!ok && context.mounted) {
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(const SnackBar(content: Text('No se pudo abrir el enlace')));
  }
}

// ── Lo cargado de la galería ────────────────────────────────────────────────

/// Un video de más de esto no se guarda: haría crecer mucho el respaldo.
const maxVideoBytes = 30 * 1024 * 1024;

/// La referencia de un ejercicio mientras se edita: el enlace y lo
/// multimedia, ya guardado ([mediaId]) o recién elegido ([bytes]).
class ReferenceDraft {
  ReferenceDraft({String? link, this.mediaId}) : link = TextEditingController(text: link ?? '');

  final TextEditingController link;
  int? mediaId;
  Uint8List? bytes;
  String? kind;
  String? extension;

  bool get hasMedia => mediaId != null || bytes != null;

  void clearMedia() {
    mediaId = null;
    bytes = null;
    kind = null;
    extension = null;
  }

  /// Guarda lo recién elegido y devuelve el id que va en el ejercicio.
  Future<int?> saveMedia() async {
    final b = bytes;
    if (b == null) return mediaId;
    return mediaId = await getIt<ExerciseRepository>().saveMedia(bytes: b, kind: kind!, extension: extension!);
  }

  String? get url => normalizeReferenceUrl(link.text);

  void dispose() => link.dispose();
}

String _extensionOf(String name, {required String fallback}) {
  final dot = name.lastIndexOf('.');
  return dot < 0 ? fallback : name.substring(dot + 1).toLowerCase();
}

/// Elige una foto, GIF o video de la galería. Devuelve false si se canceló o
/// el video es demasiado grande (con aviso).
Future<bool> pickReferenceMedia(BuildContext context, ReferenceDraft draft) async {
  final choice = await showModalBottomSheet<String>(
    context: context,
    showDragHandle: true,
    builder: (sheetContext) => SafeArea(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          ListTile(
            leading: const Icon(IconsaxPlusLinear.gallery),
            title: const Text('Foto'),
            subtitle: const Text('Se guarda comprimida'),
            onTap: () => Navigator.pop(sheetContext, 'photo'),
          ),
          ListTile(
            leading: const Icon(IconsaxPlusLinear.video_play),
            title: const Text('Video o GIF'),
            subtitle: const Text('Hasta 30 MB, unos 30 a 60 segundos'),
            onTap: () => Navigator.pop(sheetContext, 'video'),
          ),
          const SizedBox(height: 8),
        ],
      ),
    ),
  );
  if (choice == null) return false;
  final picker = ImagePicker();
  final XFile? file = choice == 'photo'
      ? await picker.pickImage(source: ImageSource.gallery, maxWidth: 1440, maxHeight: 1440, imageQuality: 80)
      : await picker.pickMedia();
  if (file == null) return false;
  final ext = _extensionOf(file.name, fallback: choice == 'photo' ? 'jpg' : 'mp4');
  final isImage = ['jpg', 'jpeg', 'png', 'gif', 'webp', 'heic'].contains(ext);
  final size = await file.length();
  if (!isImage && size > maxVideoBytes) {
    if (context.mounted) {
      ScaffoldMessenger.of(context)
        ..hideCurrentSnackBar()
        ..showSnackBar(SnackBar(
          content: Text('El video pesa ${(size / 1048576).toStringAsFixed(0)} MB; el máximo es 30 MB. '
              'Recórtalo o usa un enlace.'),
        ));
    }
    return false;
  }
  draft
    ..mediaId = null
    ..bytes = await file.readAsBytes()
    ..kind = isImage ? 'image' : 'video'
    ..extension = ext;
  return true;
}

/// Campo de enlace y botón de galería, para el editor de un ejercicio.
class ReferenceEditor extends StatefulWidget {
  const ReferenceEditor({super.key, required this.draft, this.dense = false});

  final ReferenceDraft draft;
  final bool dense;

  @override
  State<ReferenceEditor> createState() => _ReferenceEditorState();
}

class _ReferenceEditorState extends State<ReferenceEditor> {
  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;
    final d = widget.draft;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        ReferenceLinkField(controller: d.link, dense: widget.dense),
        const SizedBox(height: 8),
        if (!d.hasMedia)
          OutlinedButton.icon(
            onPressed: () async {
              if (await pickReferenceMedia(context, d) && mounted) setState(() {});
            },
            icon: const Icon(IconsaxPlusLinear.gallery_add, size: 18),
            label: const Text('Foto, GIF o video de la galería'),
          )
        else
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(color: cs.surfaceContainerHigh, borderRadius: BorderRadius.circular(14)),
            child: Row(
              children: [
                ClipRRect(
                  borderRadius: BorderRadius.circular(10),
                  child: SizedBox(width: 52, height: 52, child: _DraftThumb(draft: d)),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    d.bytes != null
                        ? '${d.kind == 'video' ? 'Video' : 'Imagen'} de la galería · '
                            '${(d.bytes!.length / 1048576).toStringAsFixed(1)} MB'
                        : 'Multimedia de la galería',
                    style: theme.textTheme.bodySmall?.copyWith(color: cs.onSurface),
                  ),
                ),
                IconButton(
                  tooltip: 'Quitar',
                  icon: Icon(IconsaxPlusLinear.trash, size: 18, color: cs.error),
                  onPressed: () => setState(d.clearMedia),
                ),
              ],
            ),
          ),
      ],
    );
  }
}

class _DraftThumb extends StatelessWidget {
  const _DraftThumb({required this.draft});

  final ReferenceDraft draft;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final videoIcon = ColoredBox(
      color: cs.surfaceContainerHighest,
      child: Icon(IconsaxPlusBold.video_play, color: cs.primary),
    );
    if (draft.bytes != null) {
      return draft.kind == 'image' ? Image.memory(draft.bytes!, fit: BoxFit.cover, cacheWidth: 156) : videoIcon;
    }
    return FutureBuilder<ExerciseMediaData?>(
      future: getIt<ExerciseRepository>().getMedia(draft.mediaId!),
      builder: (context, snap) {
        final m = snap.data;
        if (m == null) return ColoredBox(color: cs.surfaceContainerHighest);
        return m.kind == 'image' ? Image.memory(m.bytes, fit: BoxFit.cover, cacheWidth: 156) : videoIcon;
      },
    );
  }
}

/// Campo para pegar el enlace de referencia de un ejercicio.
class ReferenceLinkField extends StatelessWidget {
  const ReferenceLinkField({super.key, required this.controller, this.dense = false});

  final TextEditingController controller;
  final bool dense;

  @override
  Widget build(BuildContext context) {
    return TextField(
      controller: controller,
      keyboardType: TextInputType.url,
      autocorrect: false,
      decoration: InputDecoration(
        labelText: 'Enlace de video o imagen',
        hintText: 'YouTube, Vimeo, Instagram, TikTok o una imagen',
        isDense: dense,
        prefixIcon: const Icon(IconsaxPlusLinear.link_1, size: 20),
        suffixIcon: IconButton(
          tooltip: 'Pegar',
          icon: const Icon(IconsaxPlusLinear.clipboard_text, size: 20),
          onPressed: () async {
            final data = await Clipboard.getData(Clipboard.kTextPlain);
            final text = data?.text?.trim();
            if (text != null && text.isNotEmpty) controller.text = text;
          },
        ),
      ),
    );
  }
}

// ── Ver la referencia ───────────────────────────────────────────────────────

/// La referencia de un ejercicio: lo cargado de la galería y el enlace. Se
/// reproduce dentro de la app cuando se puede.
class ExerciseReference extends StatelessWidget {
  const ExerciseReference({super.key, this.url, this.mediaId, this.height = 200});

  final String? url;
  final int? mediaId;
  final double height;

  @override
  Widget build(BuildContext context) {
    final link = url;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (mediaId != null) _StoredMedia(mediaId: mediaId!, height: height),
        if (mediaId != null && link != null) const SizedBox(height: 10),
        if (link != null) _LinkReference(url: link, height: height),
      ],
    );
  }
}

class _LinkReference extends StatelessWidget {
  const _LinkReference({required this.url, required this.height});

  final String url;
  final double height;

  @override
  Widget build(BuildContext context) {
    final yt = youtubeId(url);
    if (yt != null) return _YouTubeInline(url: url, id: yt);
    final vimeo = vimeoId(url);
    if (vimeo != null) return _VimeoInline(url: url, id: vimeo);
    if (isVideoUrl(url)) return _VideoBox(open: () async => VideoPlayerController.networkUrl(Uri.parse(url)));
    if (isImageUrl(url)) return _NetworkImage(url: url, height: height);
    return _ReferenceLink(url: url);
  }
}

/// Miniatura de YouTube; al tocarla, su reproductor oficial dentro de la app.
class _YouTubeInline extends StatefulWidget {
  const _YouTubeInline({required this.url, required this.id});

  final String url;
  final String id;

  @override
  State<_YouTubeInline> createState() => _YouTubeInlineState();
}

class _YouTubeInlineState extends State<_YouTubeInline> {
  YoutubePlayerController? _controller;

  @override
  void dispose() {
    _controller?.close();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final controller = _controller;
    if (controller != null) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          ClipRRect(
            borderRadius: BorderRadius.circular(18),
            child: YoutubePlayer(controller: controller, aspectRatio: 16 / 9),
          ),
          Align(
            alignment: Alignment.centerRight,
            child: TextButton.icon(
              onPressed: () => openReference(context, widget.url),
              icon: const Icon(IconsaxPlusLinear.export_3, size: 16),
              label: const Text('¿No carga? Abrir en YouTube'),
            ),
          ),
        ],
      );
    }
    return GestureDetector(
      onTap: () => setState(() {
        _controller = YoutubePlayerController.fromVideoId(
          videoId: widget.id,
          autoPlay: true,
          params: const YoutubePlayerParams(showFullscreenButton: true, strictRelatedVideos: true),
        );
      }),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(18),
        child: AspectRatio(
          aspectRatio: 16 / 9,
          child: Stack(
            fit: StackFit.expand,
            children: [
              Image.network(
                'https://img.youtube.com/vi/${widget.id}/hqdefault.jpg',
                fit: BoxFit.cover,
                errorBuilder: (_, __, ___) => ColoredBox(color: Theme.of(context).colorScheme.surfaceContainerHigh),
              ),
              const _PlayOverlay(label: 'Reproducir video'),
            ],
          ),
        ),
      ),
    );
  }
}

/// El reproductor de Vimeo, dentro de la app.
class _VimeoInline extends StatefulWidget {
  const _VimeoInline({required this.url, required this.id});

  final String url;
  final String id;

  @override
  State<_VimeoInline> createState() => _VimeoInlineState();
}

class _VimeoInlineState extends State<_VimeoInline> {
  WebViewController? _controller;

  @override
  Widget build(BuildContext context) {
    final controller = _controller;
    return ClipRRect(
      borderRadius: BorderRadius.circular(18),
      child: AspectRatio(
        aspectRatio: 16 / 9,
        child: controller != null
            ? WebViewWidget(controller: controller)
            : GestureDetector(
                onTap: () => setState(() {
                  _controller = WebViewController()
                    ..setJavaScriptMode(JavaScriptMode.unrestricted)
                    ..loadRequest(Uri.parse('https://player.vimeo.com/video/${widget.id}?autoplay=1'));
                }),
                child: Stack(
                  fit: StackFit.expand,
                  children: [
                    ColoredBox(color: Theme.of(context).colorScheme.surfaceContainerHigh),
                    const _PlayOverlay(label: 'Reproducir video de Vimeo'),
                  ],
                ),
              ),
      ),
    );
  }
}

class _PlayOverlay extends StatelessWidget {
  const _PlayOverlay({required this.label});

  final String label;

  @override
  Widget build(BuildContext context) => Stack(
        fit: StackFit.expand,
        children: [
          const DecoratedBox(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [Color(0x00000000), Color(0x99000000)],
              ),
            ),
          ),
          Center(
            child: Container(
              width: 60,
              height: 60,
              decoration: BoxDecoration(gradient: context.kc.brandGradient, shape: BoxShape.circle),
              child: const Icon(IconsaxPlusBold.play, color: Colors.white, size: 28),
            ),
          ),
          Positioned(
            left: 12,
            bottom: 10,
            child: Text(label, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w700, fontSize: 13)),
          ),
        ],
      );
}

/// Lo cargado de la galería: imagen o video.
class _StoredMedia extends StatelessWidget {
  const _StoredMedia({required this.mediaId, required this.height});

  final int mediaId;
  final double height;

  /// El reproductor de video necesita un archivo: se escribe una vez.
  static Future<VideoPlayerController> _videoFor(ExerciseMediaData media) async {
    final dir = await getTemporaryDirectory();
    final file = File('${dir.path}/exercise_media_${media.id}.${media.extension}');
    if (!await file.exists() || await file.length() != media.bytes.length) {
      await file.writeAsBytes(media.bytes, flush: true);
    }
    return VideoPlayerController.file(file);
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<ExerciseMediaData?>(
      future: getIt<ExerciseRepository>().getMedia(mediaId),
      builder: (context, snap) {
        final media = snap.data;
        if (media == null) {
          return SizedBox(height: height, child: const Center(child: CircularProgressIndicator()));
        }
        if (media.kind == 'video') return _VideoBox(open: () => _videoFor(media));
        return GestureDetector(
          onTap: () => _showFullImage(context, Image.memory(media.bytes)),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(18),
            child: Image.memory(media.bytes, height: height, width: double.infinity, fit: BoxFit.cover),
          ),
        );
      },
    );
  }
}

void _showFullImage(BuildContext context, Widget image) => Navigator.of(context).push(
      MaterialPageRoute<void>(
        fullscreenDialog: true,
        builder: (_) => Scaffold(
          backgroundColor: Colors.black,
          appBar: AppBar(backgroundColor: Colors.black, foregroundColor: Colors.white),
          body: Center(child: InteractiveViewer(maxScale: 4, child: image)),
        ),
      ),
    );

/// Un video con tocar para pausar, barra de avance y repetición.
class _VideoBox extends StatefulWidget {
  const _VideoBox({required this.open});

  final Future<VideoPlayerController> Function() open;

  @override
  State<_VideoBox> createState() => _VideoBoxState();
}

class _VideoBoxState extends State<_VideoBox> {
  VideoPlayerController? _controller;
  bool _failed = false;

  @override
  void initState() {
    super.initState();
    _init();
  }

  Future<void> _init() async {
    try {
      final controller = await widget.open();
      await controller.initialize();
      await controller.setLooping(true);
      if (!mounted) {
        await controller.dispose();
        return;
      }
      controller.addListener(() {
        if (mounted) setState(() {});
      });
      setState(() => _controller = controller);
    } catch (_) {
      if (mounted) setState(() => _failed = true);
    }
  }

  @override
  void dispose() {
    _controller?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final c = _controller;
    if (_failed) {
      return Container(
        height: 120,
        alignment: Alignment.center,
        decoration: BoxDecoration(color: cs.surfaceContainerHigh, borderRadius: BorderRadius.circular(18)),
        child: const Text('No se pudo reproducir el video'),
      );
    }
    if (c == null) {
      return Container(
        height: 200,
        alignment: Alignment.center,
        decoration: BoxDecoration(color: cs.surfaceContainerHigh, borderRadius: BorderRadius.circular(18)),
        child: const CircularProgressIndicator(),
      );
    }
    return ClipRRect(
      borderRadius: BorderRadius.circular(18),
      child: ConstrainedBox(
        // Videos verticales: que no ocupen toda la pantalla.
        constraints: const BoxConstraints(maxHeight: 420),
        child: AspectRatio(
          aspectRatio: c.value.aspectRatio,
          child: GestureDetector(
            onTap: () => c.value.isPlaying ? c.pause() : c.play(),
            child: Stack(
              fit: StackFit.expand,
              children: [
                VideoPlayer(c),
                if (!c.value.isPlaying) const _PlayOverlay(label: 'Reproducir'),
                Positioned(
                  left: 0,
                  right: 0,
                  bottom: 0,
                  child: VideoProgressIndicator(
                    c,
                    allowScrubbing: true,
                    colors: VideoProgressColors(playedColor: cs.primary, backgroundColor: Colors.white24),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _NetworkImage extends StatelessWidget {
  const _NetworkImage({required this.url, required this.height});

  final String url;
  final double height;

  @override
  Widget build(BuildContext context) => GestureDetector(
        onTap: () => _showFullImage(context, Image.network(url)),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(18),
          child: Image.network(
            url,
            height: height,
            width: double.infinity,
            fit: BoxFit.cover,
            loadingBuilder: (context, child, progress) => progress == null
                ? child
                : SizedBox(height: height, child: const Center(child: CircularProgressIndicator())),
            errorBuilder: (_, __, ___) => _ReferenceLink(url: url),
          ),
        ),
      );
}

class _ReferenceLink extends StatelessWidget {
  const _ReferenceLink({required this.url});

  final String url;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;
    final host = Uri.tryParse(url)?.host.replaceFirst('www.', '') ?? url;
    return Material(
      color: cs.surfaceContainerHigh,
      borderRadius: BorderRadius.circular(16),
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: () => openReference(context, url),
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Row(
            children: [
              Icon(IconsaxPlusBold.video_play, color: cs.primary),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Ver referencia', style: theme.textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w700)),
                    Text('Se abre en $host', style: theme.textTheme.bodySmall, maxLines: 1, overflow: TextOverflow.ellipsis),
                  ],
                ),
              ),
              Icon(IconsaxPlusLinear.export_3, size: 18, color: cs.onSurfaceVariant),
            ],
          ),
        ),
      ),
    );
  }
}

/// Hoja con la referencia de un ejercicio.
Future<void> showReferenceSheet(BuildContext context, String exerciseName, {String? url, int? mediaId}) =>
    showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      isScrollControlled: true,
      builder: (sheetContext) => SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(exerciseName, style: Theme.of(sheetContext).textTheme.titleLarge),
              const SizedBox(height: 14),
              ExerciseReference(url: url, mediaId: mediaId, height: 260),
            ],
          ),
        ),
      ),
    );
