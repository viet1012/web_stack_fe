import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../models/website.dart';
import '../services/website_service.dart';
import '../theme/dash_theme.dart';

// ============================================================
// SITE ICON: favicon thật, fallback icon glyph
// ============================================================

/// Tile màu phòng ban nhạt. Glyph hiện ngay; favicon tải nền
/// (GET /api/websites/{id}/favicon) — có ảnh thì thay glyph bằng ảnh,
/// 204 / lỗi thì giữ glyph. Không chặn render card.
class SiteIcon extends StatefulWidget {
  final Website website;
  final double size;

  const SiteIcon({super.key, required this.website, this.size = 52});

  /// Tăng khi bấm Refresh → quên các icon "không có" + tải lại (cache-bust).
  static final retry = ValueNotifier<int>(0);

  static void forgetMissing() {
    _SiteIconState._missing.clear();
    retry.value++;
  }

  @override
  State<SiteIcon> createState() => _SiteIconState();
}

class _SiteIconState extends State<SiteIcon> {
  /// URL đã biết là không có favicon (204/lỗi) trong phiên này →
  /// không request lại khi card rebuild / remount (ImageCache không giữ lỗi).
  static final Set<String> _missing = {};

  String get _src {
    final u = WebsiteService.faviconUrl(widget.website.id);
    final v = SiteIcon.retry.value;
    return v == 0 ? u : '$u?r=$v';
  }

  @override
  void initState() {
    super.initState();
    SiteIcon.retry.addListener(_onRetry);
  }

  @override
  void dispose() {
    SiteIcon.retry.removeListener(_onRetry);
    super.dispose();
  }

  void _onRetry() {
    if (mounted) setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    final w = widget.website;
    final size = widget.size;
    final c = context.dash;
    final src = _src;

    // Favicon ~60% tile, glyph ~56%. Nền trung tính (không màu phòng ban).
    final img = size * .6;
    final glyph = Icon(siteIcon(w), size: size * .56, color: c.textSoft);

    return Container(
      width: size,
      height: size,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: c.surface2,
        borderRadius: BorderRadius.circular(size / 4),
      ),
      // id âm = không có trên BE → không gọi API.
      child: w.id < 0 || _missing.contains(src)
          ? glyph
          : Image.network(
              src,
              key: ValueKey(src),
              width: img,
              height: img,
              fit: BoxFit.contain, // object-fit: contain
              filterQuality: FilterQuality.medium,
              gaplessPlayback: true,
              // Mặc định tải + vẽ qua canvas (nhẹ). Chỉ khi canvas KHÔNG
              // giải mã được (favicon SVG) mới dùng thẻ <img> của trình
              // duyệt — trình duyệt vẽ được SVG. Ít site dùng SVG-only nên
              // số platform view vẫn nhỏ.
              webHtmlElementStrategy: WebHtmlElementStrategy.fallback,
              // Chưa có frame → glyph (không nháy ô trống).
              frameBuilder: (_, child, frame, sync) =>
                  frame != null || sync ? child : glyph,
              // 204 (body rỗng) / 404 / timeout → glyph.
              errorBuilder: (_, _, _) {
                if (_missing.add(src)) {
                  WidgetsBinding.instance.addPostFrameCallback((_) {
                    if (mounted) setState(() {});
                  });
                }
                return glyph;
              },
            ),
    );
  }
}

/// Tên icon lucide (config `icon`) → LucideIcons.
const Map<String, IconData> kSiteIcons = {
  'bar-chart': LucideIcons.chartColumn,
  'package': LucideIcons.package,
  'flame': LucideIcons.flame,
  'layers-2': LucideIcons.layers2,
  'press': LucideIcons.layers2,
  'layers': LucideIcons.layers,
  'zap': LucideIcons.zap,
  'trending-up': LucideIcons.trendingUp,
  'factory': LucideIcons.factory,
  'users': LucideIcons.users,
  'monitor': LucideIcons.monitor,
  'clipboard-list': LucideIcons.clipboardList,
  'wrench': LucideIcons.wrench,
  'folder': LucideIcons.folder,
  'shield-check': LucideIcons.shieldCheck,
  'warehouse': LucideIcons.warehouse,
  'globe': LucideIcons.globe,
};

/// Suy icon theo tên site khi config không có `icon`.
/// Thứ tự quan trọng: "Follow Sale Press" phải khớp trước "press".
const List<(String, String)> _byName = [
  ('followsale', 'trending-up'),
  ('costmonitor', 'bar-chart'),
  ('fixedasset', 'package'),
  ('heatguide', 'flame'),
  ('heatpress', 'press'),
  ('molyb', 'layers'),
  ('utility', 'zap'),
  ('productioncontrol', 'factory'),
  ('packingpo', 'clipboard-list'),
  ('patrol', 'shield-check'),
  ('warehouse', 'warehouse'),
  ('kvhpj', 'folder'),
  ('mamonitor', 'monitor'),
];

IconData siteIcon(Website w) {
  final key = w.icon?.trim().toLowerCase();
  if (key != null && kSiteIcons.containsKey(key)) return kSiteIcons[key]!;

  final name = w.name.toLowerCase();
  final compact = name.replaceAll(RegExp(r'[^a-z0-9]'), '');
  for (final (needle, icon) in _byName) {
    if (compact.contains(needle)) return kSiteIcons[icon]!;
  }

  final first = name.trim().split(RegExp(r'[\s\-_]+')).first;
  if (first == 'hr') return kSiteIcons['users']!;
  if (first == 'te') return kSiteIcons['wrench']!;

  return kSiteIcons['globe']!;
}
