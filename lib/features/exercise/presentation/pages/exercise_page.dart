import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:iconsax_plus/iconsax_plus.dart';
import 'package:intl/intl.dart';
import 'package:kiolog/core/database/app_database.dart';
import 'package:kiolog/core/domain/app_module.dart';
import 'package:kiolog/core/domain/day.dart';
import 'package:kiolog/core/modules/cubit/modules_cubit.dart';
import 'package:kiolog/core/modules/cubit/modules_state.dart';
import 'package:kiolog/core/theme/app_theme.dart';
import 'package:kiolog/features/exercise/domain/reps.dart';
import 'package:kiolog/shared/widgets/entrance.dart';
import 'package:kiolog/shared/widgets/exercise_reference.dart';
import 'package:kiolog/shared/widgets/inactive_module_page.dart';
import 'package:kiolog/shared/widgets/kiolog_glyphs.dart';
import 'package:kiolog/shared/widgets/themed_page.dart';
import '../../../../core/di/injection.dart';
import '../../data/services/exercise_weight_unit_service.dart';
import '../../domain/models/independent_exercise_log.dart';
import '../../domain/repositories/exercise_repository.dart';
import '../bloc/exercise_bloc.dart';
import '../bloc/exercise_event.dart';
import '../bloc/exercise_state.dart';
import '../cubit/exercise_weight_unit_cubit.dart';
import 'exercise_config_page.dart';
import 'exercise_progress_page.dart';
import 'exercise_session_page.dart';

const _settle = Cubic(.3, .9, .25, 1);

class ExercisePage extends StatelessWidget {
  const ExercisePage({super.key});

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<ModulesCubit, ModulesState>(
      builder: (context, modulesState) {
        if (!modulesState.isEnabled(AppModule.exercise)) {
          return const InactiveModulePage(module: AppModule.exercise);
        }
        return MultiBlocProvider(
          providers: [
            BlocProvider(
              create: (_) => ExerciseBloc(getIt<ExerciseRepository>())..add(ExerciseLoaded(date: DateTime.now())),
            ),
            BlocProvider(
              create: (_) => ExerciseWeightUnitCubit(getIt<ExerciseWeightUnitService>())..init(),
            ),
          ],
          child: const _ExerciseView(),
        );
      },
    );
  }
}

/// Ícono de un tipo de cardio: Iconsax no tiene bici, correr ni nadar.
IconData _cardioIcon(String type) => switch (type.toLowerCase()) {
      'correr' => IconsaxPlusBold.activity,
      'bici' => IconsaxPlusBold.routing,
      'elíptica' || 'eliptica' => IconsaxPlusBold.repeat_circle,
      'nadar' => IconsaxPlusBold.drop,
      _ => IconsaxPlusBold.heart,
    };

String _weekdayName(int weekday) =>
    const ['', 'lunes', 'martes', 'miércoles', 'jueves', 'viernes', 'sábado', 'domingo'][weekday.clamp(1, 7)];

/// Tarjeta redondeada con la sombra del tema.
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

/// Ícono en recuadro, título y una etiqueta a la derecha.
class _CardTitle extends StatelessWidget {
  const _CardTitle({required this.icon, required this.wash, required this.title, this.trailing});

  final Widget icon;
  final Color wash;
  final String title;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) => Row(
        children: [
          Container(
            width: 40,
            height: 40,
            alignment: Alignment.center,
            decoration: BoxDecoration(color: wash, borderRadius: BorderRadius.circular(13)),
            child: icon,
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(title, style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w800)),
          ),
          if (trailing != null) trailing!,
        ],
      );
}

/// "3 / 4 días" en una píldora; con degradado al cumplir.
class _GoalPill extends StatelessWidget {
  const _GoalPill({required this.done, required this.goal});

  final int done;
  final int goal;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final met = done >= goal;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: ShapeDecoration(
        gradient: met ? context.kc.brandGradient : null,
        color: met ? null : theme.colorScheme.surfaceContainerHigh,
        shape: const StadiumBorder(),
      ),
      child: Text(
        '$done / $goal días',
        style: theme.textTheme.labelMedium?.copyWith(
          fontWeight: FontWeight.w800,
          color: met ? Colors.white : theme.colorScheme.onSurfaceVariant,
        ),
      ),
    );
  }
}

class _Bar extends StatelessWidget {
  const _Bar({required this.value, required this.color});

  final double value;
  final Color color;

  @override
  Widget build(BuildContext context) => ClipRRect(
        borderRadius: BorderRadius.circular(6),
        child: TweenAnimationBuilder<double>(
          tween: Tween(begin: 0, end: value.clamp(0.0, 1.0)),
          duration: const Duration(milliseconds: 900),
          curve: _settle,
          builder: (context, v, _) =>
              LinearProgressIndicator(value: v, minHeight: 7, color: color, backgroundColor: context.hc.ringTrack),
        ),
      );
}

class _ExerciseView extends StatefulWidget {
  const _ExerciseView();

  @override
  State<_ExerciseView> createState() => _ExerciseViewState();
}

class _ExerciseViewState extends State<_ExerciseView> {
  int? _expandedRoutineId;
  int? _selectedRoutineId; // null = la primera pendiente de la semana

  void _openSession(ExerciseSessionLog session) {
    final bloc = context.read<ExerciseBloc>();
    final weightCubit = context.read<ExerciseWeightUnitCubit>();
    Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => MultiBlocProvider(
          providers: [BlocProvider.value(value: bloc), BlocProvider.value(value: weightCubit)],
          child: ExerciseSessionPage(sessionId: session.id),
        ),
      ),
    );
  }

  void _openProgress() {
    final bloc = context.read<ExerciseBloc>();
    final weightCubit = context.read<ExerciseWeightUnitCubit>();
    Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => MultiBlocProvider(
          providers: [BlocProvider.value(value: bloc), BlocProvider.value(value: weightCubit)],
          child: const ExerciseProgressPage(),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return ThemedPage(
      child: BlocConsumer<ExerciseBloc, ExerciseState>(
        listenWhen: (prev, curr) =>
            (prev.status == ExerciseStatus.success && !prev.hasActiveSession && curr.hasActiveSession) ||
            prev.activePlan?.id != curr.activePlan?.id,
        listener: (context, state) {
          // Al cambiar de plan se vuelve a elegir el día.
          setState(() => _selectedRoutineId = null);
          // Una sesión nueva abre su pantalla.
          if (state.hasActiveSession) _openSession(state.activeSession!);
        },
        builder: (context, state) {
          if (state.status == ExerciseStatus.loading && state.activePlan == null) {
            return const Center(child: CircularProgressIndicator());
          }
          if (state.status == ExerciseStatus.failure) {
            return Center(child: Text('Error: ${state.error}'));
          }
          final header = _Header(
            planName: state.activePlan?.name,
            onProgress: _openProgress,
            onPlans: () => _showPlansDialog(context),
          );
          if (state.activePlan == null) {
            return ListView(
              padding: const EdgeInsets.fromLTRB(18, 14, 18, 24),
              children: [header, const SizedBox(height: 40), _NoPlan(onCreate: () => _showCreatePlanDialog(context))],
            );
          }
          final items = <Widget>[
            header,
            if (state.hasActiveSession)
              _ResumeCard(state: state, onOpen: () => _openSession(state.activeSession!))
            else if (state.routines.isNotEmpty)
              _todayCard(context, state),
            _WeekCard(state: state),
            _routinesCard(context, state),
            _cardioCard(context, state),
            _freeCard(context, state),
          ];
          return RefreshIndicator(
            onRefresh: () async => context.read<ExerciseBloc>().add(ExerciseLoaded(date: DateTime.now())),
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

  // ── Hoy ─────────────────────────────────────────────────────────────────

  Widget _todayCard(BuildContext context, ExerciseState state) {
    final theme = Theme.of(context);
    final hc = context.hc;
    final doneIds = state.completedRoutineSessionsThisWeek.map((s) => s.routineId).whereType<int>().toSet();
    final fallback = state.routines.firstWhere((r) => !doneIds.contains(r.id), orElse: () => state.routines.first);
    final selected = state.routines.firstWhere(
      (r) => r.id == (_selectedRoutineId ?? fallback.id),
      orElse: () => state.routines.first,
    );
    final items = state.routineItemsByRoutine[selected.id] ?? const <ExerciseRoutineItem>[];
    final doneToday = state.completedRoutineSessionsToday > 0;

    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(gradient: hc.gymCard, borderRadius: BorderRadius.circular(28)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(doneToday ? 'YA ENTRENASTE HOY · OTRA RUTINA' : '¿QUÉ HARÁS HOY?',
              style: theme.textTheme.labelSmall?.copyWith(fontSize: 11, color: hc.gymInk)),
          const SizedBox(height: 10),
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: [
                for (final routine in state.routines)
                  Padding(
                    padding: const EdgeInsets.only(right: 8),
                    child: GestureDetector(
                      onTap: () => setState(() => _selectedRoutineId = routine.id),
                      child: AnimatedContainer(
                        duration: const Duration(milliseconds: 250),
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                        decoration: ShapeDecoration(
                          color: routine.id == selected.id ? Colors.white : hc.gymChip,
                          shape: const StadiumBorder(),
                        ),
                        child: Row(
                          children: [
                            if (doneIds.contains(routine.id)) ...[
                              Icon(IconsaxPlusBold.tick_circle,
                                  size: 14, color: routine.id == selected.id ? const Color(0xFF1E7A4C) : hc.gymInk),
                              const SizedBox(width: 4),
                            ],
                            Text(
                              'Día ${routine.dayNumber}',
                              style: theme.textTheme.labelLarge?.copyWith(
                                fontWeight: FontWeight.w800,
                                color: routine.id == selected.id ? const Color(0xFF0E1424) : hc.gymInk,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
              ],
            ),
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              Container(
                width: 52,
                height: 52,
                alignment: Alignment.center,
                decoration: BoxDecoration(color: hc.gymChip, borderRadius: BorderRadius.circular(18)),
                child: KiologGlyph(KiologGlyphKind.dumbbell, size: 30, color: hc.gymInk),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(selected.routineName,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: theme.textTheme.titleLarge?.copyWith(color: Colors.white, fontWeight: FontWeight.w800)),
                    Text(
                      doneIds.contains(selected.id)
                          ? 'Ya la hiciste esta semana · ${items.length} ejercicios'
                          : '${items.length} ejercicios',
                      style: theme.textTheme.bodyMedium?.copyWith(color: hc.gymSub, fontSize: 13),
                    ),
                  ],
                ),
              ),
            ],
          ),
          if (items.isNotEmpty) ...[
            const SizedBox(height: 12),
            Text(
              items.take(4).map((i) => i.exerciseName).join(' · ') + (items.length > 4 ? ' …' : ''),
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: theme.textTheme.bodySmall?.copyWith(color: hc.gymSub),
            ),
          ],
          const SizedBox(height: 16),
          _StartButton(
            label: 'Iniciar ${selected.routineName}',
            onTap: () {
              HapticFeedback.mediumImpact();
              context.read<ExerciseBloc>().add(ExerciseSessionStarted(date: DateTime.now(), routineId: selected.id));
            },
          ),
        ],
      ),
    );
  }

  // ── Rutina ──────────────────────────────────────────────────────────────

  Widget _routinesCard(BuildContext context, ExerciseState state) {
    final theme = Theme.of(context);
    final kc = context.kc;
    final doneIds = state.completedRoutineSessionsThisWeek.map((s) => s.routineId).whereType<int>().toSet();
    return _Card(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _CardTitle(
            icon: KiologGlyph(KiologGlyphKind.dumbbell, size: 20, color: kc.gymInk),
            wash: kc.gymWash,
            title: 'Tu rutina',
            trailing: BlocBuilder<ExerciseWeightUnitCubit, String>(
              builder: (ctx, unit) => SegmentedButton<String>(
                segments: const [
                  ButtonSegment(value: 'kg', label: Text('kg')),
                  ButtonSegment(value: 'lbs', label: Text('lbs')),
                ],
                selected: {unit},
                showSelectedIcon: false,
                onSelectionChanged: (s) => ctx.read<ExerciseWeightUnitCubit>().setUnit(s.first),
                style: const ButtonStyle(
                  visualDensity: VisualDensity.compact,
                  tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                ),
              ),
            ),
          ),
          const SizedBox(height: 12),
          if (state.routines.isEmpty)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 8),
              child: Text('Sin días de rutina configurados.', style: theme.textTheme.bodyMedium),
            ),
          for (final routine in state.routines)
            _RoutineTile(
              routine: routine,
              items: state.routineItemsByRoutine[routine.id] ?? const [],
              done: doneIds.contains(routine.id),
              expanded: _expandedRoutineId == routine.id,
              onToggle: () => setState(
                () => _expandedRoutineId = _expandedRoutineId == routine.id ? null : routine.id,
              ),
              onEdit: (item) => _showExerciseDialog(context, state, item: item, routineId: routine.id),
              onDelete: (item) => _confirmDeleteItem(context, item),
              onAdd: () => _showExerciseDialog(context, state, routineId: routine.id),
            ),
          const SizedBox(height: 4),
          PillButton(
            icon: IconsaxPlusLinear.add,
            label: 'Agregar día de rutina',
            color: theme.colorScheme.primary,
            onTap: () => _showAddRoutineDialog(context, state),
          ),
        ],
      ),
    );
  }

  // ── Cardio ──────────────────────────────────────────────────────────────

  Widget _cardioCard(BuildContext context, ExerciseState state) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;
    final kc = context.kc;
    final done = state.weeklyCardioLogs.map((l) => storedDay(l.date)).toSet().length;
    return _Card(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _CardTitle(
            icon: Icon(IconsaxPlusBold.activity, size: 20, color: kc.waterInk),
            wash: kc.waterWash,
            title: 'Cardio',
            trailing: _GoalPill(done: done, goal: state.cardioDaysGoal),
          ),
          const SizedBox(height: 12),
          _Bar(value: state.cardioDaysGoal > 0 ? done / state.cardioDaysGoal : 0, color: kc.waterInk),
          const SizedBox(height: 4),
          Text('Meta: ${state.cardioMinutesGoal} min por sesión', style: theme.textTheme.bodySmall),
          for (final log in state.weeklyCardioLogs)
            Padding(
              padding: const EdgeInsets.only(top: 10),
              child: Container(
                padding: const EdgeInsets.fromLTRB(12, 8, 4, 8),
                decoration: BoxDecoration(color: cs.surfaceContainerLow, borderRadius: BorderRadius.circular(18)),
                child: Row(
                  children: [
                    Container(
                      width: 36,
                      height: 36,
                      alignment: Alignment.center,
                      decoration: BoxDecoration(color: kc.waterWash, borderRadius: BorderRadius.circular(12)),
                      child: Icon(_cardioIcon(log.cardioType), size: 18, color: kc.waterInk),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(log.cardioType, style: theme.textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w700)),
                          Text('${log.durationMinutes} min · ${_weekdayName(storedDay(log.date).weekday)}',
                              style: theme.textTheme.bodySmall),
                        ],
                      ),
                    ),
                    IconButton(
                      tooltip: 'Editar',
                      icon: Icon(IconsaxPlusLinear.edit_2, size: 18, color: cs.onSurfaceVariant),
                      onPressed: () => _showCardioDialog(context, log: log),
                    ),
                    IconButton(
                      tooltip: 'Borrar',
                      icon: Icon(IconsaxPlusLinear.trash, size: 18, color: cs.error),
                      onPressed: () => context.read<ExerciseBloc>().add(CardioDeleted(cardioId: log.id)),
                    ),
                  ],
                ),
              ),
            ),
          const SizedBox(height: 12),
          PillButton(
            icon: IconsaxPlusLinear.add,
            label: 'Registrar cardio',
            color: kc.waterInk,
            onTap: () => _showCardioDialog(context),
          ),
        ],
      ),
    );
  }

  // ── Ejercicio libre ─────────────────────────────────────────────────────

  Widget _freeCard(BuildContext context, ExerciseState state) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;
    final kc = context.kc;
    return _Card(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _CardTitle(
            icon: Icon(IconsaxPlusBold.flash, size: 20, color: kc.foodInk),
            wash: kc.foodWash,
            title: 'Ejercicio libre',
            trailing: Text('esta semana', style: theme.textTheme.bodySmall),
          ),
          BlocBuilder<ExerciseWeightUnitCubit, String>(
            builder: (ctx, unit) => Column(
              children: [
                for (final IndependentExerciseLog log in state.weeklyIndependentLogs)
                  Padding(
                    padding: const EdgeInsets.only(top: 10),
                    child: Container(
                      padding: const EdgeInsets.fromLTRB(14, 10, 4, 10),
                      decoration: BoxDecoration(color: cs.surfaceContainerLow, borderRadius: BorderRadius.circular(18)),
                      child: Row(
                        children: [
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(log.exerciseName,
                                    style: theme.textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w700)),
                                Text(
                                  '${log.sets}×${log.reps}${log.weightKg != null ? ' · ${log.weightKg} $unit' : ''}'
                                  ' · ${_weekdayName(storedDay(log.date).weekday)}',
                                  style: theme.textTheme.bodySmall,
                                ),
                              ],
                            ),
                          ),
                          IconButton(
                            tooltip: 'Borrar',
                            icon: Icon(IconsaxPlusLinear.trash, size: 18, color: cs.error),
                            onPressed: () => context
                                .read<ExerciseBloc>()
                                .add(IndependentExerciseDeleted(sessionId: log.sessionId)),
                          ),
                        ],
                      ),
                    ),
                  ),
              ],
            ),
          ),
          const SizedBox(height: 12),
          PillButton(
            icon: IconsaxPlusLinear.add,
            label: 'Registrar ejercicio libre',
            color: kc.foodInk,
            onTap: () => _showIndependentExerciseDialog(context, context.read<ExerciseWeightUnitCubit>().state),
          ),
        ],
      ),
    );
  }

  void _showPlansDialog(BuildContext context) {
    context.read<ExerciseBloc>().add(const ExercisePlanLoaded());
    showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      isScrollControlled: true,
      builder: (_) => BlocProvider.value(value: context.read<ExerciseBloc>(), child: const _PlansSheet()),
    );
  }

  void _showExerciseDialog(
    BuildContext context,
    ExerciseState state, {
    ExerciseRoutineItem? item,
    required int routineId,
  }) {
    final weightUnit = context.read<ExerciseWeightUnitCubit>().state;
    final nameCtrl = TextEditingController(text: item?.exerciseName ?? '');
    final setsCtrl =
        TextEditingController(text: item != null ? '${item.sets}' : '');
    final repsCtrl = TextEditingController(
        text: item != null ? item.repsLabel ?? '${item.reps}' : '');
    final notesCtrl = TextEditingController(text: item?.notes ?? '');
    final weightCtrl = TextEditingController(
        text: item?.weightKg != null ? '${item!.weightKg}' : '');
    final reference = ReferenceDraft(link: item?.referenceUrl, mediaId: item?.mediaId);

    showDialog(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text(item == null ? 'Agregar ejercicio' : 'Editar ejercicio'),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: nameCtrl,
                decoration: const InputDecoration(labelText: 'Nombre *'),
                autofocus: item == null,
              ),
              const SizedBox(height: 8),
              Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: setsCtrl,
                      decoration:
                          const InputDecoration(labelText: 'Series *'),
                      keyboardType: TextInputType.number,
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: TextField(
                      controller: repsCtrl,
                      decoration: const InputDecoration(
                          labelText: 'Reps *', hintText: '8 o 6-8'),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: TextField(
                      controller: weightCtrl,
                      decoration: InputDecoration(labelText: weightUnit),
                      keyboardType: const TextInputType.numberWithOptions(
                          decimal: true),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              TextField(
                controller: notesCtrl,
                decoration: const InputDecoration(labelText: 'Indicaciones'),
                minLines: 1,
                maxLines: 4,
              ),
              const SizedBox(height: 8),
              ReferenceEditor(draft: reference),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: const Text('Cancelar'),
          ),
          ElevatedButton(
            onPressed: () async {
              final name = nameCtrl.text.trim();
              final sets = int.tryParse(setsCtrl.text);
              final parsed = parseReps(repsCtrl.text);
              if (name.isEmpty || sets == null || parsed == null) return;
              final bloc = context.read<ExerciseBloc>();
              final navigator = Navigator.of(dialogContext);
              final mediaId = await reference.saveMedia();
              final (reps, repsLabel) = parsed;
              final notes = notesCtrl.text.trim().isEmpty
                  ? null
                  : notesCtrl.text.trim();
              final weight =
                  double.tryParse(weightCtrl.text.replaceAll(',', '.'));

              if (item == null) {
                bloc.add(
                      ExerciseRoutineItemAdded(
                        routineId: routineId,
                        exerciseName: name,
                        sets: sets,
                        reps: reps,
                        weightKg: weight,
                        repsLabel: repsLabel,
                        notes: notes,
                        referenceUrl: reference.url,
                        mediaId: mediaId,
                      ),
                    );
              } else {
                bloc.add(
                      ExerciseRoutineItemUpdated(
                        itemId: item.id,
                        exerciseName: name,
                        sets: sets,
                        reps: reps,
                        weightKg: weight,
                        repsLabel: (value: repsLabel),
                        notes: (value: notes),
                        referenceUrl: (value: reference.url),
                        mediaId: (value: mediaId),
                      ),
                    );
              }
              navigator.pop();
            },
            child: const Text('Guardar'),
          ),
        ],
      ),
    );
  }

  void _confirmDeleteItem(BuildContext context, ExerciseRoutineItem item) {
    showDialog<void>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('¿Eliminar ejercicio?'),
        content: Text('Se eliminará "${item.exerciseName}" de la rutina.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: const Text('Cancelar'),
          ),
          ElevatedButton(
            onPressed: () {
              context.read<ExerciseBloc>().add(ExerciseRoutineItemDeleted(
                    itemId: item.id,
                    routineId: item.routineId,
                  ));
              Navigator.pop(dialogContext);
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: Theme.of(context).colorScheme.error,
              foregroundColor: Theme.of(context).colorScheme.onError,
            ),
            child: const Text('Eliminar'),
          ),
        ],
      ),
    );
  }

  void _showCardioDialog(BuildContext context, {CardioLog? log}) {
    const types = ['Correr', 'Bici', 'Elíptica', 'Nadar', 'Otro'];
    String selectedType = log?.cardioType ?? types.first;
    final durationCtrl = TextEditingController(
        text: log != null ? '${log.durationMinutes}' : '');

    showDialog<void>(
      context: context,
      builder: (dialogContext) => StatefulBuilder(
        builder: (ctx, setInner) => AlertDialog(
          title: Text(log == null ? 'Registrar cardio' : 'Editar cardio'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              DropdownButtonFormField<String>(
                value: selectedType,
                decoration: const InputDecoration(labelText: 'Tipo'),
                items: types
                    .map((t) => DropdownMenuItem(value: t, child: Text(t)))
                    .toList(),
                onChanged: (v) {
                  if (v != null) setInner(() => selectedType = v);
                },
              ),
              const SizedBox(height: 8),
              TextField(
                controller: durationCtrl,
                decoration:
                    const InputDecoration(labelText: 'Duración (minutos) *'),
                keyboardType: TextInputType.number,
                autofocus: log == null,
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext),
              child: const Text('Cancelar'),
            ),
            ElevatedButton(
              onPressed: () {
                final duration = int.tryParse(durationCtrl.text);
                if (duration == null || duration <= 0) return;
                if (log == null) {
                  context.read<ExerciseBloc>().add(CardioLogged(
                        date: DateTime.now(),
                        cardioType: selectedType,
                        durationMinutes: duration,
                      ));
                } else {
                  context.read<ExerciseBloc>().add(CardioUpdated(
                        cardioId: log.id,
                        cardioType: selectedType,
                        durationMinutes: duration,
                      ));
                }
                Navigator.pop(dialogContext);
              },
              child: const Text('Guardar'),
            ),
          ],
        ),
      ),
    );
  }

  void _showIndependentExerciseDialog(
      BuildContext context, String weightUnit) {
    final nameCtrl = TextEditingController();
    final setsCtrl = TextEditingController();
    final repsCtrl = TextEditingController();
    final weightCtrl = TextEditingController();

    showDialog<void>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Registrar ejercicio libre'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: nameCtrl,
              decoration: const InputDecoration(labelText: 'Nombre *'),
              autofocus: true,
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: setsCtrl,
                    decoration: const InputDecoration(labelText: 'Series *'),
                    keyboardType: TextInputType.number,
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: TextField(
                    controller: repsCtrl,
                    decoration: const InputDecoration(labelText: 'Reps *'),
                    keyboardType: TextInputType.number,
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: TextField(
                    controller: weightCtrl,
                    decoration: InputDecoration(labelText: weightUnit),
                    keyboardType:
                        const TextInputType.numberWithOptions(decimal: true),
                  ),
                ),
              ],
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: const Text('Cancelar'),
          ),
          ElevatedButton(
            onPressed: () {
              final name = nameCtrl.text.trim();
              final sets = int.tryParse(setsCtrl.text);
              final reps = int.tryParse(repsCtrl.text);
              if (name.isEmpty || sets == null || reps == null) return;
              final weight =
                  double.tryParse(weightCtrl.text.replaceAll(',', '.'));
              context.read<ExerciseBloc>().add(IndependentExerciseLogged(
                    date: DateTime.now(),
                    exerciseName: name,
                    sets: sets,
                    reps: reps,
                    weightKg: weight,
                  ));
              Navigator.pop(dialogContext);
            },
            child: const Text('Guardar'),
          ),
        ],
      ),
    );
  }

  void _showAddRoutineDialog(BuildContext context, ExerciseState state) {
    final nameController = TextEditingController();
    final nextDay = state.routines.isEmpty
        ? 1
        : (state.routines
                .map((r) => r.dayNumber)
                .reduce((a, b) => a > b ? a : b) +
            1);

    showDialog(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text('Día $nextDay de rutina'),
        content: TextField(
          controller: nameController,
          decoration: const InputDecoration(
            labelText: 'Nombre de la rutina',
            hintText: 'Ej: Pecho y tríceps',
          ),
          autofocus: true,
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: const Text('Cancelar'),
          ),
          ElevatedButton(
            onPressed: () {
              if (nameController.text.isNotEmpty) {
                context.read<ExerciseBloc>().add(
                      ExerciseRoutineAdded(
                        planId: state.activePlan!.id,
                        dayNumber: nextDay,
                        routineName: nameController.text,
                      ),
                    );
              }
              Navigator.pop(dialogContext);
            },
            child: const Text('Agregar'),
          ),
        ],
      ),
    );
  }

  void _showCreatePlanDialog(BuildContext context) {
    final controller = TextEditingController();
    showDialog(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Nuevo plan de ejercicio'),
        content: TextField(
          controller: controller,
          decoration: const InputDecoration(labelText: 'Nombre del plan'),
          autofocus: true,
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: const Text('Cancelar'),
          ),
          ElevatedButton(
            onPressed: () {
              if (controller.text.isNotEmpty) {
                context.read<ExerciseBloc>().add(
                      ExercisePlanCreated(name: controller.text),
                    );
              }
              Navigator.pop(dialogContext);
            },
            child: const Text('Crear'),
          ),
        ],
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
              Text(planName == null ? 'EJERCICIO' : 'PLAN ACTIVO',
                  style: theme.textTheme.labelSmall?.copyWith(fontSize: 11, color: theme.colorScheme.primary)),
              const SizedBox(height: 2),
              Text(
                planName ?? 'Ejercicio',
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: theme.textTheme.displayMedium?.copyWith(fontSize: 23, height: 1.15),
              ),
            ],
          ),
        ),
        HeaderIconButton(icon: IconsaxPlusBold.chart_2, tooltip: 'Progreso', onTap: onProgress),
        HeaderIconButton(icon: IconsaxPlusBold.book_1, tooltip: 'Planes', onTap: onPlans),
      ],
    );
  }
}

class _NoPlan extends StatelessWidget {
  const _NoPlan({required this.onCreate});

  final VoidCallback onCreate;

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
          decoration: BoxDecoration(color: kc.gymWash, borderRadius: BorderRadius.circular(30)),
          child: KiologGlyph(KiologGlyphKind.dumbbell, size: 48, color: kc.gymInk),
        ),
        const SizedBox(height: 20),
        Text('Sin plan de ejercicio', style: theme.textTheme.headlineMedium),
        const SizedBox(height: 8),
        Text(
          'Crea un plan para empezar a registrar tus rutinas.',
          textAlign: TextAlign.center,
          style: theme.textTheme.bodyMedium?.copyWith(color: theme.colorScheme.onSurfaceVariant),
        ),
        const SizedBox(height: 24),
        ElevatedButton.icon(onPressed: onCreate, icon: const Icon(IconsaxPlusLinear.add), label: const Text('Crear plan')),
      ],
    );
  }
}

/// Botón blanco grande para iniciar, con un latido suave.
class _StartButton extends StatefulWidget {
  const _StartButton({required this.label, required this.onTap});

  final String label;
  final VoidCallback onTap;

  @override
  State<_StartButton> createState() => _StartButtonState();
}

class _StartButtonState extends State<_StartButton> with SingleTickerProviderStateMixin {
  late final _pulse = AnimationController(vsync: this, duration: const Duration(milliseconds: 2400))..repeat();

  @override
  void dispose() {
    _pulse.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final hc = context.hc;
    return AnimatedBuilder(
      animation: _pulse,
      builder: (context, child) {
        final wave = math.sin(_pulse.value * math.pi);
        return DecoratedBox(
          decoration: ShapeDecoration(
            shape: const StadiumBorder(),
            shadows: [BoxShadow(color: hc.pulse.withValues(alpha: hc.pulse.a * (1 - wave)), spreadRadius: 6 * wave)],
          ),
          child: child,
        );
      },
      child: Material(
        color: Colors.white,
        shape: const StadiumBorder(),
        child: InkWell(
          customBorder: const StadiumBorder(),
          onTap: widget.onTap,
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 18),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Icon(IconsaxPlusBold.play, color: Color(0xFF1E7A4C), size: 20),
                const SizedBox(width: 8),
                Flexible(
                  child: Text(
                    widget.label,
                    overflow: TextOverflow.ellipsis,
                    style: theme.textTheme.titleSmall?.copyWith(color: const Color(0xFF0E1424), fontWeight: FontWeight.w800),
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

/// La sesión en curso, con el tiempo que lleva.
class _ResumeCard extends StatefulWidget {
  const _ResumeCard({required this.state, required this.onOpen});

  final ExerciseState state;
  final VoidCallback onOpen;

  @override
  State<_ResumeCard> createState() => _ResumeCardState();
}

class _ResumeCardState extends State<_ResumeCard> {
  // Refresca los minutos que lleva la sesión.
  late final Timer _tick;

  @override
  void initState() {
    super.initState();
    _tick = Timer.periodic(const Duration(seconds: 30), (_) => setState(() {}));
  }

  @override
  void dispose() {
    _tick.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final hc = context.hc;
    final session = widget.state.activeSession!;
    final routine = widget.state.routineById(session.routineId);
    final started = session.gymArrivedAt.toLocal();
    final minutes = DateTime.now().difference(started).inMinutes;
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(gradient: hc.gymCard, borderRadius: BorderRadius.circular(28)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Container(
                width: 10,
                height: 10,
                decoration: const BoxDecoration(color: Color(0xFFFF6B5A), shape: BoxShape.circle),
              ),
              const SizedBox(width: 8),
              Text('SESIÓN EN CURSO', style: theme.textTheme.labelSmall?.copyWith(fontSize: 11, color: hc.gymInk)),
              const Spacer(),
              Icon(IconsaxPlusBold.timer_1, size: 16, color: hc.gymSub),
              const SizedBox(width: 4),
              Text('$minutes min', style: theme.textTheme.labelLarge?.copyWith(color: hc.gymSub)),
            ],
          ),
          const SizedBox(height: 10),
          Text(routine?.routineName ?? 'Sesión libre',
              style: theme.textTheme.titleLarge?.copyWith(color: Colors.white, fontWeight: FontWeight.w800)),
          Text('Iniciada a las ${DateFormat('HH:mm').format(started)}',
              style: theme.textTheme.bodyMedium?.copyWith(color: hc.gymSub, fontSize: 13)),
          const SizedBox(height: 16),
          _StartButton(label: 'Continuar la sesión', onTap: widget.onOpen),
        ],
      ),
    );
  }
}

/// Lunes a domingo: los días con rutina hecha, hoy, y el avance de la meta.
class _WeekCard extends StatelessWidget {
  const _WeekCard({required this.state});

  final ExerciseState state;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;
    final kc = context.kc;
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final monday = today.subtract(Duration(days: now.weekday - 1));
    const letters = ['L', 'M', 'X', 'J', 'V', 'S', 'D'];
    final routineDays = state.completedRoutineSessionsThisWeek
        .where((s) => s.gymLeftAt != null)
        .map((s) => storedDay(s.date))
        .toSet();
    final cardioDays = state.weeklyCardioLogs.map((l) => storedDay(l.date)).toSet();
    final goal = state.routineDaysGoal;

    return _Card(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Expanded(child: Text('ESTA SEMANA', style: theme.textTheme.labelSmall?.copyWith(fontSize: 11))),
              _GoalPill(done: routineDays.length, goal: goal),
            ],
          ),
          const SizedBox(height: 14),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              for (var i = 0; i < 7; i++)
                Builder(builder: (context) {
                  final day = monday.add(Duration(days: i));
                  final done = routineDays.contains(day);
                  final isToday = day == today;
                  final future = day.isAfter(today);
                  return Column(
                    children: [
                      Text(letters[i],
                          style: theme.textTheme.labelSmall?.copyWith(
                            color: isToday ? cs.primary : cs.onSurfaceVariant,
                          )),
                      const SizedBox(height: 6),
                      AnimatedContainer(
                        duration: Duration(milliseconds: 300 + i * 60),
                        width: 36,
                        height: 36,
                        alignment: Alignment.center,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          gradient: done ? kc.brandGradient : null,
                          color: done ? null : (future ? Colors.transparent : cs.surfaceContainerHigh),
                          border: isToday && !done ? Border.all(color: cs.primary, width: 2) : null,
                        ),
                        child: done
                            ? const Icon(IconsaxPlusBold.tick_circle, size: 18, color: Colors.white)
                            : Text('${day.day}',
                                style: theme.textTheme.labelMedium?.copyWith(
                                  color: future ? cs.outline : cs.onSurface,
                                  fontWeight: FontWeight.w700,
                                )),
                      ),
                      const SizedBox(height: 4),
                      Container(
                        width: 5,
                        height: 5,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: cardioDays.contains(day) ? kc.waterInk : Colors.transparent,
                        ),
                      ),
                    ],
                  );
                }),
            ],
          ),
          const SizedBox(height: 12),
          _Bar(value: goal > 0 ? routineDays.length / goal : 0, color: cs.primary),
          const SizedBox(height: 6),
          Row(
            children: [
              Expanded(child: Text('Días de rutina', style: theme.textTheme.bodySmall)),
              Container(width: 6, height: 6, decoration: BoxDecoration(color: kc.waterInk, shape: BoxShape.circle)),
              const SizedBox(width: 4),
              Text('cardio', style: theme.textTheme.bodySmall),
            ],
          ),
        ],
      ),
    );
  }
}

class _RoutineTile extends StatelessWidget {
  const _RoutineTile({
    required this.routine,
    required this.items,
    required this.done,
    required this.expanded,
    required this.onToggle,
    required this.onEdit,
    required this.onDelete,
    required this.onAdd,
  });

  final ExerciseRoutine routine;
  final List<ExerciseRoutineItem> items;
  final bool done;
  final bool expanded;
  final VoidCallback onToggle;
  final ValueChanged<ExerciseRoutineItem> onEdit;
  final ValueChanged<ExerciseRoutineItem> onDelete;
  final VoidCallback onAdd;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;
    final kc = context.kc;
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 250),
        decoration: BoxDecoration(
          color: expanded ? kc.gymWash : cs.surfaceContainerLow,
          borderRadius: BorderRadius.circular(20),
        ),
        child: Column(
          children: [
            InkWell(
              borderRadius: BorderRadius.circular(20),
              onTap: onToggle,
              child: Padding(
                padding: const EdgeInsets.all(12),
                child: Row(
                  children: [
                    Container(
                      width: 38,
                      height: 38,
                      alignment: Alignment.center,
                      decoration: BoxDecoration(
                        gradient: done ? kc.brandGradient : null,
                        color: done ? null : cs.surfaceContainerLowest,
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: done
                          ? const Icon(IconsaxPlusBold.tick_circle, size: 18, color: Colors.white)
                          : Text('${routine.dayNumber}',
                              style: theme.textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w800)),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(routine.routineName,
                              style: theme.textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w800)),
                          Text(
                            done ? 'Hecha esta semana · ${items.length} ejercicios' : '${items.length} ejercicios',
                            style: theme.textTheme.bodySmall?.copyWith(color: done ? cs.primary : null),
                          ),
                        ],
                      ),
                    ),
                    AnimatedRotation(
                      turns: expanded ? 0.5 : 0,
                      duration: const Duration(milliseconds: 250),
                      child: Icon(IconsaxPlusLinear.arrow_down_1, size: 18, color: cs.onSurfaceVariant),
                    ),
                  ],
                ),
              ),
            ),
            AnimatedSize(
              duration: const Duration(milliseconds: 250),
              curve: Curves.easeOutCubic,
              alignment: Alignment.topCenter,
              child: !expanded
                  ? const SizedBox(width: double.infinity)
                  : BlocBuilder<ExerciseWeightUnitCubit, String>(
                      builder: (ctx, unit) => Padding(
                        padding: const EdgeInsets.fromLTRB(12, 0, 12, 12),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            for (final item in items)
                              Container(
                                margin: const EdgeInsets.only(bottom: 6),
                                padding: const EdgeInsets.fromLTRB(12, 8, 0, 8),
                                decoration: BoxDecoration(
                                  color: cs.surfaceContainerLowest,
                                  borderRadius: BorderRadius.circular(14),
                                ),
                                child: Row(
                                  children: [
                                    Expanded(
                                      child: Column(
                                        crossAxisAlignment: CrossAxisAlignment.start,
                                        children: [
                                          Text(item.exerciseName,
                                              style: theme.textTheme.bodyMedium?.copyWith(fontWeight: FontWeight.w700)),
                                          Text(
                                            '${item.sets} × ${item.repsLabel ?? item.reps}'
                                            '${item.weightKg != null ? ' · ${item.weightKg} $unit' : ''}',
                                            style: theme.textTheme.bodySmall,
                                          ),
                                          if (item.notes != null)
                                            Text(item.notes!,
                                                style: theme.textTheme.bodySmall?.copyWith(fontStyle: FontStyle.italic)),
                                        ],
                                      ),
                                    ),
                                    if (item.referenceUrl != null || item.mediaId != null)
                                      IconButton(
                                        tooltip: 'Ver referencia',
                                        visualDensity: VisualDensity.compact,
                                        icon: Icon(IconsaxPlusBold.video_play, size: 18, color: cs.primary),
                                        onPressed: () => showReferenceSheet(
                                          context,
                                          item.exerciseName,
                                          url: item.referenceUrl,
                                          mediaId: item.mediaId,
                                        ),
                                      ),
                                    IconButton(
                                      tooltip: 'Editar',
                                      visualDensity: VisualDensity.compact,
                                      icon: Icon(IconsaxPlusLinear.edit_2, size: 18, color: cs.onSurfaceVariant),
                                      onPressed: () => onEdit(item),
                                    ),
                                    IconButton(
                                      tooltip: 'Eliminar',
                                      visualDensity: VisualDensity.compact,
                                      icon: Icon(IconsaxPlusLinear.trash, size: 18, color: cs.error),
                                      onPressed: () => onDelete(item),
                                    ),
                                  ],
                                ),
                              ),
                            const SizedBox(height: 4),
                            PillButton(icon: IconsaxPlusLinear.add, label: 'Agregar ejercicio', onTap: onAdd),
                          ],
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

class _PlansSheet extends StatelessWidget {
  const _PlansSheet();

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;
    final kc = context.kc;
    final f = DateFormat('d MMM yyyy', 'es');
    return SafeArea(
      child: ConstrainedBox(
        constraints: BoxConstraints(maxHeight: MediaQuery.sizeOf(context).height * 0.8),
        child: BlocBuilder<ExerciseBloc, ExerciseState>(
          builder: (context, state) {
            final plans = [...state.allPlans]..sort((a, b) {
                if (a.isActive != b.isActive) return a.isActive ? -1 : 1;
                return (b.periodStart ?? b.createdAt).compareTo(a.periodStart ?? a.createdAt);
              });
            return ListView(
              shrinkWrap: true,
              padding: const EdgeInsets.fromLTRB(18, 0, 18, 16),
              children: [
                Text('Planes de ejercicio', style: theme.textTheme.titleLarge),
                const SizedBox(height: 4),
                Text('Activa el que te dio tu entrenador.', style: theme.textTheme.bodySmall),
                const SizedBox(height: 14),
                if (plans.isEmpty) Text('No hay planes registrados.', style: theme.textTheme.bodyMedium),
                for (final plan in plans)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 10),
                    child: Container(
                      padding: const EdgeInsets.all(14),
                      decoration: BoxDecoration(
                        color: plan.isActive ? kc.gymWash : cs.surfaceContainerLow,
                        borderRadius: BorderRadius.circular(22),
                        border: Border.all(color: plan.isActive ? cs.primary.withValues(alpha: 0.5) : Colors.transparent),
                      ),
                      child: Row(
                        children: [
                          Container(
                            width: 40,
                            height: 40,
                            alignment: Alignment.center,
                            decoration: BoxDecoration(
                              color: cs.surfaceContainerLowest,
                              borderRadius: BorderRadius.circular(13),
                            ),
                            child: KiologGlyph(
                              KiologGlyphKind.dumbbell,
                              size: 20,
                              color: plan.isActive ? kc.gymInk : cs.onSurfaceVariant,
                              filled: plan.isActive,
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(plan.name, style: theme.textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w800)),
                                Text(
                                  plan.periodEnd == null
                                      ? 'Desde el ${f.format((plan.periodStart ?? plan.createdAt).toLocal())}'
                                      : '${f.format((plan.periodStart ?? plan.createdAt).toLocal())} – ${f.format(plan.periodEnd!.toLocal())}',
                                  style: theme.textTheme.bodySmall,
                                ),
                              ],
                            ),
                          ),
                          if (plan.id == state.activePlan?.id)
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                              decoration: ShapeDecoration(gradient: kc.brandGradient, shape: const StadiumBorder()),
                              child: Text('Activo',
                                  style: theme.textTheme.labelSmall?.copyWith(color: Colors.white, fontSize: 11)),
                            )
                          else
                            PillButton(
                              icon: IconsaxPlusLinear.tick_circle,
                              label: 'Activar',
                              color: cs.primary,
                              onTap: () {
                                context.read<ExerciseBloc>().add(ExercisePlanActivated(planId: plan.id));
                                Navigator.pop(context);
                              },
                            ),
                        ],
                      ),
                    ),
                  ),
                const SizedBox(height: 6),
                ElevatedButton.icon(
                  icon: const Icon(IconsaxPlusLinear.add),
                  label: const Text('Nuevo plan'),
                  onPressed: () {
                    final bloc = context.read<ExerciseBloc>();
                    Navigator.pop(context);
                    Navigator.of(context).push(
                      MaterialPageRoute<void>(
                        builder: (_) => ExerciseConfigPage(onComplete: () => bloc.add(ExerciseLoaded(date: DateTime.now()))),
                      ),
                    );
                  },
                ),
              ],
            );
          },
        ),
      ),
    );
  }
}
