import 'package:flutter/material.dart';

import '../theme/dash_theme.dart';

/// Hiệu ứng "rèm cửa" khi đổi Light/Dark — KHÔNG chụp màn hình.
///
/// (Bản trước dùng RenderRepaintBoundary.toImage(): trên Flutter web
/// CanvasKit việc chụp dùng chung GPU với màn hình → nháy 1 frame + trễ
/// lúc bấm. Bản này chỉ vẽ 2 tấm màu đặc nên rất nhẹ.)
///
/// 3 nhịp:
///   1. Rèm KHÉP từ 2 bên vào giữa (bắt đầu ngay khi bấm), màu = nền cũ.
///   2. Rèm kín: đổi theme NGẦM phía sau + màu rèm chuyển DẦN nền cũ → nền mới
///      (độ sáng đổi từ từ, không chớp). Frame rebuild nặng nằm sau rèm.
///   3. Rèm MỞ ra, lộ theme mới.
///
/// Đặt trong `MaterialApp.builder`. Gọi `ThemeCurtain.of(context)?.toggle()`.
class ThemeCurtain extends StatefulWidget {
  final Widget child;
  const ThemeCurtain({super.key, required this.child});

  static ThemeCurtainState? of(BuildContext context) =>
      context.findAncestorStateOfType<ThemeCurtainState>();

  @override
  State<ThemeCurtain> createState() => ThemeCurtainState();
}

enum _Phase { closing, morphing, opening }

class ThemeCurtainState extends State<ThemeCurtain>
    with SingleTickerProviderStateMixin {
  static const _close = Duration(milliseconds: 280);
  static const _morph = Duration(milliseconds: 220);
  static const _open = Duration(milliseconds: 340);

  late final AnimationController _ctl = AnimationController(vsync: this);

  bool _active = false;
  _Phase _phase = _Phase.closing;
  Color _from = Colors.white;
  Color _to = Colors.black;

  @override
  void dispose() {
    _ctl.dispose();
    super.dispose();
  }

  Future<void> _run(_Phase phase, Duration d) async {
    setState(() => _phase = phase);
    _ctl.duration = d;
    try {
      await _ctl.forward(from: 0).orCancel;
    } on TickerCanceled {
      // Widget bị huỷ giữa chừng — bỏ qua.
    }
  }

  Future<void> toggle() async {
    if (_active) return;
    final current = Theme.of(context).brightness;

    // Giảm chuyển động → đổi ngay.
    if (Motion.reduced(context)) {
      ThemeController.toggle(current);
      return;
    }

    _from = context.dash.bg;
    _to = ThemeController.palette.value
        .of(current == Brightness.dark ? Brightness.light : Brightness.dark)
        .bg;
    setState(() => _active = true);

    try {
      // 1. Khép rèm.
      await _run(_Phase.closing, _close);
      if (!mounted) return;

      // 2. Đổi theme sau rèm (màu đổi tức thì, không animate ngầm),
      //    đợi frame theme mới vẽ xong, rồi chuyển màu rèm.
      Motion.instant = true;
      ThemeController.toggle(current);
      await WidgetsBinding.instance.endOfFrame;
      Motion.instant = false;
      if (!mounted) return;
      await _run(_Phase.morphing, _morph);
      if (!mounted) return;

      // 3. Mở rèm.
      await _run(_Phase.opening, _open);
    } finally {
      Motion.instant = false;
      if (mounted) setState(() => _active = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Stack(
      fit: StackFit.expand,
      textDirection: TextDirection.ltr,
      children: [
        RepaintBoundary(child: widget.child),
        if (_active)
          Positioned.fill(
            // Chặn click trong lúc đổi theme.
            child: AbsorbPointer(
              child: RepaintBoundary(
                child: AnimatedBuilder(
                  animation: _ctl,
                  builder: (_, _) {
                    final v = _ctl.value;
                    final (cover, color) = switch (_phase) {
                      _Phase.closing => (
                          Curves.easeInOutCubic.transform(v),
                          _from,
                        ),
                      _Phase.morphing => (
                          1.0,
                          Color.lerp(_from, _to, Curves.easeInOut.transform(v))!,
                        ),
                      _Phase.opening => (
                          1 - Curves.easeInOutCubic.transform(v),
                          _to,
                        ),
                    };
                    return CustomPaint(painter: _CurtainPainter(cover, color));
                  },
                ),
              ),
            ),
          ),
      ],
    );
  }
}

class _CurtainPainter extends CustomPainter {
  /// 0 = rèm mở hết, 1 = khép kín.
  final double cover;
  final Color color;

  _CurtainPainter(this.cover, this.color);

  static const _pleats = 6;

  @override
  void paint(Canvas canvas, Size size) {
    if (cover <= 0) return;
    final w = size.width;
    final h = size.height;
    // +0.5 để 2 tấm chồng nhẹ ở giữa khi khép kín (không lộ khe 1px).
    final pw = (w / 2) * cover + (cover >= 1 ? .5 : 0);

    final left = Rect.fromLTWH(0, 0, pw, h);
    final right = Rect.fromLTWH(w - pw, 0, pw, h);
    final fill = Paint()..color = color;
    canvas.drawRect(left, fill);
    canvas.drawRect(right, fill);

    // Nếp vải rất nhẹ → nhìn ra "rèm" chứ không phải màn trống.
    final dark = color.computeLuminance() < .3;
    final hi = Colors.white.withValues(alpha: dark ? .025 : .35);
    final lo = Colors.black.withValues(alpha: dark ? .22 : .045);
    for (final r in [left, right]) {
      final stripe = (w / 2) / _pleats;
      // Nếp bám theo mép ngoài của tấm rèm (như vải dồn về phía thanh treo).
      final fromLeft = r.left == 0;
      for (var i = 0; i < _pleats; i++) {
        final x = fromLeft ? r.right - (i + 1) * stripe : r.left + i * stripe;
        final s = Rect.fromLTWH(x, 0, stripe, h).intersect(r);
        if (s.width <= 0) continue;
        canvas.drawRect(
          s,
          Paint()
            ..shader = LinearGradient(
              colors: [hi, Colors.transparent, lo],
              stops: const [0, .5, 1],
            ).createShader(Rect.fromLTWH(x, 0, stripe, h)),
        );
      }
    }

    // Bóng mềm ở mép trong khi rèm chưa khép kín.
    if (cover < 1) {
      const sw = 24.0;
      final a = .16 * cover;
      final l = Rect.fromLTWH(left.right, 0, sw, h);
      final rr = Rect.fromLTWH(right.left - sw, 0, sw, h);
      canvas.drawRect(
        l,
        Paint()
          ..shader = LinearGradient(
            colors: [Colors.black.withValues(alpha: a), Colors.transparent],
          ).createShader(l),
      );
      canvas.drawRect(
        rr,
        Paint()
          ..shader = LinearGradient(
            colors: [Colors.transparent, Colors.black.withValues(alpha: a)],
          ).createShader(rr),
      );
    }
  }

  @override
  bool shouldRepaint(_CurtainPainter old) =>
      old.cover != cover || old.color != color;
}
