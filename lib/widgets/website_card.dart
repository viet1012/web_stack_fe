import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../models/website.dart';
import '../services/auth_store.dart';
import '../services/screenshot_store.dart';
import '../services/status_store.dart';
import '../theme/dash_theme.dart';
import 'dash_ui.dart';
import 'site_icons.dart';
import 'site_thumbnail.dart';

/// Card tối giản: tên · chấm trạng thái · địa chỉ + 2 nút icon (mở tab mới,
/// copy) ở TRÊN, ảnh preview (luôn hiện) ở DƯỚI. Bấm ảnh = mở site.
/// Không dùng màu phòng ban.
class WebsiteCard extends StatefulWidget {
  final Website website;
  final ValueListenable<SiteStatus> status;
  final ValueListenable<ShotMeta> meta;
  final VoidCallback onOpen;

  /// Nút "Open live" trên ảnh (khi chưa có ảnh chụp) → dialog xem live.
  final VoidCallback? onOpenLive;

  /// Nút ẩn/hiện preview ở header (áp dụng cho mọi card).
  final bool showPreview;

  /// Gắn sao = thêm vào khung Favorites.
  final bool starred;
  final VoidCallback? onToggleStar;

  const WebsiteCard({
    super.key,
    required this.website,
    required this.status,
    required this.meta,
    required this.onOpen,
    this.onOpenLive,
    this.showPreview = true,
    this.starred = false,
    this.onToggleStar,
  });

  @override
  State<WebsiteCard> createState() => _WebsiteCardState();
}

class _WebsiteCardState extends State<WebsiteCard> {
  bool _copied = false;
  Timer? _copyTimer;

  @override
  void dispose() {
    _copyTimer?.cancel();
    super.dispose();
  }

  Future<void> _copy() async {
    await Clipboard.setData(ClipboardData(text: widget.website.url));
    if (!mounted) return;
    setState(() => _copied = true);
    _copyTimer?.cancel();
    _copyTimer = Timer(const Duration(milliseconds: 1400), () {
      if (mounted) setState(() => _copied = false);
    });
  }

  @override
  Widget build(BuildContext context) {
    final c = context.dash;
    final t = context.tone;
    final w = widget.website;

    return ValueListenableBuilder<SiteStatus>(
      valueListenable: widget.status,
      builder: (context, s, _) {
        final spec = statusChipSpec(s, t);
        final cert = showCertWarning(s);

        return Semantics(
          container: true,
          label: '${w.name}, ${spec.label}',
          // Hover: chỉ repaint viền/bóng — nội dung KHÔNG rebuild.
          child: HoverSurface(
            radius: 12,
            clip: true,
            color: c.surface,
            hoverColor: c.surface,
            borderColor: s.isOffline ? t.offBorder : c.border,
            hoverBorderColor: s.isOffline ? t.offBorder : c.faint,
            hoverShadow: c.shadow,
            // Card được giãn bằng card cao nhất cùng hàng; Spacer dồn khoảng
            // trống xuống dưới phần chữ → khung ảnh luôn bám đáy, thẳng hàng.
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // Tên · chấm · địa chỉ · nút (đặt trên ảnh)
                Padding(
                  padding: const EdgeInsets.fromLTRB(10, 10, 6, 10),
                  child: Row(
                    children: [
                      SiteIcon(website: w, size: 44),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                // Không cắt "…": tên dài tự xuống dòng.
                                Flexible(
                                  child: Text(
                                    w.name,
                                    softWrap: true,
                                    style: TextStyle(
                                      color: c.text,
                                      fontSize: 14,
                                      fontWeight: FontWeight.w600,
                                      height: 1.25,
                                    ),
                                  ),
                                ),
                                const SizedBox(width: 7),
                                // Trạng thái = 1 dấu chấm (chi tiết ở tooltip).
                                Tooltip(
                                  message: cert
                                      ? '${spec.label} · Cert warning'
                                      : spec.label,
                                  child: StatusDot(
                                    color: statusDotColor(s, t),
                                    size: 8,
                                  ),
                                ),
                                // Site Private (người dùng thêm): ổ khoá.
                                if (w.isPrivate) ...[
                                  const SizedBox(width: 5),
                                  Tooltip(
                                    message:
                                        w.owner == auth.user?.username
                                        ? 'Private · chỉ bạn và admin thấy'
                                        : 'Private · của ${w.owner ?? '—'}',
                                    child: Icon(
                                      LucideIcons.lock,
                                      size: 12.5,
                                      color: c.muted,
                                    ),
                                  ),
                                ],
                                if (cert) ...[
                                  const SizedBox(width: 5),
                                  Tooltip(
                                    message:
                                        'Chứng chỉ tự ký – trình duyệt sẽ cảnh báo khi mở',
                                    child: Icon(
                                      LucideIcons.shieldAlert,
                                      size: 13,
                                      color: t.slowFg,
                                    ),
                                  ),
                                ],
                              ],
                            ),
                            const SizedBox(height: 2),
                            Tooltip(
                              message: w.url,
                              // Không cắt "…": host dài xuống dòng tại . - : /
                              child: Text(
                                breakableHost(w.url),
                                softWrap: true,
                                style: monoText(size: 11.5, color: c.hostText),
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(width: 4),
                      if (widget.onToggleStar != null)
                        _IconBtn(
                          // ★ đặc (Material) khi đã gắn — Lucide chỉ có
                          // bản viền, không thể hiện được trạng thái "đã gắn".
                          icon: widget.starred
                              ? Icons.star_rounded
                              : LucideIcons.star,
                          tooltip: widget.starred
                              ? 'Bỏ sao (gỡ khỏi Favorites)'
                              : 'Gắn sao (thêm vào Favorites)',
                          color: widget.starred ? Brand.yellow : null,
                          size: widget.starred ? 19 : 16,
                          onTap: widget.onToggleStar!,
                        ),
                      _IconBtn(
                        icon: LucideIcons.externalLink,
                        tooltip: 'Open in new tab',
                        onTap: widget.onOpen,
                      ),
                      _IconBtn(
                        icon: _copied ? LucideIcons.check : LucideIcons.copy,
                        tooltip: _copied ? 'Copied' : 'Copy URL',
                        color: _copied ? t.okFg : null,
                        onTap: _copy,
                      ),
                    ],
                  ),
                ),
                const Spacer(),
                // Ảnh preview trong khung "cửa sổ trình duyệt" — bấm để mở site.
                // Tắt preview (nút ở header) → không build ảnh, card chỉ còn
                // hàng tên/địa chỉ.
                if (widget.showPreview)
                  Padding(
                    padding: const EdgeInsets.fromLTRB(10, 0, 10, 10),
                    child: MouseRegion(
                      cursor: SystemMouseCursors.click,
                      child: GestureDetector(
                        onTap: widget.onOpen,
                        child: ScreenFrame(child: _preview(s)),
                      ),
                    ),
                  ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _preview(SiteStatus s) {
    return ValueListenableBuilder<ShotMeta>(
      valueListenable: widget.meta,
      builder: (context, meta, _) {
        final offline = s.isOffline || meta.state == ShotState.offline;
        return ColorFiltered(
          colorFilter: offline
              ? const ColorFilter.matrix(<double>[
                  0.2126, 0.7152, 0.0722, 0, 0, //
                  0.2126, 0.7152, 0.0722, 0, 0, //
                  0.2126, 0.7152, 0.0722, 0, 0, //
                  0, 0, 0, 1, 0,
                ])
              : const ColorFilter.mode(Colors.transparent, BlendMode.dst),
          child: SiteThumbnail(
            website: widget.website,
            status: s,
            meta: meta,
            onOpenLive: widget.onOpenLive,
          ),
        );
      },
    );
  }
}

/// Khung "cửa sổ trình duyệt" bao ảnh preview: viền 1px, bo 8,
/// thanh tiêu đề mỏng 3 chấm, ảnh 16:9 bên dưới. Màu trung tính theo theme.
class ScreenFrame extends StatelessWidget {
  final Widget child;
  const ScreenFrame({super.key, required this.child});

  @override
  Widget build(BuildContext context) {
    final c = context.dash;
    Widget dot() => Container(
      width: 6,
      height: 6,
      margin: const EdgeInsets.only(right: 4),
      decoration: BoxDecoration(color: c.faint, shape: BoxShape.circle),
    );

    return Container(
      clipBehavior: Clip.antiAlias,
      decoration: BoxDecoration(
        color: c.surface2,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: c.border),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Thanh tiêu đề cửa sổ
          Container(
            height: 16,
            padding: const EdgeInsets.symmetric(horizontal: 7),
            decoration: BoxDecoration(
              color: c.surface2,
              border: Border(bottom: BorderSide(color: c.border)),
            ),
            child: Row(children: [dot(), dot(), dot()]),
          ),
          AspectRatio(aspectRatio: 16 / 9, child: child),
        ],
      ),
    );
  }
}

/// Nút icon ghost 30px: không nền, không viền; hover = nền xám nhạt.
class _IconBtn extends StatelessWidget {
  final IconData icon;
  final String tooltip;
  final VoidCallback onTap;
  final Color? color;
  final double size;

  const _IconBtn({
    required this.icon,
    required this.tooltip,
    required this.onTap,
    this.color,
    this.size = 16,
  });

  @override
  Widget build(BuildContext context) {
    final c = context.dash;
    return Tooltip(
      message: tooltip,
      child: HoverSurface(
        onTap: onTap,
        radius: 8,
        color: Colors.transparent,
        hoverColor: c.surface2,
        child: SizedBox(
          width: 30,
          height: 30,
          child: AnimatedSwitcher(
            duration: Motion.of(context, Motion.fast),
            child: Icon(
              icon,
              key: ValueKey(icon),
              size: size,
              color: color ?? c.muted,
            ),
          ),
        ),
      ),
    );
  }
}
