import 'package:flutter/material.dart';
import 'package:iconsax_plus/iconsax_plus.dart';
import 'package:intl/intl.dart';
import 'package:kiolog/core/dao/measurements_dao.dart';
import 'package:kiolog/core/di/injection.dart';
import 'package:kiolog/core/domain/day.dart';
import 'package:kiolog/core/theme/app_theme.dart';
import 'package:kiolog/shared/widgets/entrance.dart';
import 'package:kiolog/shared/widgets/themed_page.dart';

import '../../domain/repositories/progress_repository.dart';
import '../widgets/album_media.dart';

String _capitalized(String s) => s.isEmpty ? s : s[0].toUpperCase() + s.substring(1);

/// El álbum de progreso: hasta 3 fotos o videos cortos por día.
class ProgressAlbumPage extends StatefulWidget {
  const ProgressAlbumPage({super.key});

  @override
  State<ProgressAlbumPage> createState() => _ProgressAlbumPageState();
}

class _ProgressAlbumPageState extends State<ProgressAlbumPage> {
  List<ProgressMediaInfo>? _media;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final media = await getIt<ProgressRepository>().getProgressMediaInfo();
    if (mounted) setState(() => _media = media);
  }

  Future<void> _add() async {
    if (await addTodayAlbumMedia(context)) await _load();
  }

  Future<void> _open(ProgressMediaInfo item) async {
    final media = _media!;
    await Navigator.of(context).push(MaterialPageRoute<void>(
      fullscreenDialog: true,
      builder: (_) => _AlbumViewer(media: media, initial: media.indexOf(item)),
    ));
    await _load();
  }

  @override
  Widget build(BuildContext context) {
    final media = _media;
    final today = todayUtcDay();
    final byDay = <DateTime, List<ProgressMediaInfo>>{};
    for (final m in media ?? const <ProgressMediaInfo>[]) {
      byDay.putIfAbsent(storedDay(m.day), () => []).add(m);
    }
    final todayKey = storedDay(today);
    final past = byDay.entries.where((e) => e.key != todayKey).toList();

    final items = <Widget>[
      const _Header(),
      if (media == null)
        const Padding(padding: EdgeInsets.all(40), child: Center(child: CircularProgressIndicator()))
      else ...[
        _TodayCard(items: byDay[todayKey] ?? const [], onAdd: _add, onOpen: _open),
        if (byDay.length >= 2) _CompareCard(first: byDay.values.last.first, last: byDay.values.first.first, onOpen: _open),
        if (past.isNotEmpty)
          Text('DÍAS ANTERIORES', style: Theme.of(context).textTheme.labelSmall?.copyWith(fontSize: 11)),
        for (final day in past) _DayRow(day: day.key, items: day.value, onOpen: _open),
        if (past.isEmpty)
          Text(
            'Cada día que agregues aparecerá aquí, para que veas tu cambio con el tiempo.',
            textAlign: TextAlign.center,
            style: Theme.of(context).textTheme.bodySmall,
          ),
      ],
    ];
    return ThemedPage(
      child: ListView.separated(
        padding: const EdgeInsets.fromLTRB(18, 14, 18, 32),
        itemCount: items.length,
        separatorBuilder: (_, __) => const SizedBox(height: 14),
        itemBuilder: (context, i) => Entrance(index: i, child: items[i]),
      ),
    );
  }
}

class _Header extends StatelessWidget {
  const _Header();

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;
    return Row(
      children: [
        _BackButton(color: cs.onSurface, background: cs.surfaceContainerLowest),
        const SizedBox(width: 14),
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('ÁLBUM', style: theme.textTheme.labelSmall?.copyWith(fontSize: 11, color: cs.primary)),
            Text('Mi progreso', style: theme.textTheme.displayMedium?.copyWith(fontSize: 26)),
          ],
        ),
      ],
    );
  }
}

class _BackButton extends StatelessWidget {
  const _BackButton({required this.color, required this.background});

  final Color color;
  final Color background;

  @override
  Widget build(BuildContext context) => Material(
        color: background,
        borderRadius: BorderRadius.circular(16),
        child: InkWell(
          borderRadius: BorderRadius.circular(16),
          onTap: () => Navigator.of(context).maybePop(),
          child: Tooltip(
            message: 'Volver',
            child: SizedBox(width: 44, height: 44, child: Icon(IconsaxPlusLinear.arrow_left, color: color)),
          ),
        ),
      );
}

class _Card extends StatelessWidget {
  const _Card({required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.all(18),
        decoration: BoxDecoration(
          color: Theme.of(context).colorScheme.surfaceContainerLowest,
          borderRadius: BorderRadius.circular(28),
          boxShadow: [context.kc.shadow],
        ),
        child: child,
      );
}

/// Los 3 lugares de hoy: llenos o para agregar.
class _TodayCard extends StatelessWidget {
  const _TodayCard({required this.items, required this.onAdd, required this.onOpen});

  final List<ProgressMediaInfo> items;
  final VoidCallback onAdd;
  final ValueChanged<ProgressMediaInfo> onOpen;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;
    final date = _capitalized(DateFormat("EEEE d 'de' MMMM", 'es').format(DateTime.now()));
    return _Card(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('HOY', style: theme.textTheme.labelSmall?.copyWith(fontSize: 11, color: cs.primary)),
                    Text(date, style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w800)),
                  ],
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                decoration: ShapeDecoration(color: context.kc.gymWash, shape: const StadiumBorder()),
                child: Text(
                  '${items.length} de $maxProgressMediaPerDay',
                  style: theme.textTheme.labelMedium?.copyWith(color: context.kc.gymInk, fontWeight: FontWeight.w800),
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          Row(
            children: [
              for (var i = 0; i < maxProgressMediaPerDay; i++) ...[
                if (i > 0) const SizedBox(width: 10),
                Expanded(
                  child: AspectRatio(
                    aspectRatio: 3 / 4,
                    child: i < items.length
                        ? GestureDetector(
                            onTap: () => onOpen(items[i]),
                            child: AlbumThumb(id: items[i].id, isVideo: items[i].isVideo),
                          )
                        : _AddSlot(onTap: i == items.length ? onAdd : null),
                  ),
                ),
              ],
            ],
          ),
          const SizedBox(height: 12),
          Text(
            'Una foto o un video corto de hoy. Solo se guarda en tu teléfono.',
            style: theme.textTheme.bodySmall,
          ),
        ],
      ),
    );
  }
}

class _AddSlot extends StatelessWidget {
  const _AddSlot({required this.onTap});

  /// Null en los lugares que siguen al primero libre.
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final active = onTap != null;
    return Material(
      color: active ? context.kc.gymWash : cs.surfaceContainerHigh.withValues(alpha: 0.5),
      borderRadius: BorderRadius.circular(16),
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: onTap,
        child: Tooltip(
          message: 'Agregar foto o video',
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(IconsaxPlusLinear.camera, color: active ? cs.primary : cs.outline, size: 26),
              if (active) ...[
                const SizedBox(height: 6),
                Text('Agregar', style: Theme.of(context).textTheme.labelMedium?.copyWith(color: cs.primary)),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

/// El primer día junto al más reciente.
class _CompareCard extends StatelessWidget {
  const _CompareCard({required this.first, required this.last, required this.onOpen});

  final ProgressMediaInfo first;
  final ProgressMediaInfo last;
  final ValueChanged<ProgressMediaInfo> onOpen;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final f = DateFormat('d MMM yyyy', 'es');
    final days = storedDay(last.day).difference(storedDay(first.day)).inDays;
    Widget side(ProgressMediaInfo m, String label) => Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              AspectRatio(
                aspectRatio: 3 / 4,
                child: GestureDetector(onTap: () => onOpen(m), child: AlbumThumb(id: m.id, isVideo: m.isVideo, radius: 20)),
              ),
              const SizedBox(height: 8),
              Text(label, style: theme.textTheme.labelMedium?.copyWith(fontWeight: FontWeight.w800)),
              Text(f.format(storedDay(m.day)), style: theme.textTheme.bodySmall),
            ],
          ),
        );
    return _Card(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Expanded(child: Text('ANTES Y AHORA', style: theme.textTheme.labelSmall?.copyWith(fontSize: 11))),
              Text('$days ${days == 1 ? 'día' : 'días'}',
                  style: theme.textTheme.labelMedium?.copyWith(color: theme.colorScheme.primary)),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              side(first, 'Primer día'),
              const SizedBox(width: 12),
              side(last, 'Más reciente'),
            ],
          ),
        ],
      ),
    );
  }
}

class _DayRow extends StatelessWidget {
  const _DayRow({required this.day, required this.items, required this.onOpen});

  final DateTime day;
  final List<ProgressMediaInfo> items;
  final ValueChanged<ProgressMediaInfo> onOpen;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return _Card(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(_capitalized(DateFormat("EEEE d 'de' MMMM yyyy", 'es').format(day)),
              style: theme.textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w800)),
          const SizedBox(height: 10),
          Row(
            children: [
              for (var i = 0; i < maxProgressMediaPerDay; i++) ...[
                if (i > 0) const SizedBox(width: 8),
                Expanded(
                  child: AspectRatio(
                    aspectRatio: 3 / 4,
                    child: i < items.length
                        ? GestureDetector(
                            onTap: () => onOpen(items[i]),
                            child: AlbumThumb(id: items[i].id, isVideo: items[i].isVideo, radius: 14),
                          )
                        : const SizedBox(),
                  ),
                ),
              ],
            ],
          ),
        ],
      ),
    );
  }
}

/// Todo el álbum a pantalla completa, deslizando de uno en uno.
class _AlbumViewer extends StatefulWidget {
  const _AlbumViewer({required this.media, required this.initial});

  final List<ProgressMediaInfo> media;
  final int initial;

  @override
  State<_AlbumViewer> createState() => _AlbumViewerState();
}

class _AlbumViewerState extends State<_AlbumViewer> {
  late final List<ProgressMediaInfo> _media = [...widget.media];
  late final PageController _pages = PageController(initialPage: widget.initial);
  late int _index = widget.initial;

  @override
  void dispose() {
    _pages.dispose();
    super.dispose();
  }

  Future<void> _delete() async {
    final item = _media[_index];
    final ok = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text(item.isVideo ? '¿Borrar este video?' : '¿Borrar esta foto?'),
        content: const Text('Se borra de tu álbum y no se puede recuperar.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(dialogContext, false), child: const Text('Cancelar')),
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, true),
            child: Text('Borrar', style: TextStyle(color: Theme.of(dialogContext).colorScheme.error)),
          ),
        ],
      ),
    );
    if (ok != true) return;
    await getIt<ProgressRepository>().deleteProgressMedia(item.id);
    forgetAlbumMedia(item.id);
    if (!mounted) return;
    if (_media.length == 1) return Navigator.of(context).pop();
    setState(() {
      _media.removeAt(_index);
      _index = _index.clamp(0, _media.length - 1);
    });
  }

  @override
  Widget build(BuildContext context) {
    final item = _media[_index];
    final date = _capitalized(DateFormat("EEEE d 'de' MMMM yyyy", 'es').format(storedDay(item.day)));
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.black,
        foregroundColor: Colors.white,
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(date, style: const TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.w700)),
            Text('${_index + 1} de ${_media.length}', style: const TextStyle(color: Colors.white60, fontSize: 12)),
          ],
        ),
        actions: [
          IconButton(
            tooltip: 'Borrar',
            icon: const Icon(IconsaxPlusLinear.trash, color: Colors.white),
            onPressed: _delete,
          ),
        ],
      ),
      body: PageView.builder(
        controller: _pages,
        itemCount: _media.length,
        onPageChanged: (i) => setState(() => _index = i),
        itemBuilder: (context, i) => AlbumMediaView(
          key: ValueKey(_media[i].id),
          id: _media[i].id,
          isVideo: _media[i].isVideo,
          active: i == _index,
        ),
      ),
    );
  }
}
