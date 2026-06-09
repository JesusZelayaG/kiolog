import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:kiolog/core/dao/achievements_dao.dart';
import '../../../../core/di/injection.dart';
import '../bloc/achievements_bloc.dart';
import '../bloc/achievements_event.dart';
import '../bloc/achievements_state.dart';

class AchievementsPage extends StatelessWidget {
  const AchievementsPage({super.key});

  @override
  Widget build(BuildContext context) {
    return BlocProvider(
      create: (_) => AchievementsBloc(getIt<AchievementsDao>())
        ..add(const AchievementsLoaded()),
      child: const _AchievementsView(),
    );
  }
}

class _AchievementsView extends StatelessWidget {
  const _AchievementsView();

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Logros'),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => context.go('/'),
        ),
      ),
      body: BlocBuilder<AchievementsBloc, AchievementsState>(
        builder: (context, state) {
          if (state.status == AchievementsStatus.loading) {
            return const Center(child: CircularProgressIndicator());
          }
          if (state.status == AchievementsStatus.failure) {
            return Center(child: Text('Error: ${state.error}'));
          }

          return SafeArea(
            child: ListView(
              padding: const EdgeInsets.all(16),
              children: [
                if (state.unlocked.isNotEmpty) ...[
                  Text('Desbloqueados', style: Theme.of(context).textTheme.titleMedium),
                  const SizedBox(height: 8),
                  ...state.unlocked.map((a) => _AchievementTile(
                        achievement: a,
                        isUnlocked: true,
                      )),
                  const SizedBox(height: 24),
                ],
                Text('Por desbloquear', style: Theme.of(context).textTheme.titleMedium),
                const SizedBox(height: 8),
                ...state.locked.map((a) => _AchievementTile(
                      achievement: a,
                      isUnlocked: false,
                    )),
              ],
            ),
          );
        },
      ),
    );
  }
}

class _AchievementTile extends StatelessWidget {
  final dynamic achievement;
  final bool isUnlocked;

  const _AchievementTile({
    required this.achievement,
    required this.isUnlocked,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Card(
      color: isUnlocked
          ? theme.colorScheme.primaryContainer.withOpacity(0.4)
          : theme.colorScheme.surfaceContainerHighest.withOpacity(0.3),
      child: ListTile(
        leading: Icon(
          isUnlocked ? Icons.emoji_events : Icons.emoji_events_outlined,
          color: isUnlocked ? Colors.amber : theme.colorScheme.onSurfaceVariant,
        ),
        title: Text(achievement.title),
        subtitle: Text(achievement.description),
        trailing: isUnlocked
            ? const Icon(Icons.check_circle, color: Colors.green)
            : null,
      ),
    );
  }
}
