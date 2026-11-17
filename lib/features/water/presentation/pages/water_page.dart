import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:iconsax_plus/iconsax_plus.dart';
import 'package:intl/intl.dart';
import 'package:kiolog/core/database/app_database.dart';
import 'package:kiolog/core/domain/app_module.dart';
import 'package:kiolog/core/modules/cubit/modules_cubit.dart';
import 'package:kiolog/core/modules/cubit/modules_state.dart';
import 'package:kiolog/core/theme/app_theme.dart';
import 'package:kiolog/shared/widgets/entrance.dart';
import 'package:kiolog/shared/widgets/inactive_module_page.dart';
import 'package:kiolog/shared/widgets/themed_page.dart';
import 'package:kiolog/shared/widgets/water_widgets.dart';
import '../../../../core/di/injection.dart';
import '../../domain/repositories/water_repository.dart';
import '../bloc/water_bloc.dart';
import '../bloc/water_event.dart';
import '../bloc/water_state.dart';

const _settle = Cubic(.3, .9, .25, 1);
const _quickAmounts = [250, 500, 750, 1000];

class WaterPage extends StatelessWidget {
  const WaterPage({super.key});

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<ModulesCubit, ModulesState>(
      builder: (context, modulesState) {
        if (!modulesState.isEnabled(AppModule.water)) {
          return const InactiveModulePage(module: AppModule.water);
        }
        return BlocProvider(
          create: (_) => WaterBloc(getIt<WaterRepository>())..add(WaterLoaded(date: DateTime.now())),
          child: const _WaterView(),
        );
      },
    );
  }
}

void _add(BuildContext context, int ml) {
  HapticFeedback.lightImpact();
  context.read<WaterBloc>().add(WaterAdded(date: DateTime.now(), amountMl: ml));
}

Future<void> _addOther(BuildContext context) async {
  final bloc = context.read<WaterBloc>();
  final ml = await showWaterAmountSheet(context);
  if (ml != null) {
    HapticFeedback.lightImpact();
    bloc.add(WaterAdded(date: DateTime.now(), amountMl: ml));
  }
}

Future<void> _editGoal(BuildContext context) async {
  final bloc = context.read<WaterBloc>();
  final ml = await showWaterAmountSheet(
    context,
    title: 'Meta diaria de agua',
    action: 'Guardar',
    presets: const [2000, 2500, 3000, 3500],
    initialMl: bloc.state.dailyGoalMl,
    startInLiters: true,
  );
  if (ml != null) bloc.add(WaterGoalUpdated(ml));
}

class _WaterView extends StatelessWidget {
  const _WaterView();

  @override
  Widget build(BuildContext context) {
    return ThemedPage(
      child: BlocConsumer<WaterBloc, WaterState>(
        listenWhen: (before, after) =>
            before.status == WaterStatus.success &&
            before.dailyTotalMl < before.dailyGoalMl &&
            after.dailyTotalMl >= after.dailyGoalMl,
        listener: (context, state) {
          HapticFeedback.mediumImpact();
          ScaffoldMessenger.of(context)
            ..hideCurrentSnackBar()
            ..showSnackBar(const SnackBar(content: Text('¡Meta de agua cumplida!')));
        },
        builder: (context, state) {
          if (state.status == WaterStatus.failure) {
            return Center(child: Text('Error: ${state.error}'));
          }
          if (state.status != WaterStatus.success) {
            return const Center(child: CircularProgressIndicator());
          }
          final items = <Widget>[
            const _Header(),
            _GlassCard(state: state),
            const _QuickAdd(),
            _IntakesCard(logs: state.logs),
          ];
          return ListView.separated(
            padding: const EdgeInsets.fromLTRB(18, 14, 18, 32),
            itemCount: items.length,
            separatorBuilder: (_, __) => const SizedBox(height: 14),
            itemBuilder: (context, i) => Entrance(index: i, child: items[i]),
          );
        },
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
        Material(
          color: cs.surfaceContainerLowest,
          borderRadius: BorderRadius.circular(16),
          child: InkWell(
            borderRadius: BorderRadius.circular(16),
            onTap: () => context.canPop() ? context.pop() : context.go('/'),
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
              Text('HIDRATACIÓN', style: theme.textTheme.labelSmall?.copyWith(fontSize: 11, color: cs.primary)),
              Text('Agua de hoy', style: theme.textTheme.displayMedium?.copyWith(fontSize: 26)),
            ],
          ),
        ),
        HeaderIconButton(icon: IconsaxPlusBold.flag, tooltip: 'Meta diaria', onTap: () => _editGoal(context)),
      ],
    );
  }
}

/// El "vaso": se llena con olas hasta la meta.
class _GlassCard extends StatefulWidget {
  const _GlassCard({required this.state});

  final WaterState state;

  @override
  State<_GlassCard> createState() => _GlassCardState();
}

class _GlassCardState extends State<_GlassCard> with SingleTickerProviderStateMixin {
  late final _wave = AnimationController(vsync: this, duration: const Duration(milliseconds: 3200))..repeat();

  @override
  void dispose() {
    _wave.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final kc = context.kc;
    final hc = context.hc;
    final s = widget.state;
    final left = s.dailyGoalMl - s.dailyTotalMl;
    final met = left <= 0;

    return Material(
      color: kc.waterWash,
      borderRadius: BorderRadius.circular(32),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: () => _addOther(context),
        child: SizedBox(
          height: 280,
          child: Stack(
            children: [
              Positioned.fill(
                child: TweenAnimationBuilder<double>(
                  tween: Tween(begin: 0, end: s.progress.clamp(0.0, 1.0)),
                  duration: const Duration(milliseconds: 1100),
                  curve: _settle,
                  builder: (context, level, _) => AnimatedBuilder(
                    animation: _wave,
                    builder: (context, _) => CustomPaint(
                      painter: WavePainter(level: level, phase: _wave.value, front: hc.waterFill, back: hc.waveBack),
                    ),
                  ),
                ),
              ),
              Center(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Container(
                      width: 48,
                      height: 48,
                      alignment: Alignment.center,
                      decoration: BoxDecoration(
                        color: theme.colorScheme.surfaceContainerLowest,
                        borderRadius: BorderRadius.circular(16),
                      ),
                      child: Icon(IconsaxPlusBold.drop, color: kc.waterInk, size: 26),
                    ),
                    const SizedBox(height: 12),
                    TweenAnimationBuilder<double>(
                      tween: Tween(begin: 0, end: s.dailyTotalMl.toDouble()),
                      duration: const Duration(milliseconds: 1000),
                      curve: Curves.easeOutCubic,
                      builder: (context, v, _) => Row(
                        mainAxisSize: MainAxisSize.min,
                        crossAxisAlignment: CrossAxisAlignment.baseline,
                        textBaseline: TextBaseline.alphabetic,
                        children: [
                          Text(litersLabel(v.round()),
                              style: theme.textTheme.displayLarge?.copyWith(fontSize: 64, color: hc.waterNumber)),
                          const SizedBox(width: 6),
                          Text('/ ${litersLabel(s.dailyGoalMl)} L',
                              style: theme.textTheme.titleLarge?.copyWith(color: kc.waterInk)),
                        ],
                      ),
                    ),
                    const SizedBox(height: 4),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                      decoration: ShapeDecoration(
                        color: theme.colorScheme.surfaceContainerLowest.withValues(alpha: 0.8),
                        shape: const StadiumBorder(),
                      ),
                      child: Text(
                        met
                            ? '¡Meta cumplida! · ${s.dailyTotalMl} ml'
                            : '${(s.progress * 100).round()} % · faltan $left ml',
                        style: theme.textTheme.labelLarge?.copyWith(color: kc.waterInk, fontWeight: FontWeight.w800),
                      ),
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

class _QuickAdd extends StatelessWidget {
  const _QuickAdd();

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;
    final kc = context.kc;
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: cs.surfaceContainerLowest,
        borderRadius: BorderRadius.circular(28),
        boxShadow: [kc.shadow],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text('AGREGAR', style: theme.textTheme.labelSmall?.copyWith(fontSize: 11)),
          const SizedBox(height: 10),
          Row(
            children: [
              for (var i = 0; i < _quickAmounts.length; i++) ...[
                if (i > 0) const SizedBox(width: 8),
                Expanded(
                  child: Material(
                    color: kc.waterWash,
                    borderRadius: BorderRadius.circular(18),
                    child: InkWell(
                      borderRadius: BorderRadius.circular(18),
                      onTap: () => _add(context, _quickAmounts[i]),
                      child: Padding(
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        child: Column(
                          children: [
                            SizedBox(
                              height: 26,
                              child: Center(
                                child: Icon(IconsaxPlusBold.drop, color: kc.waterInk, size: 14 + i * 3.0),
                              ),
                            ),
                            const SizedBox(height: 6),
                            Text(
                              _quickAmounts[i] >= 1000
                                  ? '${litersLabel(_quickAmounts[i])} L'
                                  : '${_quickAmounts[i]} ml',
                              style: theme.textTheme.labelLarge?.copyWith(
                                color: kc.waterInk,
                                fontWeight: FontWeight.w800,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            ],
          ),
          const SizedBox(height: 10),
          PillButton(
            icon: IconsaxPlusLinear.edit_2,
            label: 'Otra cantidad (ml o L)',
            color: cs.primary,
            onTap: () => _addOther(context),
          ),
        ],
      ),
    );
  }
}

class _IntakesCard extends StatelessWidget {
  const _IntakesCard({required this.logs});

  final List<DailyWaterLog> logs;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;
    final kc = context.kc;
    final time = DateFormat('HH:mm');
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: cs.surfaceContainerLowest,
        borderRadius: BorderRadius.circular(28),
        boxShadow: [kc.shadow],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Expanded(child: Text('TOMAS DE HOY', style: theme.textTheme.labelSmall?.copyWith(fontSize: 11))),
              Text('${logs.length}', style: theme.textTheme.labelLarge?.copyWith(color: kc.waterInk)),
            ],
          ),
          if (logs.isEmpty)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 14),
              child: Text('Todavía no registras agua hoy.', style: theme.textTheme.bodyMedium),
            ),
          for (final log in logs.reversed)
            Padding(
              padding: const EdgeInsets.only(top: 8),
              child: Container(
                padding: const EdgeInsets.fromLTRB(12, 6, 4, 6),
                decoration: BoxDecoration(color: cs.surfaceContainerLow, borderRadius: BorderRadius.circular(16)),
                child: Row(
                  children: [
                    Icon(IconsaxPlusBold.drop, size: 18, color: kc.waterInk),
                    const SizedBox(width: 10),
                    Text(time.format(log.timestamp.toLocal()), style: theme.textTheme.bodyMedium),
                    const Spacer(),
                    Text(
                      log.amountMl >= 1000 ? '${litersLabel(log.amountMl)} L' : '${log.amountMl} ml',
                      style: theme.textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w800),
                    ),
                    IconButton(
                      tooltip: 'Borrar esta toma',
                      icon: Icon(IconsaxPlusLinear.trash, size: 18, color: cs.onSurfaceVariant),
                      onPressed: () {
                        context.read<WaterBloc>().add(WaterLogDeleted(log.id));
                        ScaffoldMessenger.of(context)
                          ..hideCurrentSnackBar()
                          ..showSnackBar(const SnackBar(content: Text('Toma borrada')));
                      },
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
