import 'dart:math' show min, max;
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:iconsax_plus/iconsax_plus.dart';
import 'package:intl/intl.dart';
import 'package:kiolog/core/dao/measurements_dao.dart';
import 'package:kiolog/core/dao/nutrition_dao.dart';
import 'package:kiolog/core/database/app_database.dart';
import 'package:kiolog/core/domain/day.dart';
import 'package:kiolog/core/theme/app_theme.dart';
import 'package:kiolog/shared/widgets/entrance.dart';
import 'package:kiolog/shared/widgets/meal_photo.dart';
import 'package:kiolog/shared/widgets/themed_page.dart';
import '../../../../core/di/injection.dart';
import '../../../exercise/domain/repositories/exercise_repository.dart';
import '../../../nutrition/domain/repositories/nutrition_repository.dart';
import '../../../sleep/domain/repositories/sleep_repository.dart';
import '../../../water/domain/repositories/water_repository.dart';
import '../../domain/repositories/progress_repository.dart';
import '../bloc/progress_bloc.dart';
import '../bloc/progress_event.dart';
import '../bloc/progress_overview_cubit.dart';
import '../bloc/progress_state.dart';
import '../widgets/album_media.dart';
import '../widgets/progress_charts.dart';
import 'meal_album_page.dart';
import 'progress_album_page.dart';

class ProgressPage extends StatelessWidget {
  const ProgressPage({super.key});

  @override
  Widget build(BuildContext context) {
    return MultiBlocProvider(
      providers: [
        BlocProvider(
          create: (_) => ProgressBloc(getIt<ProgressRepository>())
            ..add(const ProgressLoaded()),
        ),
        BlocProvider(
          create: (_) => ProgressOverviewCubit(
            exercise: getIt<ExerciseRepository>(),
            nutrition: getIt<NutritionRepository>(),
            water: getIt<WaterRepository>(),
            sleep: getIt<SleepRepository>(),
            progress: getIt<ProgressRepository>(),
          )..load(),
        ),
      ],
      child: const _ProgressView(),
    );
  }
}

class _ProgressView extends StatelessWidget {
  const _ProgressView();

  @override
  Widget build(BuildContext context) {
    return ThemedPage(
      child: BlocBuilder<ProgressBloc, ProgressState>(
        builder: (context, state) {
          if (state.status == ProgressStatus.failure) {
            return Center(child: Text('Error: ${state.error}'));
          }
          final loading = state.status == ProgressStatus.loading && state.weightLogs.isEmpty;
          final items = <Widget>[
            _Header(onConsultations: () => _openConsultations(context)),
            if (loading)
              const Padding(padding: EdgeInsets.all(40), child: Center(child: CircularProgressIndicator()))
            else ...[
              _WeightCard(state: state, onAdd: () => _showAddWeightDialog(context)),
              const _AlbumsRow(),
              if (state.latestMeasurement != null)
                _MeasurementsCard(measurement: state.latestMeasurement!, onOpen: () => _openConsultations(context)),
              const ProgressCharts(),
            ],
          ];
          return ListView.separated(
            padding: const EdgeInsets.fromLTRB(18, 14, 18, 120),
            itemCount: items.length,
            separatorBuilder: (_, __) => const SizedBox(height: 14),
            itemBuilder: (context, i) => Entrance(index: i, child: items[i]),
          );
        },
      ),
    );
  }

  void _showAddWeightDialog(BuildContext context) {
    final bloc = context.read<ProgressBloc>();
    final controller = TextEditingController();
    showDialog(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Registrar peso'),
        content: TextField(
          controller: controller,
          keyboardType: const TextInputType.numberWithOptions(decimal: true),
          decoration: const InputDecoration(labelText: 'Peso', suffixText: 'kg'),
          autofocus: true,
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: const Text('Cancelar'),
          ),
          ElevatedButton(
            onPressed: () {
              final weight = double.tryParse(controller.text.replaceAll(',', '.'));
              if (weight != null && weight > 0) {
                bloc.add(ProgressWeightAdded(date: DateTime.now(), weightKg: weight));
              }
              Navigator.pop(dialogContext);
            },
            child: const Text('Guardar'),
          ),
        ],
      ),
    );
  }

  Future<void> _openConsultations(BuildContext context) async {
    final progress = context.read<ProgressBloc>();
    final overview = context.read<ProgressOverviewCubit>();
    await context.push('/consultations');
    progress.add(const ProgressLoaded());
    await overview.load();
  }
}

class _Header extends StatelessWidget {
  const _Header({required this.onConsultations});

  final VoidCallback onConsultations;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Row(
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('TU AVANCE',
                  style: theme.textTheme.labelSmall?.copyWith(fontSize: 11, color: theme.colorScheme.primary)),
              Text('Progreso', style: theme.textTheme.displayMedium?.copyWith(fontSize: 28)),
            ],
          ),
        ),
        HeaderIconButton(icon: IconsaxPlusLinear.ruler, tooltip: 'Consultas y medidas', onTap: onConsultations),
        const SizedBox(width: 10),
        HeaderIconButton(
          icon: IconsaxPlusLinear.calendar_1,
          tooltip: 'Historial',
          onTap: () => context.push('/history'),
        ),
      ],
    );
  }
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

String _kg(double v) => v.toStringAsFixed(1);

class _WeightCard extends StatelessWidget {
  const _WeightCard({required this.state, required this.onAdd});

  final ProgressState state;
  final VoidCallback onAdd;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;
    final kc = context.kc;
    final logs = state.weightLogs;
    final latest = state.latestWeight;
    final change = state.weightChange;
    final recent = logs.length > 10 ? logs.sublist(logs.length - 10) : logs;
    final changeColor = change == null || change.abs() < 0.05
        ? cs.onSurfaceVariant
        : change < 0
            ? kc.success
            : kc.warning;
    return _Card(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('PESO', style: theme.textTheme.labelSmall?.copyWith(fontSize: 11)),
                    const SizedBox(height: 2),
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.baseline,
                      textBaseline: TextBaseline.alphabetic,
                      children: [
                        Text(latest == null ? '—' : _kg(latest),
                            style: theme.textTheme.displayMedium?.copyWith(fontSize: 38)),
                        if (latest != null) ...[
                          const SizedBox(width: 4),
                          Text('kg', style: theme.textTheme.titleMedium?.copyWith(color: cs.onSurfaceVariant)),
                        ],
                      ],
                    ),
                  ],
                ),
              ),
              PillButton(icon: IconsaxPlusLinear.add, label: 'Registrar', color: cs.primary, onTap: onAdd),
            ],
          ),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            runSpacing: 6,
            children: [
              if (change != null)
                _Chip(
                  color: changeColor,
                  icon: change.abs() < 0.05
                      ? IconsaxPlusLinear.minus
                      : change < 0
                          ? IconsaxPlusLinear.trend_down
                          : IconsaxPlusLinear.trend_up,
                  text: change.abs() < 0.05
                      ? 'Sin cambio'
                      : '${change > 0 ? '+' : '−'}${_kg(change.abs())} kg desde el inicio',
                ),
              _Chip(
                color: cs.onSurfaceVariant,
                icon: IconsaxPlusLinear.note_2,
                text: '${logs.length} ${logs.length == 1 ? 'registro' : 'registros'}',
              ),
            ],
          ),
          const SizedBox(height: 16),
          if (recent.length >= 2) ...[
            SizedBox(
              height: 140,
              child: TweenAnimationBuilder<double>(
                tween: Tween(begin: 0, end: 1),
                duration: const Duration(milliseconds: 1100),
                curve: Curves.easeOutCubic,
                builder: (context, t, _) => CustomPaint(
                  size: Size.infinite,
                  painter: _LineChartPainter(
                    logs: recent,
                    gradient: kc.brandGradient,
                    ink: cs.onSurfaceVariant,
                    grid: context.hc.ringTrack,
                    dot: cs.surfaceContainerLowest,
                    progress: t,
                  ),
                ),
              ),
            ),
            Align(
              alignment: Alignment.centerRight,
              child: TextButton.icon(
                onPressed: () => _showHistory(context, logs),
                icon: const Icon(IconsaxPlusLinear.clock, size: 16),
                label: const Text('Ver historial'),
              ),
            ),
          ] else
            Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(color: cs.surfaceContainerHigh, borderRadius: BorderRadius.circular(18)),
              child: Row(
                children: [
                  Icon(IconsaxPlusLinear.chart_2, color: cs.primary),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text('Registra tu peso otro día y aquí verás cómo cambia.',
                        style: theme.textTheme.bodySmall),
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }

  void _showHistory(BuildContext context, List<WeightLog> logs) {
    final f = DateFormat("EEE d 'de' MMM yyyy", 'es');
    showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      isScrollControlled: true,
      builder: (sheetContext) {
        final theme = Theme.of(sheetContext);
        final rows = logs.reversed.toList();
        return SafeArea(
          child: ConstrainedBox(
            constraints: BoxConstraints(maxHeight: MediaQuery.sizeOf(sheetContext).height * 0.7),
            child: ListView.separated(
              shrinkWrap: true,
              padding: const EdgeInsets.fromLTRB(20, 0, 20, 16),
              itemCount: rows.length + 1,
              separatorBuilder: (_, i) => i == 0 ? const SizedBox(height: 8) : const Divider(height: 1),
              itemBuilder: (context, i) {
                if (i == 0) return Text('Historial de peso', style: theme.textTheme.titleLarge);
                final log = rows[i - 1];
                final previous = i < rows.length ? rows[i].weightKg : null;
                final diff = previous == null ? null : log.weightKg - previous;
                return Padding(
                  padding: const EdgeInsets.symmetric(vertical: 12),
                  child: Row(
                    children: [
                      Expanded(child: Text(f.format(log.date.toUtc()), style: theme.textTheme.bodyMedium)),
                      if (diff != null && diff.abs() >= 0.05)
                        Padding(
                          padding: const EdgeInsets.only(right: 12),
                          child: Text(
                            '${diff > 0 ? '+' : '−'}${_kg(diff.abs())}',
                            style: theme.textTheme.bodySmall?.copyWith(
                              color: diff < 0 ? sheetContext.kc.success : sheetContext.kc.warning,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ),
                      Text('${_kg(log.weightKg)} kg',
                          style: theme.textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w800)),
                    ],
                  ),
                );
              },
            ),
          ),
        );
      },
    );
  }
}

class _Chip extends StatelessWidget {
  const _Chip({required this.color, required this.icon, required this.text});

  final Color color;
  final IconData icon;
  final String text;

  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
        decoration: ShapeDecoration(color: color.withValues(alpha: 0.12), shape: const StadiumBorder()),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 14, color: color),
            const SizedBox(width: 5),
            Text(text,
                style: Theme.of(context).textTheme.labelMedium?.copyWith(color: color, fontWeight: FontWeight.w700)),
          ],
        ),
      );
}

/// Las dos portadas: el álbum de progreso y el de comidas.
class _AlbumsRow extends StatefulWidget {
  const _AlbumsRow();

  @override
  State<_AlbumsRow> createState() => _AlbumsRowState();
}

class _AlbumsRowState extends State<_AlbumsRow> {
  List<ProgressMediaInfo>? _progress;
  List<MealPhotoEntry>? _meals;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final progress = await getIt<ProgressRepository>().getProgressMediaInfo();
    final meals = await getIt<NutritionRepository>().getMealPhotoEntries();
    if (mounted) {
      setState(() {
        _progress = progress;
        _meals = meals;
      });
    }
  }

  Future<void> _open(Widget page) async {
    await Navigator.of(context).push(MaterialPageRoute<void>(builder: (_) => page));
    await _load();
  }

  @override
  Widget build(BuildContext context) {
    final kc = context.kc;
    final progress = _progress;
    final meals = _meals;
    final today = todayUtcDay();
    final todayCount = progress?.where((m) => m.day.isAtSameMomentAs(today)).length ?? 0;
    final days = progress?.map((m) => m.day).toSet().length ?? 0;
    return Row(
      children: [
        Expanded(
          child: _AlbumCover(
            title: 'Mi progreso',
            subtitle: progress == null
                ? ''
                : progress.isEmpty
                    ? 'Tu foto de hoy'
                    : '$days ${days == 1 ? 'día' : 'días'} · hoy $todayCount/$maxProgressMediaPerDay',
            icon: IconsaxPlusLinear.camera,
            wash: kc.gymWash,
            ink: kc.gymInk,
            cover: progress == null || progress.isEmpty
                ? null
                : AlbumThumb(id: progress.first.id, isVideo: progress.first.isVideo, radius: 0),
            onTap: () => _open(const ProgressAlbumPage()),
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: _AlbumCover(
            title: 'Comidas',
            subtitle: meals == null
                ? ''
                : meals.isEmpty
                    ? 'Fotos de tus platos'
                    : '${meals.length} ${meals.length == 1 ? 'foto' : 'fotos'}',
            icon: IconsaxPlusLinear.gallery,
            wash: kc.foodWash,
            ink: kc.foodInk,
            cover: meals == null || meals.isEmpty
                ? null
                : LayoutBuilder(
                    builder: (context, c) =>
                        MealPhotoImage(photoId: meals.first.photoId, width: c.maxWidth, height: c.maxHeight, radius: 0),
                  ),
            onTap: () => _open(const MealAlbumPage()),
          ),
        ),
      ],
    );
  }
}

class _AlbumCover extends StatelessWidget {
  const _AlbumCover({
    required this.title,
    required this.subtitle,
    required this.icon,
    required this.wash,
    required this.ink,
    required this.cover,
    required this.onTap,
  });

  final String title;
  final String subtitle;
  final IconData icon;
  final Color wash;
  final Color ink;
  final Widget? cover;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final hasCover = cover != null;
    return AspectRatio(
      aspectRatio: 1,
      child: Material(
        color: wash,
        borderRadius: BorderRadius.circular(26),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: onTap,
          child: Stack(
            fit: StackFit.expand,
            children: [
              if (hasCover) cover!,
              if (hasCover)
                const DecoratedBox(
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                      colors: [Colors.transparent, Colors.black87],
                      stops: [0.35, 1],
                    ),
                  ),
                ),
              Padding(
                padding: const EdgeInsets.all(14),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Container(
                      width: 40,
                      height: 40,
                      decoration: BoxDecoration(
                        color: hasCover ? Colors.black38 : theme.colorScheme.surfaceContainerLowest,
                        borderRadius: BorderRadius.circular(14),
                      ),
                      child: Icon(icon, size: 20, color: hasCover ? Colors.white : ink),
                    ),
                    const Spacer(),
                    Text('ÁLBUM',
                        style: theme.textTheme.labelSmall
                            ?.copyWith(fontSize: 10, color: hasCover ? Colors.white70 : ink)),
                    Text(
                      title,
                      style: theme.textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.w800,
                        color: hasCover ? Colors.white : theme.colorScheme.onSurface,
                      ),
                    ),
                    Text(
                      subtitle,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: theme.textTheme.bodySmall?.copyWith(color: hasCover ? Colors.white70 : null),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _MeasurementsCard extends StatelessWidget {
  const _MeasurementsCard({required this.measurement, required this.onOpen});

  final Measurement measurement;
  final VoidCallback onOpen;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final m = measurement;
    String cm(double? v) => v == null ? '' : '${v.toStringAsFixed(1).replaceAll('.0', '')} cm';
    final fields = <(String, String)>[
      if (m.weightKg > 0) ('Peso', '${_kg(m.weightKg)} kg'),
      if (m.waistCm != null) ('Cintura', cm(m.waistCm)),
      if (m.hipCm != null) ('Cadera', cm(m.hipCm)),
      if (m.chestCm != null) ('Tórax', cm(m.chestCm)),
      if (m.armFlexedCm != null) ('Brazo flex.', cm(m.armFlexedCm)),
      if (m.armRelaxedCm != null) ('Brazo relaj.', cm(m.armRelaxedCm)),
      if (m.thighCm != null) ('Muslo', cm(m.thighCm)),
      if (m.calfCm != null) ('Pantorrilla', cm(m.calfCm)),
      if (m.lowerAbdomenCm != null) ('Abdomen bajo', cm(m.lowerAbdomenCm)),
      if (m.midGluteusCm != null) ('Glúteo', cm(m.midGluteusCm)),
      if (m.bodyFatPct != null) ('% Grasa', '${m.bodyFatPct}%'),
      if (m.leanMassKg != null) ('Masa magra', '${m.leanMassKg} kg'),
      if (m.visceralMass != null) ('Visceral', '${m.visceralMass}'),
      if (m.heightCm > 0) ('Talla', cm(m.heightCm)),
    ];
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
                    Text('ÚLTIMA CONSULTA', style: theme.textTheme.labelSmall?.copyWith(fontSize: 11)),
                    Text(DateFormat("d 'de' MMMM yyyy", 'es').format(m.date.toUtc()),
                        style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w800)),
                  ],
                ),
              ),
              PillButton(icon: IconsaxPlusLinear.ruler, label: 'Consultas', onTap: onOpen),
            ],
          ),
          const SizedBox(height: 14),
          GridView.count(
            crossAxisCount: 3,
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            mainAxisSpacing: 8,
            crossAxisSpacing: 8,
            childAspectRatio: 1.45,
            children: [
              for (final (label, value) in fields)
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                  decoration: BoxDecoration(
                    color: theme.colorScheme.surfaceContainerHigh,
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      FittedBox(
                        fit: BoxFit.scaleDown,
                        alignment: Alignment.centerLeft,
                        child: Text(value, style: theme.textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w800)),
                      ),
                      Text(label,
                          maxLines: 1, overflow: TextOverflow.ellipsis, style: theme.textTheme.bodySmall),
                    ],
                  ),
                ),
            ],
          ),
        ],
      ),
    );
  }
}

// ── Gráfica de peso ───────────────────────────────────────────────────────

class _LineChartPainter extends CustomPainter {
  _LineChartPainter({
    required this.logs,
    required this.gradient,
    required this.ink,
    required this.grid,
    required this.dot,
    required this.progress,
  });

  final List<WeightLog> logs;
  final LinearGradient gradient;
  final Color ink;
  final Color grid;
  final Color dot;

  /// 0 a 1: cuánto de la línea se ha dibujado.
  final double progress;

  static const _padLeft = 34.0;
  static const _padRight = 10.0;
  static const _padTop = 12.0;
  static const _padBottom = 22.0;

  @override
  void paint(Canvas canvas, Size size) {
    if (logs.length < 2) return;
    final chartW = size.width - _padLeft - _padRight;
    final chartH = size.height - _padTop - _padBottom;

    final weights = logs.map((l) => l.weightKg).toList();
    var minW = weights.reduce(min);
    var maxW = weights.reduce(max);
    if (maxW - minW < 1) {
      minW -= 0.5;
      maxW += 0.5;
    }
    final range = maxW - minW;

    // Un punto por registro, a la misma distancia: se leen como pasos.
    Offset at(int i) => Offset(
          _padLeft + chartW * i / (logs.length - 1),
          _padTop + (1 - (logs[i].weightKg - minW) / range) * chartH,
        );
    final points = [for (var i = 0; i < logs.length; i++) at(i)];

    final gridPaint = Paint()
      ..color = grid
      ..strokeWidth = 1;
    for (var i = 0; i <= 2; i++) {
      final y = _padTop + chartH * i / 2;
      canvas.drawLine(Offset(_padLeft, y), Offset(_padLeft + chartW, y), gridPaint);
    }

    final line = Path()..moveTo(points.first.dx, points.first.dy);
    for (var i = 1; i < points.length; i++) {
      final p0 = points[i - 1];
      final p1 = points[i];
      final mid = (p0.dx + p1.dx) / 2;
      line.cubicTo(mid, p0.dy, mid, p1.dy, p1.dx, p1.dy);
    }
    final rect = Rect.fromLTWH(_padLeft, _padTop, chartW, chartH);

    canvas.save();
    canvas.clipRect(Rect.fromLTWH(0, 0, _padLeft + chartW * progress + 6, size.height));
    final fill = Path.from(line)
      ..lineTo(points.last.dx, _padTop + chartH)
      ..lineTo(points.first.dx, _padTop + chartH)
      ..close();
    canvas.drawPath(
      fill,
      Paint()
        ..shader = LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [gradient.colors.last.withValues(alpha: 0.28), gradient.colors.last.withValues(alpha: 0)],
        ).createShader(rect),
    );
    canvas.drawPath(
      line,
      Paint()
        ..shader = gradient.createShader(rect)
        ..strokeWidth = 3
        ..style = PaintingStyle.stroke
        ..strokeCap = StrokeCap.round,
    );
    for (var i = 0; i < points.length; i++) {
      final last = i == points.length - 1;
      canvas.drawCircle(points[i], last ? 6 : 4, Paint()..color = dot);
      canvas.drawCircle(points[i], last ? 4 : 2.5, Paint()..color = gradient.colors.last);
    }
    canvas.restore();

    _text(canvas, maxW.toStringAsFixed(1), Offset(0, _padTop - 6));
    _text(canvas, minW.toStringAsFixed(1), Offset(0, _padTop + chartH - 6));
    _text(canvas, _fmt(logs.first.date), Offset(_padLeft, size.height - 14));
    _text(canvas, _fmt(logs.last.date), Offset(size.width - _padRight, size.height - 14), right: true);
  }

  String _fmt(DateTime d) => DateFormat('d MMM', 'es').format(d.toUtc());

  void _text(Canvas canvas, String text, Offset offset, {bool right = false}) {
    final tp = TextPainter(
      text: TextSpan(text: text, style: TextStyle(color: ink, fontSize: 10, fontWeight: FontWeight.w600)),
      textDirection: ui.TextDirection.ltr,
    )..layout();
    tp.paint(canvas, right ? offset - Offset(tp.width, 0) : offset);
  }

  @override
  bool shouldRepaint(_LineChartPainter old) =>
      old.logs != logs || old.progress != progress || old.gradient != gradient || old.ink != ink;
}
