import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';

import '../theme/dash_theme.dart';

// ============================================================
// THEME REVEAL: chụp màn hình cũ, đổi theme ngay bên dưới, rồi một
// "vụ nổ" răng cưa kiểu truyện tranh loang ra từ nút bấm để lộ theme mới.
// ============================================================

class ThemeReveal extends StatefulWidget {
  /// [instant] = true khi đang reveal: app phải đổi theme ngay, không lerp
  /// (ảnh chụp cũ đang che phía trên).
  final Widget Function(BuildContext context, ThemeMode mode, bool instant)
      builder;

  const ThemeReveal({super.key, required this.builder});

  /// [origin]: toạ độ global nơi vụ nổ bắt đầu (thường là nút gạt).
  static Future<void> toggle(BuildContext context, Offset origin) {
    final state = context.findAncestorStateOfType<_ThemeRevealState>();
    if (state == null || Motion.reduced(context)) {
      return ThemeController.toggle();
    }
    return state._run(origin, View.of(context).devicePixelRatio);
  }

  @override
  State<ThemeReveal> createState() => _ThemeRevealState();
}

class _ThemeRevealState extends State<ThemeReveal>
    with SingleTickerProviderStateMixin {
  final _boundary = GlobalKey();

  late final AnimationController _anim = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 950),
  );

  ui.Image? _shot;
  Offset _origin = Offset.zero;
  bool _toDark = true;
  bool _busy = false;

  Future<void> _run(Offset origin, double dpr) async {
    if (_busy) return;
    _busy = true;

    ui.Image? shot;
    try {
      final boundary =
          _boundary.currentContext?.findRenderObject() as RenderRepaintBoundary?;
      shot = await boundary?.toImage(pixelRatio: dpr);
    } catch (_) {}

    // Không chụp được → đổi theme bình thường (lerp màu).
    if (!mounted || shot == null) {
      shot?.dispose();
      _busy = false;
      return ThemeController.toggle();
    }

    setState(() {
      _shot = shot;
      _origin = origin;
      _toDark = ThemeController.mode.value != ThemeMode.dark;
    });
    final saved = ThemeController.toggle();
    await _anim.forward(from: 0);
    await saved;

    final old = _shot;
    if (mounted) setState(() => _shot = null);
    // Giải phóng sau frame kế tiếp, khi không còn layer nào vẽ ảnh này.
    WidgetsBinding.instance.addPostFrameCallback((_) => old?.dispose());
    _busy = false;
  }

  @override
  void dispose() {
    _anim.dispose();
    _shot?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final shot = _shot;
    return Directionality(
      textDirection: TextDirection.ltr,
      child: Stack(
        fit: StackFit.expand,
        children: [
          RepaintBoundary(
            key: _boundary,
            child: ValueListenableBuilder<ThemeMode>(
              valueListenable: ThemeController.mode,
              builder: (context, mode, _) =>
                  widget.builder(context, mode, shot != null),
            ),
          ),
          if (shot != null)
            IgnorePointer(
              child: CustomPaint(
                painter: _BurstPainter(
                  shot: shot,
                  origin: _origin,
                  t: _anim,
                  label: _toDark ? 'NIGHT SHIFT!' : 'DAY SHIFT!',
                ),
              ),
            ),
        ],
      ),
    );
  }
}

class _BurstPainter extends CustomPainter {
  final ui.Image shot;
  final Offset origin;
  final Animation<double> t;
  final String label;

  _BurstPainter({
    required this.shot,
    required this.origin,
    required this.t,
    required this.label,
  }) : super(repaint: t);

  static const _ink = Color(0xFF14121F);
  static const _hero = Color(0xFFFFD23F);
  static const _spikes = 18;

  /// Bán kính trong nhỏ nhất của răng cưa (so với đỉnh nhọn).
  static const _minRatio = .72;

  late final TextPainter _fill = _text(Paint()..color = _hero);
  late final TextPainter _shadow = _text(Paint()..color = _ink);
  late final TextPainter _stroke = _text(
    Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 7
      ..strokeJoin = StrokeJoin.round
      ..color = _ink,
  );

  TextPainter _text(Paint paint) => TextPainter(
        text: TextSpan(
          text: label,
          style: TextStyle(
            fontFamily: kComicFont,
            fontFamilyFallback: const ['Impact', 'Arial Black'],
            fontSize: 46,
            letterSpacing: 2,
            foreground: paint,
          ),
        ),
        textDirection: TextDirection.ltr,
      )..layout();

  /// Răng cưa không đều (cố định theo chỉ số) cho giống nét vẽ tay.
  Path _burst(double r, double spin) {
    final p = Path();
    for (var i = 0; i < _spikes * 2; i++) {
      final ratio = i.isEven
          ? 1 - .06 * ((i * 13) % 5) / 4
          : _minRatio + .1 * ((i * 37) % 11) / 10;
      final a = spin + i * math.pi / _spikes;
      final o = origin + Offset(math.cos(a), math.sin(a)) * r * ratio;
      if (i == 0) {
        p.moveTo(o.dx, o.dy);
      } else {
        p.lineTo(o.dx, o.dy);
      }
    }
    return p..close();
  }

  @override
  void paint(Canvas canvas, Size size) {
    final p = t.value;
    final e = Curves.easeInOutCubic.transform(p);
    final full = Offset.zero & size;

    final maxD = [
      Offset.zero,
      Offset(size.width, 0),
      Offset(0, size.height),
      Offset(size.width, size.height),
    ].map((c) => (c - origin).distance).reduce(math.max);
    // Hết animation: phần lõm nhất cũng phủ kín góc xa nhất.
    final r = maxD / _minRatio * e;
    final burst = _burst(r, p * .9);

    // Ảnh theme cũ, khoét lỗ hình vụ nổ.
    canvas.save();
    canvas.clipPath(
      Path()
        ..fillType = PathFillType.evenOdd
        ..addRect(full)
        ..addPath(burst, Offset.zero),
    );
    canvas.drawImageRect(
      shot,
      Rect.fromLTWH(0, 0, shot.width.toDouble(), shot.height.toDouble()),
      full,
      Paint()..filterQuality = FilterQuality.medium,
    );

    // Vệt tốc độ toả ra ngoài mép vụ nổ (mờ dần nửa đầu).
    if (p < .5) {
      final speed = Paint()
        ..color = _ink.withValues(alpha: 1 - p * 2)
        ..strokeWidth = 3
        ..strokeCap = StrokeCap.round;
      for (var i = 0; i < 24; i++) {
        final a = i * math.pi / 12 + .13;
        final dir = Offset(math.cos(a), math.sin(a));
        final from = r + 14 + (i % 3) * 10;
        canvas.drawLine(
          origin + dir * from,
          origin + dir * (from + 36 * (1 - p * 2)),
          speed,
        );
      }
    }
    canvas.restore();

    // Viền vụ nổ: mực – vàng – mực.
    if (r > 1) {
      canvas.drawPath(
        burst,
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = 10
          ..color = _ink,
      );
      canvas.drawPath(
        burst,
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = 4
          ..color = _hero,
      );
    }

    // Chữ "NIGHT SHIFT!" bật ra (elastic) rồi mờ dần.
    final fade = p < .65 ? 1.0 : (1 - (p - .65) / .35).clamp(0.0, 1.0);
    if (fade <= 0) return;
    final pop = Curves.elasticOut.transform((p / .4).clamp(0.0, 1.0));
    final w = _fill.width;
    final h = _fill.height;
    final at = Offset(
      (origin.dx - w - 24).clamp(16.0, math.max(16.0, size.width - w - 16)),
      (origin.dy + 30).clamp(16.0, math.max(16.0, size.height - h - 16)),
    );
    final box = (at & Size(w, h)).inflate(60);
    canvas.saveLayer(box, Paint()..color = Colors.black.withValues(alpha: fade));
    canvas.translate(at.dx + w / 2, at.dy + h / 2);
    canvas.rotate(-.07);
    canvas.scale(.3 + .7 * pop);
    canvas.translate(-w / 2, -h / 2);
    _stroke.paint(canvas, const Offset(4, 4));
    _shadow.paint(canvas, const Offset(4, 4));
    _stroke.paint(canvas, Offset.zero);
    _fill.paint(canvas, Offset.zero);
    canvas.restore();
  }

  @override
  bool shouldRepaint(covariant _BurstPainter old) =>
      old.shot != shot || old.origin != origin || old.label != label;
}

// ============================================================
// THEME TOGGLE: nút gạt mặt trời ↔ mặt trăng
// ============================================================

class ThemeToggle extends StatefulWidget {
  const ThemeToggle({super.key});

  @override
  State<ThemeToggle> createState() => _ThemeToggleState();
}

class _ThemeToggleState extends State<ThemeToggle> {
  static const _size = Size(64, 32);

  bool _hover = false;
  bool _focus = false;

  void _toggle() {
    final box = context.findRenderObject() as RenderBox?;
    final dark = ThemeController.mode.value == ThemeMode.dark;
    // Vụ nổ bắt đầu từ núm gạt (trái = mặt trời, phải = mặt trăng).
    final knobX = dark ? _size.width - _size.height / 2 : _size.height / 2;
    final origin = box == null
        ? Offset.zero
        : box.localToGlobal(Offset(knobX, _size.height / 2));
    ThemeReveal.toggle(context, origin);
  }

  @override
  Widget build(BuildContext context) {
    final c = context.dash;
    return ValueListenableBuilder<ThemeMode>(
      valueListenable: ThemeController.mode,
      builder: (context, mode, _) {
        final dark = mode == ThemeMode.dark;
        return Tooltip(
          message: dark ? 'Day shift (light theme)' : 'Night shift (dark theme)',
          child: Semantics(
            button: true,
            toggled: dark,
            label: 'Dark theme',
            child: FocusableActionDetector(
              mouseCursor: SystemMouseCursors.click,
              onShowHoverHighlight: (v) => setState(() => _hover = v),
              onShowFocusHighlight: (v) => setState(() => _focus = v),
              shortcuts: const {
                SingleActivator(LogicalKeyboardKey.enter): ActivateIntent(),
                SingleActivator(LogicalKeyboardKey.space): ActivateIntent(),
              },
              actions: {
                ActivateIntent: CallbackAction<ActivateIntent>(
                  onInvoke: (_) {
                    _toggle();
                    return null;
                  },
                ),
              },
              child: GestureDetector(
                onTap: _toggle,
                child: AnimatedScale(
                  scale: _hover ? 1.07 : 1,
                  duration: Motion.of(context, Motion.fast),
                  curve: Curves.easeOutBack,
                  child: TweenAnimationBuilder<double>(
                    tween: Tween(end: dark ? 1 : 0),
                    duration: Motion.of(
                      context,
                      const Duration(milliseconds: 700),
                    ),
                    curve: Curves.easeOutBack,
                    builder: (_, v, _) => CustomPaint(
                      size: _size,
                      painter: _TogglePainter(v, c, _focus),
                    ),
                  ),
                ),
              ),
            ),
          ),
        );
      },
    );
  }
}

class _TogglePainter extends CustomPainter {
  /// 0 = ngày, 1 = đêm (có thể vượt nhẹ do easeOutBack).
  final double v;
  final DashColors c;
  final bool focus;

  _TogglePainter(this.v, this.c, this.focus);

  Paint _ink(double w, [double alpha = 1]) => Paint()
    ..color = c.ink.withValues(alpha: alpha)
    ..style = PaintingStyle.stroke
    ..strokeWidth = w
    ..strokeCap = StrokeCap.round
    ..strokeJoin = StrokeJoin.round;

  void _sparkle(Canvas canvas, Offset o, double r, Color color) {
    canvas.drawPath(
      Path()
        ..moveTo(o.dx, o.dy - r)
        ..quadraticBezierTo(o.dx, o.dy, o.dx + r, o.dy)
        ..quadraticBezierTo(o.dx, o.dy, o.dx, o.dy + r)
        ..quadraticBezierTo(o.dx, o.dy, o.dx - r, o.dy)
        ..quadraticBezierTo(o.dx, o.dy, o.dx, o.dy - r)
        ..close(),
      Paint()..color = color,
    );
  }

  @override
  void paint(Canvas canvas, Size size) {
    final t = v.clamp(0.0, 1.0);
    final h = size.height;
    final track = RRect.fromRectAndRadius(
      Offset.zero & size,
      Radius.circular(h / 2),
    );

    // Bóng in lệch + nền trời.
    canvas.drawRRect(track.shift(const Offset(3, 3)), Paint()..color = c.ink);
    canvas.drawRRect(
      track,
      Paint()
        ..color = Color.lerp(
          const Color(0xFF8FD8FF),
          const Color(0xFF2B1D5C),
          t,
        )!,
    );

    canvas.save();
    canvas.clipRRect(track);
    // Sao (đêm) lấp lánh phía trái.
    for (final (dx, dy, r) in const [
      (10.0, 9.0, 3.2),
      (21.0, 21.0, 2.4),
      (30.0, 8.0, 2.0),
      (12.0, 24.0, 1.6),
    ]) {
      _sparkle(
        canvas,
        Offset(dx, dy),
        r * (.5 + .5 * t),
        Colors.white.withValues(alpha: t),
      );
    }
    // Mây (ngày) chìm xuống khi trời tối.
    final cy = 19 + 14 * t;
    var cloud = Path()..addOval(Rect.fromCircle(center: Offset(40, cy), radius: 5));
    for (final part in [
      Path()..addOval(Rect.fromCircle(center: Offset(47, cy - 3), radius: 6.5)),
      Path()..addOval(Rect.fromCircle(center: Offset(54, cy), radius: 5)),
      Path()..addRect(Rect.fromLTRB(40, cy, 54, cy + 5)),
    ]) {
      cloud = Path.combine(PathOperation.union, cloud, part);
    }
    canvas.drawPath(cloud, Paint()..color = Colors.white.withValues(alpha: 1 - t));
    canvas.drawPath(cloud, _ink(1.4, 1 - t));
    canvas.restore();

    canvas.drawRRect(track, _ink(2.5));

    // Núm: mặt trời (mắt mở, cười) ↔ mặt trăng (hố, ngủ gật).
    final r = h / 2 - 4.5;
    final center = Offset(ui.lerpDouble(h / 2, size.width - h / 2, v)!, h / 2);

    if (t < 1) {
      canvas.save();
      canvas.translate(center.dx, center.dy);
      canvas.rotate(v * math.pi);
      final ray = _ink(2, 1 - t);
      for (var i = 0; i < 8; i++) {
        final d = Offset(math.cos(i * math.pi / 4), math.sin(i * math.pi / 4));
        canvas.drawLine(d * (r + 2), d * (r + 2 + 3.5 * (1 - t)), ray);
      }
      canvas.restore();
    }

    canvas.drawCircle(
      center,
      r,
      Paint()..color = Color.lerp(c.hero, const Color(0xFFF6EFCF), t)!,
    );
    final crater = Paint()..color = const Color(0xFFD9CFA0).withValues(alpha: t);
    canvas.drawCircle(center + const Offset(-4.5, -4.5), 2.2, crater);
    canvas.drawCircle(center + const Offset(4.8, 4.2), 1.8, crater);

    // Mặt trời: mắt chấm + miệng cười.
    final sun = 1 - t;
    if (sun > 0) {
      final eye = Paint()..color = c.ink.withValues(alpha: sun);
      canvas.drawCircle(center + const Offset(-2.6, -1.2), 1.1, eye);
      canvas.drawCircle(center + const Offset(2.6, -1.2), 1.1, eye);
      canvas.drawArc(
        Rect.fromCircle(center: center + const Offset(0, .8), radius: 3),
        .35,
        math.pi - .7,
        false,
        _ink(1.1, sun),
      );
    }
    // Mặt trăng: mắt nhắm.
    if (t > 0) {
      for (final dx in [-2.6, 2.6]) {
        canvas.drawArc(
          Rect.fromCircle(center: center + Offset(dx, -1.2), radius: 1.6),
          .2,
          math.pi - .4,
          false,
          _ink(1, t),
        );
      }
    }
    canvas.drawCircle(center, r, _ink(2.2));

    if (focus) {
      canvas.drawRRect(
        track.inflate(3),
        Paint()
          ..color = c.accent
          ..style = PaintingStyle.stroke
          ..strokeWidth = 2,
      );
    }
  }

  @override
  bool shouldRepaint(covariant _TogglePainter old) =>
      old.v != v || old.c != c || old.focus != focus;
}
