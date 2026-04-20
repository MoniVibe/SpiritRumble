import 'dart:math' as math;

import 'package:flutter/material.dart';

class TargetingLinePainter extends CustomPainter {
  const TargetingLinePainter({required this.from, required this.to});

  final Offset from;
  final Offset to;

  @override
  void paint(Canvas canvas, Size size) {
    final midX = (from.dx + to.dx) / 2;
    final control = Offset(midX, math.min(from.dy, to.dy) - 80);
    final path = Path()
      ..moveTo(from.dx, from.dy)
      ..quadraticBezierTo(control.dx, control.dy, to.dx, to.dy);

    final glow = Paint()
      ..color = const Color(0xFF62D8A8).withValues(alpha: 0.35)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 8
      ..strokeCap = StrokeCap.round;
    final line = Paint()
      ..color = const Color(0xFF62D8A8)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2.6
      ..strokeCap = StrokeCap.round;

    canvas.drawPath(path, glow);
    canvas.drawPath(path, line);
    canvas.drawCircle(
      to,
      8,
      Paint()..color = const Color(0xFF62D8A8).withValues(alpha: 0.22),
    );
    canvas.drawCircle(to, 4, Paint()..color = const Color(0xFF62D8A8));
  }

  @override
  bool shouldRepaint(covariant TargetingLinePainter oldDelegate) {
    return oldDelegate.from != from || oldDelegate.to != to;
  }
}
