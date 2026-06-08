import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

class HomePage extends StatelessWidget {
  const HomePage({super.key});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Resumen del día', style: theme.textTheme.headlineSmall),
            const SizedBox(height: 16),
            Expanded(
              child: GridView.count(
                crossAxisCount: 2,
                mainAxisSpacing: 12,
                crossAxisSpacing: 12,
                children: [
                  _HomeCard(
                    icon: Icons.water_drop,
                    label: 'Agua',
                    color: theme.colorScheme.primary,
                    onTap: () => context.push('/water'),
                  ),
                  _HomeCard(
                    icon: Icons.nightlight_round,
                    label: 'Sueño',
                    color: theme.colorScheme.tertiary,
                    onTap: () => context.push('/sleep'),
                  ),
                  _HomeCard(
                    icon: Icons.restaurant,
                    label: 'Nutrición',
                    color: Colors.orange,
                    onTap: () => context.go('/nutrition'),
                  ),
                  _HomeCard(
                    icon: Icons.fitness_center,
                    label: 'Ejercicio',
                    color: Colors.red,
                    onTap: () => context.go('/exercise'),
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

class _HomeCard extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color color;
  final VoidCallback onTap;

  const _HomeCard({
    required this.icon,
    required this.label,
    required this.color,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(icon, size: 40, color: color),
              const SizedBox(height: 12),
              Text(
                label,
                style: Theme.of(context).textTheme.titleMedium,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
