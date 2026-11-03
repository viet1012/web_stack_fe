import 'dart:math';

import 'package:flutter/material.dart';

import '../theme/dash_theme.dart';

/// Nền kiểu truyện tranh: tia sáng toả từ tâm + chấm halftone to dần ra mép.
/// Vẽ tĩnh (không animation) để không tốn CPU khi dashboard mở cả ngày.
class ComicBackdrop extends StatelessWidget {
  const ComicBackdrop({super.key});

  @override
  Widget build(BuildContext context) {
    return RepaintBoundary(
      child: CustomPaint(
        size: Size.infinite,
        painter: _BackdropPainter(
          context.dash,
          Theme.of(context).brightness == Brightness.dark,
        ),
      ),
    );
  }
}

class _BackdropPainter extends CustomPainter {
  final DashColors c;
  final bool dark;

  _BackdropPainter(this.c, this.dark);

  static const _rays = 24;
  static const _step = 16.0;

  @override
  void paint(Canvas canvas, Size size) {
    final rect = Offset.zero & size;
    final center = Offset(size.width * .62, size.height * .38);

    canvas.drawRect(
      rect,
      Paint()
        ..shader = RadialGradient(
          center: const Alignment(.24, -.24),
          radius: 1.1,
          colors: dark ? [c.surface2, c.bg] : [const Color(0xFFFFFBEA), c.bg],
        ).createShader(rect),
    );

    final r = size.longestSide * 1.5;
    final rays = Path();
    for (var i = 0; i < _rays; i++) {
      final a = i * 2 * pi / _rays;
      final b = a + pi / _rays;
      rays
        ..moveTo(center.dx, center.dy)
        ..lineTo(center.dx + r * cos(a), center.dy + r * sin(a))
        ..lineTo(center.dx + r * cos(b), center.dy + r * sin(b))
        ..close();
    }
    canvas.drawPath(
      rays,
      Paint()..color = Colors.white.withValues(alpha: dark ? .025 : .4),
    );

    final maxD = [
      Offset.zero,
      Offset(size.width, 0),
      Offset(0, size.height),
      Offset(size.width, size.height),
    ].map((p) => (p - center).distance).reduce(max);

    final dots = Path();
    for (var y = _step / 2; y < size.height; y += _step) {
      for (var x = _step / 2; x < size.width; x += _step) {
        final t = ((Offset(x, y) - center).distance / maxD).clamp(0.0, 1.0);
        dots.addOval(
          Rect.fromCircle(center: Offset(x, y), radius: .4 + 2.4 * t),
        );
      }
    }
    canvas.drawPath(
      dots,
      Paint()
        ..color = dark
            ? const Color(0xFF6C4CF0).withValues(alpha: .16)
            : const Color(0xFFA8400C).withValues(alpha: .1),
    );
  }

  @override
  bool shouldRepaint(covariant _BackdropPainter old) =>
      old.c != c || old.dark != dark;
}
