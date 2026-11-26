import 'dart:html' as html;

import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:flutter/services.dart';

import '../services/status_store.dart';
import '../theme/dash_theme.dart';

// ============================================================
// HELPERS
// ============================================================

void openInNewTab(String url) => html.window.open(url, '_blank');

Future<void> copyUrl(BuildContext context, String url) async {
  await Clipboard.setData(ClipboardData(text: url));
  if (!context.mounted) return;
  final messenger = ScaffoldMessenger.of(context);
  messenger.hideCurrentSnackBar();
  messenger.showSnackBar(
    const SnackBar(
      content: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(LucideIcons.check, size: 16),
          SizedBox(width: 8),
          Text('Copied'),
        ],
      ),
      width: 140,
      duration: Duration(milliseconds: 1200),
    ),
  );
}

String two(int n) => n.toString().padLeft(2, '0');

String hms(DateTime t) => '${two(t.hour)}:${two(t.minute)}:${two(t.second)}';

/// " · last seen 5m ago", hoặc "" nếu chưa từng thấy online.
String lastSeenSuffix(DateTime? t) =>
    t == null ? '' : ' · last seen ${relativeTime(t)}';

String relativeTime(DateTime? t) {
  if (t == null) return 'never';
  final d = DateTime.now().difference(t);
  if (d.inSeconds < 60) return 'just now';
  if (d.inMinutes < 60) return '${d.inMinutes}m ago';
  if (d.inHours < 24) return '${d.inHours}h ago';
  return '${d.inDays}d ago';
}

({String host, int? port}) hostPort(String url) {
  final uri = Uri.tryParse(url.startsWith('http') ? url : 'http://$url');
  if (uri == null || uri.host.isEmpty) return (host: url, port: null);
  return (host: uri.host, port: uri.hasPort ? uri.port : null);
}

/// Host hiển thị: bỏ http(s):// và "/" cuối.
String displayHost(String url) {
  var u = url.trim().replaceFirst(
    RegExp(r'^https?://', caseSensitive: false),
    '',
  );
  while (u.endsWith('/')) {
    u = u.substring(0, u.length - 1);
  }
  return u;
}

/// Host để HIỂN THỊ nhiều dòng: chèn zero-width space (U+200B) sau
/// `. - : /` → chuỗi không khoảng trắng vẫn xuống dòng gọn ở các dấu đó
/// thay vì bị cắt "…". (Copy URL dùng url gốc, không ảnh hưởng.)
String breakableHost(String url) =>
    displayHost(url).replaceAllMapped(RegExp(r'[.\-:/]'), (m) => '${m[0]}​');

// ============================================================
// STATUS CHIP SPEC (Online / Slow / Offline...)
// ============================================================

typedef ChipSpec = ({String label, Color fg, Color bg});

ChipSpec statusChipSpec(SiteStatus s, StatusTone t) {
  switch (s.state) {
    case SiteState.online:
      final ms = s.latencyMs;
      if (ms == null) return (label: 'Online', fg: t.okFg, bg: t.okBg);
      return ms < kSlowMs
          ? (label: 'Online · $ms ms', fg: t.okFg, bg: t.okBg)
          : (label: 'Slow · $ms ms', fg: t.slowFg, bg: t.slowBg);
    case SiteState.authRequired:
      return (label: 'Login required', fg: t.slowFg, bg: t.slowBg);
    case SiteState.offline:
      return (label: 'Offline', fg: t.offFg, bg: t.offBg);
    case SiteState.checking:
      return (label: 'Checking…', fg: t.idleFg, bg: t.idleBg);
    case SiteState.unknown:
      return (label: 'Not checked', fg: t.idleFg, bg: t.idleBg);
  }
}

/// Màu chấm trạng thái (xanh / cam / đỏ / xám).
Color statusDotColor(SiteStatus s, StatusTone t) => switch (s.state) {
  SiteState.online => (s.latencyMs ?? 0) < kSlowMs ? t.okFg : t.slowFg,
  SiteState.authRequired || SiteState.checking => t.slowFg,
  SiteState.offline => t.offFg,
  SiteState.unknown => t.idleFg,
};

// ============================================================
// ICON TILE (màu theo phòng ban)
// ============================================================

class IconTile extends StatelessWidget {
  final IconData icon;
  final String dept;
  final double size;

  const IconTile({
    super.key,
    required this.icon,
    required this.dept,
    this.size = 44,
  });

  @override
  Widget build(BuildContext context) {
    final dc = DeptColor(context.dash.textSoft, context.dash.surface2);
    return Container(
      width: size,
      height: size,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: dc.bg,
        borderRadius: BorderRadius.circular(size / 4),
      ),
      child: Icon(icon, size: size * .48, color: dc.fg),
    );
  }
}

// ============================================================
// SOFT CHIP (fg trên bg nhạt)
// ============================================================

class SoftChip extends StatelessWidget {
  final String label;
  final Color fg;
  final Color bg;

  const SoftChip({
    super.key,
    required this.label,
    required this.fg,
    required this.bg,
  });

  SoftChip.spec(ChipSpec s, {Key? key})
    : this(key: key, label: s.label, fg: s.fg, bg: s.bg);

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(6),
      ),
      // Không dùng ellipsis: Flutter web làm tròn độ rộng → cắt mất ký tự cuối
      // ("Productio"). Chip nằm trong Wrap nên luôn đủ chỗ xuống dòng.
      child: Text(
        label,
        maxLines: 1,
        softWrap: false,
        style: TextStyle(
          color: fg,
          fontSize: 11.5,
          fontWeight: FontWeight.w600,
          height: 1.25,
          fontFeatures: const [FontFeature.tabularFigures()],
        ),
      ),
    );
  }
}

// ============================================================
// HOVER SURFACE — hover KHÔNG rebuild
// ============================================================

/// Bề mặt có hover (nền / viền / bóng) mà **không rebuild** khi chuột vào/ra.
///
/// Hover chỉ đổi 1 `ValueNotifier<bool>`; nền + viền + bóng do
/// `CustomPainter` lắng nghe notifier đó vẽ (`super(repaint:)`) →
/// hover = chỉ repaint, không build, không layout, không animation.
/// Không dùng `InkWell`/`setState` (đều rebuild khi hover).
///
/// Phần con cần đổi theo hover (vd chữ nút Open) → truyền [hover] từ ngoài
/// rồi dùng `ValueListenableBuilder` bọc đúng phần nhỏ đó.
class HoverSurface extends StatefulWidget {
  final Widget child;
  final VoidCallback? onTap;
  final double radius;
  final Color color;
  final Color hoverColor;
  final Color? borderColor;
  final Color? hoverBorderColor;

  /// Bóng khi hover (null = không bóng).
  final Color? hoverShadow;

  /// Cắt nội dung theo góc bo (card có viền màu phía trên).
  final bool clip;

  final ValueNotifier<bool>? hover;

  const HoverSurface({
    super.key,
    required this.child,
    required this.color,
    required this.hoverColor,
    this.onTap,
    this.radius = 10,
    this.borderColor,
    this.hoverBorderColor,
    this.hoverShadow,
    this.clip = false,
    this.hover,
  });

  @override
  State<HoverSurface> createState() => _HoverSurfaceState();
}

class _HoverSurfaceState extends State<HoverSurface> {
  ValueNotifier<bool>? _own;
  ValueNotifier<bool> get _hover =>
      widget.hover ?? (_own ??= ValueNotifier(false));

  @override
  void dispose() {
    _own?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final bw = widget.borderColor != null ? 1.0 : 0.0;
    Widget content = widget.child;
    if (widget.clip) {
      content = ClipRRect(
        borderRadius: BorderRadius.circular(widget.radius - bw),
        child: content,
      );
    }
    content = Padding(padding: EdgeInsets.all(bw), child: content);

    Widget w = CustomPaint(
      painter: _HoverSurfacePainter(
        hover: _hover,
        radius: widget.radius,
        color: widget.color,
        hoverColor: widget.hoverColor,
        border: widget.borderColor,
        hoverBorder: widget.hoverBorderColor ?? widget.borderColor,
        shadow: widget.hoverShadow,
      ),
      child: content,
    );

    if (widget.onTap != null) {
      w = GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: widget.onTap,
        child: w,
      );
    }

    return MouseRegion(
      cursor: widget.onTap != null
          ? SystemMouseCursors.click
          : MouseCursor.defer,
      onEnter: (_) => _hover.value = true,
      onExit: (_) => _hover.value = false,
      child: w,
    );
  }
}

class _HoverSurfacePainter extends CustomPainter {
  final ValueNotifier<bool> hover;
  final double radius;
  final Color color;
  final Color hoverColor;
  final Color? border;
  final Color? hoverBorder;
  final Color? shadow;

  _HoverSurfacePainter({
    required this.hover,
    required this.radius,
    required this.color,
    required this.hoverColor,
    required this.border,
    required this.hoverBorder,
    required this.shadow,
  }) : super(repaint: hover);

  @override
  void paint(Canvas canvas, Size size) {
    final h = hover.value;
    final rr = RRect.fromRectAndRadius(
      Offset.zero & size,
      Radius.circular(radius),
    );

    if (h && shadow != null) {
      canvas.drawRRect(
        rr.shift(const Offset(0, 6)),
        Paint()
          ..color = shadow!
          ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 9),
      );
    }

    canvas.drawRRect(rr, Paint()..color = h ? hoverColor : color);

    final b = h ? hoverBorder : border;
    if (b != null) {
      canvas.drawRRect(
        rr.deflate(.5),
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = 1
          ..color = b,
      );
    }
  }

  @override
  bool shouldRepaint(_HoverSurfacePainter old) =>
      old.hover != hover ||
      old.radius != radius ||
      old.color != color ||
      old.hoverColor != hoverColor ||
      old.border != border ||
      old.hoverBorder != hoverBorder ||
      old.shadow != shadow;
}

/// Chip "Cert warning": chỉ hiện khi site online (vẫn tính là online).
bool showCertWarning(SiteStatus s) => s.isReachable && s.certWarning;

class CertWarningChip extends StatelessWidget {
  const CertWarningChip({super.key});

  @override
  Widget build(BuildContext context) {
    final t = context.tone;
    return Tooltip(
      message: 'Chứng chỉ tự ký – trình duyệt sẽ cảnh báo khi mở',
      child: SoftChip(label: 'Cert warning', fg: t.slowFg, bg: t.slowBg),
    );
  }
}

// ============================================================
// STATUS PILL (đặt trên thumbnail)
// ============================================================

class StatusPill extends StatelessWidget {
  final SiteStatus status;
  final bool compact;

  const StatusPill({super.key, required this.status, this.compact = false});

  @override
  Widget build(BuildContext context) {
    final c = context.dash;
    final (Color color, String label) = switch (status.state) {
      SiteState.online => (
        c.ok,
        status.latencyMs == null ? 'Online' : 'Online · ${status.latencyMs}ms',
      ),
      SiteState.authRequired => (c.warn, 'Login required'),
      SiteState.offline => (c.bad, 'Offline'),
      SiteState.checking => (c.warn, 'Checking…'),
      SiteState.unknown => (c.muted, 'Not checked'),
    };

    return AnimatedSwitcher(
      duration: Motion.of(context, Motion.fast),
      child: Container(
        key: ValueKey(label),
        padding: EdgeInsets.symmetric(
          horizontal: compact ? 8 : 9,
          vertical: compact ? 3 : 4,
        ),
        decoration: BoxDecoration(
          color: const Color(0xCC0A0F1C),
          borderRadius: BorderRadius.circular(999),
          border: Border.all(color: color.withValues(alpha: .45)),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            StatusDot(color: color, pulse: status.isOnline),
            const SizedBox(width: 6),
            Text(
              label,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 11.5,
                fontWeight: FontWeight.w600,
                height: 1.1,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class StatusDot extends StatefulWidget {
  final Color color;
  final bool pulse;
  final double size;

  const StatusDot({
    super.key,
    required this.color,
    this.pulse = false,
    this.size = 7,
  });

  @override
  State<StatusDot> createState() => _StatusDotState();
}

class _StatusDotState extends State<StatusDot>
    with SingleTickerProviderStateMixin {
  late final AnimationController _c = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 1600),
  );

  void _sync() {
    if (widget.pulse && !Motion.reduced(context)) {
      if (!_c.isAnimating) _c.repeat();
    } else {
      _c.stop();
      _c.value = 0;
    }
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _sync();
  }

  @override
  void didUpdateWidget(covariant StatusDot oldWidget) {
    super.didUpdateWidget(oldWidget);
    _sync();
  }

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final s = widget.size;
    return SizedBox(
      width: s,
      height: s,
      child: AnimatedBuilder(
        animation: _c,
        builder: (_, _) => Stack(
          clipBehavior: Clip.none,
          alignment: Alignment.center,
          children: [
            if (_c.isAnimating)
              Transform.scale(
                scale: 1 + _c.value * 1.6,
                child: Container(
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: widget.color.withValues(alpha: .5 * (1 - _c.value)),
                  ),
                ),
              ),
            Container(
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: widget.color,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ============================================================
// CHIPS
// ============================================================

class DashChip extends StatelessWidget {
  final String label;
  final Color? color;
  final IconData? icon;

  const DashChip({super.key, required this.label, this.color, this.icon});

  @override
  Widget build(BuildContext context) {
    final c = context.dash;
    final fg = color ?? c.muted;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: (color ?? c.muted).withValues(alpha: color == null ? .1 : .14),
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: fg.withValues(alpha: .25)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (icon != null) ...[
            Icon(icon, size: 12, color: fg),
            const SizedBox(width: 4),
          ],
          Flexible(
            child: Text(
              label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                color: fg,
                fontSize: 11,
                fontWeight: FontWeight.w600,
                height: 1.2,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class TagChip extends StatelessWidget {
  final String tag;
  const TagChip(this.tag, {super.key});

  @override
  Widget build(BuildContext context) =>
      DashChip(label: tag.isEmpty ? 'Other' : tag, color: tagColor(tag));
}

// ============================================================
// ICON BUTTON nhỏ có hover + focus ring
// ============================================================

class DashIconButton extends StatelessWidget {
  final IconData icon;
  final String tooltip;
  final VoidCallback onPressed;
  final double size;

  const DashIconButton({
    super.key,
    required this.icon,
    required this.tooltip,
    required this.onPressed,
    this.size = 16,
  });

  @override
  Widget build(BuildContext context) {
    final c = context.dash;
    return Tooltip(
      message: tooltip,
      child: IconButton(
        onPressed: onPressed,
        icon: Icon(icon, size: size),
        color: c.muted,
        hoverColor: c.accent.withValues(alpha: .12),
        highlightColor: c.accent.withValues(alpha: .18),
        visualDensity: VisualDensity.compact,
        padding: const EdgeInsets.all(6),
        constraints: const BoxConstraints(minWidth: 30, minHeight: 30),
        style: IconButton.styleFrom(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
        ),
      ),
    );
  }
}
