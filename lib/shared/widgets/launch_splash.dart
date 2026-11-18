import 'package:flutter/material.dart';

/// Los colores del logo: el azul marino del fondo y sus verdes.
const _navy = Color(0xFF0B1123);
const _deepGreen = Color(0xFF0E3B26);
const _lime = Color(0xFF8CC63F);

/// Pantalla de bienvenida con el degradado del logo. Continúa el splash
/// del sistema (mismo azul y mismo logo) y se desvanece hacia la app.
class LaunchSplash extends StatefulWidget {
  const LaunchSplash({super.key, required this.child});

  final Widget child;

  @override
  State<LaunchSplash> createState() => _LaunchSplashState();
}

class _LaunchSplashState extends State<LaunchSplash> with SingleTickerProviderStateMixin {
  late final AnimationController _c = AnimationController(vsync: this, duration: const Duration(milliseconds: 1300))
    ..forward().whenComplete(() {
      if (mounted) setState(() => _done = true);
    });
  bool _done = false;

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (_done) return widget.child;
    // Primero aparece el degradado, luego todo se desvanece.
    final glow = CurvedAnimation(parent: _c, curve: const Interval(0, 0.45, curve: Curves.easeOut));
    final fade = CurvedAnimation(parent: _c, curve: const Interval(0.6, 1, curve: Curves.easeInCubic));
    return Stack(
      children: [
        widget.child,
        IgnorePointer(
          child: AnimatedBuilder(
            animation: _c,
            builder: (context, _) => Opacity(
              opacity: 1 - fade.value,
              child: DecoratedBox(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [_navy, Color.lerp(_navy, _deepGreen, glow.value)!],
                  ),
                ),
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    gradient: RadialGradient(
                      radius: 0.75,
                      colors: [_lime.withValues(alpha: 0.22 * glow.value), _lime.withValues(alpha: 0)],
                    ),
                  ),
                  child: Center(
                    child: Transform.scale(
                      scale: 1 + 0.08 * fade.value,
                      child: Image.asset('assets/img/splash_logo.png', width: 158, height: 158),
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }
}
