import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../theme/dash_theme.dart';

@immutable
class DeptHealth {
  final String name;
  final int total;

  /// online + login required (cùng định nghĩa với header "X/Y online").
  final int online;
  final int offline;
  final int checking;
  final int unknown;

  const DeptHealth({
    required this.name,
    required this.total,
    required this.online,
    required this.offline,
    required this.checking,
    required this.unknown,
  });

  @override
  bool operator ==(Object other) =>
      other is DeptHealth &&
      other.name == name &&
      other.total == total &&
      other.online == online &&
      other.offline == offline &&
      other.checking == checking &&
      other.unknown == unknown;

  @override
  int get hashCode =>
      Object.hash(name, total, online, offline, checking, unknown);
}

enum _Dot { ok, bad, warn, none }

/// "5 IT members": 5 người ngồi chung 1 bàn dài, mỗi màn hình hiện
/// UI nhỏ + chấm trạng thái của nhóm phòng ban mình phụ trách.
/// Hover → tooltip, click → lọc phòng ban đó.
class TeamArt extends StatefulWidget {
  /// Không gồm "ALL".
  final List<DeptHealth> depts;
  final int online;
  final int total;
  final String selected;
  final ValueChanged<String> onSelect;

  const TeamArt({
    super.key,
    required this.depts,
    required this.online,
    required this.total,
    required this.selected,
    required this.onSelect,
  });

  @override
  State<TeamArt> createState() => _TeamArtState();
}

class _TeamArtState extends State<TeamArt> with SingleTickerProviderStateMixin {
  static const members = 5;
  static const middle = 2;

  late final AnimationController _c = AnimationController(
    vsync: this,
    duration: const Duration(seconds: 4),
  );

  int? _hover;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (Motion.reduced(context)) {
      _c.stop();
      _c.value = 0;
    } else if (!_c.isAnimating) {
      _c.repeat();
    }
  }

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  /// Chia phòng ban vòng tròn cho 5 người; IT ngồi giữa.
  List<List<DeptHealth>> _groups() {
    final groups = List.generate(members, (_) => <DeptHealth>[]);
    for (var i = 0; i < widget.depts.length; i++) {
      groups[i % members].add(widget.depts[i]);
    }
    final it = groups.indexWhere(
      (g) => g.any((d) => d.name.toUpperCase() == 'IT'),
    );
    if (it > 0 && it != middle) {
      final tmp = groups[middle];
      groups[middle] = groups[it];
      groups[it] = tmp;
    }
    return groups;
  }

  _Dot _dotOf(List<DeptHealth> g) {
    if (g.isEmpty || g.every((d) => d.total == 0)) return _Dot.none;
    if (g.any((d) => d.offline > 0)) return _Dot.bad;
    if (g.any((d) => d.checking > 0)) return _Dot.warn;
    if (g.every((d) => d.online == 0)) return _Dot.none; // toàn unknown → xám
    return _Dot.ok;
  }

  String _tooltip(int i, List<DeptHealth> g) {
    final who = i == middle ? 'Team lead' : 'Member ${i + 1}';
    if (g.isEmpty) return '$who · no department';
    final lines = g.map((d) {
      final extra = d.offline > 0 ? ' · ${d.offline} offline' : '';
      return '${d.name}: ${d.online}/${d.total} online$extra';
    });
    return '$who\n${lines.join('\n')}\nClick to filter ${g.first.name}';
  }

  @override
  Widget build(BuildContext context) {
    final c = context.dash;
    final groups = _groups();
    final dots = groups.map(_dotOf).toList();
    final ratio = widget.total == 0 ? 0.0 : widget.online / widget.total;
    final selectedIdx = groups.indexWhere(
      (g) => g.any((d) => d.name == widget.selected),
    );

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Expanded(
          child: Stack(
            fit: StackFit.expand,
            children: [
              RepaintBoundary(
                child: CustomPaint(
                  painter: _TeamPainter(
                    t: _c,
                    dots: dots,
                    hover: _hover,
                    selected: selectedIdx < 0 ? null : selectedIdx,
                    c: c,
                  ),
                ),
              ),
              // Vùng hover/click cho từng người.
              Row(
                children: [
                  for (var i = 0; i < members; i++)
                    Expanded(
                      flex: i == middle ? 12 : 10,
                      child: Tooltip(
                        message: _tooltip(i, groups[i]),
                        child: MouseRegion(
                          cursor: groups[i].isEmpty
                              ? SystemMouseCursors.basic
                              : SystemMouseCursors.click,
                          onEnter: (_) => setState(() => _hover = i),
                          onExit: (_) => setState(() => _hover = null),
                          child: GestureDetector(
                            behavior: HitTestBehavior.opaque,
                            onTap: groups[i].isEmpty
                                ? null
                                : () => widget.onSelect(groups[i].first.name),
                          ),
                        ),
                      ),
                    ),
                ],
              ),
            ],
          ),
        ),
        const SizedBox(height: 8),
        Row(
          children: [
            Text(
              '${widget.online}/${widget.total}',
              style: TextStyle(
                color: c.text,
                fontSize: 13,
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(width: 4),
            Text('online', style: TextStyle(color: c.muted, fontSize: 12)),
            const Spacer(),
            Text(
              '${(ratio * 100).round()}%',
              style: TextStyle(color: c.muted, fontSize: 11.5),
            ),
          ],
        ),
        const SizedBox(height: 6),
        ClipRRect(
          borderRadius: BorderRadius.circular(99),
          child: SizedBox(
            height: 6,
            child: Stack(
              fit: StackFit.expand,
              children: [
                ColoredBox(color: c.surface2),
                TweenAnimationBuilder<double>(
                  tween: Tween(end: ratio),
                  duration: Motion.of(context, const Duration(milliseconds: 400)),
                  curve: Motion.curve,
                  builder: (_, v, _) => FractionallySizedBox(
                    alignment: Alignment.centerLeft,
                    widthFactor: v.clamp(0, 1),
                    child: DecoratedBox(
                      decoration: BoxDecoration(
                        gradient: LinearGradient(colors: [c.accent, c.cyan]),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

class _TeamPainter extends CustomPainter {
  final Animation<double> t;
  final List<_Dot> dots;
  final int? hover;
  final int? selected;
  final DashColors c;

  _TeamPainter({
    required this.t,
    required this.dots,
    required this.hover,
    required this.selected,
    required this.c,
  }) : super(repaint: t);

  Color _dotColor(_Dot d) => switch (d) {
        _Dot.ok => c.ok,
        _Dot.bad => c.bad,
        _Dot.warn => c.warn,
        _Dot.none => c.muted,
      };

  @override
  void paint(Canvas canvas, Size size) {
    final w = size.width;
    final h = size.height;
    final time = t.value;

    // Tỉ lệ slot khớp flex 10/10/12/10/10 của vùng hit-test.
    const flex = [10.0, 10.0, 12.0, 10.0, 10.0];
    final unit = w / flex.reduce((a, b) => a + b);
    final base = math.min(unit * 10 / 40, h / 110);

    final deskY = h * .62;
    final stroke = 1.6 * base;

    Paint line(Color col, [double width = 1]) => Paint()
      ..color = col
      ..style = PaintingStyle.stroke
      ..strokeWidth = stroke * width
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round;

    Paint fill(Color col, double a) => Paint()..color = col.withValues(alpha: a);

    // Bàn dài
    final desk = RRect.fromRectAndRadius(
      Rect.fromLTWH(w * .02, deskY, w * .96, 7 * base),
      Radius.circular(4 * base),
    );
    canvas.drawRRect(desk, fill(c.accent, .14));
    canvas.drawRRect(desk, line(c.accent.withValues(alpha: .55)));
    // Chân bàn
    for (final x in [w * .07, w * .93]) {
      canvas.drawLine(
        Offset(x, deskY + 7 * base),
        Offset(x, h * .98),
        line(c.accent.withValues(alpha: .35)),
      );
    }

    var left = 0.0;
    for (var i = 0; i < 5; i++) {
      final slotW = flex[i] * unit;
      final cx = left + slotW / 2;
      left += slotW;

      final lead = i == 2;
      final s = base * (lead ? 1.18 : 1.0);
      final lifted = hover == i ? -2.0 * base : 0.0;
      final isSel = selected == i;
      final body = lead ? c.cyan : c.accent;

      // ---------- MONITOR ----------
      final mw = 30 * s;
      final mh = 21 * s;
      final mTop = deskY - mh - 7 * s + lifted;
      final screen = RRect.fromRectAndRadius(
        Rect.fromLTWH(cx - mw / 2, mTop, mw, mh),
        Radius.circular(3 * s),
      );

      // Chân màn hình
      canvas.drawLine(
        Offset(cx, mTop + mh),
        Offset(cx, deskY),
        line(c.muted.withValues(alpha: .7)),
      );
      canvas.drawLine(
        Offset(cx - 5 * s, deskY),
        Offset(cx + 5 * s, deskY),
        line(c.muted.withValues(alpha: .7)),
      );

      canvas.drawRRect(screen, Paint()..color = c.surface2);
      canvas.drawRRect(screen, fill(body, isSel ? .22 : .1));
      canvas.drawRRect(
        screen,
        line(isSel ? body : body.withValues(alpha: .7), isSel ? 1.2 : 1),
      );

      // UI nhỏ trên màn hình
      final inner = screen.outerRect.deflate(3.5 * s);
      final ui = fill(body, .55);
      canvas.drawRRect(
        RRect.fromRectAndRadius(
          Rect.fromLTWH(inner.left, inner.top, inner.width * .55, 2.2 * s),
          Radius.circular(1 * s),
        ),
        ui,
      );
      for (var k = 0; k < 3; k++) {
        final lw = inner.width * [.8, .6, .7][(k + i) % 3];
        canvas.drawRRect(
          RRect.fromRectAndRadius(
            Rect.fromLTWH(
              inner.left,
              inner.top + (5 + k * 3.6) * s,
              lw,
              1.6 * s,
            ),
            Radius.circular(1 * s),
          ),
          fill(body, .3),
        );
      }

      // Scan line
      canvas.save();
      canvas.clipRRect(screen);
      final scanY = screen.top + ((time + i * .2) % 1.0) * screen.height;
      canvas.drawRect(
        Rect.fromLTWH(screen.left, scanY, screen.width, 1.2 * s),
        fill(c.cyan, .35),
      );
      canvas.restore();

      // Chấm trạng thái (pulse)
      final dc = _dotColor(dots[i]);
      final dotPos = Offset(screen.right - 4 * s, screen.top + 4 * s);
      final pulse = (time * 2 + i * .15) % 1.0;
      if (dots[i] != _Dot.none) {
        canvas.drawCircle(
          dotPos,
          2.2 * s * (1 + pulse * 1.4),
          fill(dc, .45 * (1 - pulse)),
        );
      }
      canvas.drawCircle(dotPos, 2.2 * s, Paint()..color = dc);

      // ---------- NGƯỜI (nhìn từ sau, ngồi trước bàn) ----------
      final bob = math.sin((time * 4 + i * .37) * 2 * math.pi) * .9 * s;
      final headC = Offset(cx, deskY - 1 * s + bob + lifted);
      final headR = 6.2 * s;

      // Vai / thân
      final torsoTop = headC.dy + headR * .7;
      final torso = Path()
        ..moveTo(cx - 12 * s, deskY + 26 * s)
        ..lineTo(cx - 12 * s, torsoTop + 9 * s)
        ..quadraticBezierTo(cx - 12 * s, torsoTop, cx - 4 * s, torsoTop)
        ..lineTo(cx + 4 * s, torsoTop)
        ..quadraticBezierTo(cx + 12 * s, torsoTop, cx + 12 * s, torsoTop + 9 * s)
        ..lineTo(cx + 12 * s, deskY + 26 * s);
      canvas.drawPath(torso, Paint()..color = c.surface);
      canvas.drawPath(torso, fill(body, .22));
      canvas.drawPath(torso, line(body));

      // Tay gõ phím (nhấp nhô ngược pha)
      for (final side in [-1.0, 1.0]) {
        final armBob = math.sin((time * 8 + i * .5 + side) * math.pi) * .8 * s;
        canvas.drawLine(
          Offset(cx + side * 10 * s, torsoTop + 7 * s),
          Offset(cx + side * 6 * s, deskY + 2 * s + armBob),
          line(body, 1.1),
        );
      }

      // Đầu
      canvas.drawCircle(headC, headR, Paint()..color = c.surface);
      canvas.drawCircle(headC, headR, fill(c.cyan, lead ? .3 : .2));
      canvas.drawCircle(headC, headR, line(lead ? c.cyan : body));
      // Tóc
      canvas.drawArc(
        Rect.fromCircle(center: headC, radius: headR),
        math.pi * 1.05,
        math.pi * .9,
        false,
        line(lead ? c.cyan : body, 1.6),
      );

      // Gạch chân người đang được chọn
      if (isSel) {
        canvas.drawLine(
          Offset(cx - 8 * s, h * .99),
          Offset(cx + 8 * s, h * .99),
          line(body, 1.4),
        );
      }
    }
  }

  @override
  bool shouldRepaint(covariant _TeamPainter old) =>
      old.hover != hover ||
      old.selected != selected ||
      old.c != c ||
      old.dots.length != dots.length ||
      !Iterable.generate(dots.length).every((i) => old.dots[i] == dots[i]);
}
