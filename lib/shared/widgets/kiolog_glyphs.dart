import 'package:flutter/material.dart';

/// Íconos que Iconsax no tiene, dibujados en su estilo: una capa al 30 % y
/// el trazo encima. Con [filled] en false solo queda el trazo.
enum KiologGlyphKind { bowl, dumbbell }

class KiologGlyph extends StatelessWidget {
  const KiologGlyph(this.kind, {super.key, this.size = 24, this.color, this.filled = true});

  final KiologGlyphKind kind;
  final double size;
  final Color? color;
  final bool filled;

  @override
  Widget build(BuildContext context) {
    final c = color ?? IconTheme.of(context).color ?? Theme.of(context).colorScheme.onSurface;
    return CustomPaint(
      size: Size.square(size),
      painter: _GlyphPainter(kind, c, filled),
    );
  }
}

class _GlyphPainter extends CustomPainter {
  _GlyphPainter(this.kind, this.color, this.filled);

  final KiologGlyphKind kind;
  final Color color;
  final bool filled;

  @override
  void paint(Canvas canvas, Size size) {
    canvas.scale(size.width / 24);
    final soft = Paint()..color = color.withValues(alpha: filled ? 0.3 : 0);
    final solid = Paint()..color = color;
    final stroke = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.8
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round;

    switch (kind) {
      case KiologGlyphKind.bowl:
        final bowl = Path()
          ..moveTo(3, 11)
          ..lineTo(21, 11)
          ..arcToPoint(const Offset(3, 11), radius: const Radius.circular(9))
          ..close();
        canvas.drawPath(bowl, soft);
        canvas.drawPath(bowl, stroke);
        canvas.drawLine(const Offset(7.5, 20.5), const Offset(16.5, 20.5), stroke);
        final steam = Path()
          ..moveTo(9.5, 7.5)
          ..cubicTo(9.5, 6.3, 10.5, 6.3, 10.5, 5)
          ..moveTo(14, 7.5)
          ..cubicTo(14, 6.3, 15, 6.3, 15, 5);
        canvas.drawPath(steam, stroke..strokeWidth = 1.6);
      case KiologGlyphKind.dumbbell:
        RRect r(double x, double y, double w, double h, double rad) =>
            RRect.fromRectAndRadius(Rect.fromLTWH(x, y, w, h), Radius.circular(rad));
        // Discos interiores, suaves; exteriores y barra, sólidos.
        final inner = [r(4.5, 6.5, 3.5, 11, 1.4), r(16, 6.5, 3.5, 11, 1.4)];
        for (final plate in inner) {
          canvas.drawRRect(plate, soft);
          canvas.drawRRect(plate, stroke..strokeWidth = 1.6);
        }
        canvas.drawRRect(r(1.5, 9, 3, 6, 1.2), solid);
        canvas.drawRRect(r(19.5, 9, 3, 6, 1.2), solid);
        canvas.drawRRect(r(8, 11, 8, 2, 1), solid);
    }
  }

  @override
  bool shouldRepaint(_GlyphPainter old) =>
      old.kind != kind || old.color != color || old.filled != filled;
}
