import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:kiolog/core/dao/rewards_dao.dart';
import 'package:kiolog/core/dao/user_profile_dao.dart';
import 'package:kiolog/core/database/app_database.dart';
import 'package:kiolog/core/di/injection.dart';
import 'package:kiolog/features/reports/domain/repositories/report_repository.dart';
import 'package:kiolog/shared/widgets/vitality_card.dart';

import '../domain/xp.dart';
import 'rewards_cubit.dart';

class RewardsPage extends StatelessWidget {
  const RewardsPage({super.key});

  @override
  Widget build(BuildContext context) {
    return BlocProvider(
      create: (_) => RewardsCubit(
        getIt<ReportRepository>(),
        getIt<UserProfileDao>(),
        getIt<RewardsDao>(),
      )..load(),
      child: Scaffold(
        appBar: AppBar(title: const Text('Recompensas')),
        body: BlocBuilder<RewardsCubit, RewardsState>(
          builder: (context, state) {
            if (state.loading) return const Center(child: CircularProgressIndicator());
            return RefreshIndicator(
              onRefresh: context.read<RewardsCubit>().load,
              child: ListView(
                padding: const EdgeInsets.all(16),
                children: [
                  _LevelCard(state.level),
                  const SizedBox(height: 16),
                  _MonthCard(state),
                  const SizedBox(height: 16),
                  _TodayCard(state.today),
                ],
              ),
            );
          },
        ),
      ),
    );
  }
}

class _LevelCard extends StatelessWidget {
  const _LevelCard(this.level);

  final Level level;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;
    return VitalityCard(
      child: Row(
        children: [
          // El avatar chibi ocupará este lugar.
          Container(
            width: 64,
            height: 64,
            alignment: Alignment.center,
            decoration: BoxDecoration(shape: BoxShape.circle, color: cs.primaryContainer),
            child: Text('${level.number}',
                style: theme.textTheme.headlineMedium?.copyWith(color: cs.onPrimaryContainer)),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Nivel ${level.number}', style: theme.textTheme.titleLarge),
                const SizedBox(height: 6),
                ClipRRect(
                  borderRadius: BorderRadius.circular(4),
                  child: LinearProgressIndicator(value: level.progress, minHeight: 8),
                ),
                const SizedBox(height: 4),
                Text(
                  '${level.xp} XP · faltan ${level.next - level.xp} para el nivel ${level.number + 1}',
                  style: theme.textTheme.bodySmall?.copyWith(color: cs.onSurfaceVariant),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _MonthCard extends StatelessWidget {
  const _MonthCard(this.state);

  final RewardsState state;

  Future<void> _edit(BuildContext context, int threshold, MonthlyReward? current) async {
    final cubit = context.read<RewardsCubit>();
    final controller = TextEditingController(text: current?.title ?? '');
    final title = await showDialog<String>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text('Recompensa al $threshold %'),
        content: TextField(
          controller: controller,
          autofocus: true,
          textCapitalization: TextCapitalization.sentences,
          decoration: const InputDecoration(
            labelText: '¿Con qué te vas a premiar?',
            hintText: 'Ej: ir al cine, zapatillas nuevas',
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: const Text('Cancelar'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(dialogContext, controller.text),
            child: const Text('Guardar'),
          ),
        ],
      ),
    );
    if (title != null) await cubit.setReward(threshold, title);
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;
    final percent = state.month.percent;
    return VitalityCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('${_capitalize(state.monthLabel)}: $percent % del mes',
              style: theme.textTheme.titleMedium),
          const SizedBox(height: 4),
          Text(
            'Un mes cumplido por completo llega a 100 %. Elige con qué te premias en cada meta.',
            style: theme.textTheme.bodySmall?.copyWith(color: cs.onSurfaceVariant),
          ),
          const SizedBox(height: 12),
          ClipRRect(
            borderRadius: BorderRadius.circular(5),
            child: LinearProgressIndicator(value: state.month.fraction, minHeight: 10),
          ),
          const SizedBox(height: 8),
          for (final threshold in rewardThresholds)
            _RewardRow(
              threshold: threshold,
              reward: state.rewards[threshold],
              unlocked: percent >= threshold,
              missing: threshold - percent,
              onEdit: () => _edit(context, threshold, state.rewards[threshold]),
              onRedeem: (reward, redeemed) => context
                  .read<RewardsCubit>()
                  .setRedeemed(reward, redeemed: redeemed),
            ),
        ],
      ),
    );
  }
}

class _RewardRow extends StatelessWidget {
  const _RewardRow({
    required this.threshold,
    required this.reward,
    required this.unlocked,
    required this.missing,
    required this.onEdit,
    required this.onRedeem,
  });

  final int threshold;
  final MonthlyReward? reward;
  final bool unlocked;
  final int missing;
  final VoidCallback onEdit;
  final void Function(MonthlyReward reward, bool redeemed) onRedeem;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;
    final redeemed = reward?.redeemedAt != null;
    final status = reward == null
        ? 'Toca para elegir tu recompensa'
        : redeemed
            ? 'Te la diste. ¡Bien hecho!'
            : unlocked
                ? 'Desbloqueada: date el gusto'
                : 'Faltan $missing %';
    return ListTile(
      contentPadding: EdgeInsets.zero,
      leading: CircleAvatar(
        backgroundColor: unlocked ? cs.primary : cs.surfaceContainerHighest,
        foregroundColor: unlocked ? cs.onPrimary : cs.onSurfaceVariant,
        child: Icon(redeemed
            ? Icons.check
            : unlocked
                ? Icons.card_giftcard
                : Icons.lock_outline),
      ),
      title: Text(reward?.title ?? '$threshold %',
          style: theme.textTheme.bodyLarge?.copyWith(
            decoration: redeemed ? TextDecoration.lineThrough : null,
          )),
      subtitle: Text(reward == null ? status : '$threshold % · $status'),
      trailing: reward != null && unlocked
          ? TextButton(
              onPressed: () => onRedeem(reward!, !redeemed),
              child: Text(redeemed ? 'Deshacer' : 'Me lo di'),
            )
          : null,
      onTap: redeemed ? null : onEdit,
    );
  }
}

class _TodayCard extends StatelessWidget {
  const _TodayCard(this.items);

  final List<XpItem> items;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;
    final total = items.fold(0, (sum, i) => sum + i.points);
    return VitalityCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Hoy: +$total XP', style: theme.textTheme.titleMedium),
          const SizedBox(height: 8),
          for (final item in items)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 4),
              child: Row(
                children: [
                  Icon(item.done ? Icons.check_circle : Icons.radio_button_unchecked,
                      size: 20, color: item.done ? cs.primary : cs.onSurfaceVariant),
                  const SizedBox(width: 10),
                  Expanded(child: Text(item.label, style: theme.textTheme.bodyMedium)),
                  Text(item.points > 0 ? '+${item.points}' : '0',
                      style: theme.textTheme.bodyMedium?.copyWith(
                        color: item.points > 0 ? cs.onSurface : cs.onSurfaceVariant,
                      )),
                ],
              ),
            ),
        ],
      ),
    );
  }
}

String _capitalize(String text) =>
    text.isEmpty ? text : text[0].toUpperCase() + text.substring(1);
