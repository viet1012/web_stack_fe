import 'dart:async';
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

/// Cảnh nhà máy kiểu truyện tranh, tự đổi giữa các cảnh:
/// - Xưởng cơ khí: cầu trục, công nhân đẩy xe / hàn, 5 dev ngồi code.
/// - Dây chuyền lắp ráp: 5 trạm robot gắp hàng, xe nâng, AGV, ống khói.
/// 5 vị trí (dev / trạm) mỗi vị trí phụ trách một nhóm phòng ban: đèn báo
/// = trạng thái nhóm đó. Hover → tooltip, click → lọc phòng ban đó.
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

  /// Tên cảnh + cách gọi 5 vị trí trong tooltip.
  static const _scenes = [
    (name: 'Workshop', lead: 'Team lead', member: 'Member'),
    (name: 'Assembly line', lead: 'Main station', member: 'Station'),
    (name: 'Server room', lead: 'Core rack', member: 'Rack'),
    (name: 'Press line', lead: 'Main press', member: 'Press'),
    (name: 'Warehouse', lead: 'Main bay', member: 'Bay'),
  ];
  static const _rotateEvery = Duration(seconds: 15);

  /// Mọi chuyển động có chu kỳ chia hết 24s → vòng lặp liền mạch.
  late final AnimationController _c = AnimationController(
    vsync: this,
    duration: const Duration(seconds: 24),
  );

  Timer? _rotate;
  Timer? _titleTimer;
  int? _hover;

  final _rng = math.Random();

  /// Các cảnh còn lại của lượt hiện tại (xáo như rút bài).
  final _queue = <int>[];

  /// Mỗi lần vào trang bắt đầu bằng một cảnh ngẫu nhiên, hiện tên ngay.
  late int _scene = _rng.nextInt(_scenes.length);
  bool _showTitle = true;

  @override
  void initState() {
    super.initState();
    _hideTitleLater();
  }

  void _hideTitleLater() {
    _titleTimer?.cancel();
    _titleTimer = Timer(const Duration(milliseconds: 2600), () {
      if (mounted) setState(() => _showTitle = false);
    });
  }

  /// Rút cảnh kế tiếp; hết bộ thì xáo lại. Chiếu đủ mọi cảnh trước khi lặp
  /// và không bao giờ chiếu lại ngay cảnh đang hiện.
  int _nextScene() {
    if (_queue.isEmpty) {
      _queue
        ..addAll(List.generate(_scenes.length, (i) => i)..shuffle(_rng))
        ..remove(_scene);
    }
    return _queue.removeAt(0);
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (Motion.reduced(context)) {
      _c.stop();
      _c.value = 0;
      _rotate?.cancel();
      _rotate = null;
    } else {
      if (!_c.isAnimating) _c.repeat();
      if (_rotate == null) _scheduleRotate();
    }
  }

  /// Tự chuyển cảnh; chọn tay thì đếm lại từ đầu. Đang hover (đọc tooltip)
  /// thì giữ nguyên cảnh.
  void _scheduleRotate() {
    _rotate?.cancel();
    _rotate = Timer.periodic(_rotateEvery, (_) {
      if (mounted && _hover == null) _show(_nextScene());
    });
  }

  /// Đổi cảnh + hiện nhãn tên cảnh vài giây.
  void _show(int scene) {
    setState(() {
      _scene = scene;
      _showTitle = true;
    });
    _hideTitleLater();
  }

  void _pick(int scene) {
    _queue.remove(scene);
    _show(scene);
    if (_rotate != null) _scheduleRotate();
  }

  @override
  void dispose() {
    _rotate?.cancel();
    _titleTimer?.cancel();
    _c.dispose();
    super.dispose();
  }

  _ScenePainter _painter(_SceneArgs a, _Layer layer) => switch (_scene) {
        0 => _WorkshopPainter(a, layer),
        1 => _LinePainter(a, layer),
        2 => _ServerPainter(a, layer),
        3 => _PressPainter(a, layer),
        _ => _WarehousePainter(a, layer),
      };

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
    final s = _scenes[_scene];
    final who = i == middle ? s.lead : '${s.member} ${i + 1}';
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
    final ratio = widget.total == 0 ? 0.0 : widget.online / widget.total;
    final selectedIdx = groups.indexWhere(
      (g) => g.any((d) => d.name == widget.selected),
    );
    final _SceneArgs args = (
      t: _c,
      dots: groups.map(_dotOf).toList(),
      hover: _hover,
      selected: selectedIdx < 0 ? null : selectedIdx,
      c: c,
      dark: Theme.of(context).brightness == Brightness.dark,
    );

    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Container(
          decoration: comicPanel(c, radius: 12, offset: 4),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(9.5),
            child: AspectRatio(
              aspectRatio: 1,
              child: LayoutBuilder(
                builder: (context, box) {
                  final k = box.maxWidth / _Scene.size;
                  return Stack(
                    children: [
                      Positioned.fill(
                        child: AnimatedSwitcher(
                          duration: Motion.of(
                            context,
                            const Duration(milliseconds: 420),
                          ),
                          switchInCurve: Curves.easeInOutCubic,
                          switchOutCurve: Curves.linear,
                          // Cảnh mới quét chéo lên trên cảnh cũ (cảnh cũ
                          // đứng yên bên dưới, không mờ / co giãn).
                          transitionBuilder: (child, anim) =>
                              child.key == ValueKey(_scene)
                                  ? _PageWipe(
                                      animation: anim,
                                      ink: c.ink,
                                      edge: c.hero,
                                      child: child,
                                    )
                                  : child,
                          // 2 lớp: nền tĩnh chỉ vẽ lại khi theme / hover /
                          // trạng thái đổi; lớp động vẽ mỗi frame.
                          child: Stack(
                            key: ValueKey(_scene),
                            fit: StackFit.expand,
                            children: [
                              for (final layer in _Layer.values)
                                RepaintBoundary(
                                  child: CustomPaint(
                                    isComplex: layer == _Layer.back,
                                    willChange: layer == _Layer.front,
                                    painter: _painter(args, layer),
                                  ),
                                ),
                            ],
                          ),
                        ),
                      ),
                      // Vùng hover/click cho từng vị trí (chung cho mọi cảnh).
                      for (var i = 0; i < members; i++)
                        Positioned.fromRect(
                          rect: _scaled(_Scene.slot(i), k),
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
                      // Nhãn tên cảnh bật ra vài giây mỗi lần đổi cảnh.
                      Positioned(
                        left: 6,
                        top: 6,
                        child: IgnorePointer(
                          child: AnimatedSlide(
                            offset: _showTitle ? Offset.zero : const Offset(0, -.5),
                            duration: Motion.of(context, const Duration(milliseconds: 300)),
                            curve: Curves.easeOutBack,
                            child: AnimatedOpacity(
                              opacity: _showTitle ? 1 : 0,
                              duration: Motion.of(context, const Duration(milliseconds: 250)),
                              child: Container(
                                padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                                decoration: BoxDecoration(
                                  color: c.hero,
                                  borderRadius: BorderRadius.circular(4),
                                  border: Border.all(color: c.ink, width: 1.5),
                                  boxShadow: [
                                    BoxShadow(color: c.ink, offset: const Offset(2, 2)),
                                  ],
                                ),
                                child: Text(
                                  _scenes[_scene].name.toUpperCase(),
                                  style: TextStyle(
                                    color: c.ink,
                                    fontFamily: kComicFont,
                                    fontSize: 12,
                                    letterSpacing: 1,
                                  ),
                                ),
                              ),
                            ),
                          ),
                        ),
                      ),
                    ],
                  );
                },
              ),
            ),
          ),
        ),
        const SizedBox(height: 12),
        Row(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            Text(
              '${widget.online}/${widget.total}',
              style: TextStyle(
                color: c.accent,
                fontFamily: kComicFont,
                fontSize: 19,
                letterSpacing: 1,
              ),
            ),
            const SizedBox(width: 5),
            Text(
              'ONLINE',
              style: TextStyle(
                color: c.muted,
                fontFamily: kComicFont,
                fontSize: 13,
                letterSpacing: 1.2,
              ),
            ),
            const Spacer(),
            Text(
              '${(ratio * 100).round()}%',
              style: TextStyle(
                color: c.muted,
                fontSize: 11.5,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
        const SizedBox(height: 6),
        Container(
          height: 12,
          decoration: BoxDecoration(
            color: c.surface2,
            borderRadius: BorderRadius.circular(99),
            border: Border.all(color: c.ink, width: 2),
          ),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(99),
            child: TweenAnimationBuilder<double>(
              tween: Tween(end: ratio),
              duration: Motion.of(context, const Duration(milliseconds: 400)),
              curve: Motion.curve,
              builder: (_, v, _) => FractionallySizedBox(
                alignment: Alignment.centerLeft,
                widthFactor: v.clamp(0, 1),
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    gradient: LinearGradient(colors: [c.hero, c.ok]),
                  ),
                ),
              ),
            ),
          ),
        ),
        const SizedBox(height: 4),
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            for (var s = 0; s < _scenes.length; s++)
              _SceneDot(
                label: _scenes[s].name,
                active: s == _scene,
                onTap: () => _pick(s),
              ),
          ],
        ),
      ],
    );
  }

  static Rect _scaled(Rect r, double k) =>
      Rect.fromLTWH(r.left * k, r.top * k, r.width * k, r.height * k);
}

/// Chuyển cảnh kiểu lật trang truyện: mép chéo quét từ trái sang phải,
/// mép có viền mực + vàng.
class _PageWipe extends AnimatedWidget {
  final Color ink;
  final Color edge;
  final Widget child;

  const _PageWipe({
    required Animation<double> animation,
    required this.ink,
    required this.edge,
    required this.child,
  }) : super(listenable: animation);

  @override
  Widget build(BuildContext context) {
    final t = (listenable as Animation<double>).value;
    return Stack(
      fit: StackFit.expand,
      children: [
        // Giữ cây widget ổn định suốt và sau animation; xong thì bỏ clip.
        ClipPath(
          clipper: _WipeClipper(t),
          clipBehavior: t >= 1 ? Clip.none : Clip.antiAlias,
          child: child,
        ),
        if (t < 1)
          IgnorePointer(
            child: CustomPaint(painter: _WipeEdgePainter(t, ink, edge)),
          ),
      ],
    );
  }
}

/// Mép quét: đường chéo, tâm chạy từ -skew đến width+skew.
({Offset top, Offset bottom}) _wipeEdge(Size size, double t) {
  final skew = size.height * .35;
  final cx = -skew + t * (size.width + 2 * skew);
  return (top: Offset(cx + skew, 0), bottom: Offset(cx - skew, size.height));
}

class _WipeClipper extends CustomClipper<Path> {
  final double t;
  _WipeClipper(this.t);

  @override
  Path getClip(Size size) {
    final e = _wipeEdge(size, t);
    return Path()
      ..moveTo(0, 0)
      ..lineTo(e.top.dx, 0)
      ..lineTo(e.bottom.dx, size.height)
      ..lineTo(0, size.height)
      ..close();
  }

  @override
  bool shouldReclip(covariant _WipeClipper old) => old.t != t;
}

class _WipeEdgePainter extends CustomPainter {
  final double t;
  final Color ink;
  final Color edge;
  _WipeEdgePainter(this.t, this.ink, this.edge);

  @override
  void paint(Canvas canvas, Size size) {
    final e = _wipeEdge(size, t);
    canvas.drawLine(
      e.top,
      e.bottom,
      Paint()
        ..color = ink
        ..strokeWidth = 6,
    );
    canvas.drawLine(
      e.top,
      e.bottom,
      Paint()
        ..color = edge
        ..strokeWidth = 2.5,
    );
  }

  @override
  bool shouldRepaint(covariant _WipeEdgePainter old) => old.t != t;
}

/// Chấm chọn cảnh: cảnh đang chiếu kéo dài thành viên thuốc vàng.
class _SceneDot extends StatelessWidget {
  final String label;
  final bool active;
  final VoidCallback onTap;

  const _SceneDot({
    required this.label,
    required this.active,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final c = context.dash;
    return Tooltip(
      message: label,
      child: Semantics(
        button: true,
        selected: active,
        label: 'Scene: $label',
        child: InkResponse(
          onTap: onTap,
          radius: 12,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 2, vertical: 6),
            child: AnimatedContainer(
              duration: Motion.of(context, Motion.fast),
              curve: Motion.curve,
              width: active ? 18 : 9,
              height: 9,
              decoration: BoxDecoration(
                color: active ? c.hero : c.surface2,
                borderRadius: BorderRadius.circular(99),
                border: Border.all(color: c.ink, width: 1.5),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// Toạ độ thiết kế của cảnh: khung vuông 200×200, co giãn theo bề rộng.
abstract final class _Scene {
  static const size = 200.0;
  static const flex = [10.0, 10.0, 12.0, 10.0, 10.0];

  /// Dải chứa 5 vị trí tương tác (phòng dev / các trạm robot).
  static const band = Rect.fromLTWH(6, 72, 188, 66);

  static Rect slot(int i) {
    final unit = band.width / flex.reduce((a, b) => a + b);
    var left = band.left;
    for (var j = 0; j < i; j++) {
      left += flex[j] * unit;
    }
    return Rect.fromLTWH(left, band.top, flex[i] * unit, band.height);
  }

  static final slots = [for (var i = 0; i < 5; i++) slot(i)];
}

typedef _SceneArgs = ({
  Animation<double> t,
  List<_Dot> dots,
  int? hover,
  int? selected,
  DashColors c,
  bool dark,
});

// ============================================================
// NỀN CHUNG: lớp vẽ, helper nét mực, sàn xưởng, công nhân, biển hiệu
// ============================================================

const _kPeriod = 24.0;

/// Tỉ lệ công nhân: hình gốc (cảnh "Xưởng cơ khí" HTML) cao ~116 đơn vị.
const _kWorkerScale = .38;

const _kSkin = Color(0xFFF2C39B);
const _kSteel = Color(0xFF9AA6BD);
const _kBox = Color(0xFFD9A066);
const _kCyan = Color(0xFF2FD3E0);
const _kOrange = Color(0xFFFF7A3D);

/// Nền tĩnh (tường, sàn, bàn…) chỉ vẽ lại khi theme / hover / trạng thái đổi;
/// lớp động (người, máy, khói…) vẽ mỗi frame.
enum _Layer { back, front }

abstract class _ScenePainter extends CustomPainter {
  final _Layer layer;
  final Animation<double> t;
  final List<_Dot> dots;
  final int? hover;
  final int? selected;
  final DashColors c;
  final bool dark;

  _ScenePainter(_SceneArgs a, this.layer)
      : t = a.t,
        dots = a.dots,
        hover = a.hover,
        selected = a.selected,
        c = a.c,
        dark = a.dark,
        super(repaint: layer == _Layer.front ? a.t : null);

  // Hình công nhân dựng sẵn: gốc ở chân, quay mặt sang phải.
  static final _workerTorso = Path()
    ..moveTo(-15, -84)
    ..quadraticBezierTo(0, -90, 15, -84)
    ..lineTo(13, -42)
    ..lineTo(-13, -42)
    ..close();
  static final _workerHat = Path()
    ..moveTo(-13, -99)
    ..quadraticBezierTo(-12, -116, 1, -116)
    ..quadraticBezierTo(13, -116, 14, -99)
    ..lineTo(19, -99)
    ..lineTo(19, -95)
    ..lineTo(-14, -95)
    ..close();

  double _time = 0;

  // Dùng lại Paint thay vì tạo hàng trăm object mỗi frame (trên web mỗi
  // object là một handle CanvasKit → GC giật). Canvas chép trạng thái Paint
  // ngay lúc vẽ nên đổi màu cho lần vẽ sau là an toàn.
  final _fillPaint = Paint();
  final _linePaint = Paint()
    ..style = PaintingStyle.stroke
    ..strokeCap = StrokeCap.round
    ..strokeJoin = StrokeJoin.round;
  final _shaderPaint = Paint();
  final _glowPaint = Paint();
  final _inks = <double, Paint>{};
  final _glows = <(Color, double), Shader>{};

  void back(Canvas canvas);
  void front(Canvas canvas);

  @override
  void paint(Canvas canvas, Size size) {
    _time = t.value * _kPeriod;
    canvas.save();
    canvas.scale(size.width / _Scene.size);
    canvas.clipRect(const Rect.fromLTWH(0, 0, _Scene.size, _Scene.size));
    if (layer == _Layer.back) {
      back(canvas);
    } else {
      front(canvas);
    }
    canvas.restore();
  }

  Paint _fill(Color color) => _fillPaint..color = color;

  Paint _line(Color color, double w) => _linePaint
    ..color = color
    ..strokeWidth = w;

  Paint _ink(double w, [double alpha = 1]) => alpha == 1
      ? _inks.putIfAbsent(
          w,
          () => Paint()
            ..color = c.ink
            ..style = PaintingStyle.stroke
            ..strokeWidth = w
            ..strokeJoin = StrokeJoin.round
            ..strokeCap = StrokeCap.round,
        )
      : _line(c.ink.withValues(alpha: alpha), w);

  void _shape(Canvas canvas, Path p, Color fill, [double w = 1.2]) {
    canvas.drawPath(p, _fill(fill));
    canvas.drawPath(p, _ink(w));
  }

  void _rect(
    Canvas canvas,
    Rect r,
    Color fill, [
    double w = 1.2,
    double radius = 0,
  ]) {
    final rr = RRect.fromRectAndRadius(r, Radius.circular(radius));
    canvas.drawRRect(rr, _fill(fill));
    canvas.drawRRect(rr, _ink(w));
  }

  /// Quầng sáng tròn; shader dựng một lần cho mỗi màu/bán kính,
  /// độ sáng [strength] điều khiển qua alpha của Paint.
  void _glow(
    Canvas canvas,
    Offset at,
    double r,
    Color color, [
    double strength = 1,
  ]) {
    final shader = _glows.putIfAbsent(
      (color, r),
      () => RadialGradient(
        colors: [color.withValues(alpha: .7), color.withValues(alpha: 0)],
      ).createShader(Rect.fromCircle(center: Offset.zero, radius: r)),
    );
    canvas.save();
    canvas.translate(at.dx, at.dy);
    canvas.drawCircle(
      Offset.zero,
      r,
      _glowPaint
        ..shader = shader
        ..color = Colors.black.withValues(alpha: strength.clamp(0.0, 1.0)),
    );
    canvas.restore();
  }

  /// Hướng mặt khi đi qua lại (+1 phải, -1 trái). Quay đầu bằng cách "lật"
  /// dần (scaleX qua 0) trong lúc đứng lại ở hai đầu, thay vì lật tức thì.
  double _facing(double period) {
    const w = .04;
    final p = (_time % period) / period;
    double ease(double a, double b, double t) =>
        a + (b - a) * Curves.easeInOut.transform(t.clamp(0.0, 1.0));
    if (p < w) return ease(-1, 1, (p + w) / (2 * w));
    if (p < .5 - w) return 1;
    if (p < .5 + w) return ease(1, -1, (p - (.5 - w)) / (2 * w));
    if (p < 1 - w) return -1;
    return ease(-1, 1, (p - (1 - w)) / (2 * w));
  }

  double _wave(double period, [double phase = 0]) =>
      math.sin((_time / period + phase) * 2 * math.pi);

  /// 0 → 1 → 0 trong một chu kỳ.
  double _tri(double period) {
    final p = (_time % period) / period;
    return p < .5 ? p * 2 : 2 - p * 2;
  }

  Color _dotColor(_Dot d) => switch (d) {
        _Dot.ok => c.ok,
        _Dot.bad => c.bad,
        _Dot.warn => c.warn,
        _Dot.none => c.muted,
      };

  /// Số giả ngẫu nhiên 0..1, cố định theo [n] (đèn nháy, kích cỡ thùng…).
  static double _hash(int n) {
    final v = math.sin(n * 12.9898) * 43758.5453;
    return v - v.floorToDouble();
  }

  /// Đèn trạng thái nhóm phòng ban của vị trí [i], nhấp nháy lan toả.
  void _led(Canvas canvas, Offset at, int i, [double r = 2]) {
    final dc = _dotColor(dots[i]);
    if (dots[i] != _Dot.none) {
      final p = (_time + i * .2) % 1.0;
      canvas.drawCircle(at, r * (1 + p * 1.6), _fill(dc.withValues(alpha: .5 * (1 - p))));
    }
    canvas.drawCircle(at, r, _fill(dc));
    canvas.drawCircle(at, r, _ink(.7));
  }

  /// Nền vàng mờ cho vị trí đang hover / đang chọn.
  void _slotHighlight(Canvas canvas) {
    for (var i = 0; i < 5; i++) {
      if (hover != i && selected != i) continue;
      canvas.drawRRect(
        RRect.fromRectAndRadius(_Scene.slots[i].deflate(1), const Radius.circular(4)),
        _fill(c.hero.withValues(alpha: selected == i ? .24 : .14)),
      );
    }
  }

  /// Công nhân đi qua lại (đẩy xe hoặc tay không), chậm dần ở hai đầu rồi
  /// quay đầu.
  void _walker(
    Canvas canvas, {
    required double from,
    required double span,
    required Color vest,
    bool cart = true,
    double period = 12,
  }) {
    final p = (_time % period) / period;
    final tri = _tri(period);
    final x = from + span * Curves.easeInOut.transform(tri);
    final pace = math.sin(tri * math.pi);
    final travelled = p < .5 ? x - from : span + (from + span - x);
    _worker(
      canvas,
      Offset(x, 194),
      _facing(period),
      vest: vest,
      swing: _wave(.75) * .35 * pace,
      wheel: travelled / (7 * _kWorkerScale),
      pushing: cart,
    );
  }

  TextPainter _label(String text, double size, Paint paint) => TextPainter(
        text: TextSpan(
          text: text,
          style: TextStyle(
            fontFamily: kComicFont,
            fontSize: size,
            letterSpacing: .8,
            foreground: paint,
          ),
        ),
        textDirection: TextDirection.ltr,
      )..layout();

  /// Biển hiệu: nền màu, viền mực, chữ trắng viền mực.
  void _plate(
    Canvas canvas,
    Rect r,
    Color color,
    TextPainter fill,
    TextPainter stroke,
  ) {
    _rect(canvas, r, color, 1.4, 2);
    canvas.drawRRect(
      RRect.fromRectAndRadius(r.deflate(2), const Radius.circular(1)),
      _line(Colors.white, .6),
    );
    final o = r.center - Offset(fill.width / 2, fill.height / 2);
    stroke.paint(canvas, o);
    fill.paint(canvas, o);
  }

  void _star(Canvas canvas, Offset at) {
    final r = 3.6 * (1 + _wave(1) * .12);
    final p = Path();
    for (var j = 0; j < 10; j++) {
      final a = -math.pi / 2 + j * math.pi / 5;
      final o = at + Offset(math.cos(a), math.sin(a)) * (j.isEven ? r : r * .45);
      if (j == 0) {
        p.moveTo(o.dx, o.dy);
      } else {
        p.lineTo(o.dx, o.dy);
      }
    }
    _shape(canvas, p..close(), c.hero, .9);
  }

  void _floor(Canvas canvas) {
    const s = _Scene.size;
    canvas.drawRect(
      const Rect.fromLTWH(0, 140, s, 60),
      _fill(dark ? const Color(0xFF474F70) : const Color(0xFF7D889F)),
    );

    // Vạch cảnh báo vàng/đen.
    const band = Rect.fromLTWH(-2, 138, s + 4, 5);
    canvas.save();
    canvas.clipRect(band);
    canvas.drawRect(band, _fill(c.hero));
    final stripes = Path();
    for (var x = -10.0; x < s + 10; x += 8) {
      stripes
        ..moveTo(x, 143)
        ..lineTo(x + 4, 143)
        ..lineTo(x + 9, 138)
        ..lineTo(x + 5, 138)
        ..close();
    }
    canvas.drawPath(stripes, _fill(c.ink));
    canvas.restore();
    canvas.drawRect(band, _ink(1));

    for (var x = 4.0; x < s; x += 13) {
      canvas.drawLine(Offset(x, 197), Offset(x + 8, 197), _line(_kCyan, 1.4));
    }
  }

  void _wheel(Canvas canvas, Offset o, double r, double angle) {
    const hub = Color(0xFFC8D0DE);
    canvas.drawCircle(o, r, _fill(c.ink));
    canvas.drawCircle(o, r * .43, _fill(hub));
    canvas.drawLine(
      o,
      o + Offset(math.cos(angle), math.sin(angle)) * r * .85,
      _line(hub, r * .23),
    );
  }

  /// Công nhân: toạ độ gốc ở chân, quay mặt sang phải ([dir] = -1 lật trái).
  void _worker(
    Canvas canvas,
    Offset feet,
    double dir, {
    required Color vest,
    double swing = 0,
    double wheel = 0,
    bool pushing = false,
    double? weldGlow,
  }) {
    canvas.save();
    canvas.translate(feet.dx, feet.dy);
    canvas.scale(dir * _kWorkerScale, _kWorkerScale);

    for (final side in [-1.0, 1.0]) {
      canvas.save();
      canvas.translate(0, -44);
      canvas.rotate(side * swing);
      _rect(
        canvas,
        const Rect.fromLTRB(-5, 0, 5, 41),
        side < 0 ? const Color(0xFF1E2742) : const Color(0xFF2A3557),
        3,
      );
      canvas.drawRect(const Rect.fromLTRB(-6, 38, 10, 44), _fill(c.ink));
      canvas.restore();
    }

    _shape(canvas, _workerTorso, vest, 3);
    final stripe = _line(const Color(0xFFEEF4FF), 4);
    canvas.drawLine(const Offset(-12, -66), const Offset(12, -66), stripe);
    canvas.drawLine(const Offset(-11, -54), const Offset(11, -54), stripe);

    canvas.drawCircle(const Offset(0, -97), 11, _fill(_kSkin));
    canvas.drawCircle(const Offset(0, -97), 11, _ink(3));

    if (weldGlow != null) {
      // Mặt nạ hàn, kính loé sáng theo tia lửa.
      _rect(canvas, const Rect.fromLTRB(-12, -111, 15, -84), const Color(0xFF56618A), 3, 6);
      _rect(
        canvas,
        const Rect.fromLTRB(4, -103, 15, -92),
        Color.lerp(const Color(0xFF1B2A3A), const Color(0xFF9FE8FF), weldGlow * .8)!,
        2,
      );
    } else {
      canvas.drawCircle(const Offset(7, -96), 1.8, _fill(c.ink));
      _shape(canvas, _workerHat, c.hero, 3);
    }

    // Tay: đẩy xe, hoặc cầm mỏ hàn.
    const shoulder = Offset(4, -78);
    final hand = pushing ? const Offset(25, -61) : const Offset(22, -66);
    canvas.drawLine(shoulder, hand, _ink(10));
    canvas.drawLine(shoulder, hand, _line(vest, 6));
    if (weldGlow != null) {
      canvas.drawLine(hand, const Offset(34, -58), _ink(4));
    }
    canvas.drawCircle(hand, 4, _fill(_kSkin));
    canvas.drawCircle(hand, 4, _ink(2));

    if (pushing) _cart(canvas, wheel);
    canvas.restore();
  }

  void _cart(Canvas canvas, double wheel) {
    canvas.drawLine(const Offset(27, -60), const Offset(32, -24), _ink(3));
    _rect(canvas, const Rect.fromLTRB(30, -24, 80, -15), _kSteel, 3);
    _rect(canvas, const Rect.fromLTRB(36, -48, 56, -24), _kBox, 3);
    canvas.drawLine(const Offset(46, -48), const Offset(46, -24), _ink(1.5, .5));
    _rect(canvas, const Rect.fromLTRB(58, -40, 76, -24), _kBox, 3);
    _wheel(canvas, const Offset(40, -8), 7, wheel);
    _wheel(canvas, const Offset(70, -8), 7, wheel);
  }

  @override
  bool shouldRepaint(covariant _ScenePainter old) =>
      old.runtimeType != runtimeType ||
      old.layer != layer ||
      old.hover != hover ||
      old.selected != selected ||
      old.c != c ||
      old.dark != dark ||
      old.dots.length != dots.length ||
      !Iterable.generate(dots.length).every((i) => old.dots[i] == dots[i]);
}

// ============================================================
// CẢNH 1: XƯỞNG CƠ KHÍ + PHÒNG DEV
// ============================================================

class _WorkshopPainter extends _ScenePainter {
  _WorkshopPainter(super.a, super.layer);

  static const _shirts = [
    Color(0xFFE8384F),
    Color(0xFF2F7DE0),
    Color(0xFF2FD3E0),
    Color(0xFF2EA05A),
    Color(0xFFFF7A3D),
  ];
  static const _hair = [
    Color(0xFF3A2A1E),
    Color(0xFF14121F),
    Color(0xFF14121F),
    Color(0xFF6B3F1F),
    Color(0xFFC98A3A),
  ];
  static const _code = [
    Color(0xFF7FF6FF),
    Color(0xFFFFD23F),
    Color(0xFFFF7AB8),
    Color(0xFF9CFF8A),
  ];
  static const _codeW = [.55, .8, .45, .7, .85, .35, .65, .5];
  static const _codeX = [0.0, .1, .1, .2, .1, 0.0, .1, 0.0];

  /// Tốc độ cuộn code (đơn vị/giây) — số nguyên để lặp liền mạch sau 24s.
  static const _scroll = [4.0, 6.0, 3.0, 5.0, 4.0];

  static final _gearBig = _gearPath(13, 10);
  static final _gearSmall = _gearPath(8.5, 8);

  /// Hơi cà phê, gốc ở miệng cốc.
  static final _steam = Path()
    ..relativeQuadraticBezierTo(-1.2, -1.5, 0, -3)
    ..relativeQuadraticBezierTo(1.2, -1.5, 0, -3);

  /// Mũ bảo hộ của lead, gốc ở tâm đầu.
  static final _leadHat = Path()
    ..moveTo(-7.1, -1)
    ..quadraticBezierTo(-6.6, -10.6, 0, -10.6)
    ..quadraticBezierTo(6.6, -10.6, 7.1, -1)
    ..close();

  late final _signFill = _label('DEV ROOM', 8.5, Paint()..color = Colors.white);
  late final _signStroke = _label('DEV ROOM', 8.5, _ink(1.6));

  /// Thân dev nhìn từ sau lưng; chỉ đổi khi hover đổi (painter dựng lại).
  late final _torsos = [
    for (var i = 0; i < 5; i++) _torso(_Scene.slots[i].center.dx, 117 + _lift(i)),
  ];

  double _lift(int i) => hover == i ? -1.5 : 0.0;

  Rect _frame(int i) =>
      Rect.fromLTWH(_Scene.slots[i].center.dx - 13, 84 + _lift(i), 26, 17);

  static Path _gearPath(double r, int teeth) {
    final p = Path();
    final step = 2 * math.pi / teeth;
    const profile = [(-.5, 3.0), (-.25, 3.0), (-.15, 0.0), (.15, 0.0), (.25, 3.0)];
    for (var i = 0; i < teeth; i++) {
      for (final (da, depth) in profile) {
        final a = (i + da) * step;
        final o = Offset(math.cos(a), math.sin(a)) * (r - depth);
        if (i == 0 && da == -.5) {
          p.moveTo(o.dx, o.dy);
        } else {
          p.lineTo(o.dx, o.dy);
        }
      }
    }
    return p..close();
  }

  static Path _torso(double cx, double shoulderY) => Path()
    ..moveTo(cx - 10, 138)
    ..lineTo(cx - 10, shoulderY + 7)
    ..quadraticBezierTo(cx - 10, shoulderY, cx, shoulderY)
    ..quadraticBezierTo(cx + 10, shoulderY, cx + 10, shoulderY + 7)
    ..lineTo(cx + 10, 138)
    ..close();

  // ------------------------------------------------------------

  @override
  void back(Canvas canvas) {
    _wall(canvas);
    _plate(
      canvas,
      const Rect.fromLTWH(144, 44, 50, 14),
      const Color(0xFF2EA05A),
      _signFill,
      _signStroke,
    );
    _floor(canvas);
    _beams(canvas);
    _rail(canvas);

    _rect(canvas, _Scene.band, const Color(0xFF233056), 1.4, 3);
    _rect(canvas, const Rect.fromLTWH(4, 69, 192, 4), const Color(0xFF56618A), 1.1);
    for (var i = 0; i < 5; i++) {
      _monitorBack(canvas, i);
    }
    _rect(canvas, const Rect.fromLTWH(9, 104, 182, 3), const Color(0xFFC9A47A), .9);
    _rect(canvas, const Rect.fromLTWH(9, 107, 182, 31), const Color(0xFF7A5A3C), .9);
    final cup = _Scene.slots[1].right;
    _rect(canvas, Rect.fromLTWH(cup - 2, 99, 4, 5), Colors.white, .8, .6);
    canvas.drawArc(
      Rect.fromLTWH(cup + .8, 100, 2.6, 2.6),
      -math.pi / 2,
      math.pi,
      false,
      _ink(.7),
    );

    // Phôi thép trên giá cho thợ hàn.
    _rect(canvas, const Rect.fromLTWH(132, 171, 33, 5), _kSteel, 1, .6);
    canvas.drawLine(const Offset(137, 176), const Offset(134, 194), _ink(1.3));
    canvas.drawLine(const Offset(160, 176), const Offset(163, 194), _ink(1.3));
  }

  @override
  void front(Canvas canvas) {
    _gear(canvas, const Offset(20, 52), 13, _gearBig, 1, c.hero);
    _gear(canvas, const Offset(36, 42), 8.5, _gearSmall, -1.25, _kCyan);
    for (var i = 0; i < 5; i++) {
      _monitorFront(canvas, i);
    }
    _steamPuffs(canvas, _Scene.slots[1].right);
    for (var i = 0; i < 5; i++) {
      _dev(canvas, i);
    }
    final sel = selected;
    if (sel != null) _star(canvas, Offset(_Scene.slots[sel].center.dx, 77.5));
    _trolley(canvas);
    _welder(canvas);
    _walker(canvas, from: 34, span: 64, vest: _kOrange);
  }

  // ------------------------------------------------------------

  void _wall(Canvas canvas) {
    const s = _Scene.size;
    canvas.drawRect(
      const Rect.fromLTWH(0, 0, s, s),
      _shaderPaint
        ..shader = LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: dark
              ? const [Color(0xFF23284D), Color(0xFF353C6C)]
              : const [Color(0xFFA9BCD8), Color(0xFFDBE5F2)],
        ).createShader(const Rect.fromLTWH(0, 0, s, 140)),
    );

    // Mái răng cưa + ô kính lấy sáng (ban đêm: đèn vàng).
    canvas.drawRect(const Rect.fromLTWH(0, 0, s, 20), _fill(const Color(0xFF2C3354)));
    final glass = dark ? const Color(0xBFFFE58A) : const Color(0xFFFFF3B0);
    for (var x = 10.0; x < s + 40; x += 40) {
      _shape(
        canvas,
        Path()
          ..moveTo(x, 4)
          ..lineTo(x + 33, 19)
          ..lineTo(x, 19)
          ..close(),
        const Color(0xFF8A9CC2),
        1,
      );
      _rect(canvas, Rect.fromLTWH(x - 7, 4, 7, 15), glass, 1);
      canvas.drawLine(Offset(x - 3.5, 4), Offset(x - 3.5, 19), _ink(.5));
    }
    _rect(canvas, const Rect.fromLTWH(-2, 19, s + 4, 3), const Color(0xFF3B4466), 1);
  }

  void _beams(Canvas canvas) {
    final beam = Paint()
      ..shader = LinearGradient(
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
        colors: [
          const Color(0xFFFFF8D6).withValues(alpha: dark ? .14 : .55),
          const Color(0x00FFF8D6),
        ],
      ).createShader(const Rect.fromLTWH(0, 22, _Scene.size, 178));
    final rays = Path();
    for (var x = 10.0; x < _Scene.size + 40; x += 40) {
      rays
        ..moveTo(x - 7, 22)
        ..lineTo(x, 22)
        ..lineTo(x + 52, 200)
        ..lineTo(x + 26, 200)
        ..close();
    }
    canvas.drawPath(rays, beam);
  }

  void _rail(Canvas canvas) {
    _rect(canvas, const Rect.fromLTWH(-2, 23, _Scene.size + 4, 6), c.hero, 1.2);
    final truss = Path()..moveTo(0, 29);
    for (var x = 0.0; x < _Scene.size; x += 8) {
      truss
        ..lineTo(x + 4, 23)
        ..lineTo(x + 8, 29);
    }
    canvas.drawPath(truss, _ink(.5, .45));
  }

  /// [turns] vòng mỗi 24s; răng đối xứng nên số lẻ vòng vẫn lặp liền mạch.
  void _gear(
    Canvas canvas,
    Offset at,
    double r,
    Path path,
    double turns,
    Color color,
  ) {
    canvas.save();
    canvas.translate(at.dx, at.dy);
    canvas.rotate(_time / _kPeriod * turns * 2 * math.pi);
    _shape(canvas, path, color, 1.4);
    canvas.drawCircle(Offset.zero, r * .62, _ink(.7, .5));
    canvas.drawCircle(Offset.zero, r * .3, _fill(const Color(0xFF3B4466)));
    canvas.drawCircle(Offset.zero, r * .3, _ink(1.1));
    canvas.restore();
  }

  void _monitorBack(Canvas canvas, int i) {
    final frame = _frame(i);
    final glow = frame.inflate(7);
    canvas.drawOval(
      glow,
      _shaderPaint
        ..shader = const RadialGradient(
          colors: [Color(0x8C7FF6FF), Color(0x007FF6FF)],
        ).createShader(glow),
    );
    canvas.drawRect(
      Rect.fromLTWH(frame.center.dx - 1.5, frame.bottom, 3, 104 - frame.bottom),
      _fill(c.ink),
    );
    final rr = RRect.fromRectAndRadius(frame, const Radius.circular(1.5));
    canvas.drawRRect(rr, _fill(c.ink));
    if (selected == i) canvas.drawRRect(rr.inflate(.7), _line(c.hero, 1.4));
    canvas.drawRect(frame.deflate(1.5), _fill(const Color(0xFF0D1830)));
  }

  void _monitorFront(Canvas canvas, int i) {
    final frame = _frame(i);
    final screen = frame.deflate(1.5);

    // Code cuộn lên + con trỏ nhấp nháy.
    canvas.save();
    canvas.clipRect(screen);
    final scroll = _time * _scroll[i];
    final first = (scroll / 3).floor();
    final off = scroll % 3;
    for (var k = 0; k < 7; k++) {
      final n = first + k;
      final idx = (n + i * 3) % 8;
      canvas.drawRect(
        Rect.fromLTWH(
          screen.left + 1.5 + screen.width * _codeX[idx],
          screen.top + 1.2 + k * 3 - off,
          (screen.width - 3) * _codeW[idx],
          1.3,
        ),
        _fill(_code[(n + i) % 4]),
      );
    }
    if ((_time * 2).floor().isEven) {
      canvas.drawRect(
        Rect.fromLTWH(screen.left + 4 + i * 2.5, screen.bottom - 3.2, 2.2, 1.3),
        _fill(Colors.white),
      );
    }
    canvas.restore();

    _led(canvas, Offset(frame.right - 2, frame.top), i);
  }

  void _steamPuffs(Canvas canvas, double x) {
    for (var j = 0; j < 2; j++) {
      final p = (_time / 3 + j * .5) % 1.0;
      canvas.save();
      canvas.translate(x - .8 + j * 1.6, 98 - p * 3);
      canvas.drawPath(
        _steam,
        _line(Colors.white.withValues(alpha: (1 - p) * .85 * math.min(1, p * 4)), .6),
      );
      canvas.restore();
    }
  }

  void _arm(Canvas canvas, Offset a, Offset b, Offset hand, Color shirt) {
    canvas.drawLine(a, b, _ink(3.6));
    canvas.drawLine(b, hand, _ink(3.6));
    canvas.drawLine(a, b, _line(shirt, 2.2));
    canvas.drawLine(b, hand, _line(shirt, 2.2));
    canvas.drawCircle(hand, 1.5, _fill(_kSkin));
    canvas.drawCircle(hand, 1.5, _ink(.6));
  }

  /// Dev nhìn từ sau lưng: 0 đeo tai nghe lắc lư theo nhạc, 2 (lead) đội
  /// mũ bảo hộ, 3 đeo tai nghe, 4 vừa gõ vừa gãi đầu.
  void _dev(Canvas canvas, int i) {
    final cx = _Scene.slots[i].center.dx;
    final lead = i == _TeamArtState.middle;
    final lift = _lift(i);
    final shirt = _shirts[i];
    final headR = lead ? 6.6 : 6.0;
    final bob = i == 0 ? 0.0 : _wave(3, i * .23) * .4;
    final head = Offset(cx, 112 + bob + lift);
    final shoulderY = 117 + lift;

    _shape(canvas, _torsos[i], shirt);

    // Tay gõ phím: hai tay lệch pha, nhấc lên rồi gõ xuống.
    final scratching = i == 4;
    for (final side in [-1.0, 1.0]) {
      if (scratching && side > 0) continue;
      final tap = math.max(0.0, _wave(.4, i * .3 + (side > 0 ? .5 : 0))) * 1.4;
      _arm(
        canvas,
        Offset(cx + side * 9, shoulderY + 5),
        Offset(cx + side * 12, shoulderY - 3),
        Offset(cx + side * 8, 107 + lift - tap),
        shirt,
      );
    }

    canvas.save();
    if (i == 0) {
      // Lắc đầu theo nhạc, xoay quanh cổ.
      final neck = head + Offset(0, headR);
      canvas.translate(neck.dx, neck.dy);
      canvas.rotate(_wave(1) * .12);
      canvas.translate(-neck.dx, -neck.dy);
    }
    for (final side in [-1.0, 1.0]) {
      final ear = head + Offset(side * headR, 1);
      canvas.drawCircle(ear, 1.6, _fill(_kSkin));
      canvas.drawCircle(ear, 1.6, _ink(.7));
    }
    canvas.drawCircle(head, headR, _fill(_hair[i]));
    canvas.drawCircle(head, headR, _ink(1.2));

    if (i == 0 || i == 3) {
      canvas.drawArc(
        Rect.fromCircle(center: head, radius: headR + 1.4),
        math.pi,
        math.pi,
        false,
        _ink(1.6),
      );
      for (final side in [-1.0, 1.0]) {
        _rect(
          canvas,
          Rect.fromCenter(
            center: head + Offset(side * (headR + .6), 1),
            width: 3,
            height: 5.5,
          ),
          _kCyan,
          .8,
          1.2,
        );
      }
    }
    if (lead) {
      canvas.translate(head.dx, head.dy);
      _shape(canvas, _leadHat, c.hero, 1);
      _rect(canvas, Rect.fromLTWH(-headR - 2.5, -2, headR * 2 + 5, 2), c.hero, .9, 1);
    }
    canvas.restore();

    if (scratching) {
      _arm(
        canvas,
        Offset(cx + 9, shoulderY + 5),
        Offset(cx + 13, shoulderY - 4),
        Offset(cx + 5.5 + _wave(.5) * .9, head.dy - 4.5),
        shirt,
      );
    }
  }

  /// Xe con cầu trục chạy trên ray + tấm thép đung đưa.
  void _trolley(Canvas canvas) {
    final x = 24 + 150 * Curves.easeInOut.transform(_tri(24));
    canvas.drawCircle(Offset(x - 7, 29), 1.8, _fill(c.ink));
    canvas.drawCircle(Offset(x + 7, 29), 1.8, _fill(c.ink));
    _rect(canvas, Rect.fromLTWH(x - 11, 29.5, 22, 7), _kOrange, 1.2, 1.5);
    _rect(canvas, Rect.fromLTWH(x - 8, 31, 7, 3.6), const Color(0xFFFFB070), .7);

    canvas.save();
    canvas.translate(x, 36.5);
    canvas.rotate(_wave(4) * .06);
    canvas.drawLine(Offset.zero, const Offset(0, 9), _ink(1));
    _rect(canvas, const Rect.fromLTWH(-3.5, 9, 7, 4), c.hero, .9, 1);
    canvas.drawLine(const Offset(0, 13), const Offset(-13, 18), _ink(.8));
    canvas.drawLine(const Offset(0, 13), const Offset(13, 18), _ink(.8));
    _rect(canvas, const Rect.fromLTWH(-16, 18, 32, 6), _kSteel, 1.2, .8);
    canvas.drawLine(const Offset(-5, 18), const Offset(-5, 24), _ink(.7));
    canvas.drawLine(const Offset(5, 18), const Offset(5, 24), _ink(.7));
    canvas.restore();
  }

  void _welder(Canvas canvas) {
    final flicker =
        .35 + .65 * (.5 + .5 * _wave(1 / 3)) * (.5 + .5 * _wave(.8, .3));
    const feet = Offset(178, 194);
    _worker(canvas, feet, -1, vest: const Color(0xFF2F7DE0), weldGlow: flicker);

    final tip = feet + const Offset(-34 * _kWorkerScale, -58 * _kWorkerScale);
    final glow = Rect.fromCircle(center: tip, radius: 12);
    canvas.drawOval(
      glow,
      _shaderPaint
        ..shader = RadialGradient(
          colors: [
            Colors.white.withValues(alpha: .9 * flicker),
            const Color(0xFF9FE8FF).withValues(alpha: .55 * flicker),
            const Color(0x002FD3E0),
          ],
        ).createShader(glow),
    );

    // Tia lửa bắn ra rồi rơi xuống.
    for (var j = 0; j < 10; j++) {
      final life = (_time / .8 + j / 10) % 1.0;
      final a = -math.pi * (.1 + .8 * ((j * 7) % 10) / 10);
      final dirv = Offset(math.cos(a), math.sin(a));
      Offset at(double l) => tip + dirv * 20 * l + Offset(0, 22 * l * l);
      canvas.drawLine(
        at(math.max(0, life - .06)),
        at(life),
        _line(Color.lerp(Colors.white, c.hero, life)!.withValues(alpha: 1 - life), .9),
      );
    }
  }
}

// ============================================================
// CẢNH 2: DÂY CHUYỀN LẮP RÁP TỰ ĐỘNG
// ============================================================

class _LinePainter extends _ScenePainter {
  _LinePainter(super.a, super.layer);

  static const _windows = [
    Rect.fromLTWH(10, 8, 52, 48),
    Rect.fromLTWH(74, 8, 52, 48),
    Rect.fromLTWH(138, 8, 52, 48),
  ];
  static const _chimneys = [32.0, 98.0, 166.0];
  static const _orb = Offset(115, 20);
  static const _stars = [
    (18.0, 14.0),
    (44.0, 24.0),
    (86.0, 13.0),
    (102.0, 32.0),
    (150.0, 16.0),
    (176.0, 27.0),
    (60.0, 34.0),
  ];

  static final _windowClip = () {
    final p = Path();
    for (final w in _windows) {
      p.addRect(w);
    }
    return p;
  }();

  /// Mây dựng một lần (gốc ở mép trái), trôi bằng translate.
  static final _cloud = () {
    var p = Path()..addOval(Rect.fromCircle(center: const Offset(0, 3), radius: 4));
    for (final part in [
      Path()..addOval(Rect.fromCircle(center: const Offset(6, 0), radius: 5.5)),
      Path()..addOval(Rect.fromCircle(center: const Offset(12, 3), radius: 4)),
      Path()..addRect(const Rect.fromLTRB(0, 3, 12, 7)),
    ]) {
      p = Path.combine(PathOperation.union, p, part);
    }
    return p;
  }();

  /// Mũ tài xế xe nâng (toạ độ xe nâng).
  static final _driverHat = Path()
    ..moveTo(-7.8, -21)
    ..quadraticBezierTo(-7.4, -26.5, -4, -26.5)
    ..quadraticBezierTo(-.6, -26.5, -.2, -21)
    ..close();

  late final _plateFill =
      _label('ASSEMBLY LINE 01', 7, Paint()..color = Colors.white);
  late final _plateStroke = _label('ASSEMBLY LINE 01', 7, _ink(1.4));

  // ------------------------------------------------------------

  @override
  void back(Canvas canvas) {
    _wall(canvas);
    _outdoorBack(canvas);
    _plate(
      canvas,
      const Rect.fromLTWH(56, 59, 88, 11),
      const Color(0xFFE8384F),
      _plateFill,
      _plateStroke,
    );
    _floor(canvas);
    _slotHighlight(canvas);

    // Dầm treo robot.
    _rect(canvas, const Rect.fromLTWH(-2, 72, 204, 5), const Color(0xFF56618A), 1.2);
    for (var x = 4.0; x < 200; x += 12) {
      canvas.drawCircle(Offset(x, 74.5), .8, _fill(c.ink.withValues(alpha: .5)));
    }

    // Khung băng chuyền + con lăn.
    for (final x in [14.0, 60.0, 106.0, 152.0, 188.0]) {
      canvas.drawLine(Offset(x, 134), Offset(x, 140), _ink(2));
    }
    _rect(canvas, const Rect.fromLTWH(4, 126, 192, 8), const Color(0xFF2C3354), 1.2, 1);
    for (var x = 10.0; x < 196; x += 12) {
      canvas.drawCircle(Offset(x, 130.5), 2.4, _fill(const Color(0xFF8A93A6)));
    }

    for (var i = 0; i < 5; i++) {
      final slot = _Scene.slots[i];
      final px = slot.right - 5;
      canvas.drawLine(Offset(px, 100), Offset(px, 126), _ink(1.2));
      _rect(canvas, Rect.fromLTWH(px - 3.2, 83.5, 6.4, 2), c.ink, .6, .5);
      _rect(canvas, Rect.fromLTWH(slot.center.dx - 9, 76, 12, 6), const Color(0xFF3B4466), 1, 1.5);
    }
  }

  @override
  void front(Canvas canvas) {
    _outdoorFront(canvas);
    _windowFrames(canvas);
    _conveyorFront(canvas);
    for (var i = 0; i < 5; i++) {
      _lamps(canvas, i);
      _robot(canvas, i);
    }
    _forklift(canvas);
    _agv(canvas);
  }

  // ------------------------------------------------------------

  void _wall(Canvas canvas) {
    canvas.drawRect(
      const Rect.fromLTWH(0, 0, 200, 140),
      _shaderPaint
        ..shader = LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: dark
              ? const [Color(0xFF2E2547), Color(0xFF3D3260)]
              : const [Color(0xFFF3E3C3), Color(0xFFE6CFA6)],
        ).createShader(const Rect.fromLTWH(0, 0, 200, 140)),
    );
    final brick = Path();
    for (var row = 0; row < 18; row++) {
      final y = row * 8.0;
      brick
        ..moveTo(0, y)
        ..lineTo(200, y);
      for (var x = row.isEven ? 0.0 : 8.0; x < 200; x += 16) {
        brick
          ..moveTo(x, y)
          ..lineTo(x, y + 8);
      }
    }
    canvas.drawPath(brick, _ink(.5, .12));
  }

  /// Phần tĩnh ngoài cửa sổ: trời, trăng, nhà máy xa + ống khói.
  void _outdoorBack(Canvas canvas) {
    const sky = Rect.fromLTWH(0, 8, 200, 48);
    canvas.save();
    canvas.clipPath(_windowClip);
    canvas.drawRect(
      sky,
      _shaderPaint
        ..shader = LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: dark
              ? const [Color(0xFF0B0A26), Color(0xFF2B1D5C)]
              : const [Color(0xFF8FD8FF), Color(0xFFDDF4FF)],
        ).createShader(sky),
    );
    if (dark) {
      canvas.drawCircle(_orb, 7, _fill(const Color(0xFFF6EFCF)));
      canvas.drawCircle(_orb + const Offset(-2, -2), 1.6, _fill(const Color(0xFFD9CFA0)));
      canvas.drawCircle(_orb + const Offset(2.5, 2), 1.1, _fill(const Color(0xFFD9CFA0)));
      canvas.drawCircle(_orb, 7, _ink(1));
    }

    final far = dark ? const Color(0xFF1C1442) : const Color(0xFF7B6AA8);
    for (final x in _chimneys) {
      _rect(canvas, Rect.fromLTWH(x - 3, 22, 6, 22), far, .8);
      canvas.drawRect(Rect.fromLTWH(x - 3, 24, 6, 2.5), _fill(const Color(0xFFE8384F)));
    }
    final skyline = Path()
      ..moveTo(0, 56)
      ..lineTo(0, 46);
    for (var x = 0.0; x < 200; x += 20) {
      skyline
        ..lineTo(x + 14, 39)
        ..lineTo(x + 14, 46)
        ..lineTo(x + 20, 46);
    }
    skyline
      ..lineTo(200, 56)
      ..close();
    _shape(canvas, skyline, far, .8);
    canvas.restore();
  }

  /// Phần động ngoài cửa sổ: sao lấp lánh / mặt trời xoay tia, mây trôi, khói.
  void _outdoorFront(Canvas canvas) {
    canvas.save();
    canvas.clipPath(_windowClip);
    if (dark) {
      for (final (x, y) in _stars) {
        canvas.drawCircle(
          Offset(x, y),
          .9,
          _fill(Colors.white.withValues(alpha: .4 + .6 * (.5 + .5 * _wave(2, x / 50)))),
        );
      }
    } else {
      canvas.save();
      canvas.translate(_orb.dx, _orb.dy);
      canvas.rotate(_time / _kPeriod * 2 * math.pi);
      for (var i = 0; i < 8; i++) {
        final d = Offset(math.cos(i * math.pi / 4), math.sin(i * math.pi / 4));
        canvas.drawLine(d * 10, d * 13, _ink(1.2));
      }
      canvas.restore();
      canvas.drawCircle(_orb, 8, _fill(c.hero));
      canvas.drawCircle(_orb, 8, _ink(1.2));
      // Mây trôi liên tục trái → phải (240 đơn vị / 24s).
      for (final off in [0.0, 120.0]) {
        canvas.save();
        canvas.translate((_time * 10 + off) % 240 - 20, 15);
        _shape(canvas, _cloud, Colors.white, .8);
        canvas.restore();
      }
    }

    final smoke = dark ? const Color(0xFF8A83B0) : Colors.white;
    for (var ci = 0; ci < _chimneys.length; ci++) {
      for (var k = 0; k < 4; k++) {
        final life = (_time / 4 + k / 4 + ci * .17) % 1.0;
        final o = Offset(
          _chimneys[ci] + life * 9 + math.sin(life * 6) * 1.5,
          21 - life * 20,
        );
        final r = 1.8 + life * 4.5;
        canvas.drawCircle(o, r, _fill(smoke.withValues(alpha: (1 - life) * .85)));
        canvas.drawCircle(o, r, _ink(.5, (1 - life) * .5));
      }
    }
    canvas.restore();
  }

  void _windowFrames(Canvas canvas) {
    for (final w in _windows) {
      canvas.drawLine(Offset(w.center.dx, w.top), Offset(w.center.dx, w.bottom), _ink(1));
      canvas.drawLine(Offset(w.left, w.center.dy), Offset(w.right, w.center.dy), _ink(1));
      canvas.drawRect(w, _ink(1.6));
      _rect(canvas, Rect.fromLTWH(w.left - 2, w.bottom, w.width + 4, 3), const Color(0xFFB9BDC8), .8);
    }
  }

  void _conveyorFront(Canvas canvas) {
    // Nan con lăn quay theo tốc độ băng (8 đơn vị/giây).
    final a = _time * 8 / 2.4;
    final spoke = Offset(math.cos(a), math.sin(a)) * 2.2;
    for (var x = 10.0; x < 196; x += 12) {
      canvas.drawLine(Offset(x, 130.5), Offset(x, 130.5) + spoke, _ink(.6));
    }

    canvas.save();
    canvas.clipRect(const Rect.fromLTWH(4, 100, 192, 28));
    final dash = _line(const Color(0xFF8A93A6), 1);
    final off = (_time * 8) % 8;
    for (var x = -4.0 + off; x < 200; x += 8) {
      canvas.drawLine(Offset(x, 127.4), Offset(x + 4, 127.4), dash);
    }
    // Hàng trên băng chạy trái → phải; mỗi kiện giữ màu riêng khi trôi.
    final moved = _time * 8;
    final shift = moved % 24;
    final passed = (moved / 24).floor();
    for (var k = -1; k < 9; k++) {
      final x = 4 + k * 24 + shift;
      _rect(canvas, Rect.fromLTWH(x, 118, 10, 8), (k - passed).isEven ? _kBox : _kCyan, 1, .8);
      canvas.drawLine(Offset(x + 5, 118), Offset(x + 5, 126), _ink(.5, .5));
    }
    canvas.restore();
  }

  /// Tháp đèn: đỏ / vàng / xanh = offline / đang check / ổn.
  /// Xanh sáng đều; đỏ, vàng "thở" sáng–tối để gây chú ý.
  void _lamps(Canvas canvas, int i) {
    final px = _Scene.slots[i].right - 5;
    final colors = [c.bad, c.warn, c.ok];
    final lit = switch (dots[i]) {
      _Dot.bad => 0,
      _Dot.warn => 1,
      _Dot.ok => 2,
      _Dot.none => -1,
    };
    final level = lit == 2 ? 1.0 : .2 + .8 * (.5 + .5 * _wave(1, i * .3));
    for (var k = 0; k < colors.length; k++) {
      final r = Rect.fromLTWH(px - 2.6, 85.5 + k * 5, 5.2, 5);
      final dim = Color.lerp(colors[k], c.ink, .65)!;
      if (k == lit) _glow(canvas, r.center, 7, colors[k], level);
      _rect(canvas, r, k == lit ? Color.lerp(dim, colors[k], level)! : dim, .8, .8);
    }
    if (selected == i) _star(canvas, Offset(px, 79));
  }

  /// Tay robot 2 khớp: vung qua lại, kẹp đóng khi hạ xuống gắp hàng.
  void _robot(Canvas canvas, int i) {
    final cx = _Scene.slots[i].center.dx - 3;
    final color = i == _TeamArtState.middle ? _kCyan : _kOrange;
    final s = _wave(3, i * .15);
    final shoulder = Offset(cx, 81 + (hover == i ? -2.0 : 0.0));
    final a1 = math.pi / 2 + .3 * s;
    final a2 = math.pi / 2 + .65 * s;
    final elbow = shoulder + Offset(math.cos(a1), math.sin(a1)) * 19;
    final wrist = elbow + Offset(math.cos(a2), math.sin(a2)) * 17;

    canvas.drawLine(shoulder, elbow, _ink(6));
    canvas.drawLine(elbow, wrist, _ink(6));
    canvas.drawLine(shoulder, elbow, _line(color, 3.6));
    canvas.drawLine(elbow, wrist, _line(color, 3.6));

    final dir = Offset(math.cos(a2), math.sin(a2));
    final nrm = Offset(-dir.dy, dir.dx);
    final open = (s.abs() * 2.6).clamp(.7, 2.6);
    for (final side in [-1.0, 1.0]) {
      canvas.drawLine(
        wrist + nrm * side * 1.4,
        wrist + nrm * side * open + dir * 4.5,
        _ink(1.4),
      );
    }
    canvas.drawCircle(shoulder, 3.2, _fill(c.hero));
    canvas.drawCircle(shoulder, 3.2, _ink(1));
    canvas.drawCircle(elbow, 2.6, _fill(const Color(0xFF3B4466)));
    canvas.drawCircle(elbow, 2.6, _ink(.9));
  }

  /// Xe nâng chạy qua lại: chạy thì hạ càng, dừng ở hai đầu thì nâng hàng.
  void _forklift(Canvas canvas) {
    const period = 12.0;
    const from = 32.0;
    const span = 78.0;
    const k = 1.15;
    final p = (_time % period) / period;
    final tri = _tri(period);
    final x = from + span * Curves.easeInOut.transform(tri);
    final pace = math.sin(tri * math.pi);
    final lift = 9 * (1 - pace);
    final travelled = p < .5 ? x - from : span + (from + span - x);

    canvas.save();
    canvas.translate(x, 194);
    canvas.scale(_facing(period) * k, k);

    // Khung mui + tài xế đội mũ bảo hộ.
    canvas.drawLine(const Offset(-10, -15), const Offset(-10, -31), _ink(1.6));
    canvas.drawLine(const Offset(3, -15), const Offset(3, -31), _ink(1.6));
    canvas.drawLine(const Offset(-12, -31), const Offset(5, -31), _ink(2));
    canvas.drawCircle(const Offset(-4, -20.5), 3.4, _fill(_kSkin));
    canvas.drawCircle(const Offset(-4, -20.5), 3.4, _ink(.8));
    _shape(canvas, _driverHat, c.hero, .8);

    _rect(canvas, const Rect.fromLTRB(-18, -16, 8, -5), const Color(0xFFFFB020), 1.3, 2);
    _rect(canvas, const Rect.fromLTRB(-19, -14, -14, -5), const Color(0xFF3B4466), 1, 1);
    _rect(canvas, const Rect.fromLTRB(8, -32, 11, -2), const Color(0xFF56618A), 1);

    canvas.save();
    canvas.translate(0, -lift);
    canvas.drawLine(const Offset(11, -3), const Offset(24, -3), _ink(1.6));
    _rect(canvas, const Rect.fromLTRB(11, -6.5, 24, -4), const Color(0xFFC9A47A), .8);
    _rect(canvas, const Rect.fromLTRB(12, -16, 23, -6.5), _kBox, 1, .6);
    canvas.restore();

    for (final wx in [-11.0, 3.0]) {
      _wheel(canvas, Offset(wx, -3.8), 3.8, travelled / (3.8 * k));
    }
    canvas.restore();
  }

  /// Xe tự hành (AGV) chở thùng, đèn hiệu nhấp nháy.
  void _agv(Canvas canvas) {
    final x = 154 + 30 * Curves.easeInOut.transform(_tri(8));
    canvas.save();
    canvas.translate(x, 194);
    _rect(canvas, const Rect.fromLTRB(-7, -16, 7, -8), _kCyan, 1, .6);
    canvas.drawLine(const Offset(0, -16), const Offset(0, -8), _ink(.5, .5));
    _rect(canvas, const Rect.fromLTRB(-11, -8, 11, -2.5), const Color(0xFFE8EDF5), 1.2, 1.5);
    canvas.drawLine(const Offset(-8, -5.2), const Offset(8, -5.2), _line(_kCyan, 1.2));
    final level = .5 + .5 * _wave(1);
    canvas.drawLine(const Offset(-9, -8), const Offset(-9, -12), _ink(.8));
    _glow(canvas, const Offset(-9, -13), 5, c.hero, level);
    canvas.drawCircle(
      const Offset(-9, -13),
      1.6,
      _fill(Color.lerp(Color.lerp(c.hero, c.ink, .6)!, c.hero, level)!),
    );
    canvas.drawCircle(const Offset(-9, -13), 1.6, _ink(.6));
    canvas.drawCircle(const Offset(-7, -1.8), 1.9, _fill(c.ink));
    canvas.drawCircle(const Offset(7, -1.8), 1.9, _fill(c.ink));
    canvas.restore();
  }
}

// ============================================================
// CẢNH 3: PHÒNG SERVER
// ============================================================

class _ServerPainter extends _ScenePainter {
  _ServerPainter(super.a, super.layer);

  static const _rackBody = Color(0xFF1D2238);
  static const _unit = Color(0xFF2A3150);
  static const _units = 7;
  static const _ledColors = [
    Color(0xFF9CFF8A),
    Color(0xFF7FF6FF),
    Color(0xFFFFB020),
  ];
  static const _screen = Rect.fromLTWH(59, 33, 82, 30);
  static const _clock = Offset(26, 46);
  static const _fan = Offset(173, 166);

  /// Luồng gió lạnh, gốc ở đầu phải (thổi sang trái).
  static final _air = Path()
    ..relativeQuadraticBezierTo(-3, -2, -6, 0)
    ..relativeQuadraticBezierTo(-3, 2, -6, 0);

  late final _plateFill = _label('SERVER ROOM', 7, Paint()..color = Colors.white);
  late final _plateStroke = _label('SERVER ROOM', 7, _ink(1.4));

  static Rect _rack(int i) {
    final s = _Scene.slots[i];
    return Rect.fromLTRB(s.left + 3, 75, s.right - 3, 138);
  }

  static Rect _unitRect(Rect rack, int u) =>
      Rect.fromLTWH(rack.left + 2.5, 79 + u * 8.4, rack.width - 5, 6.2);

  @override
  void back(Canvas canvas) {
    canvas.drawRect(
      const Rect.fromLTWH(0, 0, 200, 140),
      _shaderPaint
        ..shader = LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: dark
              ? const [Color(0xFF0F1630), Color(0xFF1B2550)]
              : const [Color(0xFFDFE7F3), Color(0xFFC9D4E6)],
        ).createShader(const Rect.fromLTWH(0, 0, 200, 140)),
    );

    // Trần: đèn tuýp + máng cáp vàng.
    canvas.drawRect(const Rect.fromLTWH(0, 0, 200, 14), _fill(const Color(0xFF2C3354)));
    for (final x in [16.0, 86.0, 156.0]) {
      _rect(
        canvas,
        Rect.fromLTWH(x, 13, 30, 3),
        dark ? const Color(0xFFFFF3B0) : Colors.white,
        .8,
        1.5,
      );
    }
    _rect(canvas, const Rect.fromLTWH(-2, 20, 204, 5), c.hero, 1);

    // Cáp thả từ máng xuống từng tủ.
    for (final s in _Scene.slots) {
      for (final (dx, color) in const [
        (-4.0, Color(0xFF2F7DE0)),
        (4.0, Color(0xFFFF7AB8)),
      ]) {
        final x = s.center.dx + dx;
        canvas.drawLine(Offset(x, 25), Offset(x, 75), _ink(2.4));
        canvas.drawLine(Offset(x, 25), Offset(x, 75), _line(color, 1.2));
      }
    }

    // Màn hình giám sát + biển tên.
    _rect(canvas, _screen.inflate(3), c.ink, 1.4, 2);
    canvas.drawRect(_screen, _fill(const Color(0xFF0D1830)));
    for (var y = _screen.top + 7.5; y < _screen.bottom; y += 7.5) {
      canvas.drawLine(
        Offset(_screen.left, y),
        Offset(_screen.right, y),
        _line(_kCyan.withValues(alpha: .15), .5),
      );
    }
    _plate(
      canvas,
      const Rect.fromLTWH(148, 34, 46, 12),
      const Color(0xFF2F7DE0),
      _plateFill,
      _plateStroke,
    );

    // Mặt đồng hồ treo tường (kim vẽ ở lớp động, chạy theo giờ thật).
    canvas.drawCircle(_clock, 10, _fill(Colors.white));
    canvas.drawCircle(_clock, 10, _ink(1.4));
    for (var h = 0; h < 12; h++) {
      final d = Offset(math.cos(h * math.pi / 6), math.sin(h * math.pi / 6));
      canvas.drawLine(_clock + d * 7.6, _clock + d * 8.8, _ink(h % 3 == 0 ? 1.1 : .5));
    }

    // Sàn nâng: tấm lát có lỗ thông gió.
    canvas.drawRect(
      const Rect.fromLTWH(0, 140, 200, 60),
      _fill(dark ? const Color(0xFF3A4466) : const Color(0xFFAEB8CC)),
    );
    final grid = Path();
    for (var x = 0.0; x <= 200; x += 20) {
      grid
        ..moveTo(x, 140)
        ..lineTo(x, 200);
    }
    for (var y = 140.0; y <= 200; y += 20) {
      grid
        ..moveTo(0, y)
        ..lineTo(200, y);
    }
    canvas.drawPath(grid, _ink(.6, .35));
    for (final (tx, ty) in const [(20.0, 140.0), (80.0, 160.0), (140.0, 140.0), (40.0, 180.0)]) {
      for (var k = 0; k < 9; k++) {
        canvas.drawCircle(
          Offset(tx + 5 + (k % 3) * 5, ty + 5 + (k ~/ 3) * 5),
          .9,
          _fill(c.ink.withValues(alpha: .35)),
        );
      }
    }
    _rect(canvas, const Rect.fromLTWH(-2, 137, 204, 3), const Color(0xFF56618A), 1);

    // Tủ rack.
    for (var i = 0; i < 5; i++) {
      final rack = _rack(i);
      _rect(canvas, Rect.fromLTWH(rack.left - 1, 72.5, rack.width + 2, 3), c.ink, .6, .5);
      _rect(canvas, rack, _rackBody, 1.4, 1.5);
      for (var u = 0; u < _units; u++) {
        final ur = _unitRect(rack, u);
        _rect(canvas, ur, _unit, .6, .6);
        for (var v = 0; v < 3; v++) {
          final x = ur.right - 2.5 - v * 2;
          canvas.drawLine(Offset(x, ur.top + 1.5), Offset(x, ur.bottom - 1.5), _ink(.5, .7));
        }
      }
      final fan = Offset(rack.center.dx + 2, _unitRect(rack, _units - 1).center.dy);
      canvas.drawCircle(fan, 2.6, _fill(const Color(0xFF0D1830)));
      canvas.drawCircle(fan, 2.6, _ink(.5));
      if (hover == i || selected == i) {
        canvas.drawRRect(
          RRect.fromRectAndRadius(rack.inflate(1.6), const Radius.circular(2.5)),
          _line(c.hero.withValues(alpha: selected == i ? 1 : .6), 1.6),
        );
      }
    }

    // Máy lạnh chính xác (CRAC).
    _rect(canvas, const Rect.fromLTWH(152, 148, 42, 46), const Color(0xFFE8EDF5), 1.2, 2);
    canvas.drawCircle(_fan, 11, _fill(const Color(0xFF2C3354)));
    canvas.drawCircle(_fan, 11, _ink(1));
    for (var k = 0; k < 4; k++) {
      canvas.drawLine(Offset(157, 182 + k * 2.6), Offset(189, 182 + k * 2.6), _ink(.7, .6));
    }
  }

  @override
  void front(Canvas canvas) {
    // Gói dữ liệu chạy trên máng cáp (20 đơn vị/giây, vòng 240).
    for (var k = 0; k < 9; k++) {
      final x = (_time * 20 + k * 240 / 9) % 240 - 20;
      canvas.drawCircle(Offset(x, 22.5), 1.3, _fill(_ledColors[k % 3]));
    }
    // …và chạy xuống từng tủ (bị màn hình che thì bỏ qua).
    final hidden = _screen.inflate(3);
    for (var i = 0; i < 5; i++) {
      final at = Offset(
        _Scene.slots[i].center.dx - 4,
        25 + (_time * 12 + i * 9) % 48,
      );
      if (!hidden.contains(at)) canvas.drawCircle(at, 1.1, _fill(Colors.white));
    }

    // Biểu đồ tải trên màn hình.
    canvas.save();
    canvas.clipRect(_screen);
    final graph = Path();
    for (var x = 0.0; x <= _screen.width; x += 2) {
      final v = .5 +
          .26 * math.sin(2 * math.pi * (x / 40 - _time / 4)) +
          .12 * math.sin(2 * math.pi * (x / 17 - _time / 3));
      final o = Offset(_screen.left + x, _screen.bottom - 3 - v * (_screen.height - 6));
      if (x == 0) {
        graph.moveTo(o.dx, o.dy);
      } else {
        graph.lineTo(o.dx, o.dy);
      }
    }
    canvas.drawPath(graph, _line(const Color(0xFF9CFF8A), 1.1));
    for (var b = 0; b < 6; b++) {
      final h = 3 + 6 * (.5 + .5 * _wave(1.5, b * .17));
      canvas.drawRect(
        Rect.fromLTWH(_screen.right - 22 + b * 3.4, _screen.top + 12 - h, 2.2, h),
        _fill(_kCyan.withValues(alpha: .8)),
      );
    }
    canvas.restore();

    // Kim đồng hồ theo giờ thật.
    final now = DateTime.now();
    final sec = now.second + now.millisecond / 1000;
    final min = now.minute + sec / 60;
    final hour = now.hour % 12 + min / 60;
    for (final (turns, len, w, color) in [
      (hour / 12, 5.0, 1.6, c.ink),
      (min / 60, 7.5, 1.1, c.ink),
      (sec / 60, 8.0, .5, c.bad),
    ]) {
      final a = turns * 2 * math.pi - math.pi / 2;
      canvas.drawLine(_clock, _clock + Offset(math.cos(a), math.sin(a)) * len, _line(color, w));
    }
    canvas.drawCircle(_clock, 1, _fill(c.ink));

    // Đèn từng máy chủ nháy ngẫu nhiên — sáng/tối dần giữa hai nhịp thay vì
    // bật/tắt cứng, quạt quay, đèn trạng thái nhóm.
    final beat = _time * 6;
    final step = beat.floor();
    final blend = Curves.easeInOut.transform(beat - step);
    const off = Color(0xFF3B4466);
    for (var i = 0; i < 5; i++) {
      final rack = _rack(i);
      for (var u = 0; u < _units; u++) {
        final ur = _unitRect(rack, u);
        for (var j = 0; j < 3; j++) {
          final n = i * 31 + u * 7 + j * 3;
          final a = _ScenePainter._hash(step + n);
          final b = _ScenePainter._hash(step + 1 + n);
          final v = ((a + (b - a) * blend - .3) / .25).clamp(0.0, 1.0);
          canvas.drawCircle(
            Offset(ur.left + 2 + j * 3, ur.center.dy),
            .9,
            _fill(Color.lerp(off, _ledColors[j], v)!),
          );
        }
      }
      final fan = Offset(rack.center.dx + 2, _unitRect(rack, _units - 1).center.dy);
      final a = _time * 4 * math.pi + i;
      for (var b = 0; b < 3; b++) {
        final d = Offset(math.cos(a + b * 2.094), math.sin(a + b * 2.094));
        canvas.drawLine(fan, fan + d * 2.2, _line(const Color(0xFF8A93A6), .9));
      }
      _led(canvas, Offset(rack.center.dx, 77), i, 1.6);
    }
    final sel = selected;
    if (sel != null) _star(canvas, Offset(_rack(sel).center.dx, 67));

    // Quạt máy lạnh + luồng gió lạnh.
    canvas.save();
    canvas.translate(_fan.dx, _fan.dy);
    canvas.rotate(_time * 3 * math.pi);
    for (var b = 0; b < 4; b++) {
      canvas.rotate(math.pi / 2);
      canvas.drawLine(Offset.zero, const Offset(0, -8.5), _line(const Color(0xFF8A93A6), 3));
    }
    canvas.restore();
    canvas.drawCircle(_fan, 2, _fill(c.ink));
    for (var k = 0; k < 3; k++) {
      final life = (_time / 2 + k / 3) % 1.0;
      canvas.save();
      canvas.translate(150 - life * 34, 158 + k * 9);
      canvas.drawPath(_air, _line(const Color(0xFF7FC8FF).withValues(alpha: (1 - life) * .9), 1.1));
      canvas.restore();
    }

    _walker(canvas, from: 26, span: 70, vest: const Color(0xFF2F7DE0));
  }
}

// ============================================================
// CẢNH 4: DÂY CHUYỀN MÁY ÉP
// ============================================================

class _PressPainter extends _ScenePainter {
  _PressPainter(super.a, super.layer);

  static const _body = Color(0xFFE8384F);
  static const _hot = Color(0xFFFF7A3D);
  static const _gauges = [Offset(80, 42), Offset(114, 42), Offset(148, 42)];

  late final _plateFill = _label('PRESS LINE', 7.5, Paint()..color = Colors.white);
  late final _plateStroke = _label('PRESS LINE', 7.5, _ink(1.4));
  late final _bamFill = _label('BAM!', 9, Paint()..color = const Color(0xFFFFD23F));
  late final _bamStroke = _label('BAM!', 9, _ink(2));

  /// Pha của máy ép [i] trong chu kỳ 2s (lệch nhau để dập lần lượt).
  double _phase(int i) => (_time / 2 + i * .2) % 1.0;

  /// 0 = tấm ép ở trên, 1 = ép xuống hết: xuống nhanh, giữ, lên chậm.
  double _press(double p) {
    if (p < .25) return Curves.easeIn.transform(p / .25);
    if (p < .45) return 1;
    return 1 - Curves.easeInOut.transform((p - .45) / .55);
  }

  @override
  void back(Canvas canvas) {
    canvas.drawRect(
      const Rect.fromLTWH(0, 0, 200, 140),
      _shaderPaint
        ..shader = LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: dark
              ? const [Color(0xFF2A1A2E), Color(0xFF3D2440)]
              : const [Color(0xFFF0D9C4), Color(0xFFE3BFA0)],
        ).createShader(const Rect.fromLTWH(0, 0, 200, 140)),
    );

    // Ống dẫn trên trần + van tay quay.
    _rect(canvas, const Rect.fromLTWH(-2, 6, 204, 5), const Color(0xFFB9BDC8), 1, 2.5);
    _rect(canvas, const Rect.fromLTWH(-2, 14, 204, 4), _body, 1, 2);
    for (var x = 20.0; x < 200; x += 40) {
      _rect(canvas, Rect.fromLTWH(x, 4.5, 3, 15), const Color(0xFF56618A), .8);
    }
    const valve = Offset(60, 8.5);
    canvas.drawCircle(valve, 4.5, _ink(2.6));
    canvas.drawCircle(valve, 4.5, _line(c.hero, 1.4));
    canvas.drawLine(valve - const Offset(4.5, 0), valve + const Offset(4.5, 0), _ink(.8));
    canvas.drawLine(valve - const Offset(0, 4.5), valve + const Offset(0, 4.5), _ink(.8));

    // Ống thuỷ lực xuống từng máy ép.
    for (final s in _Scene.slots) {
      final x = s.right - 7;
      canvas.drawLine(Offset(x, 18), Offset(x, 72), _ink(2.6));
      canvas.drawLine(Offset(x, 18), Offset(x, 72), _line(_body, 1.4));
    }
    _plate(
      canvas,
      const Rect.fromLTWH(8, 30, 46, 13),
      const Color(0xFF2F7DE0),
      _plateFill,
      _plateStroke,
    );

    // Mặt đồng hồ áp suất (vùng đỏ cuối thang).
    for (final g in _gauges) {
      canvas.drawCircle(g, 9, _fill(Colors.white));
      canvas.drawCircle(g, 9, _ink(1.3));
      canvas.drawArc(
        Rect.fromCircle(center: g, radius: 6.8),
        2.25 * math.pi - .9,
        .9,
        false,
        _line(c.bad, 2),
      );
      for (var k = 0; k <= 6; k++) {
        final a = .75 * math.pi + k * 1.5 * math.pi / 6;
        final d = Offset(math.cos(a), math.sin(a));
        canvas.drawLine(g + d * 6, g + d * 8, _ink(.6));
      }
    }

    _floor(canvas);
    _slotHighlight(canvas);

    // Băng tải + khung máy ép.
    for (final x in [14.0, 60.0, 106.0, 152.0, 188.0]) {
      canvas.drawLine(Offset(x, 134), Offset(x, 140), _ink(2));
    }
    _rect(canvas, const Rect.fromLTWH(4, 128, 192, 7), const Color(0xFF2C3354), 1.2, 1);
    for (var i = 0; i < 5; i++) {
      final s = _Scene.slots[i];
      _rect(canvas, Rect.fromLTWH(s.left + 4, 78, 4, 50), const Color(0xFF56618A), 1);
      _rect(canvas, Rect.fromLTWH(s.right - 8, 78, 4, 50), const Color(0xFF56618A), 1);
      _rect(
        canvas,
        Rect.fromLTWH(s.left + 2, 70, s.width - 4, 10),
        i == _TeamArtState.middle ? c.hero : _body,
        1.2,
        1.5,
      );
      _rect(canvas, Rect.fromLTWH(s.center.dx - 3.5, 80, 7, 11), const Color(0xFFB9BDC8), 1, 1);
    }
  }

  @override
  void front(Canvas canvas) {
    // Kim áp suất dao động theo nhịp ép, rung nhẹ.
    for (var g = 0; g < _gauges.length; g++) {
      final v = .55 + .3 * _wave(2, g * .3) + .04 * _wave(.25, g * .5);
      final a = .75 * math.pi + v * 1.5 * math.pi;
      final at = _gauges[g];
      canvas.drawLine(at, at + Offset(math.cos(a), math.sin(a)) * 6.5, _line(c.ink, 1.1));
      canvas.drawCircle(at, 1.3, _fill(c.ink));
    }

    // Phôi chạy trên băng, nóng đỏ dần sau mỗi máy ép.
    canvas.save();
    canvas.clipRect(const Rect.fromLTWH(4, 110, 192, 18));
    final shift = (_time * 6) % 24;
    for (var k = -1; k < 9; k++) {
      final x = 4 + k * 24 + shift;
      final heat = ((x - 4) / 192).clamp(0.0, 1.0);
      _rect(canvas, Rect.fromLTWH(x, 124, 14, 4), Color.lerp(_kSteel, _hot, heat)!, .8, .5);
    }
    canvas.restore();

    for (var i = 0; i < 5; i++) {
      _ram(canvas, i);
    }
    final sel = selected;
    if (sel != null) _star(canvas, Offset(_Scene.slots[sel].center.dx, 64));

    _walker(canvas, from: 24, span: 150, vest: const Color(0xFF2EA05A), cart: false);
  }

  void _ram(Canvas canvas, int i) {
    final s = _Scene.slots[i];
    final cx = s.center.dx;
    final p = _phase(i);
    final d = _press(p);
    final top = 98 + 20 * d;

    // Cần piston + tấm ép (đỏ dần khi ép, toả nhiệt).
    canvas.drawLine(Offset(cx, 90), Offset(cx, top), _ink(4.4));
    canvas.drawLine(Offset(cx, 90), Offset(cx, top), _line(const Color(0xFFE8EDF5), 2.6));
    if (d > .9) _glow(canvas, Offset(cx, top + 6), 11, _hot);
    _rect(
      canvas,
      Rect.fromLTWH(s.left + 7, top, s.width - 14, 6),
      Color.lerp(_kSteel, _hot, d * d)!,
      1.1,
      1,
    );

    // Va chạm: vạch tốc độ bắn ra hai bên.
    if (p >= .25 && p < .37) {
      final k = 1 - (p - .25) / .12;
      for (final side in [-1.0, 1.0]) {
        final x0 = cx + side * (s.width / 2 - 7);
        for (var j = 0; j < 3; j++) {
          final y = 117.4 + j * 2.6;
          canvas.drawLine(
            Offset(x0, y),
            Offset(x0 + side * 5 * k, y + (j - 1) * 1.5 * k),
            _ink(.8),
          );
        }
      }
    }
    // Máy chính hô "BAM!" mỗi lần dập.
    if (i == _TeamArtState.middle && p >= .25 && p < .45) {
      final k = math.min(1.0, (p - .25) / .2 * 3);
      canvas.save();
      canvas.translate(s.right - 2, 104);
      canvas.rotate(-.2);
      canvas.scale(.6 + .5 * Curves.easeOutBack.transform(k));
      final o = Offset(-_bamFill.width / 2, -_bamFill.height / 2);
      _bamStroke.paint(canvas, o);
      _bamFill.paint(canvas, o);
      canvas.restore();
    }

    // Hơi nước xì ra khi nâng lên.
    if (p >= .45 && p < .85) {
      final life = (p - .45) / .4;
      for (final side in [-1.0, 1.0]) {
        final o = Offset(
          cx + side * (s.width / 2 - 8) + side * life * 4,
          top - life * 10,
        );
        final r = 1.5 + life * 3;
        canvas.drawCircle(o, r, _fill(Colors.white.withValues(alpha: (1 - life) * .75)));
        canvas.drawCircle(o, r, _ink(.4, (1 - life) * .5));
      }
    }

    _led(canvas, Offset(s.left + 6, 75), i, 1.8);
  }
}

// ============================================================
// CẢNH 5: KHO HÀNG
// ============================================================

class _WarehousePainter extends _ScenePainter {
  _WarehousePainter(super.a, super.layer);

  static const _doors = [
    Rect.fromLTWH(8, 9, 56, 53),
    Rect.fromLTWH(72, 9, 56, 53),
    Rect.fromLTWH(136, 9, 56, 53),
  ];

  /// Mặt trên xà kệ (đáy mỗi tầng hàng).
  static const _levels = [94.0, 114.0, 135.0];
  static const _upright = Color(0xFF2F7DE0);
  static const _curtainColor = Color(0xFF9AA6BD);
  static const _amber = Color(0xFFFFB020);

  /// Cửa cuốn giữa: 0 = đóng, 1 = mở (mở – chờ xe – đóng, chu kỳ 8s).
  double _open() {
    final p = (_time % 8) / 8;
    if (p < .15) return Curves.easeInOut.transform(p / .15);
    if (p < .6) return 1;
    if (p < .75) return 1 - Curves.easeInOut.transform((p - .6) / .15);
    return 0;
  }

  void _curtain(Canvas canvas, Rect r, double h) {
    final cr = Rect.fromLTWH(r.left, r.top, r.width, h);
    canvas.drawRect(cr, _fill(_curtainColor));
    for (var y = r.top + 4; y < cr.bottom - 2; y += 4) {
      canvas.drawLine(Offset(r.left, y), Offset(r.right, y), _ink(.5, .35));
    }
    _rect(canvas, Rect.fromLTWH(r.left, cr.bottom - 2.5, r.width, 2.5), const Color(0xFF56618A), .8);
  }

  void _doorFrame(Canvas canvas, Rect r) {
    canvas.drawRect(r.inflate(1.5), _line(c.hero, 3));
    canvas.drawRect(r.inflate(3), _ink(1));
    canvas.drawRect(r, _ink(1));
  }

  /// Ngoài cửa giữa: đuôi xe tải lùi sát bến.
  void _outside(Canvas canvas, Rect r) {
    canvas.save();
    canvas.clipRect(r);
    canvas.drawRect(
      r,
      _shaderPaint
        ..shader = LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: dark
              ? const [Color(0xFF0B0A26), Color(0xFF2B1D5C)]
              : const [Color(0xFF8FD8FF), Color(0xFFDDF4FF)],
        ).createShader(r),
    );
    canvas.drawRect(
      Rect.fromLTWH(r.left, r.bottom - 10, r.width, 10),
      _fill(const Color(0xFF4A5272)),
    );
    final trailer = Rect.fromLTWH(r.left + 8, r.top + 8, r.width - 16, r.height - 14);
    _rect(canvas, trailer, const Color(0xFFE8EDF5), 1.2, 1);
    canvas.drawLine(
      Offset(trailer.center.dx, trailer.top),
      Offset(trailer.center.dx, trailer.bottom),
      _ink(.8),
    );
    for (final dx in [-3.0, 3.0]) {
      canvas.drawLine(
        Offset(trailer.center.dx + dx, trailer.top + 8),
        Offset(trailer.center.dx + dx, trailer.bottom - 10),
        _ink(1),
      );
    }
    // Dải phản quang đỏ/trắng + cản sau.
    for (var x = trailer.left; x < trailer.right; x += 6) {
      canvas.drawRect(
        Rect.fromLTWH(x, trailer.bottom - 5, 3, 2),
        _fill(const Color(0xFFE8384F)),
      );
    }
    canvas.drawRect(
      Rect.fromLTWH(trailer.left - 2, trailer.bottom, trailer.width + 4, 2.5),
      _fill(c.ink),
    );
    canvas.restore();
  }

  @override
  void back(Canvas canvas) {
    canvas.drawRect(
      const Rect.fromLTWH(0, 0, 200, 140),
      _shaderPaint
        ..shader = LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: dark
              ? const [Color(0xFF1F2B3A), Color(0xFF2C3D52)]
              : const [Color(0xFFD6E2EA), Color(0xFFC2D2DE)],
        ).createShader(const Rect.fromLTWH(0, 0, 200, 140)),
    );

    // Cửa cuốn 1, 3 đóng; cửa giữa: cảnh ngoài (rèm cuốn ở lớp động).
    for (var d = 0; d < _doors.length; d++) {
      final r = _doors[d];
      if (d == 1) {
        _outside(canvas, r);
      } else {
        _curtain(canvas, r, r.height);
        _doorFrame(canvas, r);
      }
    }

    _floor(canvas);
    _slotHighlight(canvas);

    // Hàng trên kệ: kích cỡ / màu cố định theo vị trí.
    for (var i = 0; i < 5; i++) {
      final s = _Scene.slots[i];
      for (var lv = 0; lv < _levels.length; lv++) {
        var x = s.left + 4.5;
        for (var b = 0; b < 2; b++) {
          final n = i * 7 + lv * 3 + b;
          final w = 10 + 4 * _ScenePainter._hash(n);
          final h = 8 + 6 * _ScenePainter._hash(n + 50);
          if (x + w > s.right - 3) break;
          final color = _ScenePainter._hash(n + 99) > .8
              ? _kCyan
              : (_ScenePainter._hash(n + 77) > .85 ? const Color(0xFFE8384F) : _kBox);
          final bottom = _levels[lv];
          _rect(canvas, Rect.fromLTWH(x, bottom - h, w, h), color, .8, .5);
          canvas.drawLine(Offset(x + w / 2, bottom - h), Offset(x + w / 2, bottom), _ink(.5, .45));
          x += w + 2;
        }
      }
    }

    // Kệ pallet: xà cam, cột xanh, ray cho robot kho.
    for (final y in _levels) {
      _rect(canvas, Rect.fromLTWH(6, y, 188, 3), _kOrange, .8);
    }
    for (final s in _Scene.slots) {
      _rect(canvas, Rect.fromLTWH(s.left - .5, 72, 3, 66), _upright, .8);
    }
    _rect(canvas, Rect.fromLTWH(_Scene.band.right - 2.5, 72, 3, 66), _upright, .8);
    canvas.drawLine(const Offset(4, 71), const Offset(196, 71), _ink(1.6));
  }

  @override
  void front(Canvas canvas) {
    // Rèm cửa cuốn giữa + đèn xoay khi cửa đang chạy.
    final door = _doors[1];
    final open = _open();
    _curtain(canvas, door, door.height * (1 - open * .85));
    _doorFrame(canvas, door);
    // Đèn xoay: sáng dần khi cửa bắt đầu chạy, "quét" nhanh, tắt dần khi dừng.
    final motion = math.sin(open * math.pi);
    final level = motion * (.5 + .5 * _wave(1 / 3));
    final beacon = Offset(door.center.dx, 3.5);
    _glow(canvas, beacon, 6, _amber, level);
    canvas.drawCircle(
      beacon,
      2,
      _fill(Color.lerp(Color.lerp(_amber, c.ink, .6)!, _amber, level)!),
    );
    canvas.drawCircle(beacon, 2, _ink(.7));

    // Robot kho (AS/RS): chạy dọc kệ, bàn nâng lên xuống, chở thùng một chiều.
    final p = (_time % 12) / 12;
    final x = 18 + 164 * Curves.easeInOut.transform(_tri(12));
    final carY = 82 + 36 * (.5 + .5 * _wave(3));
    _rect(canvas, Rect.fromLTWH(x - 1.8, 71, 3.6, 66), const Color(0xFF56618A), .8);
    _rect(canvas, Rect.fromLTWH(x - 5, 68, 10, 4), const Color(0xFF3B4466), .8, 1);
    _rect(canvas, Rect.fromLTWH(x - 5, 135, 10, 3), const Color(0xFF3B4466), .8, 1);
    _rect(canvas, Rect.fromLTWH(x - 7, carY, 14, 3.5), c.hero, .9, .8);
    if (p < .5) _rect(canvas, Rect.fromLTWH(x - 5, carY - 7, 10, 7), _kBox, .8, .5);

    for (var i = 0; i < 5; i++) {
      _led(canvas, Offset(_Scene.slots[i].center.dx, 76), i, 1.7);
    }
    final sel = selected;
    if (sel != null) _star(canvas, Offset(_Scene.slots[sel].center.dx, 66.5));

    _walker(canvas, from: 26, span: 70, vest: const Color(0xFF2F7DE0));
    _drone(canvas);
  }

  /// Drone chở thùng bay lượn, cánh quạt nhoè.
  void _drone(Canvas canvas) {
    canvas.save();
    canvas.translate(150 + 20 * _wave(6), 160 + 6 * _wave(3, .25));
    canvas.rotate(_wave(6, .25) * .12);
    canvas.drawLine(const Offset(0, 2), const Offset(0, 9), _ink(.7));
    _rect(canvas, const Rect.fromLTWH(-4, 9, 8, 7), _kCyan, .9, .5);
    canvas.drawLine(const Offset(-10, -2), const Offset(10, -2), _ink(1.6));
    for (final sx in [-10.0, 10.0]) {
      final w = 4.5 * (.35 + .65 * _wave(.125, sx > 0 ? .25 : 0).abs());
      canvas.drawOval(
        Rect.fromCenter(center: Offset(sx, -3.6), width: w * 2, height: 1.6),
        _fill(c.ink.withValues(alpha: .55)),
      );
    }
    _rect(canvas, const Rect.fromLTWH(-6, -3.5, 12, 5), const Color(0xFFE8EDF5), 1, 2);
    canvas.drawCircle(
      const Offset(0, -1),
      1,
      _fill(Color.lerp(Color.lerp(c.ok, c.ink, .6)!, c.ok, .5 + .5 * _wave(1))!),
    );
    canvas.restore();
  }
}
