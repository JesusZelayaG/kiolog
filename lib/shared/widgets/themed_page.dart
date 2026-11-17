import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:kiolog/core/theme/app_theme.dart';

/// Página de pestaña al estilo del Home: sin barra superior, con las manchas
/// de color del tema detrás y la barra de estado transparente.
class ThemedPage extends StatelessWidget {
  const ThemedPage({super.key, required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    final hc = context.hc;
    final dark = Theme.of(context).brightness == Brightness.dark;
    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: (dark ? SystemUiOverlayStyle.light : SystemUiOverlayStyle.dark)
          .copyWith(statusBarColor: Colors.transparent),
      child: Scaffold(
        body: Stack(
          children: [
            Positioned(top: -120, right: -90, child: _Blob(size: 320, color: hc.blobs[0])),
            Positioned(top: 260, left: -140, child: _Blob(size: 300, color: hc.blobs[1])),
            SafeArea(bottom: false, child: child),
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
            gradient: RadialGradient(colors: [color, color.withValues(alpha: 0)], stops: const [0, 0.7]),
          ),
        ),
      );
}

/// Botón cuadrado redondeado de los encabezados, como el del calendario.
class HeaderIconButton extends StatelessWidget {
  const HeaderIconButton({super.key, required this.icon, required this.tooltip, required this.onTap});

  final IconData icon;
  final String tooltip;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.only(left: 6),
      child: Material(
        color: cs.surfaceContainerLowest,
        borderRadius: BorderRadius.circular(16),
        child: InkWell(
          borderRadius: BorderRadius.circular(16),
          onTap: onTap,
          child: Tooltip(
            message: tooltip,
            child: SizedBox(width: 44, height: 44, child: Icon(icon, color: cs.primary, size: 21)),
          ),
        ),
      ),
    );
  }
}

/// Botón en forma de píldora, tenue: acciones secundarias de una tarjeta.
class PillButton extends StatelessWidget {
  const PillButton({super.key, required this.icon, required this.label, required this.onTap, this.color});

  final IconData icon;
  final String label;
  final VoidCallback onTap;

  /// Color del ícono y el texto; por defecto, el del texto.
  final Color? color;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final ink = color ?? theme.colorScheme.onSurface;
    return Material(
      color: theme.colorScheme.surfaceContainerHigh,
      shape: const StadiumBorder(),
      child: InkWell(
        customBorder: const StadiumBorder(),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 11),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(icon, size: 18, color: ink),
              const SizedBox(width: 8),
              Flexible(
                child: Text(
                  label,
                  overflow: TextOverflow.ellipsis,
                  style: theme.textTheme.labelLarge?.copyWith(color: ink, fontWeight: FontWeight.w700),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
