import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:iconsax_plus/iconsax_plus.dart';
import 'package:intl/intl.dart';
import 'package:kiolog/core/di/injection.dart';
import 'package:kiolog/core/theme/app_theme.dart';
import 'package:kiolog/features/exercise/domain/repositories/exercise_repository.dart';
import 'package:kiolog/features/nutrition/domain/repositories/nutrition_repository.dart';
import 'package:kiolog/features/progress/presentation/widgets/next_consultation_card.dart';
import 'package:kiolog/features/sleep/domain/repositories/sleep_repository.dart';
import 'package:kiolog/features/water/domain/repositories/water_repository.dart';
import 'package:kiolog/shared/widgets/kiolog_glyphs.dart';
import 'package:kiolog/shared/widgets/water_widgets.dart';
import '../bloc/home_bloc.dart';
import '../bloc/home_event.dart';
import '../bloc/home_state.dart';

double calcOverallProgress(HomeState s) {
  final values = [
    s.waterProgress.clamp(0.0, 1.0),
    s.sleepProgress,
    s.mealsProgress.clamp(0.0, 1.0),
    s.exerciseProgress,
  ];
  return values.reduce((a, b) => a + b) / values.length;
}

/// La curva de los anillos y rellenos: arranca rápido y se asienta suave.
const _settle = Cubic(.3, .9, .25, 1);

class HomePage extends StatelessWidget {
  const HomePage({super.key});

  @override
  Widget build(BuildContext context) {
    return BlocProvider(
      create: (_) => HomeBloc(
        waterRepository: getIt<WaterRepository>(),
        sleepRepository: getIt<SleepRepository>(),
        nutritionRepository: getIt<NutritionRepository>(),
        exerciseRepository: getIt<ExerciseRepository>(),
      )..add(HomeLoaded(date: DateTime.now())),
      child: const _HomeView(),
    );
  }
}

/// Abre una pantalla encima del Home y recarga el resumen al volver.
Future<void> _openAndReload(BuildContext context, String route) async {
  final bloc = context.read<HomeBloc>();
  await context.push(route);
  bloc.add(HomeLoaded(date: DateTime.now()));
}

class _HomeView extends StatefulWidget {
  const _HomeView();

  @override
  State<_HomeView> createState() => _HomeViewState();
}

class _HomeViewState extends State<_HomeView>
    with SingleTickerProviderStateMixin {
  // Entrada escalonada: corre una vez, al tener los primeros datos.
  late final _entrance = AnimationController(
      vsync: this, duration: const Duration(milliseconds: 1000));
  bool _toast = false;
  int _celebration = 0;

  @override
  void dispose() {
    _entrance.dispose();
    super.dispose();
  }

  void _celebrate() {
    HapticFeedback.mediumImpact();
    setState(() {
      _toast = true;
      _celebration++;
    });
    Future.delayed(const Duration(milliseconds: 2300), () {
      if (mounted) setState(() => _toast = false);
    });
  }

  Widget _stagger(int index, Widget child) {
    final start = (index * 0.08).clamp(0.0, 0.55);
    final anim = CurvedAnimation(
      parent: _entrance,
      curve: Interval(start, start + 0.45, curve: Curves.easeOutCubic),
    );
    return AnimatedBuilder(
      animation: anim,
      child: child,
      builder: (context, child) => Opacity(
        opacity: anim.value,
        child: Transform.translate(
          offset: Offset(0, 18 * (1 - anim.value)),
          child: Transform.scale(scale: 0.98 + 0.02 * anim.value, child: child),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final hc = context.hc;
    final dark = Theme.of(context).brightness == Brightness.dark;
    return AnnotatedRegion<SystemUiOverlayStyle>(
      // Sin barra superior: el fondo del Home sigue bajo la barra de estado.
      value: (dark ? SystemUiOverlayStyle.light : SystemUiOverlayStyle.dark)
          .copyWith(statusBarColor: Colors.transparent),
      child: Scaffold(
        body: Stack(
          children: [
            Positioned(
                top: -120,
                right: -90,
                child: _Blob(size: 320, color: hc.blobs[0])),
            Positioned(
                top: 260,
                left: -140,
                child: _Blob(size: 300, color: hc.blobs[1])),
            SafeArea(
              bottom: false,
              child: BlocConsumer<HomeBloc, HomeState>(
                listenWhen: (before, after) =>
                    after.status == HomeStatus.success &&
                    (before.status != HomeStatus.success ||
                        (before.dailyWaterTotalMl < before.dailyWaterGoalMl &&
                            after.dailyWaterTotalMl >= after.dailyWaterGoalMl)),
                listener: (context, state) {
                  if (_entrance.status == AnimationStatus.dismissed) {
                    _entrance.forward();
                  } else {
                    _celebrate();
                  }
                },
                builder: (context, state) {
                  if (state.status == HomeStatus.failure) {
                    return Center(child: Text('Error: ${state.error}'));
                  }
                  if (state.status != HomeStatus.success) {
                    return const Center(child: CircularProgressIndicator());
                  }
                  final tiles = <Widget>[
                    const _Header(),
                    _RingsCard(state: state),
                    _WaterTile(state: state, celebration: _celebration),
                    IntrinsicHeight(
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          Expanded(child: _SleepTile(state: state)),
                          const SizedBox(width: 14),
                          Expanded(child: _FoodTile(state: state)),
                        ],
                      ),
                    ),
                    _RoutineCard(state: state),
                    const NextConsultationCard(
                        compact: true),
                  ];
                  return RefreshIndicator(
                    onRefresh: () async => context
                        .read<HomeBloc>()
                        .add(HomeLoaded(date: DateTime.now())),
                    child: ListView.separated(
                      padding: const EdgeInsets.fromLTRB(18, 14, 18, 24),
                      itemCount: tiles.length,
                      separatorBuilder: (_, __) => const SizedBox(height: 14),
                      itemBuilder: (context, i) => _stagger(i, tiles[i]),
                    ),
                  );
                },
              ),
            ),
            Positioned(
              top: MediaQuery.paddingOf(context).top + 12,
              left: 0,
              right: 0,
              child: IgnorePointer(
                child: Center(
                  child: AnimatedSlide(
                    offset: _toast ? Offset.zero : const Offset(0, -0.6),
                    duration: const Duration(milliseconds: 300),
                    curve: Curves.easeOutBack,
                    child: AnimatedOpacity(
                      opacity: _toast ? 1 : 0,
                      duration: const Duration(milliseconds: 250),
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 16, vertical: 10),
                        decoration: BoxDecoration(
                          gradient: context.kc.brandGradient,
                          borderRadius: BorderRadius.circular(999),
                          boxShadow: const [
                            BoxShadow(
                                color: Color(0x30000000),
                                blurRadius: 30,
                                offset: Offset(0, 12)),
                          ],
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const Icon(IconsaxPlusBold.drop,
                                size: 18, color: Colors.white),
                            const SizedBox(width: 8),
                            Text(
                              '¡Meta de agua cumplida!',
                              style: Theme.of(context)
                                  .textTheme
                                  .titleSmall
                                  ?.copyWith(
                                      color: Colors.white,
                                      fontWeight: FontWeight.w700),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _Blob extends StatelessWidget {
  const _Blob({required this.size, required this.color});

  final double size;
  final Color color;

  @override
  Widget build(BuildContext context) => IgnorePointer(
        child: Container(
          width: size,
          height: size,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            gradient: RadialGradient(
                colors: [color, color.withValues(alpha: 0)],
                stops: const [0, 0.7]),
          ),
        ),
      );
}

/// Cuenta desde el valor anterior hasta [value].
class _CountUp extends StatelessWidget {
  const _CountUp(this.value, {required this.style, this.decimals = 0});

  final double value;
  final TextStyle? style;
  final int decimals;

  @override
  Widget build(BuildContext context) => TweenAnimationBuilder<double>(
        tween: Tween(begin: 0, end: value),
        duration: const Duration(milliseconds: 1100),
        curve: Curves.easeOutCubic,
        builder: (context, v, _) =>
            Text(v.toStringAsFixed(decimals), style: style),
      );
}

class _Header extends StatelessWidget {
  const _Header();

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;
    final date = DateFormat("EEEE, d 'de' MMMM", 'es').format(DateTime.now());
    return Row(
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                date[0].toUpperCase() + date.substring(1),
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: cs.onSurfaceVariant,
                  fontWeight: FontWeight.w600,
                  fontSize: 13,
                ),
              ),
              const SizedBox(height: 2),
              Text('Hola de nuevo',
                  style: theme.textTheme.displayMedium?.copyWith(fontSize: 28)),
            ],
          ),
        ),
        Material(
          color: cs.surfaceContainerLowest,
          borderRadius: BorderRadius.circular(16),
          child: InkWell(
            borderRadius: BorderRadius.circular(16),
            onTap: () => _openAndReload(context, '/history'),
            child: Tooltip(
              message: 'Historial',
              child: SizedBox(
                width: 48,
                height: 48,
                child: Icon(IconsaxPlusBold.calendar_1,
                    color: cs.primary, size: 24),
              ),
            ),
          ),
        ),
      ],
    );
  }
}

// ── Anillos del día ─────────────────────────────────────────────────────────

class _RingsCard extends StatelessWidget {
  const _RingsCard({required this.state});

  final HomeState state;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;
    final hc = context.hc;
    final values = [
      state.waterProgress.clamp(0.0, 1.0),
      state.mealsProgress.clamp(0.0, 1.0),
      state.sleepProgress,
      state.exerciseProgress,
    ];
    final legend = [
      ('Agua', '${(values[0] * 100).round()}%'),
      ('Comidas', '${state.mealsLogged}/${state.totalMeals}'),
      (
        'Sueño',
        state.sleepHours == null
            ? '—'
            : '${state.sleepHours!.toStringAsFixed(1)} h'
      ),
      (
        'Ejercicio',
        state.exerciseRoutineDone
            ? 'Hecha'
            : state.hasGymSession
                ? 'En curso'
                : 'Pendiente'
      ),
    ];
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: cs.surfaceContainerLowest,
        borderRadius: BorderRadius.circular(28),
        boxShadow: [context.kc.shadow],
      ),
      child: Row(
        children: [
          SizedBox(
            width: 150,
            height: 150,
            child: Stack(
              fit: StackFit.expand,
              children: [
                for (var i = 0; i < 4; i++)
                  TweenAnimationBuilder<double>(
                    tween: Tween(begin: 0, end: values[i]),
                    duration: const Duration(milliseconds: 1300),
                    curve: _settle,
                    builder: (context, v, _) => CustomPaint(
                      painter: _RingPainter(
                        radius: 68 - i * 12.0,
                        progress: v,
                        color: hc.rings[i],
                        track: hc.ringTrack,
                      ),
                    ),
                  ),
                Center(
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.baseline,
                    textBaseline: TextBaseline.alphabetic,
                    children: [
                      _CountUp(
                        calcOverallProgress(state) * 100,
                        style: theme.textTheme.displayMedium
                            ?.copyWith(fontSize: 19),
                      ),
                      Text('%',
                          style: theme.textTheme.labelLarge
                              ?.copyWith(fontWeight: FontWeight.w800)),
                    ],
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('RESUMEN DE HOY',
                    style: theme.textTheme.labelSmall?.copyWith(fontSize: 11)),
                const SizedBox(height: 4),
                for (var i = 0; i < 4; i++)
                  Padding(
                    padding: const EdgeInsets.only(top: 8),
                    child: Row(
                      children: [
                        Container(
                          width: 10,
                          height: 10,
                          decoration: BoxDecoration(
                              color: hc.rings[i], shape: BoxShape.circle),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(legend[i].$1,
                              style: theme.textTheme.bodyMedium?.copyWith(
                                  fontWeight: FontWeight.w600, fontSize: 13)),
                        ),
                        Text(legend[i].$2,
                            style: theme.textTheme.bodyMedium?.copyWith(
                              fontWeight: FontWeight.w700,
                              fontSize: 13,
                              color: cs.onSurfaceVariant,
                            )),
                      ],
                    ),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _RingPainter extends CustomPainter {
  _RingPainter(
      {required this.radius,
      required this.progress,
      required this.color,
      required this.track});

  final double radius;
  final double progress;
  final Color color;
  final Color track;

  @override
  void paint(Canvas canvas, Size size) {
    final center = size.center(Offset.zero);
    final stroke = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 9
      ..strokeCap = StrokeCap.round;
    canvas.drawCircle(center, radius, stroke..color = track);
    if (progress <= 0) return;
    canvas.drawArc(
      Rect.fromCircle(center: center, radius: radius),
      -math.pi / 2,
      2 * math.pi * progress,
      false,
      stroke..color = color,
    );
  }

  @override
  bool shouldRepaint(_RingPainter old) =>
      old.progress != progress ||
      old.color != color ||
      old.track != track ||
      old.radius != radius;
}

// ── Agua ────────────────────────────────────────────────────────────────────

class _WaterTile extends StatefulWidget {
  const _WaterTile({required this.state, required this.celebration});

  final HomeState state;

  /// Cambia cada vez que se cumple la meta, para lanzar los destellos.
  final int celebration;

  @override
  State<_WaterTile> createState() => _WaterTileState();
}

class _WaterTileState extends State<_WaterTile> with TickerProviderStateMixin {
  late final _wave = AnimationController(
      vsync: this, duration: const Duration(milliseconds: 3200))
    ..repeat();
  late final _bump = AnimationController(
      vsync: this, duration: const Duration(milliseconds: 450));
  late final _float = AnimationController(
      vsync: this, duration: const Duration(milliseconds: 900));
  late final _sparks = AnimationController(
      vsync: this, duration: const Duration(milliseconds: 1000));

  late final _bumpScale = TweenSequence<double>([
    TweenSequenceItem(
        tween: Tween<double>(begin: 1, end: 0.86)
            .chain(CurveTween(curve: Curves.easeOut)),
        weight: 40),
    TweenSequenceItem(
        tween: Tween<double>(begin: 0.86, end: 1)
            .chain(CurveTween(curve: Curves.elasticOut)),
        weight: 60),
  ]).animate(_bump);

  @override
  void didUpdateWidget(_WaterTile old) {
    super.didUpdateWidget(old);
    if (old.celebration != widget.celebration) _sparks.forward(from: 0);
  }

  @override
  void dispose() {
    _wave.dispose();
    _bump.dispose();
    _float.dispose();
    _sparks.dispose();
    super.dispose();
  }

  /// Lo último que se sumó, para la etiqueta que flota.
  int _lastAdded = 0;

  Future<void> _add() async {
    _bump.forward(from: 0);
    final bloc = context.read<HomeBloc>();
    final ml = await showWaterAmountSheet(context);
    if (ml == null || !mounted) return;
    HapticFeedback.lightImpact();
    setState(() => _lastAdded = ml);
    _float.forward(from: 0);
    bloc.add(HomeWaterAdded(ml));
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;
    final kc = context.kc;
    final hc = context.hc;
    final s = widget.state;
    final left = s.dailyWaterGoalMl - s.dailyWaterTotalMl;
    final remaining = left > 0 ? 'Faltan $left ml para tu meta' : 'Meta cumplida hoy';

    return Material(
      color: kc.waterWash,
      borderRadius: BorderRadius.circular(28),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: () => _openAndReload(context, '/water'),
        child: Stack(
          children: [
            Positioned.fill(
              child: TweenAnimationBuilder<double>(
                tween: Tween(begin: 0, end: s.waterProgress.clamp(0.0, 1.0)),
                duration: const Duration(milliseconds: 1000),
                curve: _settle,
                builder: (context, level, _) => AnimatedBuilder(
                  animation: _wave,
                  builder: (context, _) => CustomPaint(
                    painter: WavePainter(
                        level: level,
                        phase: _wave.value,
                        front: hc.waterFill,
                        back: hc.waveBack),
                  ),
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.all(18),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Container(
                              width: 36,
                              height: 36,
                              decoration: BoxDecoration(
                                color: cs.surfaceContainerLowest,
                                borderRadius: BorderRadius.circular(12),
                              ),
                              child: Icon(IconsaxPlusBold.drop,
                                  size: 20, color: kc.waterInk),
                            ),
                            const SizedBox(width: 8),
                            Text('HIDRATACIÓN',
                                style: theme.textTheme.labelSmall?.copyWith(
                                    fontSize: 11, color: kc.waterInk)),
                          ],
                        ),
                        const SizedBox(height: 10),
                        Row(
                          crossAxisAlignment: CrossAxisAlignment.baseline,
                          textBaseline: TextBaseline.alphabetic,
                          children: [
                            _CountUp(
                              s.dailyWaterTotalMl.toDouble(),
                              style: theme.textTheme.displayLarge?.copyWith(
                                  fontSize: 42, color: hc.waterNumber),
                            ),
                            const SizedBox(width: 6),
                            Text('/ ${s.dailyWaterGoalMl} ml',
                                style: theme.textTheme.bodyLarge?.copyWith(
                                    color: kc.waterInk,
                                    fontWeight: FontWeight.w600)),
                          ],
                        ),
                        const SizedBox(height: 2),
                        Text(remaining,
                            style: theme.textTheme.bodyMedium?.copyWith(
                                color: kc.waterInk,
                                fontWeight: FontWeight.w600)),
                      ],
                    ),
                  ),
                  Column(
                    children: [
                      SizedBox(
                        width: 64,
                        height: 64,
                        child: Stack(
                          clipBehavior: Clip.none,
                          alignment: Alignment.center,
                          children: [
                            AnimatedBuilder(
                              animation: _sparks,
                              builder: (context, _) => _sparks.isAnimating
                                  ? CustomPaint(
                                      size: const Size(64, 64),
                                      painter: _SparksPainter(
                                          _sparks.value, hc.rings))
                                  : const SizedBox.shrink(),
                            ),
                            ScaleTransition(
                              scale: _bumpScale,
                              child: Semantics(
                                button: true,
                                label: 'Agregar agua',
                                child: GestureDetector(
                                  onTap: _add,
                                  child: Container(
                                    width: 60,
                                    height: 60,
                                    decoration: BoxDecoration(
                                      gradient: kc.brandGradient,
                                      borderRadius: BorderRadius.circular(20),
                                      boxShadow: const [
                                        BoxShadow(
                                            color: Color(0x2E000000),
                                            blurRadius: 24,
                                            offset: Offset(0, 10)),
                                      ],
                                    ),
                                    child: const Icon(IconsaxPlusLinear.add,
                                        color: Colors.white, size: 28),
                                  ),
                                ),
                              ),
                            ),
                            Positioned(
                              top: -26,
                              child: AnimatedBuilder(
                                animation: _float,
                                builder: (context, _) {
                                  if (!_float.isAnimating)
                                    return const SizedBox.shrink();
                                  final t = _float.value;
                                  final opacity =
                                      t < 0.2 ? t / 0.2 : 1 - (t - 0.2) / 0.8;
                                  return Transform.translate(
                                    offset: Offset(0, 6 - 40 * t),
                                    child: Opacity(
                                      opacity: opacity.clamp(0.0, 1.0),
                                      child: Text('+$_lastAdded ml',
                                          style: theme.textTheme.titleSmall
                                              ?.copyWith(
                                                  color: hc.waterNumber,
                                                  fontWeight: FontWeight.w800)),
                                    ),
                                  );
                                },
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text('Agregar',
                          style: theme.textTheme.labelSmall
                              ?.copyWith(fontSize: 11, color: kc.waterInk)),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Doce destellos que salen del botón al cumplir la meta.
class _SparksPainter extends CustomPainter {
  _SparksPainter(this.t, this.colors);

  final double t;
  final List<Color> colors;

  @override
  void paint(Canvas canvas, Size size) {
    final center = size.center(Offset.zero);
    final eased = Curves.easeOutCubic.transform(t);
    for (var i = 0; i < 12; i++) {
      final angle = i * math.pi / 6;
      final p =
          center + Offset(math.sin(angle), -math.cos(angle)) * (70 * eased);
      canvas.drawCircle(
        p,
        4 * (1 - 0.6 * eased),
        Paint()..color = colors[i % colors.length].withValues(alpha: 1 - t),
      );
    }
  }

  @override
  bool shouldRepaint(_SparksPainter old) => old.t != t;
}

// ── Sueño y comidas ─────────────────────────────────────────────────────────

class _TileShell extends StatelessWidget {
  const _TileShell(
      {required this.color, required this.onTap, required this.child});

  final Color color;
  final VoidCallback onTap;
  final Widget child;

  @override
  Widget build(BuildContext context) => Material(
        color: color,
        borderRadius: BorderRadius.circular(26),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: onTap,
          child: Padding(padding: const EdgeInsets.all(16), child: child),
        ),
      );
}

class _Chip extends StatelessWidget {
  const _Chip({required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) => Container(
        width: 40,
        height: 40,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: Theme.of(context).colorScheme.surfaceContainerLowest,
          borderRadius: BorderRadius.circular(14),
        ),
        child: child,
      );
}

class _SleepTile extends StatelessWidget {
  const _SleepTile({required this.state});

  final HomeState state;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final kc = context.kc;
    final hc = context.hc;
    final hours = state.sleepHours;
    return _TileShell(
      color: kc.sleepWash,
      onTap: () => _openAndReload(context, '/sleep'),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _Chip(
              child: Icon(IconsaxPlusBold.moon, size: 22, color: kc.sleepInk)),
          const SizedBox(height: 10),
          Text('SUEÑO',
              style: theme.textTheme.labelSmall
                  ?.copyWith(fontSize: 11, color: kc.sleepInk)),
          const SizedBox(height: 4),
          Row(
            crossAxisAlignment: CrossAxisAlignment.baseline,
            textBaseline: TextBaseline.alphabetic,
            children: [
              if (hours != null)
                _CountUp(hours,
                    decimals: 1,
                    style:
                        theme.textTheme.displayMedium?.copyWith(fontSize: 30))
              else
                Text('—',
                    style:
                        theme.textTheme.displayMedium?.copyWith(fontSize: 30)),
              const SizedBox(width: 4),
              Flexible(
                child: Text(hours != null ? 'h' : 'sin registro',
                    style: theme.textTheme.bodyMedium?.copyWith(
                        color: kc.sleepInk, fontWeight: FontWeight.w700)),
              ),
            ],
          ),
          const Spacer(),
          const SizedBox(height: 10),
          SizedBox(
            height: 22,
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                for (var i = 0; i < 7; i++) ...[
                  if (i > 0) const SizedBox(width: 4),
                  Expanded(
                    child: TweenAnimationBuilder<double>(
                      tween: Tween(
                          begin: 0,
                          end: (state.sleepWeek[i] / 8).clamp(0.0, 1.0)),
                      duration: Duration(milliseconds: 700 + i * 60),
                      curve: _settle,
                      builder: (context, v, _) => Container(
                        height: math.max(3, 22 * v),
                        decoration: BoxDecoration(
                          color: i == 6 ? hc.barOn : hc.barOff,
                          borderRadius: BorderRadius.circular(4),
                        ),
                      ),
                    ),
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _FoodTile extends StatelessWidget {
  const _FoodTile({required this.state});

  final HomeState state;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;
    final kc = context.kc;
    final hc = context.hc;
    final segments = state.totalMeals.clamp(1, 8);
    final next = state.mealsLogged >= state.totalMeals
        ? 'Comidas al día'
        : state.nextMeal != null
            ? 'Sigue: ${state.nextMeal}'
            : 'Comida pendiente';
    return _TileShell(
      color: kc.foodWash,
      onTap: () => context.go('/nutrition'),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              _Chip(
                  child: KiologGlyph(KiologGlyphKind.bowl,
                      size: 24, color: kc.foodInk)),
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: ShapeDecoration(
                    color: cs.surfaceContainerLowest,
                    shape: const StadiumBorder()),
                child: Text('${state.mealsLogged} / ${state.totalMeals}',
                    style: theme.textTheme.labelMedium?.copyWith(
                        color: kc.foodInk, fontWeight: FontWeight.w800)),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Text('NUTRICIÓN',
              style: theme.textTheme.labelSmall
                  ?.copyWith(fontSize: 11, color: kc.foodInk)),
          const SizedBox(height: 6),
          Text(next,
              style: theme.textTheme.titleMedium
                  ?.copyWith(fontWeight: FontWeight.w700)),
          const Spacer(),
          const SizedBox(height: 10),
          Row(
            children: [
              for (var i = 0; i < segments; i++) ...[
                if (i > 0) const SizedBox(width: 6),
                Expanded(
                  child: AnimatedContainer(
                    duration: Duration(milliseconds: 400 + i * 80),
                    height: 8,
                    decoration: BoxDecoration(
                      color: i < state.mealsLogged ? hc.foodOn : hc.foodOff,
                      borderRadius: BorderRadius.circular(4),
                    ),
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

// ── Rutina del día ──────────────────────────────────────────────────────────

class _RoutineCard extends StatefulWidget {
  const _RoutineCard({required this.state});

  final HomeState state;

  @override
  State<_RoutineCard> createState() => _RoutineCardState();
}

class _RoutineCardState extends State<_RoutineCard>
    with SingleTickerProviderStateMixin {
  late final _pulse = AnimationController(
      vsync: this, duration: const Duration(milliseconds: 2400))
    ..repeat();

  @override
  void dispose() {
    _pulse.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final hc = context.hc;
    final s = widget.state;
    final title = s.routineName == null
        ? 'Sin rutina cargada'
        : s.routineDay != null
            ? 'Día ${s.routineDay} · ${s.routineName}'
            : s.routineName!;
    final week =
        '${s.weekRoutineDays} de ${s.weekRoutineGoal} días esta semana';
    final subtitle = s.exerciseRoutineDone
        ? 'Rutina completada · $week'
        : s.hasGymSession
            ? 'Sesión en curso · $week'
            : '${s.routineExercises} ejercicios · $week';

    return Material(
      color: Colors.transparent,
      child: Ink(
        decoration: BoxDecoration(
            gradient: hc.gymCard, borderRadius: BorderRadius.circular(28)),
        child: InkWell(
          borderRadius: BorderRadius.circular(28),
          onTap: () => context.go('/exercise'),
          child: Padding(
            padding: const EdgeInsets.all(18),
            child: Row(
              children: [
                Container(
                  width: 52,
                  height: 52,
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                      color: hc.gymChip,
                      borderRadius: BorderRadius.circular(18)),
                  child: KiologGlyph(KiologGlyphKind.dumbbell,
                      size: 30, color: hc.gymInk),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('RUTINA DEL DÍA',
                          style: theme.textTheme.labelSmall
                              ?.copyWith(fontSize: 11, color: hc.gymInk)),
                      const SizedBox(height: 2),
                      Text(title,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: theme.textTheme.titleLarge?.copyWith(
                              color: Colors.white,
                              fontWeight: FontWeight.w800)),
                      const SizedBox(height: 2),
                      Text(subtitle,
                          style: theme.textTheme.bodyMedium
                              ?.copyWith(color: hc.gymSub, fontSize: 13)),
                    ],
                  ),
                ),
                const SizedBox(width: 10),
                AnimatedBuilder(
                  animation: _pulse,
                  builder: (context, child) {
                    final wave = math.sin(_pulse.value * math.pi);
                    return DecoratedBox(
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        boxShadow: s.exerciseRoutineDone
                            ? null
                            : [
                                BoxShadow(
                                  color: hc.pulse.withValues(
                                      alpha: hc.pulse.a * (1 - wave)),
                                  spreadRadius: 10 * wave,
                                ),
                              ],
                      ),
                      child: child,
                    );
                  },
                  child: Container(
                    width: 52,
                    height: 52,
                    decoration: BoxDecoration(
                        gradient: hc.gymButton, shape: BoxShape.circle),
                    child: Icon(
                      s.exerciseRoutineDone
                          ? IconsaxPlusBold.tick_circle
                          : IconsaxPlusBold.play,
                      color: Colors.white,
                      size: 24,
                    ),
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
