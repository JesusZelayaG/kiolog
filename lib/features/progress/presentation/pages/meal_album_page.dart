import 'package:flutter/material.dart';
import 'package:iconsax_plus/iconsax_plus.dart';
import 'package:intl/intl.dart';
import 'package:kiolog/core/dao/nutrition_dao.dart';
import 'package:kiolog/core/di/injection.dart';
import 'package:kiolog/core/domain/day.dart';
import 'package:kiolog/core/theme/app_theme.dart';
import 'package:kiolog/features/nutrition/domain/repositories/nutrition_repository.dart';
import 'package:kiolog/shared/widgets/entrance.dart';
import 'package:kiolog/shared/widgets/meal_photo.dart';
import 'package:kiolog/shared/widgets/themed_page.dart';

String _capitalized(String s) => s.isEmpty ? s : s[0].toUpperCase() + s.substring(1);

enum _Filter { all, plan, off }

/// Texto y color de cada estado de una comida con foto.
({String label, Color color}) mealPhotoStatusStyle(BuildContext context, MealPhotoStatus status) => switch (status) {
      MealPhotoStatus.plan => (label: 'Del plan', color: context.kc.success),
      MealPhotoStatus.offPlan => (label: 'Fuera del plan', color: context.kc.warning),
      MealPhotoStatus.skipped => (label: 'No seguí el plan', color: Theme.of(context).colorScheme.error),
    };

/// Las fotos de lo que se comió, por día.
class MealAlbumPage extends StatefulWidget {
  const MealAlbumPage({super.key});

  @override
  State<MealAlbumPage> createState() => _MealAlbumPageState();
}

class _MealAlbumPageState extends State<MealAlbumPage> {
  List<MealPhotoEntry>? _entries;
  _Filter _filter = _Filter.all;

  @override
  void initState() {
    super.initState();
    getIt<NutritionRepository>().getMealPhotoEntries().then((e) {
      if (mounted) setState(() => _entries = e);
    });
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final all = _entries;
    final shown = (all ?? const <MealPhotoEntry>[])
        .where((e) => switch (_filter) {
              _Filter.all => true,
              _Filter.plan => e.status == MealPhotoStatus.plan,
              _Filter.off => e.status != MealPhotoStatus.plan,
            })
        .toList();
    final byDay = <DateTime, List<MealPhotoEntry>>{};
    for (final e in shown) {
      byDay.putIfAbsent(storedDay(e.day), () => []).add(e);
    }
    final planCount = all?.where((e) => e.status == MealPhotoStatus.plan).length ?? 0;

    final items = <Widget>[
      _Header(count: all?.length),
      if (all == null)
        const Padding(padding: EdgeInsets.all(40), child: Center(child: CircularProgressIndicator()))
      else if (all.isEmpty)
        _Empty()
      else ...[
        GradientSegmented<_Filter>(
          value: _filter,
          options: {
            _Filter.all: 'Todas',
            _Filter.plan: 'Del plan · $planCount',
            _Filter.off: 'Fuera · ${all.length - planCount}',
          },
          onChanged: (f) => setState(() => _filter = f),
        ),
        if (shown.isEmpty)
          Padding(
            padding: const EdgeInsets.all(24),
            child: Text('No hay fotos con este filtro.', textAlign: TextAlign.center, style: theme.textTheme.bodyMedium),
          ),
        for (final day in byDay.entries) _DayGrid(day: day.key, entries: day.value, all: shown),
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
  const _Header({required this.count});

  final int? count;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;
    return Row(
      children: [
        Material(
          color: cs.surfaceContainerLowest,
          borderRadius: BorderRadius.circular(16),
          child: InkWell(
            borderRadius: BorderRadius.circular(16),
            onTap: () => Navigator.of(context).maybePop(),
            child: Tooltip(
              message: 'Volver',
              child: SizedBox(width: 44, height: 44, child: Icon(IconsaxPlusLinear.arrow_left, color: cs.onSurface)),
            ),
          ),
        ),
        const SizedBox(width: 14),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('ÁLBUM', style: theme.textTheme.labelSmall?.copyWith(fontSize: 11, color: cs.primary)),
              Text('Comidas', style: theme.textTheme.displayMedium?.copyWith(fontSize: 26)),
            ],
          ),
        ),
        if (count != null && count! > 0)
          Text('$count ${count == 1 ? 'foto' : 'fotos'}', style: theme.textTheme.bodySmall),
      ],
    );
  }
}

class _Empty extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: theme.colorScheme.surfaceContainerLowest,
        borderRadius: BorderRadius.circular(28),
        boxShadow: [context.kc.shadow],
      ),
      child: Column(
        children: [
          Container(
            width: 64,
            height: 64,
            decoration: BoxDecoration(color: context.kc.foodWash, borderRadius: BorderRadius.circular(22)),
            child: Icon(IconsaxPlusLinear.camera, color: context.kc.foodInk, size: 30),
          ),
          const SizedBox(height: 14),
          Text('Aún no hay fotos de comidas', style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w800)),
          const SizedBox(height: 6),
          Text(
            'Al marcar una comida en Nutrición puedes tomarle una foto. Todas aparecen aquí, por día.',
            textAlign: TextAlign.center,
            style: theme.textTheme.bodySmall,
          ),
        ],
      ),
    );
  }
}

class _DayGrid extends StatelessWidget {
  const _DayGrid({required this.day, required this.entries, required this.all});

  final DateTime day;
  final List<MealPhotoEntry> entries;

  /// Todo lo que se ve con el filtro, para deslizar en el visor.
  final List<MealPhotoEntry> all;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: theme.colorScheme.surfaceContainerLowest,
        borderRadius: BorderRadius.circular(28),
        boxShadow: [context.kc.shadow],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(_capitalized(DateFormat("EEEE d 'de' MMMM", 'es').format(day)),
              style: theme.textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w800)),
          const SizedBox(height: 10),
          GridView.count(
            crossAxisCount: 3,
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            mainAxisSpacing: 8,
            crossAxisSpacing: 8,
            childAspectRatio: 0.82,
            children: [for (final e in entries) _Tile(entry: e, all: all)],
          ),
        ],
      ),
    );
  }
}

class _Tile extends StatelessWidget {
  const _Tile({required this.entry, required this.all});

  final MealPhotoEntry entry;
  final List<MealPhotoEntry> all;

  @override
  Widget build(BuildContext context) {
    final style = mealPhotoStatusStyle(context, entry.status);
    return GestureDetector(
      onTap: () => Navigator.of(context).push(MaterialPageRoute<void>(
        fullscreenDialog: true,
        builder: (_) => _MealViewer(entries: all, initial: all.indexOf(entry)),
      )),
      child: Stack(
        fit: StackFit.expand,
        children: [
          LayoutBuilder(
            builder: (context, c) => MealPhotoImage(photoId: entry.photoId, width: c.maxWidth, height: c.maxHeight, radius: 16),
          ),
          Positioned(
            left: 0,
            right: 0,
            bottom: 0,
            child: Container(
              padding: const EdgeInsets.fromLTRB(8, 18, 8, 7),
              decoration: const BoxDecoration(
                borderRadius: BorderRadius.vertical(bottom: Radius.circular(16)),
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [Colors.transparent, Colors.black87],
                ),
              ),
              child: Row(
                children: [
                  Container(
                    width: 8,
                    height: 8,
                    decoration: BoxDecoration(color: style.color, shape: BoxShape.circle),
                  ),
                  const SizedBox(width: 5),
                  Expanded(
                    child: Text(
                      entry.mealType,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.w700),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _MealViewer extends StatefulWidget {
  const _MealViewer({required this.entries, required this.initial});

  final List<MealPhotoEntry> entries;
  final int initial;

  @override
  State<_MealViewer> createState() => _MealViewerState();
}

class _MealViewerState extends State<_MealViewer> {
  late final PageController _pages = PageController(initialPage: widget.initial);
  late int _index = widget.initial;

  @override
  void dispose() {
    _pages.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final e = widget.entries[_index];
    final style = mealPhotoStatusStyle(context, e.status);
    final date = _capitalized(DateFormat("EEEE d 'de' MMMM", 'es').format(storedDay(e.day)));
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.black,
        foregroundColor: Colors.white,
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(e.mealType, style: const TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.w700)),
            Text(date, style: const TextStyle(color: Colors.white60, fontSize: 12)),
          ],
        ),
      ),
      body: Column(
        children: [
          Expanded(
            child: PageView.builder(
              controller: _pages,
              itemCount: widget.entries.length,
              onPageChanged: (i) => setState(() => _index = i),
              itemBuilder: (context, i) => FutureBuilder(
                future: loadMealPhoto(widget.entries[i].photoId),
                builder: (context, snap) => snap.data == null
                    ? const Center(child: CircularProgressIndicator(color: Colors.white))
                    : InteractiveViewer(maxScale: 4, child: Center(child: Image.memory(snap.data!))),
              ),
            ),
          ),
          SafeArea(
            top: false,
            child: Padding(
              padding: const EdgeInsets.fromLTRB(20, 12, 20, 16),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                    decoration: ShapeDecoration(color: style.color.withValues(alpha: 0.2), shape: const StadiumBorder()),
                    child: Text(style.label,
                        style: TextStyle(color: style.color, fontSize: 12, fontWeight: FontWeight.w800)),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      e.description ?? '',
                      maxLines: 3,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(color: Colors.white, fontSize: 14),
                    ),
                  ),
                  Text('${_index + 1}/${widget.entries.length}', style: const TextStyle(color: Colors.white60, fontSize: 12)),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
