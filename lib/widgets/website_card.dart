import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../models/website.dart';
import '../services/screenshot_store.dart';
import '../services/status_store.dart';
import '../theme/dash_theme.dart';
import 'dash_ui.dart';
import 'site_thumbnail.dart';

/// Chiều cao phần body dưới thumbnail (dùng để tính mainAxisExtent grid).
const double kCardBodyHeight = 104;

/// Viền mực quanh thẻ và vạch ngăn thumbnail / body.
const double _kCardBorder = 2.5;

/// Chiều cao thẻ theo bề rộng ô grid (thumbnail 16:9 nằm trong viền).
double cardExtent(double width) =>
    (width - _kCardBorder * 2) * 9 / 16 + kCardBodyHeight + _kCardBorder * 3;

class WebsiteCard extends StatefulWidget {
  final Website website;
  final ValueListenable<SiteStatus> status;
  final ValueListenable<ShotMeta> meta;
  final VoidCallback onPreview;

  const WebsiteCard({
    super.key,
    required this.website,
    required this.status,
    required this.meta,
    required this.onPreview,
  });

  @override
  State<WebsiteCard> createState() => _WebsiteCardState();
}

class _WebsiteCardState extends State<WebsiteCard> {
  bool _hover = false;
  bool _focusRing = false;

  @override
  Widget build(BuildContext context) {
    final c = context.dash;
    final w = widget.website;
    final color = tagColor(w.type);
    final d = Motion.of(context);
    final lift = _hover && !Motion.reduced(context);

    return ValueListenableBuilder<SiteStatus>(
      valueListenable: widget.status,
      builder: (context, status, _) {
        return FocusableActionDetector(
          mouseCursor: SystemMouseCursors.click,
          onShowHoverHighlight: (v) => setState(() => _hover = v),
          onShowFocusHighlight: (v) => setState(() => _focusRing = v),
          shortcuts: const {
            SingleActivator(LogicalKeyboardKey.enter): ActivateIntent(),
            SingleActivator(LogicalKeyboardKey.space): ActivateIntent(),
          },
          actions: {
            ActivateIntent: CallbackAction<ActivateIntent>(
              onInvoke: (_) {
                widget.onPreview();
                return null;
              },
            ),
          },
          child: Semantics(
            button: true,
            label: '${w.name}, ${status.state.name}',
            child: GestureDetector(
              onTap: widget.onPreview,
              child: AnimatedContainer(
                duration: d,
                curve: Motion.curve,
                // Hover: thẻ "bật" lên trái-trên, bóng in lệch dài ra.
                transform: Matrix4.translationValues(
                  lift ? -2 : 0,
                  lift ? -3 : 0,
                  0,
                ),
                decoration: comicPanel(
                  c,
                  border: _kCardBorder,
                  offset: lift ? 8 : 4,
                ).copyWith(
                  border: _focusRing
                      ? Border.all(color: c.accent, width: _kCardBorder)
                      : null,
                ),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(12 - _kCardBorder),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      AspectRatio(
                        aspectRatio: 16 / 9,
                        child: _thumb(context, status, color),
                      ),
                      Container(height: _kCardBorder, color: c.ink),
                      SizedBox(
                        height: kCardBodyHeight,
                        child: _body(context, status),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _thumb(BuildContext context, SiteStatus status, Color color) {
    return ValueListenableBuilder<ShotMeta>(
      valueListenable: widget.meta,
      builder: (context, meta, _) => _thumbStack(context, status, meta, color),
    );
  }

  Widget _thumbStack(
    BuildContext context,
    SiteStatus status,
    ShotMeta meta,
    Color color,
  ) {
    final c = context.dash;
    final offline = status.isOffline || meta.state == ShotState.offline;

    return Stack(
      fit: StackFit.expand,
      children: [
        ColorFiltered(
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
            status: status,
            meta: meta,
            hover: _hover,
            onOpenLive: widget.onPreview,
          ),
        ),

        // Online: viền trên theo màu tag.
        Positioned(
          left: 0,
          right: 0,
          top: 0,
          height: 3,
          child: AnimatedOpacity(
            opacity: status.isReachable ? 1 : 0,
            duration: Motion.of(context),
            child: ColoredBox(color: color),
          ),
        ),

        // Offline: lớp phủ nhạt + icon, không còn khung đen.
        IgnorePointer(
          child: AnimatedOpacity(
            opacity: offline ? 1 : 0,
            duration: Motion.of(context),
            child: Container(
              color: c.surface.withValues(alpha: .62),
              alignment: Alignment.center,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.cloud_off_rounded, color: c.bad, size: 26),
                  const SizedBox(height: 6),
                  Text(
                    'Unreachable${lastSeenSuffix(status.lastSeen)}',
                    style: TextStyle(
                      color: c.text,
                      fontSize: 12,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),

        Positioned(left: 10, top: 10, child: StatusPill(status: status)),
      ],
    );
  }

  Widget _body(BuildContext context, SiteStatus status) {
    final c = context.dash;
    final w = widget.website;

    return Padding(
      padding: const EdgeInsets.fromLTRB(14, 12, 8, 10),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.only(right: 6),
            child: Text(
              w.name,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                color: c.text,
                fontSize: 15,
                fontWeight: FontWeight.w600,
                height: 1.25,
              ),
            ),
          ),
          const SizedBox(height: 3),
          Padding(
            padding: const EdgeInsets.only(right: 6),
            child: Tooltip(
              message: w.url,
              child: Text(
                w.url,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(color: c.muted, fontSize: 12.5, height: 1.3),
              ),
            ),
          ),
          const Spacer(),
          Row(
            children: [
              Flexible(child: TagChip(w.type)),
              if (w.departmentName.isNotEmpty) ...[
                const SizedBox(width: 6),
                Flexible(
                  child: DashChip(
                    label: w.departmentName,
                    icon: Icons.apartment_rounded,
                  ),
                ),
              ],
              const Spacer(),
              DashIconButton(
                icon: Icons.content_copy_rounded,
                tooltip: 'Copy URL',
                size: 15,
                onPressed: () => copyUrl(context, w.url),
              ),
              DashIconButton(
                icon: Icons.open_in_new_rounded,
                tooltip: 'Open in new tab',
                size: 16,
                onPressed: () => openInNewTab(w.url),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
