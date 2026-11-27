import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:visibility_detector/visibility_detector.dart';

import '../models/website.dart';
import '../services/preview_image.dart';
import '../services/status_store.dart';
import '../services/website_service.dart';
import '../theme/dash_theme.dart';
import '../services/screenshot_store.dart';
import 'dash_ui.dart';

enum ThumbKind { dashboard, table, camera, printer, map }

ThumbKind thumbKindFor(Website w) {
  final s = '${w.type} ${w.name} ${w.url}'.toLowerCase();
  bool has(List<String> keys) => keys.any(s.contains);

  if (has(['printer', 'print', 'label'])) return ThumbKind.printer;
  if (has(['camera', 'cctv', 'cam/', 'video', 'stream'])) {
    return ThumbKind.camera;
  }
  if (has(['map', 'layout', 'floor', 'location'])) return ThumbKind.map;
  if (has(['report', 'document', 'doc', 'table', 'list', 'hr'])) {
    return ThumbKind.table;
  }
  return ThumbKind.dashboard;
}

/// Thumbnail theo /api/screenshot/meta:
///  ok      → ảnh screenshot (cache-bust bằng capturedAt)
///  loading → skeleton (store poll /meta 5s, dừng sau 60s)
///  blank   → giữ ảnh cũ nếu hasImage, không thì placeholder + "Open live"
///  offline → ảnh cũ (card phủ grayscale) hoặc placeholder
/// Ảnh lỗi / quá 8s → placeholder. Kích thước theo khung cha → không layout shift.
class SiteThumbnail extends StatefulWidget {
  final Website website;
  final SiteStatus status;
  final ShotMeta meta;
  final bool hover;
  final VoidCallback? onOpenLive;

  const SiteThumbnail({
    super.key,
    required this.website,
    required this.status,
    required this.meta,
    this.hover = false,
    this.onOpenLive,
  });

  @override
  State<SiteThumbnail> createState() => _SiteThumbnailState();
}

class _SiteThumbnailState extends State<SiteThumbnail> {
  static const _timeout = Duration(seconds: 8);
  static const _maxRetry = 2;

  bool _visible = false;
  String? _loadedSrc;

  /// Ảnh lỗi hẳn (đã retry) → placeholder.
  final Set<String> _failed = {};

  /// Quá 8s chưa về: hiện placeholder nhưng VẪN tải tiếp, về thì thay vào.
  final Set<String> _slow = {};
  final Map<String, int> _retries = {};
  Timer? _timer;
  Timer? _retryTimer;
  String? _timerSrc;

  String get _url => widget.website.url;

  String get _src {
    final m = widget.meta;
    return WebsiteService.screenshotUrl(
      _url,
      t: m.capturedRaw ?? m.capturedAt?.millisecondsSinceEpoch,
    );
  }

  bool get _offline =>
      widget.status.isOffline || widget.meta.state == ShotState.offline;

  /// null → skeleton; true → ảnh; false → placeholder.
  bool? get _wantImage {
    final m = widget.meta;
    switch (m.state) {
      case ShotState.unknown:
        return null;
      case ShotState.loading:
        // Đang chụp lại mà đã có ảnh cũ → hiện ảnh cũ, không skeleton.
        if (m.hasImage) return true;
        if (m.isLoading) return null;
        return false; // poll hết 60s → như blank
      case ShotState.ok:
        return true;
      case ShotState.blank:
      case ShotState.offline:
        return m.hasImage;
    }
  }

  @override
  void dispose() {
    _timer?.cancel();
    _retryTimer?.cancel();
    super.dispose();
  }

  void _arm(String src) {
    if (_timerSrc == src || _loadedSrc == src || _failed.contains(src)) return;
    _timer?.cancel();
    _timerSrc = src;
    _timer = Timer(_timeout, () {
      if (mounted && _loadedSrc != src) setState(() => _slow.add(src));
    });
  }

  void _loaded(String src) {
    if (!mounted || _loadedSrc == src) return;
    if (_timerSrc == src) _timer?.cancel();
    setState(() {
      _loadedSrc = src;
      _slow.remove(src);
    });
  }

  void _error(String src) {
    if (!mounted || _failed.contains(src) || _retryTimer?.isActive == true) {
      return;
    }
    final n = _retries[src] ?? 0;
    if (n < _maxRetry) {
      // Mạng chập chờn → thử lại (key mới để Image.network tải lại).
      _retryTimer = Timer(Duration(seconds: 2 + n * 3), () {
        if (mounted) setState(() => _retries[src] = n + 1);
      });
      return;
    }
    if (_timerSrc == src) _timer?.cancel();
    setState(() => _failed.add(src));
  }

  void _onVisibility(VisibilityInfo info) {
    final v = info.visibleFraction > 0.05;
    if (v != _visible && mounted) setState(() => _visible = v);
  }

  /// Ảnh xem trước người dùng tự tải lên → hiện thẳng, bỏ qua ảnh chụp tự động.
  Widget _custom(BuildContext context, String src) {
    final c = context.dash;
    return ClipRect(
      child: Stack(
        fit: StackFit.expand,
        children: [
          ColoredBox(color: c.surface2),
          Image(
            image: previewImageProvider(src),
            fit: BoxFit.cover,
            alignment: Alignment.topCenter,
            gaplessPlayback: true,
            errorBuilder: (_, _, _) => ThumbPlaceholder(
              kind: thumbKindFor(widget.website),
              color: tagColor(widget.website.type),
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final custom = widget.website.previewImage;
    if (custom != null) return _custom(context, custom);

    final c = context.dash;
    final want = _wantImage;
    final src = _src;
    final imageOk = want == true && !_failed.contains(src);

    if (imageOk && _visible) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) _arm(src);
      });
    }

    // Quá 8s mà chưa từng có ảnh → placeholder đè lên, ảnh vẫn tải phía dưới.
    final slow = imageOk && _loadedSrc == null && _slow.contains(src);

    final Widget content;
    if (imageOk && (_visible || _loadedSrc != null)) {
      final image = Image.network(
        src,
        key: ValueKey('$src#${_retries[src] ?? 0}'),
        fit: BoxFit.cover,
        alignment: Alignment.topCenter,
        width: double.infinity,
        height: double.infinity,
        // Giữ ảnh cũ trong lúc tải ảnh mới (cache-bust).
        gaplessPlayback: true,
        // Preview hiện trên MỌI card → không dùng <img> platform view
        // (16 cái sẽ rất nặng). BE phải bật CORS cho /api/screenshot;
        // thiếu CORS → errorBuilder → placeholder.
        webHtmlElementStrategy: WebHtmlElementStrategy.never,
        frameBuilder: (_, child, frame, sync) {
          if (frame != null || sync) {
            WidgetsBinding.instance.addPostFrameCallback((_) => _loaded(src));
          }
          return child;
        },
        errorBuilder: (_, _, _) {
          WidgetsBinding.instance.addPostFrameCallback((_) => _error(src));
          return const SizedBox.expand();
        },
      );
      content = slow
          ? Stack(
              fit: StackFit.expand,
              children: [
                image,
                ThumbPlaceholder(
                  kind: thumbKindFor(widget.website),
                  color: tagColor(widget.website.type),
                ),
              ],
            )
          : image;
    } else if (want == null || imageOk) {
      content = const SizedBox.expand();
    } else {
      content = ThumbPlaceholder(
        kind: thumbKindFor(widget.website),
        color: tagColor(widget.website.type),
      );
    }

    final showPlaceholder = (want != null && !imageOk) || slow;
    final showShimmer =
        want == null || (imageOk && _loadedSrc == null && !slow);
    final capturedAt = widget.meta.capturedAt;
    final reduce = Motion.reduced(context);

    return VisibilityDetector(
      key: ValueKey('thumb-${widget.website.id}-$_url'),
      onVisibilityChanged: _onVisibility,
      child: ClipRect(
        child: Stack(
          fit: StackFit.expand,
          children: [
            ColoredBox(color: c.surface2),
            AnimatedScale(
              scale: widget.hover && !reduce ? 1.03 : 1,
              duration: Motion.of(context),
              curve: Motion.curve,
              child: content,
            ),
            IgnorePointer(
              child: AnimatedOpacity(
                opacity: showShimmer ? 1 : 0,
                duration: Motion.of(context, Motion.fast),
                child: const Shimmer(),
              ),
            ),

            // Blank / ảnh lỗi (site vẫn sống) → mở iframe live trong modal.
            if (showPlaceholder && !_offline && widget.onOpenLive != null)
              Center(
                child: FilledButton.tonalIcon(
                  onPressed: widget.onOpenLive,
                  icon: const Icon(LucideIcons.circlePlay, size: 16),
                  label: const Text('Open live'),
                  style: FilledButton.styleFrom(
                    visualDensity: VisualDensity.compact,
                    textStyle: const TextStyle(
                      fontSize: 12.5,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ),

            // Hover: "captured Xm ago"
            if (capturedAt != null && !showPlaceholder)
              Positioned(
                right: 8,
                bottom: 8,
                child: IgnorePointer(
                  child: AnimatedOpacity(
                    opacity: widget.hover ? 1 : 0,
                    duration: Motion.of(context, Motion.fast),
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 3,
                      ),
                      decoration: BoxDecoration(
                        color: const Color(0xCC0A0F1C),
                        borderRadius: BorderRadius.circular(999),
                      ),
                      child: Text(
                        'captured ${relativeTime(capturedAt)}',
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 11,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
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


// ============================================================
// SHIMMER
// ============================================================

class Shimmer extends StatefulWidget {
  const Shimmer({super.key});

  @override
  State<Shimmer> createState() => _ShimmerState();
}

class _ShimmerState extends State<Shimmer> with SingleTickerProviderStateMixin {
  late final AnimationController _c = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 1400),
  );

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (Motion.reduced(context)) {
      _c.stop();
    } else if (!_c.isAnimating) {
      _c.repeat();
    }
  }

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final c = context.dash;
    return AnimatedBuilder(
      animation: _c,
      builder: (_, _) {
        final t = _c.value * 3 - 1;
        return DecoratedBox(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment(t - 1, -0.3),
              end: Alignment(t + 1, 0.3),
              colors: [c.surface2, c.border, c.surface2],
              stops: const [0.35, 0.5, 0.65],
            ),
          ),
        );
      },
    );
  }
}

// ============================================================
// PLACEHOLDER
// ============================================================

class ThumbPlaceholder extends StatelessWidget {
  final ThumbKind kind;
  final Color color;

  const ThumbPlaceholder({super.key, required this.kind, required this.color});

  @override
  Widget build(BuildContext context) {
    return CustomPaint(
      painter: _PlaceholderPainter(kind, color, context.dash),
      child: const SizedBox.expand(),
    );
  }
}

class _PlaceholderPainter extends CustomPainter {
  final ThumbKind kind;
  final Color color;
  final DashColors c;

  _PlaceholderPainter(this.kind, this.color, this.c);

  @override
  void paint(Canvas canvas, Size size) {
    final w = size.width;
    final h = size.height;

    canvas.drawRect(
      Offset.zero & size,
      Paint()
        ..shader = LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            Color.alphaBlend(color.withValues(alpha: .14), c.surface2),
            Color.alphaBlend(color.withValues(alpha: .04), c.surface),
          ],
        ).createShader(Offset.zero & size),
    );

    final fill = Paint()..color = color.withValues(alpha: .28);
    final soft = Paint()..color = color.withValues(alpha: .14);
    final line = Paint()
      ..color = color.withValues(alpha: .5)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.5;

    RRect rr(double l, double t, double ww, double hh, [double r = 4]) =>
        RRect.fromRectAndRadius(Rect.fromLTWH(l, t, ww, hh), Radius.circular(r));

    switch (kind) {
      case ThumbKind.dashboard:
        canvas.drawRRect(rr(w * .06, h * .08, w * .88, h * .1), soft);
        for (var i = 0; i < 3; i++) {
          canvas.drawRRect(
            rr(w * (.06 + i * .3), h * .24, w * .26, h * .18),
            fill,
          );
        }
        final bars = [.5, .8, .35, .65, .9, .45, .7];
        final bw = w * .88 / (bars.length * 1.6);
        for (var i = 0; i < bars.length; i++) {
          final bh = h * .38 * bars[i];
          canvas.drawRRect(
            rr(w * .06 + i * bw * 1.6, h * .9 - bh, bw, bh, 2),
            fill,
          );
        }
        break;

      case ThumbKind.table:
        canvas.drawRRect(rr(w * .06, h * .1, w * .88, h * .12), fill);
        for (var i = 0; i < 5; i++) {
          final y = h * (.28 + i * .13);
          canvas.drawRRect(
            rr(w * .06, y, w * .88, h * .09, 2),
            i.isEven ? soft : (Paint()..color = color.withValues(alpha: .07)),
          );
          canvas.drawRRect(rr(w * .09, y + h * .03, w * .3, h * .03, 2), fill);
        }
        break;

      case ThumbKind.camera:
        for (var r = 0; r < 2; r++) {
          for (var col = 0; col < 2; col++) {
            final rect = Rect.fromLTWH(
              w * (.06 + col * .45),
              h * (.08 + r * .44),
              w * .43,
              h * .4,
            );
            canvas.drawRRect(
              RRect.fromRectAndRadius(rect, const Radius.circular(4)),
              soft,
            );
            canvas.drawCircle(rect.center, rect.shortestSide * .18, line);
            canvas.drawCircle(
              rect.topRight + const Offset(-8, 8),
              2.5,
              Paint()..color = c.bad.withValues(alpha: .8),
            );
          }
        }
        break;

      case ThumbKind.printer:
        final cx = w / 2;
        final top = h * .2;
        canvas.drawRRect(rr(cx - w * .14, top, w * .28, h * .2, 3), soft);
        canvas.drawRRect(rr(cx - w * .24, top + h * .16, w * .48, h * .3, 8), fill);
        canvas.drawRRect(rr(cx - w * .16, top + h * .4, w * .32, h * .26, 3), soft);
        for (var i = 0; i < 3; i++) {
          canvas.drawRRect(
            rr(cx - w * .12, top + h * (.46 + i * .06), w * .24, 2.5, 1),
            fill,
          );
        }
        break;

      case ThumbKind.map:
        final grid = Paint()
          ..color = color.withValues(alpha: .12)
          ..strokeWidth = 1;
        for (var x = 0.0; x < w; x += w / 10) {
          canvas.drawLine(Offset(x, 0), Offset(x, h), grid);
        }
        for (var y = 0.0; y < h; y += h / 6) {
          canvas.drawLine(Offset(0, y), Offset(w, y), grid);
        }
        final path = Path()
          ..moveTo(w * .1, h * .8)
          ..cubicTo(w * .3, h * .3, w * .6, h * .9, w * .88, h * .25);
        canvas.drawPath(path, line);
        for (final p in [
          Offset(w * .22, h * .58),
          Offset(w * .55, h * .62),
          Offset(w * .82, h * .32),
        ]) {
          canvas.drawCircle(p, 6, fill);
          canvas.drawCircle(p, 2.5, Paint()..color = color);
        }
        break;
    }

    // Icon mờ ở giữa để nhận diện loại.
    final icon = switch (kind) {
      ThumbKind.dashboard => LucideIcons.layoutDashboard,
      ThumbKind.table => LucideIcons.table,
      ThumbKind.camera => LucideIcons.video,
      ThumbKind.printer => LucideIcons.printer,
      ThumbKind.map => LucideIcons.map,
    };
    final tp = TextPainter(
      text: TextSpan(
        text: String.fromCharCode(icon.codePoint),
        style: TextStyle(
          fontFamily: icon.fontFamily,
          package: icon.fontPackage,
          fontSize: math.min(w, h) * .22,
          color: color.withValues(alpha: .55),
        ),
      ),
      textDirection: TextDirection.ltr,
    )..layout();
    if (kind != ThumbKind.printer) {
      tp.paint(
        canvas,
        Offset(w - tp.width - w * .05, h - tp.height - h * .06),
      );
    }
  }

  @override
  bool shouldRepaint(covariant _PlaceholderPainter old) =>
      old.kind != kind || old.color != color || old.c != c;
}
