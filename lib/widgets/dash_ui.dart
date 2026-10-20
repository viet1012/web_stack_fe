import 'dart:html' as html;

import 'package:flutter/material.dart';
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
          Icon(Icons.check_rounded, size: 16),
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
          status.latencyMs == null
              ? 'Online'
              : 'Online · ${status.latencyMs}ms',
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
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(8),
          ),
        ),
      ),
    );
  }
}
