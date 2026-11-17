import 'dart:math' as math;
import 'dart:typed_data';

import 'package:collection/collection.dart';
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
import 'package:kiolog/shared/widgets/kiolog_glyphs.dart';
import 'package:kiolog/shared/widgets/meal_icons.dart';
import 'package:kiolog/shared/widgets/meal_photo.dart';
import 'package:kiolog/shared/widgets/themed_page.dart';
import '../../../../core/di/injection.dart';
import '../../domain/repositories/nutrition_repository.dart';
import '../bloc/nutrition_bloc.dart';
import '../bloc/nutrition_event.dart';
import '../bloc/nutrition_state.dart';
import 'nutrition_config_page.dart';
import 'nutrition_progress_page.dart';

class NutritionPage extends StatelessWidget {
  const NutritionPage({super.key});

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<ModulesCubit, ModulesState>(
      builder: (context, modulesState) {
        if (!modulesState.isEnabled(AppModule.nutrition)) {
          return const InactiveModulePage(module: AppModule.nutrition);
        }
        return BlocProvider(
          create: (_) => NutritionBloc(getIt<NutritionRepository>())
            ..add(NutritionLoaded(date: DateTime.now())),
          child: const _NutritionView(),
        );
      },
    );
  }
}

/// Cómo quedó registrado un tiempo de comida hoy.
enum _MealStatus { pending, plan, offPlan, skipped }

_MealStatus _statusOf(DailyMealLog? log) {
  if (log == null) return _MealStatus.pending;
  if (log.planOptionId != null) return _MealStatus.plan;
  if (log.freeDescription != null) return _MealStatus.offPlan;
  return _MealStatus.skipped;
}

/// Color, texto e ícono de cada estado, del tema actual.
({Color color, Color tint, String label, IconData icon}) _statusStyle(BuildContext context, _MealStatus status) {
  final cs = Theme.of(context).colorScheme;
  final kc = context.kc;
  return switch (status) {
    _MealStatus.pending => (
        color: cs.onSurfaceVariant,
        tint: cs.surfaceContainerHigh,
        label: 'Pendiente',
        icon: IconsaxPlusLinear.clock,
      ),
    _MealStatus.plan => (
        color: cs.primary,
        tint: cs.primary.withValues(alpha: 0.14),
        label: 'Del plan',
        icon: IconsaxPlusBold.tick_circle,
      ),
    _MealStatus.offPlan => (
        color: kc.warning,
        tint: kc.warning.withValues(alpha: 0.16),
        label: 'Fuera de plan',
        icon: IconsaxPlusBold.edit_2,
      ),
    _MealStatus.skipped => (
        color: cs.error,
        tint: cs.error.withValues(alpha: 0.12),
        label: 'No seguido',
        icon: IconsaxPlusBold.close_circle,
      ),
  };
}

class _NutritionView extends StatelessWidget {
  const _NutritionView();

  void _openProgress(BuildContext context) {
    final bloc = context.read<NutritionBloc>();
    Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => BlocProvider.value(value: bloc, child: const NutritionProgressPage()),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return ThemedPage(
      child: BlocBuilder<NutritionBloc, NutritionState>(
        builder: (context, state) {
          if (state.status == NutritionStatus.loading && state.activePlan == null) {
            return const Center(child: CircularProgressIndicator());
          }
          if (state.status == NutritionStatus.failure) {
            return Center(child: Text('Error: ${state.error}'));
          }
          final plan = state.activePlan;
          final header = _Header(
            planName: plan?.name,
            onProgress: () => _openProgress(context),
            onPlans: () => _showPlansDialog(context),
          );
          if (plan == null) {
            return ListView(
              padding: const EdgeInsets.fromLTRB(18, 14, 18, 24),
              children: [header, const SizedBox(height: 40), const _NoPlanView()],
            );
          }
          final types = state.planOptions.keys.toList();
          final items = <Widget>[
            header,
            if (types.isNotEmpty) _DaySummary(types: types, state: state),
            if (types.isEmpty) _EmptyPlanCard(plan: plan),
            for (final type in types)
              _MealSection(
                mealType: type,
                options: state.planOptions[type] ?? const [],
                log: state.getLogForMeal(type),
              ),
            Center(
              child: PillButton(
                icon: IconsaxPlusLinear.add,
                label: 'Nuevo plan',
                onTap: () => _openPlanForm(context),
              ),
            ),
          ];
          return RefreshIndicator(
            onRefresh: () async => context.read<NutritionBloc>().add(NutritionLoaded(date: DateTime.now())),
            child: ListView.separated(
              padding: const EdgeInsets.fromLTRB(18, 14, 18, 24),
              itemCount: items.length,
              separatorBuilder: (_, __) => const SizedBox(height: 14),
              itemBuilder: (context, i) => Entrance(index: i, child: items[i]),
            ),
          );
        },
      ),
    );
  }

  void _showPlansDialog(BuildContext context) {
    context.read<NutritionBloc>().add(const NutritionPlanLoaded());
    showDialog<void>(
      context: context,
      builder: (dialogContext) => BlocProvider.value(
        value: context.read<NutritionBloc>(),
        child: const _PlansDialog(),
      ),
    );
  }
}

class _Header extends StatelessWidget {
  const _Header({required this.planName, required this.onProgress, required this.onPlans});

  final String? planName;
  final VoidCallback onProgress;
  final VoidCallback onPlans;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                planName == null ? 'NUTRICIÓN' : 'PLAN ACTIVO',
                style: theme.textTheme.labelSmall?.copyWith(fontSize: 11, color: theme.colorScheme.primary),
              ),
              const SizedBox(height: 2),
              Text(
                planName ?? 'Nutrición',
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: theme.textTheme.displayMedium?.copyWith(fontSize: 23, height: 1.15),
              ),
            ],
          ),
        ),
        HeaderIconButton(icon: IconsaxPlusBold.chart_2, tooltip: 'Progreso', onTap: onProgress),
        HeaderIconButton(icon: IconsaxPlusBold.book_1, tooltip: 'Planes', onTap: onPlans),
        HeaderIconButton(
          icon: IconsaxPlusBold.calendar_1,
          tooltip: 'Historial',
          onTap: () => context.push('/history'),
        ),
      ],
    );
  }
}

// ── Resumen del día ─────────────────────────────────────────────────────────

class _DaySummary extends StatelessWidget {
  const _DaySummary({required this.types, required this.state});

  final List<String> types;
  final NutritionState state;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;
    final hc = context.hc;
    final logged = types.where((t) => state.getLogForMeal(t) != null).length;
    final next = types.firstWhereOrNull((t) => state.getLogForMeal(t) == null);
    final title = next == null ? 'Día completo' : 'Sigue: $next';
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
            width: 88,
            height: 88,
            child: TweenAnimationBuilder<double>(
              tween: Tween(begin: 0, end: types.isEmpty ? 0 : logged / types.length),
              duration: const Duration(milliseconds: 1100),
              curve: const Cubic(.3, .9, .25, 1),
              builder: (context, v, _) => CustomPaint(
                painter: _ArcPainter(progress: v, color: hc.foodOn, track: hc.ringTrack),
                child: Center(
                  child: Text('$logged/${types.length}',
                      style: theme.textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w800)),
                ),
              ),
            ),
          ),
          const SizedBox(width: 18),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('COMIDAS DE HOY', style: theme.textTheme.labelSmall?.copyWith(fontSize: 11)),
                const SizedBox(height: 2),
                Text(title, style: theme.textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w800)),
                const SizedBox(height: 10),
                Wrap(
                  spacing: 6,
                  runSpacing: 6,
                  children: [
                    for (final type in types)
                      Builder(builder: (context) {
                        final style = _statusStyle(context, _statusOf(state.getLogForMeal(type)));
                        return AnimatedContainer(
                          duration: const Duration(milliseconds: 300),
                          padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 5),
                          decoration: ShapeDecoration(color: style.tint, shape: const StadiumBorder()),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Container(
                                width: 7,
                                height: 7,
                                decoration: BoxDecoration(color: style.color, shape: BoxShape.circle),
                              ),
                              const SizedBox(width: 5),
                              Text(type, style: theme.textTheme.labelMedium?.copyWith(color: style.color)),
                            ],
                          ),
                        );
                      }),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _ArcPainter extends CustomPainter {
  _ArcPainter({required this.progress, required this.color, required this.track});

  final double progress;
  final Color color;
  final Color track;

  @override
  void paint(Canvas canvas, Size size) {
    final center = size.center(Offset.zero);
    final radius = size.shortestSide / 2 - 6;
    final stroke = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 10
      ..strokeCap = StrokeCap.round;
    canvas.drawCircle(center, radius, stroke..color = track);
    if (progress <= 0) return;
    canvas.drawArc(Rect.fromCircle(center: center, radius: radius), -math.pi / 2, 2 * math.pi * progress, false,
        stroke..color = color);
  }

  @override
  bool shouldRepaint(_ArcPainter old) => old.progress != progress || old.color != color || old.track != track;
}

// ── Sin plan ────────────────────────────────────────────────────────────────

class _NoPlanView extends StatelessWidget {
  const _NoPlanView();

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final kc = context.kc;
    return Column(
      children: [
        Container(
          width: 96,
          height: 96,
          alignment: Alignment.center,
          decoration: BoxDecoration(color: kc.foodWash, borderRadius: BorderRadius.circular(30)),
          child: KiologGlyph(KiologGlyphKind.bowl, size: 48, color: kc.foodInk),
        ),
        const SizedBox(height: 20),
        Text('Sin plan activo', style: theme.textTheme.headlineMedium),
        const SizedBox(height: 8),
        Text(
          'Copia el plan de tu nutricionista para empezar a registrar tus comidas.',
          textAlign: TextAlign.center,
          style: theme.textTheme.bodyMedium?.copyWith(color: theme.colorScheme.onSurfaceVariant),
        ),
        const SizedBox(height: 24),
        ElevatedButton.icon(
          onPressed: () => _openPlanForm(context),
          icon: const Icon(IconsaxPlusLinear.add),
          label: const Text('Crear plan'),
        ),
      ],
    );
  }
}

// ── Formulario y acciones de plan ────────────────────────────────────────────

enum _PlanAction { activate, edit, delete }

void _pushPlanForm(BuildContext context, NutritionBloc bloc, {MealPlan? plan}) {
  Navigator.of(context).push(
    MaterialPageRoute<void>(
      builder: (_) => NutritionConfigPage(
        plan: plan,
        onComplete: () => bloc.add(NutritionLoaded(date: DateTime.now())),
      ),
    ),
  );
}

void _openPlanForm(BuildContext context, {MealPlan? plan}) =>
    _pushPlanForm(context, context.read<NutritionBloc>(), plan: plan);

Future<void> _onPlanAction(
  BuildContext context,
  _PlanAction action,
  MealPlan plan,
) async {
  final bloc = context.read<NutritionBloc>();
  final navigator = Navigator.of(context);
  switch (action) {
    case _PlanAction.activate:
      bloc.add(NutritionPlanActivated(planId: plan.id));
      navigator.pop();
    case _PlanAction.edit:
      navigator.pop();
      _pushPlanForm(context, bloc, plan: plan);
    case _PlanAction.delete:
      final confirmed = await showDialog<bool>(
        context: context,
        builder: (dialogContext) => AlertDialog(
          title: const Text('Borrar plan'),
          content: Text(
            'Se borrará "${plan.name}" con las comidas registradas en él. '
            'No se puede deshacer.',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext, false),
              child: const Text('Cancelar'),
            ),
            ElevatedButton(
              onPressed: () => Navigator.pop(dialogContext, true),
              child: const Text('Borrar'),
            ),
          ],
        ),
      );
      if (confirmed == true) {
        bloc.add(NutritionPlanDeleted(planId: plan.id));
        navigator.pop();
      }
  }
}

class _EmptyPlanCard extends StatelessWidget {
  const _EmptyPlanCard({required this.plan});

  final MealPlan plan;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: theme.colorScheme.surfaceContainerLowest,
        borderRadius: BorderRadius.circular(28),
        boxShadow: [context.kc.shadow],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text('Este plan no tiene comidas', style: theme.textTheme.titleMedium),
          const SizedBox(height: 4),
          Text('Agrégalas para registrar lo que comes cada día.', style: theme.textTheme.bodySmall),
          const SizedBox(height: 12),
          ElevatedButton.icon(
            onPressed: () => _openPlanForm(context, plan: plan),
            icon: const Icon(IconsaxPlusLinear.add),
            label: const Text('Agregar comidas'),
          ),
        ],
      ),
    );
  }
}

// ── Diálogo de planes ────────────────────────────────────────────────────────

class _PlansDialog extends StatelessWidget {
  const _PlansDialog();

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return AlertDialog(
      title: const Text('Planes alimenticios'),
      content: SizedBox(
        width: double.maxFinite,
        child: BlocBuilder<NutritionBloc, NutritionState>(
          builder: (context, state) {
            return Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                if (state.allPlans.isEmpty)
                  const Text('No hay planes registrados.')
                else
                  Flexible(
                    child: ListView.builder(
                      shrinkWrap: true,
                      itemCount: state.allPlans.length,
                      itemBuilder: (context, index) {
                        final plan = state.allPlans[index];
                        final isActive = plan.id == state.activePlan?.id;
                        return ListTile(
                          contentPadding: EdgeInsets.zero,
                          leading: Container(
                            width: 40,
                            height: 40,
                            alignment: Alignment.center,
                            decoration: BoxDecoration(
                              color: isActive ? context.kc.foodWash : cs.surfaceContainerHigh,
                              borderRadius: BorderRadius.circular(14),
                            ),
                            child: Icon(
                              isActive ? IconsaxPlusBold.book_1 : IconsaxPlusLinear.book_1,
                              size: 20,
                              color: isActive ? context.kc.foodInk : cs.onSurfaceVariant,
                            ),
                          ),
                          title: Text(plan.name),
                          subtitle: Text(
                            '${plan.isActive ? 'Plan actual' : 'Plan anterior'}'
                            ' · ${DateFormat('dd/MM/yy').format((plan.periodStart ?? plan.createdAt).toLocal())}',
                          ),
                          trailing: PopupMenuButton<_PlanAction>(
                            icon: const Icon(IconsaxPlusLinear.more),
                            onSelected: (action) => _onPlanAction(context, action, plan),
                            itemBuilder: (_) => [
                              if (!isActive)
                                const PopupMenuItem(value: _PlanAction.activate, child: Text('Activar')),
                              const PopupMenuItem(value: _PlanAction.edit, child: Text('Editar')),
                              const PopupMenuItem(value: _PlanAction.delete, child: Text('Borrar')),
                            ],
                          ),
                        );
                      },
                    ),
                  ),
                const SizedBox(height: 12),
                PillButton(
                  icon: IconsaxPlusLinear.add,
                  label: 'Nuevo plan',
                  onTap: () {
                    final bloc = context.read<NutritionBloc>();
                    Navigator.pop(context);
                    _pushPlanForm(context, bloc);
                  },
                ),
              ],
            );
          },
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Cerrar'),
        ),
      ],
    );
  }
}

// ── Tiempo de comida ────────────────────────────────────────────────────────

class _MealSection extends StatelessWidget {
  final String mealType;
  final List<MealPlanOption> options;
  final DailyMealLog? log;

  const _MealSection({
    required this.mealType,
    required this.options,
    this.log,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;
    final kc = context.kc;
    final status = _statusOf(log);
    final style = _statusStyle(context, status);

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
              Tooltip(
                message: 'Cambiar ícono',
                child: Material(
                  color: kc.foodWash,
                  borderRadius: BorderRadius.circular(14),
                  child: InkWell(
                    borderRadius: BorderRadius.circular(14),
                    onTap: () => _chooseIcon(context),
                    child: SizedBox(
                      width: 44,
                      height: 44,
                      child: Center(child: _icon.build(color: kc.foodInk)),
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(mealType, style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w800)),
                    Text(
                      '${options.length} ${options.length == 1 ? 'opción' : 'opciones'}',
                      style: theme.textTheme.bodySmall,
                    ),
                  ],
                ),
              ),
              AnimatedContainer(
                duration: const Duration(milliseconds: 300),
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                decoration: ShapeDecoration(color: style.tint, shape: const StadiumBorder()),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(style.icon, size: 14, color: style.color),
                    const SizedBox(width: 4),
                    Text(style.label,
                        style: theme.textTheme.labelMedium?.copyWith(color: style.color, fontWeight: FontWeight.w800)),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          AnimatedSize(
            duration: const Duration(milliseconds: 300),
            curve: Curves.easeOutCubic,
            alignment: Alignment.topCenter,
            child: AnimatedSwitcher(
              duration: const Duration(milliseconds: 250),
              child: KeyedSubtree(
                key: ValueKey(log == null ? 'pending' : 'log-${log!.id}'),
                child: log == null ? _buildPending(context) : _buildLogged(context, status),
              ),
            ),
          ),
        ],
      ),
    );
  }

  MealIcon get _icon => MealIcon.resolve(options.firstOrNull?.mealIcon, mealType);

  Future<void> _chooseIcon(BuildContext context) async {
    final bloc = context.read<NutritionBloc>();
    final chosen = await pickMealIcon(context, mealType: mealType, current: _icon);
    if (chosen != null) bloc.add(NutritionMealIconChanged(mealType: mealType, icon: chosen.name));
  }

  Widget _buildPending(BuildContext context) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (options.isEmpty)
          Text('Sin opciones configuradas', style: theme.textTheme.bodyMedium?.copyWith(color: cs.onSurfaceVariant))
        else
          for (final opt in options)
            Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: _OptionTile(
                option: opt,
                onPhotoTap: () => _optionPhoto(context, opt),
                onTap: () {
                  HapticFeedback.selectionClick();
                  context.read<NutritionBloc>().add(
                        NutritionMealLogged(date: DateTime.now(), mealType: mealType, planOptionId: opt.id),
                      );
                },
              ),
            ),
        const SizedBox(height: 4),
        Row(
          children: [
            Expanded(
              child: PillButton(
                icon: IconsaxPlusLinear.close_circle,
                label: 'No seguí el plan',
                color: cs.error,
                onTap: () => context.read<NutritionBloc>().add(
                      NutritionOffPlanMealLogged(date: DateTime.now(), mealType: mealType, description: null),
                    ),
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: PillButton(
                icon: IconsaxPlusLinear.edit_2,
                label: 'Fuera de plan',
                color: context.kc.warning,
                onTap: () => _showOffPlanDialog(context),
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildLogged(BuildContext context, _MealStatus status) {
    final theme = Theme.of(context);
    final kc = context.kc;
    final style = _statusStyle(context, status);
    final opt = options.firstWhereOrNull((o) => o.id == log!.planOptionId);

    final Widget result = switch (status) {
      _MealStatus.plan when opt != null => Container(
          padding: const EdgeInsets.all(10),
          decoration: BoxDecoration(color: kc.foodWash, borderRadius: BorderRadius.circular(20)),
          child: Row(
            children: [
              if (opt.photoId != null)
                GestureDetector(
                  onTap: () => _optionPhoto(context, opt),
                  child: MealPhotoImage(photoId: opt.photoId!, width: 56, height: 56),
                )
              else
                Container(
                  width: 56,
                  height: 56,
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    color: theme.colorScheme.surfaceContainerLowest,
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: _icon.build(color: kc.foodInk, size: 26),
                ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('OPCIÓN ${opt.optionNumber}',
                        style: theme.textTheme.labelSmall?.copyWith(fontSize: 10, color: kc.foodInk)),
                    const SizedBox(height: 2),
                    Text(opt.description, style: theme.textTheme.bodyMedium),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              Icon(IconsaxPlusBold.tick_circle, color: theme.colorScheme.primary),
            ],
          ),
        ),
      _ => Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(color: style.tint, borderRadius: BorderRadius.circular(20)),
          child: Row(
            children: [
              Icon(style.icon, color: style.color),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  status == _MealStatus.offPlan ? log!.freeDescription! : 'No seguí el plan',
                  style: theme.textTheme.bodyMedium?.copyWith(fontWeight: FontWeight.w600),
                ),
              ),
            ],
          ),
        ),
    };

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        result,
        const SizedBox(height: 10),
        _LogPhoto(log: log!),
        const SizedBox(height: 4),
        Align(
          alignment: Alignment.centerLeft,
          child: TextButton.icon(
            onPressed: () => context.read<NutritionBloc>().add(
                  NutritionMealLogRemoved(date: DateTime.now(), mealType: mealType),
                ),
            icon: const Icon(IconsaxPlusLinear.refresh, size: 18),
            label: const Text('Cambiar selección'),
          ),
        ),
      ],
    );
  }

  Future<void> _optionPhoto(BuildContext context, MealPlanOption opt) async {
    final bloc = context.read<NutritionBloc>();
    Future<void> pick({required bool canRemove}) async {
      final choice = await pickMealPhoto(context, title: 'Cómo debería verse', canRemove: canRemove);
      switch (choice) {
        case PhotoPicked(:final bytes):
          bloc.add(NutritionOptionPhotoChanged(optionId: opt.id, photo: bytes));
        case PhotoRemoved():
          bloc.add(NutritionOptionPhotoChanged(optionId: opt.id));
        case null:
      }
    }

    final photoId = opt.photoId;
    if (photoId == null) return pick(canRemove: false);
    return showMealPhoto(
      context,
      photoId: photoId,
      title: opt.description,
      onChange: () => pick(canRemove: true),
    );
  }

  void _showOffPlanDialog(BuildContext context) {
    final controller = TextEditingController();
    Uint8List? photo;
    showDialog<void>(
      context: context,
      builder: (dialogContext) => StatefulBuilder(
        builder: (dialogContext, setDialogState) {
          final cs = Theme.of(dialogContext).colorScheme;
          return AlertDialog(
            title: const Text('Comida fuera de plan'),
            content: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  TextField(
                    controller: controller,
                    decoration: const InputDecoration(
                      labelText: '¿Qué comiste?',
                      hintText: 'Ej: Pizza con amigos',
                    ),
                    maxLines: 2,
                    autofocus: true,
                    onChanged: (_) => setDialogState(() {}),
                  ),
                  const SizedBox(height: 12),
                  if (photo != null)
                    Stack(
                      children: [
                        ClipRRect(
                          borderRadius: BorderRadius.circular(16),
                          child: Image.memory(photo!, height: 160, width: double.infinity, fit: BoxFit.cover),
                        ),
                        Positioned(
                          top: 6,
                          right: 6,
                          child: IconButton.filledTonal(
                            tooltip: 'Quitar foto',
                            icon: const Icon(IconsaxPlusLinear.close_circle),
                            onPressed: () => setDialogState(() => photo = null),
                          ),
                        ),
                      ],
                    )
                  else
                    PillButton(
                      icon: IconsaxPlusLinear.camera,
                      label: 'Agregar foto',
                      color: cs.primary,
                      onTap: () async {
                        final choice = await pickMealPhoto(dialogContext, title: 'Foto de lo que comiste');
                        if (choice is PhotoPicked) setDialogState(() => photo = choice.bytes);
                      },
                    ),
                ],
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(dialogContext),
                child: const Text('Cancelar'),
              ),
              ElevatedButton(
                onPressed: controller.text.trim().isEmpty && photo == null
                    ? null
                    : () {
                        final text = controller.text.trim();
                        context.read<NutritionBloc>().add(
                              NutritionOffPlanMealLogged(
                                date: DateTime.now(),
                                mealType: mealType,
                                // Solo con foto, igual cuenta como "fuera de plan".
                                description: text.isEmpty ? 'Comida con foto' : text,
                                photo: photo,
                              ),
                            );
                        Navigator.pop(dialogContext);
                      },
                child: const Text('Guardar'),
              ),
            ],
          );
        },
      ),
    );
  }
}

/// La foto de lo que se comió en un registro, o el botón para agregarla.
class _LogPhoto extends StatelessWidget {
  const _LogPhoto({required this.log});

  final DailyMealLog log;

  Future<void> _pick(BuildContext context, {required bool canRemove}) async {
    final bloc = context.read<NutritionBloc>();
    final choice = await pickMealPhoto(context, title: 'Foto de lo que comiste', canRemove: canRemove);
    switch (choice) {
      case PhotoPicked(:final bytes):
        bloc.add(NutritionLogPhotoChanged(logId: log.id, photo: bytes));
      case PhotoRemoved():
        bloc.add(NutritionLogPhotoChanged(logId: log.id));
      case null:
    }
  }

  @override
  Widget build(BuildContext context) {
    final photoId = log.photoId;
    if (photoId == null) {
      return PillButton(
        icon: IconsaxPlusLinear.camera,
        label: 'Agregar foto de lo que comí',
        color: Theme.of(context).colorScheme.primary,
        onTap: () => _pick(context, canRemove: false),
      );
    }
    return LayoutBuilder(
      builder: (context, constraints) => GestureDetector(
        onTap: () => showMealPhoto(
          context,
          photoId: photoId,
          title: 'Lo que comiste',
          onChange: () => _pick(context, canRemove: true),
        ),
        child: Stack(
          children: [
            MealPhotoImage(photoId: photoId, width: constraints.maxWidth, height: 190, radius: 20),
            Positioned(
              left: 10,
              bottom: 10,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                decoration: const ShapeDecoration(color: Color(0x99000000), shape: StadiumBorder()),
                child: const Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(IconsaxPlusBold.camera, size: 14, color: Colors.white),
                    SizedBox(width: 5),
                    Text('Lo que comí',
                        style: TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.w700)),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _OptionTile extends StatelessWidget {
  final MealPlanOption option;
  final VoidCallback onTap;
  final VoidCallback onPhotoTap;

  const _OptionTile({
    required this.option,
    required this.onTap,
    required this.onPhotoTap,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;
    final kc = context.kc;
    final photoId = option.photoId;
    return Material(
      color: cs.surfaceContainerLow,
      borderRadius: BorderRadius.circular(20),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(10),
          child: Row(
            children: [
              // La foto se toca aparte: verla o agregarla no registra la comida.
              GestureDetector(
                onTap: onPhotoTap,
                child: photoId != null
                    ? MealPhotoImage(photoId: photoId, width: 64, height: 64, radius: 16)
                    : Container(
                        width: 64,
                        height: 64,
                        decoration: BoxDecoration(
                          color: cs.surfaceContainerLowest,
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(color: kc.foodInk.withValues(alpha: 0.25), width: 1.2),
                        ),
                        child: Icon(IconsaxPlusLinear.gallery_add, color: kc.foodInk, size: 24),
                      ),
              ),
              const SizedBox(width: 12),
              Expanded(child: Text(option.description, style: theme.textTheme.bodyMedium)),
              const SizedBox(width: 8),
              Icon(IconsaxPlusLinear.tick_circle, color: cs.outline),
            ],
          ),
        ),
      ),
    );
  }
}
