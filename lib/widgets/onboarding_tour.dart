import 'dart:html' as html;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../theme/dash_theme.dart';

// ============================================================
// ONBOARDING TOUR — hướng dẫn người mới, làm nổi từng nút chức năng
// ============================================================

/// 1 bước hướng dẫn. [target] = null → thẻ giữa màn hình (chào mừng).
/// Bước có [target] nhưng widget chưa hiển thị (vd. chưa có Frequently
/// visited) sẽ tự bỏ qua.
class TourStep {
  final GlobalKey? target;
  final IconData icon;
  final String title;
  final String body;

  /// Danh sách (icon, mô tả) — giới thiệu các nút nhỏ trong cùng 1 vùng.
  final List<(IconData, String)> items;

  /// Hình minh hoạ nhỏ (vd. 1 hàng phòng ban mẫu), hiện trong ô "Ví dụ".
  final Widget? example;

  const TourStep({
    this.target,
    required this.icon,
    required this.title,
    required this.body,
    this.items = const [],
    this.example,
  });
}

/// Đã xem hướng dẫn chưa (localStorage). Xem xong / bấm Bỏ qua → đánh dấu.
class OnboardingTour {
  static const _seenKey = 'itpro.tourSeen';

  static bool get seen {
    try {
      return html.window.localStorage[_seenKey] == '1';
    } catch (_) {
      return true; // không đọc được storage → không tự bật làm phiền
    }
  }

  static void markSeen() {
    try {
      html.window.localStorage[_seenKey] = '1';
    } catch (_) {}
  }

  static Future<void> show(BuildContext context, List<TourStep> steps) {
    return showGeneralDialog<void>(
      context: context,
      barrierDismissible: false,
      barrierColor: Colors.transparent,
      barrierLabel: 'Hướng dẫn sử dụng',
      transitionDuration: Motion.of(context, Motion.fast),
      transitionBuilder: (_, a, _, child) =>
          FadeTransition(opacity: a, child: child),
      pageBuilder: (_, _, _) => _TourView(steps: steps),
    ).whenComplete(markSeen);
  }
}

class _TourView extends StatefulWidget {
  final List<TourStep> steps;
  const _TourView({required this.steps});

  @override
  State<_TourView> createState() => _TourViewState();
}

class _TourViewState extends State<_TourView> with WidgetsBindingObserver {
  int _i = 0;
  Rect? _rect;
  final _focus = FocusNode(debugLabel: 'tour');

  /// Các bước hiển thị được (target đang có trên màn hình), tính lúc mở.
  late final List<TourStep> _steps = widget.steps
      .where((s) => s.target == null || s.target!.currentContext != null)
      .toList();

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    WidgetsBinding.instance.addPostFrameCallback((_) => _goto(0));
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _focus.dispose();
    super.dispose();
  }

  /// Đổi kích thước cửa sổ → layout dashboard đổi → đo lại vùng sáng.
  @override
  void didChangeMetrics() {
    WidgetsBinding.instance.addPostFrameCallback((_) => _measure());
  }

  Future<void> _goto(int i) async {
    if (!mounted) return;
    if (i < 0) return;
    if (i >= _steps.length) return _close();
    setState(() => _i = i);

    final ctx = _steps[i].target?.currentContext;
    if (ctx != null && ctx.mounted) {
      // Cuộn cho vùng cần giới thiệu vào giữa tầm nhìn.
      await Scrollable.ensureVisible(
        ctx,
        alignment: .25,
        duration: Motion.of(context, const Duration(milliseconds: 300)),
        curve: Motion.curve,
      );
      // Đợi layout sau khi cuộn xong rồi mới đo vị trí.
      await WidgetsBinding.instance.endOfFrame;
    }
    _measure();
  }

  void _measure() {
    if (!mounted || _steps.isEmpty) return;
    Rect? r;
    final ro = _steps[_i].target?.currentContext?.findRenderObject();
    if (ro is RenderBox && ro.attached && ro.hasSize) {
      r = ro.localToGlobal(Offset.zero) & ro.size;
    }
    if (r != _rect) setState(() => _rect = r);
  }

  void _close() {
    if (mounted) Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    if (_steps.isEmpty) return const SizedBox.shrink();
    final step = _steps[_i];
    final size = MediaQuery.sizeOf(context);
    final hole = _rect?.inflate(6);
    final d = Motion.of(context, const Duration(milliseconds: 280));

    return CallbackShortcuts(
      bindings: {
        const SingleActivator(LogicalKeyboardKey.escape): _close,
        const SingleActivator(LogicalKeyboardKey.arrowRight): () =>
            _goto(_i + 1),
        const SingleActivator(LogicalKeyboardKey.enter): () => _goto(_i + 1),
        const SingleActivator(LogicalKeyboardKey.arrowLeft): () =>
            _goto(_i - 1),
      },
      child: Focus(
        focusNode: _focus,
        autofocus: true,
        child: Stack(
          children: [
            // Nền tối + lỗ sáng quanh vùng đang giới thiệu (có animation).
            Positioned.fill(
              child: GestureDetector(
                behavior: HitTestBehavior.opaque,
                onTap: () {}, // chặn bấm xuyên xuống dashboard
                // TweenAnimationBuilder không nhận end = null → bước không
                // có vùng sáng dùng rect rỗng ở giữa màn hình (lỗ thu nhỏ
                // dần về giữa, painter coi rect rỗng = phủ tối toàn màn).
                child: TweenAnimationBuilder<Rect?>(
                  tween: RectTween(
                    end:
                        hole ??
                        Rect.fromCenter(
                          center: size.center(Offset.zero),
                          width: 0,
                          height: 0,
                        ),
                  ),
                  duration: d,
                  curve: Motion.curve,
                  builder: (_, r, _) => CustomPaint(
                    painter: _ScrimPainter(
                      hole: r,
                      color: Colors.black.withValues(alpha: .62),
                    ),
                  ),
                ),
              ),
            ),
            // Thẻ chú thích: đặt dưới / trên / cạnh vùng sáng, tuỳ chỗ trống.
            Positioned.fill(
              child: CustomSingleChildLayout(
                delegate: _CalloutLayout(target: hole, screen: size),
                child: AnimatedSwitcher(
                  duration: Motion.of(context, Motion.fast),
                  child: _Callout(
                    key: ValueKey(_i),
                    step: step,
                    index: _i,
                    count: _steps.length,
                    onNext: () => _goto(_i + 1),
                    onBack: _i > 0 ? () => _goto(_i - 1) : null,
                    onSkip: _close,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ------------------------------------------------------------
// SCRIM
// ------------------------------------------------------------

class _ScrimPainter extends CustomPainter {
  final Rect? hole;
  final Color color;
  _ScrimPainter({required this.hole, required this.color});

  @override
  void paint(Canvas canvas, Size size) {
    final full = Offset.zero & size;
    // Lỗ quá nhỏ (đang thu về giữa / bước chào mừng) → phủ tối toàn màn.
    if (hole == null || hole!.width < 1 || hole!.height < 1) {
      canvas.drawRect(full, Paint()..color = color);
      return;
    }
    final rr = RRect.fromRectAndRadius(hole!, const Radius.circular(14));
    final path = Path()
      ..fillType = PathFillType.evenOdd
      ..addRect(full)
      ..addRRect(rr);
    canvas.drawPath(path, Paint()..color = color);
    // Viền vàng thương hiệu quanh vùng sáng.
    canvas.drawRRect(
      rr,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2.5
        ..color = Brand.yellow,
    );
  }

  @override
  bool shouldRepaint(_ScrimPainter old) =>
      old.hole != hole || old.color != color;
}

// ------------------------------------------------------------
// CALLOUT POSITION
// ------------------------------------------------------------

class _CalloutLayout extends SingleChildLayoutDelegate {
  final Rect? target;
  final Size screen;
  _CalloutLayout({required this.target, required this.screen});

  static const _margin = 16.0;
  static const _gap = 14.0;

  @override
  BoxConstraints getConstraintsForChild(BoxConstraints c) {
    final w = (c.maxWidth - _margin * 2).clamp(0.0, 380.0);
    return BoxConstraints(
      minWidth: w,
      maxWidth: w,
      maxHeight: (c.maxHeight - _margin * 2).clamp(0.0, double.infinity),
    );
  }

  @override
  Offset getPositionForChild(Size size, Size child) {
    double clampX(double x) => x.clamp(
      _margin,
      (size.width - child.width - _margin).clamp(_margin, double.infinity),
    );
    double clampY(double y) => y.clamp(
      _margin,
      (size.height - child.height - _margin).clamp(_margin, double.infinity),
    );

    final t = target;
    if (t == null) {
      return Offset(
        (size.width - child.width) / 2,
        (size.height - child.height) / 2,
      );
    }
    // Dưới
    if (size.height - t.bottom - _gap - _margin >= child.height) {
      return Offset(clampX(t.left), t.bottom + _gap);
    }
    // Trên
    if (t.top - _gap - _margin >= child.height) {
      return Offset(clampX(t.left), t.top - _gap - child.height);
    }
    // Phải (vd. sidebar cao cả màn hình)
    if (size.width - t.right - _gap - _margin >= child.width) {
      return Offset(t.right + _gap, clampY(t.top));
    }
    // Trái
    if (t.left - _gap - _margin >= child.width) {
      return Offset(t.left - _gap - child.width, clampY(t.top));
    }
    // Không đủ chỗ → đè lên đáy màn hình.
    return Offset(
      (size.width - child.width) / 2,
      size.height - child.height - _margin,
    );
  }

  @override
  bool shouldRelayout(_CalloutLayout old) =>
      old.target != target || old.screen != screen;
}

// ------------------------------------------------------------
// CALLOUT CARD
// ------------------------------------------------------------

class _Callout extends StatelessWidget {
  final TourStep step;
  final int index;
  final int count;
  final VoidCallback onNext;
  final VoidCallback? onBack;
  final VoidCallback onSkip;

  const _Callout({
    super.key,
    required this.step,
    required this.index,
    required this.count,
    required this.onNext,
    required this.onBack,
    required this.onSkip,
  });

  @override
  Widget build(BuildContext context) {
    final c = context.dash;
    final last = index == count - 1;

    return Material(
      color: c.surface,
      elevation: 16,
      shadowColor: Colors.black54,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(14),
        side: BorderSide(color: c.border),
      ),
      child: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(18, 16, 18, 14),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                Container(
                  width: 32,
                  height: 32,
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    color: Brand.yellow,
                    borderRadius: BorderRadius.circular(9),
                  ),
                  child: Icon(
                    step.icon,
                    size: 17,
                    color: const Color(0xFF111827),
                  ),
                ),
                const SizedBox(width: 11),
                Expanded(
                  child: Text(
                    step.title,
                    style: displayText(
                      size: 16,
                      weight: FontWeight.w700,
                      color: c.text,
                    ),
                  ),
                ),
                Text(
                  '${index + 1}/$count',
                  style: TextStyle(
                    color: c.muted,
                    fontSize: 12,
                    fontFeatures: const [FontFeature.tabularFigures()],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 10),
            Text(
              step.body,
              style: TextStyle(color: c.textSoft, fontSize: 13.5, height: 1.5),
            ),
            if (step.example != null) ...[
              const SizedBox(height: 12),
              Container(
                padding: const EdgeInsets.fromLTRB(12, 8, 12, 10),
                decoration: BoxDecoration(
                  color: c.bg,
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: c.border),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'VÍ DỤ',
                      style: TextStyle(
                        color: c.muted,
                        fontSize: 10.5,
                        fontWeight: FontWeight.w700,
                        letterSpacing: .8,
                      ),
                    ),
                    const SizedBox(height: 6),
                    step.example!,
                  ],
                ),
              ),
            ],
            if (step.items.isNotEmpty) ...[
              const SizedBox(height: 10),
              for (final (icon, text) in step.items)
                Padding(
                  padding: const EdgeInsets.only(top: 6),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Container(
                        width: 24,
                        height: 24,
                        alignment: Alignment.center,
                        decoration: BoxDecoration(
                          color: c.surface2,
                          borderRadius: BorderRadius.circular(6),
                          border: Border.all(color: c.border),
                        ),
                        child: Icon(icon, size: 13, color: c.text),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Padding(
                          padding: const EdgeInsets.only(top: 3),
                          child: Text(
                            text,
                            style: TextStyle(
                              color: c.textSoft,
                              fontSize: 13,
                              height: 1.4,
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
            ],
            const SizedBox(height: 14),
            // Chấm tiến độ
            Row(
              children: [
                for (var k = 0; k < count; k++)
                  AnimatedContainer(
                    duration: Motion.of(context, Motion.fast),
                    margin: const EdgeInsets.only(right: 4),
                    width: k == index ? 16 : 6,
                    height: 6,
                    decoration: BoxDecoration(
                      color: k == index ? Brand.yellow : c.border,
                      borderRadius: BorderRadius.circular(99),
                    ),
                  ),
              ],
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                if (!last)
                  TextButton(
                    onPressed: onSkip,
                    style: TextButton.styleFrom(foregroundColor: c.muted),
                    child: const Text('Bỏ qua'),
                  ),
                const Spacer(),
                if (onBack != null) ...[
                  OutlinedButton(
                    onPressed: onBack,
                    style: OutlinedButton.styleFrom(
                      foregroundColor: c.text,
                      side: BorderSide(color: c.border),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(9),
                      ),
                    ),
                    child: const Text('Trước'),
                  ),
                  const SizedBox(width: 8),
                ],
                FilledButton(
                  onPressed: onNext,
                  style: FilledButton.styleFrom(
                    backgroundColor: c.ink,
                    foregroundColor: c.onInk,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(9),
                    ),
                  ),
                  child: Text(last ? 'Bắt đầu dùng' : 'Tiếp'),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
