import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

class SettingsPage extends StatelessWidget {
  const SettingsPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Ajustes')),
      body: SafeArea(
        child: ListView(
          children: [
            ListTile(
              leading: const Icon(Icons.picture_as_pdf),
              title: const Text('Reporte de salud'),
              subtitle: const Text('Generar PDF del período'),
              trailing: const Icon(Icons.chevron_right),
              onTap: () => context.push('/report'),
            ),
            const Divider(),
            ListTile(
              leading: const Icon(Icons.water_drop),
              title: const Text('Configuración de agua'),
              subtitle: const Text('Meta, unidad, tamaño'),
              trailing: const Icon(Icons.chevron_right),
              onTap: () => context.push('/water'),
            ),
            ListTile(
              leading: const Icon(Icons.fitness_center),
              title: const Text('Configuración de gym'),
              subtitle: const Text('Próximamente'),
              trailing: const Icon(Icons.chevron_right),
              onTap: () {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Próximamente')),
                );
              },
            ),
            const Divider(),
            ListTile(
              leading: const Icon(Icons.notifications_outlined),
              title: const Text('Notificaciones'),
              subtitle: const Text('Próximamente'),
              trailing: const Icon(Icons.chevron_right),
              onTap: () {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Próximamente')),
                );
              },
            ),
            ListTile(
              leading: const Icon(Icons.smart_toy_outlined),
              title: const Text('Integración IA'),
              subtitle: const Text('Próximamente'),
              trailing: const Icon(Icons.chevron_right),
              onTap: () {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Próximamente')),
                );
              },
            ),
            const Divider(),
            ListTile(
              leading: const Icon(Icons.info_outline),
              title: const Text('Acerca de Kiolog'),
              subtitle: const Text('v1.0.0'),
            ),
          ],
        ),
      ),
    );
  }
}
