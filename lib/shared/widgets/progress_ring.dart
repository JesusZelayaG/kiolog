import 'dart:math' as math;

import 'package:flutter/material.dart';

/// Un anillo con degradado, de arriba en sentido horario.
class GradientRing extends CustomPainter {
  GradientRing({required this.progress, required this.gradient, required this.track, required this.width});

  final double progress;
  final Gradient gradient;
  final Color track;
  final double width;

  @override
  void paint(Canvas canvas, Size size) {
    final center = size.center(Offset.zero);
    final radius = size.shortestSide / 2 - width / 2;
    final rect = Rect.fromCircle(center: center, radius: radius);
    final stroke = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = width
      ..strokeCap = StrokeCap.round;
    canvas.drawCircle(center, radius, stroke..color = track);
    if (progress <= 0) return;
    stroke.shader = SweepGradient(
      colors: gradient.colors,
      transform: const GradientRotation(-math.pi / 2),
    ).createShader(rect);
    canvas.drawArc(rect, -math.pi / 2, 2 * math.pi * progress, false, stroke);
  }

  @override
  bool shouldRepaint(GradientRing old) =>
      old.progress != progress || old.gradient != gradient || old.track != track;
}
