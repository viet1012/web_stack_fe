import 'package:flutter/material.dart';

class DevTeamBackgroundPainter extends CustomPainter {
  const DevTeamBackgroundPainter();

  static const Color _cyan = Color(0xFF00D9FF);
  static const Color _blue = Color(0xFF087BFF);

  @override
  void paint(Canvas canvas, Size size) {
    if (size.width <= 0 || size.height <= 0) return;

    _drawAmbientGlow(canvas, size);

    _drawCircuitBackground(canvas, size);

    _drawFloatingCode(canvas, size);

    _drawTeam(canvas, size);

    _drawDesk(canvas, size);

    _drawFloorGrid(canvas, size);
  }

  // ============================================================
  // AMBIENT GLOW
  // ============================================================

  void _drawAmbientGlow(
      Canvas canvas,
      Size size,
      ) {
    final glow = Paint()
      ..color = _blue.withOpacity(.08)
      ..maskFilter = const MaskFilter.blur(
        BlurStyle.normal,
        40,
      );

    canvas.drawOval(
      Rect.fromCenter(
        center: Offset(
          size.width * .50,
          size.height * .61,
        ),
        width: size.width * 1.1,
        height: size.width * .60,
      ),
      glow,
    );
  }

  // ============================================================
  // CIRCUIT BACKGROUND
  // ============================================================

  void _drawCircuitBackground(
      Canvas canvas,
      Size size,
      ) {
    final paint = Paint()
      ..color = _blue.withOpacity(.28)
      ..strokeWidth = 1
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round;

    final glow = Paint()
      ..color = _blue.withOpacity(.18)
      ..strokeWidth = 2
      ..maskFilter = const MaskFilter.blur(
        BlurStyle.normal,
        5,
      );

    final top = size.height * .24;

    // LEFT CIRCUITS
    for (int i = 0; i < 5; i++) {
      final y = top + i * 22;

      final path = Path()
        ..moveTo(0, y)
        ..lineTo(size.width * .13, y)
        ..lineTo(size.width * .22, y + 14)
        ..lineTo(size.width * (.35 + i * .015), y + 14);

      canvas.drawPath(path, paint);

      final dot = Offset(
        size.width * (.35 + i * .015),
        y + 14,
      );

      canvas.drawCircle(
        dot,
        2.2,
        glow,
      );
    }

    // RIGHT CIRCUITS
    for (int i = 0; i < 5; i++) {
      final y = top + i * 22;

      final path = Path()
        ..moveTo(size.width, y)
        ..lineTo(size.width * .87, y)
        ..lineTo(size.width * .78, y + 14)
        ..lineTo(size.width * (.65 - i * .015), y + 14);

      canvas.drawPath(path, paint);

      canvas.drawCircle(
        Offset(
          size.width * (.65 - i * .015),
          y + 14,
        ),
        2.2,
        glow,
      );
    }
  }

  // ============================================================
  // FLOATING CODE
  // ============================================================

  void _drawFloatingCode(
      Canvas canvas,
      Size size,
      ) {
    _drawText(
      canvas,
      '</>',
      Offset(
        size.width * .22,
        size.height * .22,
      ),
      13,
      _cyan.withOpacity(.45),
    );

    _drawText(
      canvas,
      '{',
      Offset(
        size.width * .48,
        size.height * .28,
      ),
      17,
      _cyan.withOpacity(.42),
    );

    _drawText(
      canvas,
      '}',
      Offset(
        size.width * .48,
        size.height * .33,
      ),
      17,
      _cyan.withOpacity(.42),
    );

    _drawText(
      canvas,
      '</>',
      Offset(
        size.width * .82,
        size.height * .29,
      ),
      13,
      _cyan.withOpacity(.42),
    );

    final codePaint = Paint()
      ..color = _blue.withOpacity(.42)
      ..strokeWidth = 1.4
      ..strokeCap = StrokeCap.round;

    final baseX = size.width * .52;
    final baseY = size.height * .29;

    for (int i = 0; i < 4; i++) {
      canvas.drawLine(
        Offset(
          baseX,
          baseY + i * 7,
        ),
        Offset(
          baseX + 28 + (i % 2) * 10,
          baseY + i * 7,
        ),
        codePaint,
      );
    }
  }
  // ============================================================
  // TEAM
  // ============================================================

  void _drawTeam(
      Canvas canvas,
      Size size,
      ) {
    final baseY =
        size.height * .63;

    final xs = [
      .14,
      .32,
      .50,
      .68,
      .86,
    ];

    for (int i = 0; i < 5; i++) {
      final isCenter = i == 2;

      _drawDeveloper(
        canvas,
        Offset(
          size.width * xs[i],
          baseY +
              (isCenter ? -8 : 0),
        ),
        scale: isCenter ? 1.35 : 1.20,
      );
    }
  }

  // ============================================================
  // SINGLE DEVELOPER
  // ============================================================

  void _drawDeveloper(
      Canvas canvas,
      Offset center, {
        required double scale,
      }) {
    final line = Paint()
      ..color = _cyan.withOpacity(.78)
      ..strokeWidth = 1.5 * scale
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round;

    final softLine = Paint()
      ..color = _blue.withOpacity(.50)
      ..strokeWidth = 1.2 * scale
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round;

    final fill = Paint()
      ..color = _cyan.withOpacity(.025)
      ..style = PaintingStyle.fill;

    final glow = Paint()
      ..color = _cyan.withOpacity(.17)
      ..maskFilter = const MaskFilter.blur(
        BlurStyle.normal,
        8,
      );

    // ----------------------------------------------------------
    // HEAD
    // ----------------------------------------------------------

    final head = Offset(
      center.dx,
      center.dy - 46 * scale,
    );

    canvas.drawCircle(
      head,
      10 * scale,
      glow,
    );

    canvas.drawOval(
      Rect.fromCenter(
        center: head,
        width: 15 * scale,
        height: 19 * scale,
      ),
      fill,
    );

    canvas.drawOval(
      Rect.fromCenter(
        center: head,
        width: 15 * scale,
        height: 19 * scale,
      ),
      line,
    );

    // Hair
    final hair = Path()
      ..moveTo(
        head.dx - 7 * scale,
        head.dy - 3 * scale,
      )
      ..quadraticBezierTo(
        head.dx,
        head.dy - 11 * scale,
        head.dx + 7 * scale,
        head.dy - 3 * scale,
      );

    canvas.drawPath(
      hair,
      line,
    );

    // Ear
    canvas.drawArc(
      Rect.fromCenter(
        center: Offset(
          head.dx - 8 * scale,
          head.dy + 1,
        ),
        width: 4 * scale,
        height: 6 * scale,
      ),
      -1.5,
      3,
      false,
      softLine,
    );

    canvas.drawArc(
      Rect.fromCenter(
        center: Offset(
          head.dx + 8 * scale,
          head.dy + 1,
        ),
        width: 4 * scale,
        height: 6 * scale,
      ),
      1.5,
      3,
      false,
      softLine,
    );

    // ----------------------------------------------------------
    // NECK
    // ----------------------------------------------------------

    canvas.drawLine(
      Offset(
        head.dx - 4 * scale,
        head.dy + 9 * scale,
      ),
      Offset(
        head.dx - 4 * scale,
        center.dy - 28 * scale,
      ),
      line,
    );

    canvas.drawLine(
      Offset(
        head.dx + 4 * scale,
        head.dy + 9 * scale,
      ),
      Offset(
        head.dx + 4 * scale,
        center.dy - 28 * scale,
      ),
      line,
    );

    // ----------------------------------------------------------
    // BODY
    // ----------------------------------------------------------

    final body = Path()
      ..moveTo(
        center.dx - 14 * scale,
        center.dy - 28 * scale,
      )
      ..quadraticBezierTo(
        center.dx,
        center.dy - 34 * scale,
        center.dx + 14 * scale,
        center.dy - 28 * scale,
      )
      ..lineTo(
        center.dx + 19 * scale,
        center.dy + 3 * scale,
      )
      ..lineTo(
        center.dx - 19 * scale,
        center.dy + 3 * scale,
      )
      ..close();

    canvas.drawPath(
      body,
      fill,
    );

    canvas.drawPath(
      body,
      line,
    );

    // Shoulders
    canvas.drawLine(
      Offset(
        center.dx - 14 * scale,
        center.dy - 25 * scale,
      ),
      Offset(
        center.dx - 22 * scale,
        center.dy - 6 * scale,
      ),
      line,
    );

    canvas.drawLine(
      Offset(
        center.dx + 14 * scale,
        center.dy - 25 * scale,
      ),
      Offset(
        center.dx + 22 * scale,
        center.dy - 6 * scale,
      ),
      line,
    );

    // ----------------------------------------------------------
    // LAPTOP
    // ----------------------------------------------------------

    final laptopRect =
    RRect.fromRectAndRadius(
      Rect.fromCenter(
        center: Offset(
          center.dx,
          center.dy + 9 * scale,
        ),
        width: 33 * scale,
        height: 21 * scale,
      ),
      Radius.circular(
        2.5 * scale,
      ),
    );

    canvas.drawRRect(
      laptopRect,
      fill,
    );

    canvas.drawRRect(
      laptopRect,
      line,
    );

    // Laptop logo
    canvas.drawCircle(
      Offset(
        center.dx,
        center.dy + 9 * scale,
      ),
      2.4 * scale,
      line,
    );

    // Laptop base
    canvas.drawLine(
      Offset(
        center.dx - 19 * scale,
        center.dy + 21 * scale,
      ),
      Offset(
        center.dx + 19 * scale,
        center.dy + 21 * scale,
      ),
      line,
    );

    // ----------------------------------------------------------
    // HANDS
    // ----------------------------------------------------------

    canvas.drawLine(
      Offset(
        center.dx - 18 * scale,
        center.dy - 3 * scale,
      ),
      Offset(
        center.dx - 13 * scale,
        center.dy + 20 * scale,
      ),
      softLine,
    );

    canvas.drawLine(
      Offset(
        center.dx + 18 * scale,
        center.dy - 3 * scale,
      ),
      Offset(
        center.dx + 13 * scale,
        center.dy + 20 * scale,
      ),
      softLine,
    );

    // ----------------------------------------------------------
    // CHAIR
    // ----------------------------------------------------------

    canvas.drawArc(
      Rect.fromCenter(
        center: Offset(
          center.dx,
          center.dy - 5 * scale,
        ),
        width: 42 * scale,
        height: 50 * scale,
      ),
      3.35,
      2.72,
      false,
      softLine,
    );
  }

  // ============================================================
  // LONG DESK
  // ============================================================

  void _drawDesk(
      Canvas canvas,
      Size size,
      ) {
    final y =
        size.height * .675;

    final line = Paint()
      ..color = _cyan.withOpacity(.68)
      ..strokeWidth = 1.4;

    final glow = Paint()
      ..color = _blue.withOpacity(.23)
      ..strokeWidth = 3
      ..maskFilter = const MaskFilter.blur(
        BlurStyle.normal,
        6,
      );

    canvas.drawLine(
      Offset(
        size.width * .03,
        y,
      ),
      Offset(
        size.width * .97,
        y,
      ),
      glow,
    );

    canvas.drawLine(
      Offset(
        size.width * .03,
        y,
      ),
      Offset(
        size.width * .97,
        y,
      ),
      line,
    );

    // Desk front
    canvas.drawLine(
      Offset(
        size.width * .07,
        y + 8,
      ),
      Offset(
        size.width * .93,
        y + 8,
      ),
      line,
    );

    // cups
    _drawCup(
      canvas,
      Offset(
        size.width * .07,
        y - 9,
      ),
    );

    _drawCup(
      canvas,
      Offset(
        size.width * .93,
        y - 9,
      ),
    );

    // plant giữa
    _drawPlant(
      canvas,
      Offset(
        size.width * .56,
        y - 7,
      ),
    );

    // status dots
    for (int i = 0; i < 4; i++) {
      canvas.drawCircle(
        Offset(
          size.width * .45 +
              i * 9,
          y + 24,
        ),
        1.8,
        Paint()
          ..color =
          _blue.withOpacity(.75),
      );
    }
  }

  // ============================================================
  // CUP
  // ============================================================

  void _drawCup(
      Canvas canvas,
      Offset p,
      ) {
    final paint = Paint()
      ..color = _cyan.withOpacity(.65)
      ..strokeWidth = 1
      ..style = PaintingStyle.stroke;

    canvas.drawRect(
      Rect.fromLTWH(
        p.dx - 4,
        p.dy,
        8,
        10,
      ),
      paint,
    );

    canvas.drawArc(
      Rect.fromCenter(
        center: Offset(
          p.dx + 5,
          p.dy + 5,
        ),
        width: 5,
        height: 6,
      ),
      -1.4,
      2.8,
      false,
      paint,
    );
  }

  // ============================================================
  // PLANT
  // ============================================================

  void _drawPlant(
      Canvas canvas,
      Offset p,
      ) {
    final paint = Paint()
      ..color = _cyan.withOpacity(.62)
      ..strokeWidth = 1
      ..style = PaintingStyle.stroke;

    canvas.drawRect(
      Rect.fromCenter(
        center: Offset(
          p.dx,
          p.dy + 8,
        ),
        width: 9,
        height: 10,
      ),
      paint,
    );

    canvas.drawLine(
      Offset(
        p.dx,
        p.dy + 3,
      ),
      Offset(
        p.dx,
        p.dy - 9,
      ),
      paint,
    );

    canvas.drawLine(
      Offset(
        p.dx,
        p.dy - 3,
      ),
      Offset(
        p.dx - 6,
        p.dy - 9,
      ),
      paint,
    );

    canvas.drawLine(
      Offset(
        p.dx,
        p.dy - 2,
      ),
      Offset(
        p.dx + 6,
        p.dy - 10,
      ),
      paint,
    );
  }

  // ============================================================
  // PERSPECTIVE FLOOR GRID
  // ============================================================

  void _drawFloorGrid(
      Canvas canvas,
      Size size,
      ) {
    final horizonY =
        size.height * .72;

    final bottomY =
        size.height * .92;

    final paint = Paint()
      ..color = _blue.withOpacity(.24)
      ..strokeWidth = .8;

    final centerX =
        size.width / 2;

    // radial perspective lines
    for (int i = -6; i <= 6; i++) {
      canvas.drawLine(
        Offset(
          centerX,
          horizonY,
        ),
        Offset(
          centerX +
              i *
                  size.width *
                  .14,
          bottomY,
        ),
        paint,
      );
    }

    // horizontal perspective
    for (int i = 1; i <= 7; i++) {
      final t =
          i / 7;

      final eased =
          t * t;

      final y =
          horizonY +
              (bottomY -
                  horizonY) *
                  eased;

      canvas.drawLine(
        Offset(
          0,
          y,
        ),
        Offset(
          size.width,
          y,
        ),
        paint,
      );
    }
  }

  // ============================================================
  // TEXT
  // ============================================================

  void _drawText(
      Canvas canvas,
      String text,
      Offset position,
      double fontSize,
      Color color,
      ) {
    final textPainter = TextPainter(
      text: TextSpan(
        text: text,
        style: TextStyle(
          color: color,
          fontSize: fontSize,
          fontWeight: FontWeight.w600,
        ),
      ),
      textDirection: TextDirection.ltr,
    );

    textPainter.layout();

    textPainter.paint(
      canvas,
      position,
    );
  }

  @override
  bool shouldRepaint(
      covariant DevTeamBackgroundPainter oldDelegate,
      ) {
    return false;
  }
}