import 'dart:math' as math;
import 'package:flutter/material.dart';

class DashboardBackgroundPainter extends CustomPainter {
  const DashboardBackgroundPainter();

  static const Color _cyan = Color(0xFF22D3EE);
  static const Color _blue = Color(0xFF3B82F6);
  static const Color _indigo = Color(0xFF6366F1);

  @override
  void paint(Canvas canvas, Size size) {
    _drawGrid(canvas, size);
    _drawCircuitLines(canvas, size);
    _drawGlowNodes(canvas, size);
    _drawLargeTechCircle(canvas, size);
    _drawCornerDecoration(canvas, size);
  }

  // ============================================================
  // GRID
  // ============================================================

  void _drawGrid(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = _blue.withOpacity(.035)
      ..strokeWidth = 1;

    const spacing = 45.0;

    for (double x = 0; x <= size.width; x += spacing) {
      canvas.drawLine(
        Offset(x, 0),
        Offset(x, size.height),
        paint,
      );
    }

    for (double y = 0; y <= size.height; y += spacing) {
      canvas.drawLine(
        Offset(0, y),
        Offset(size.width, y),
        paint,
      );
    }
  }

  // ============================================================
  // CIRCUIT LINES
  // ============================================================

  void _drawCircuitLines(Canvas canvas, Size size) {
    final linePaint = Paint()
      ..color = _cyan.withOpacity(.10)
      ..strokeWidth = 1.2
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round;

    final glowPaint = Paint()
      ..color = _cyan.withOpacity(.12)
      ..strokeWidth = 4
      ..style = PaintingStyle.stroke
      ..maskFilter = const MaskFilter.blur(
        BlurStyle.normal,
        8,
      );

    // LEFT
    for (int i = 0; i < 5; i++) {
      final y = size.height * (.18 + i * .10);

      final path = Path()
        ..moveTo(0, y)
        ..lineTo(size.width * .06, y)
        ..lineTo(
          size.width * .09,
          y + 25,
        )
        ..lineTo(
          size.width * .18,
          y + 25,
        )
        ..lineTo(
          size.width * .21,
          y + 50,
        );

      canvas.drawPath(path, glowPaint);
      canvas.drawPath(path, linePaint);
    }

    // RIGHT
    for (int i = 0; i < 5; i++) {
      final y = size.height * (.12 + i * .11);

      final path = Path()
        ..moveTo(size.width, y)
        ..lineTo(
          size.width * .94,
          y,
        )
        ..lineTo(
          size.width * .91,
          y + 25,
        )
        ..lineTo(
          size.width * .84,
          y + 25,
        )
        ..lineTo(
          size.width * .81,
          y + 50,
        );

      canvas.drawPath(path, glowPaint);
      canvas.drawPath(path, linePaint);
    }
  }

  // ============================================================
  // GLOW NODES
  // ============================================================

  void _drawGlowNodes(Canvas canvas, Size size) {
    final random = math.Random(12);

    for (int i = 0; i < 22; i++) {
      final x = random.nextDouble() * size.width;
      final y = random.nextDouble() * size.height;

      final glowPaint = Paint()
        ..color = _cyan.withOpacity(.15)
        ..maskFilter = const MaskFilter.blur(
          BlurStyle.normal,
          10,
        );

      final dotPaint = Paint()
        ..color = _cyan.withOpacity(.28);

      canvas.drawCircle(
        Offset(x, y),
        5,
        glowPaint,
      );

      canvas.drawCircle(
        Offset(x, y),
        1.2,
        dotPaint,
      );
    }
  }

  // ============================================================
  // LARGE CENTRAL TECH CIRCLE
  // ============================================================

  void _drawLargeTechCircle(
      Canvas canvas,
      Size size,
      ) {
    final center = Offset(
      size.width * .53,
      size.height * .58,
    );

    final radius = math.min(
      size.width,
      size.height,
    ) *
        .25;

    final glow = Paint()
      ..color = _blue.withOpacity(.035)
      ..style = PaintingStyle.fill
      ..maskFilter = const MaskFilter.blur(
        BlurStyle.normal,
        40,
      );

    canvas.drawCircle(
      center,
      radius,
      glow,
    );

    final circlePaint = Paint()
      ..color = _cyan.withOpacity(.055)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1;

    canvas.drawCircle(
      center,
      radius,
      circlePaint,
    );

    canvas.drawCircle(
      center,
      radius * .72,
      circlePaint,
    );

    canvas.drawCircle(
      center,
      radius * .45,
      circlePaint,
    );

    // cross hair
    canvas.drawLine(
      Offset(center.dx - radius, center.dy),
      Offset(center.dx + radius, center.dy),
      circlePaint,
    );

    canvas.drawLine(
      Offset(center.dx, center.dy - radius),
      Offset(center.dx, center.dy + radius),
      circlePaint,
    );
  }

  // ============================================================
  // CORNER DECORATION
  // ============================================================

  void _drawCornerDecoration(
      Canvas canvas,
      Size size,
      ) {
    final paint = Paint()
      ..color = _indigo.withOpacity(.12)
      ..strokeWidth = 1.2
      ..style = PaintingStyle.stroke;

    // top-left
    final topLeft = Path()
      ..moveTo(20, 90)
      ..lineTo(100, 90)
      ..lineTo(125, 115)
      ..lineTo(220, 115);

    canvas.drawPath(topLeft, paint);

    // bottom-right
    final bottomRight = Path()
      ..moveTo(size.width - 20, size.height - 90)
      ..lineTo(size.width - 100, size.height - 90)
      ..lineTo(size.width - 125, size.height - 115)
      ..lineTo(size.width - 220, size.height - 115);

    canvas.drawPath(bottomRight, paint);
  }

  @override
  bool shouldRepaint(
      covariant DashboardBackgroundPainter oldDelegate,
      ) {
    return false;
  }
}