import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import '../models/website.dart';
import '../services/status_store.dart';
import '../theme/dash_theme.dart';
import 'dash_ui.dart';
import 'iframe_view.dart';
import 'site_thumbnail.dart';

Future<void> showPreviewDialog(
  BuildContext context, {
  required Website website,
  required ValueListenable<SiteStatus> status,
  Future<void> Function()? onRecapture,
}) {
  final d = Motion.of(context);
  return showGeneralDialog(
    context: context,
    barrierDismissible: true, // Esc + click ngoài để đóng
    barrierLabel: 'Close preview',
    barrierColor: Colors.black.withValues(alpha: .55),
    transitionDuration: d,
    pageBuilder: (_, _, _) => _PreviewDialog(
      website: website,
      status: status,
      onRecapture: onRecapture,
    ),
    transitionBuilder: (_, anim, _, child) {
      final a = CurvedAnimation(parent: anim, curve: Motion.curve);
      return FadeTransition(
        opacity: a,
        child: ScaleTransition(
          scale: Tween(begin: .97, end: 1.0).animate(a),
          child: child,
        ),
      );
    },
  );
}

class _PreviewDialog extends StatefulWidget {
  final Website website;
  final ValueListenable<SiteStatus> status;
  final Future<void> Function()? onRecapture;

  const _PreviewDialog({
    required this.website,
    required this.status,
    this.onRecapture,
  });

  @override
  State<_PreviewDialog> createState() => _PreviewDialogState();
}

class _PreviewDialogState extends State<_PreviewDialog> {
  int _reload = 0;
  bool _loaded = false;
  bool _timedOut = false;
  Timer? _timer;

  String get _url => widget.website.url;

  @override
  void initState() {
    super.initState();
    _arm();
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  void _arm() {
    _timer?.cancel();
    _timer = Timer(const Duration(seconds: 8), () {
      if (mounted && !_loaded) setState(() => _timedOut = true);
    });
  }

  void _refresh() {
    setState(() {
      _reload++;
      _loaded = false;
      _timedOut = false;
    });
    _arm();
  }

  bool _recapturing = false;

  /// POST /api/screenshot/refresh?url=… — chụp lại thumbnail của site này.
  Future<void> _recapture() async {
    final fn = widget.onRecapture;
    if (fn == null || _recapturing) return;
    setState(() => _recapturing = true);
    final messenger = ScaffoldMessenger.of(context);
    messenger.hideCurrentSnackBar();
    messenger.showSnackBar(
      const SnackBar(
        content: Text('Re-capturing screenshot…'),
        width: 220,
        duration: Duration(milliseconds: 1500),
      ),
    );
    try {
      await fn();
    } finally {
      if (mounted) setState(() => _recapturing = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final c = context.dash;
    final size = MediaQuery.sizeOf(context);
    final wide = size.width >= 900;

    return Center(
      child: Padding(
        padding: EdgeInsets.all(wide ? 32 : 12),
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 1280, maxHeight: 860),
          child: DecoratedBox(
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(16),
              boxShadow: comicShadows(c, 9),
            ),
            child: Material(
              color: c.surface,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
                side: BorderSide(color: c.ink, width: 3),
              ),
              clipBehavior: Clip.antiAlias,
              child: ValueListenableBuilder<SiteStatus>(
                valueListenable: widget.status,
                builder: (context, status, _) => Column(
                  children: [
                    _toolbar(context, status),
                    Divider(height: 3, thickness: 3, color: c.ink),
                    Expanded(
                      child: wide
                          ? Row(
                              crossAxisAlignment: CrossAxisAlignment.stretch,
                              children: [
                                Expanded(child: _frame(context, status)),
                                VerticalDivider(width: 1, color: c.border),
                                SizedBox(width: 260, child: _info(context, status)),
                              ],
                            )
                          : Column(
                              children: [
                                Expanded(child: _frame(context, status)),
                                Divider(height: 1, color: c.border),
                                SizedBox(height: 180, child: _info(context, status)),
                              ],
                            ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _toolbar(BuildContext context, SiteStatus status) {
    final c = context.dash;
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 10, 8, 10),
      child: Row(
        children: [
          StatusPill(status: status, compact: true),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              widget.website.name,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                color: c.text,
                fontSize: 15,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
          DashIconButton(
            icon: Icons.refresh_rounded,
            tooltip: 'Reload live preview',
            size: 18,
            onPressed: _refresh,
          ),
          if (widget.onRecapture != null)
            DashIconButton(
              icon: _recapturing
                  ? Icons.hourglass_top_rounded
                  : Icons.photo_camera_outlined,
              tooltip: 'Re-capture thumbnail',
              size: 18,
              onPressed: _recapture,
            ),
          DashIconButton(
            icon: Icons.open_in_new_rounded,
            tooltip: 'Open in new tab',
            size: 18,
            onPressed: () => openInNewTab(_url),
          ),
          DashIconButton(
            icon: Icons.content_copy_rounded,
            tooltip: 'Copy URL',
            size: 17,
            onPressed: () => copyUrl(context, _url),
          ),
          const SizedBox(width: 4),
          DashIconButton(
            icon: Icons.close_rounded,
            tooltip: 'Close (Esc)',
            size: 18,
            onPressed: () => Navigator.of(context).maybePop(),
          ),
        ],
      ),
    );
  }

  Widget _frame(BuildContext context, SiteStatus status) {
    final c = context.dash;

    // Không nhúng được → báo rõ thay vì khung xám.
    String? blocked;
    if (isMixedContent(_url)) {
      blocked = 'This dashboard is served over HTTPS, so the browser blocks '
          'this HTTP site from being embedded (mixed content).';
    } else if (status.isOffline) {
      blocked = 'The site is unreachable right now.';
    } else if (_timedOut) {
      blocked = 'The page did not load within 8s. It may block embedding '
          '(X-Frame-Options / CSP) or be very slow.';
    }

    if (blocked != null) {
      return Stack(
        fit: StackFit.expand,
        children: [
          ThumbPlaceholder(
            kind: thumbKindFor(widget.website),
            color: tagColor(widget.website.type),
          ),
          ColoredBox(color: c.surface.withValues(alpha: .78)),
          Center(
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.block_rounded, color: c.muted, size: 36),
                  const SizedBox(height: 12),
                  Text(
                    'Preview unavailable',
                    style: TextStyle(
                      color: c.text,
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 6),
                  ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 420),
                    child: Text(
                      blocked,
                      textAlign: TextAlign.center,
                      style: TextStyle(color: c.muted, fontSize: 13, height: 1.4),
                    ),
                  ),
                  const SizedBox(height: 16),
                  FilledButton.icon(
                    onPressed: () => openInNewTab(_url),
                    icon: const Icon(Icons.open_in_new_rounded, size: 16),
                    label: const Text('Open in new tab'),
                  ),
                ],
              ),
            ),
          ),
        ],
      );
    }

    return Column(
      children: [
        Expanded(
          child: Stack(
            fit: StackFit.expand,
            children: [
              ColoredBox(color: c.surface2),
              IframeView(
                url: _url,
                interactive: true,
                reloadToken: _reload,
                onLoad: () {
                  _timer?.cancel();
                  if (mounted) setState(() => _loaded = true);
                },
              ),
              IgnorePointer(
                child: AnimatedOpacity(
                  opacity: _loaded ? 0 : 1,
                  duration: Motion.of(context, Motion.fast),
                  child: const Shimmer(),
                ),
              ),
            ],
          ),
        ),
        // Trình duyệt không cho biết iframe bị chặn (cross-origin) →
        // luôn có gợi ý ngắn + nút mở tab mới.
        Container(
          color: c.surface2,
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
          child: Row(
            children: [
              Icon(Icons.info_outline_rounded, size: 14, color: c.muted),
              const SizedBox(width: 6),
              Expanded(
                child: Text(
                  'Blank or "refused to connect"? The site blocks embedding.',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(color: c.muted, fontSize: 12),
                ),
              ),
              TextButton(
                onPressed: () => openInNewTab(_url),
                child: const Text('Open in new tab'),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _info(BuildContext context, SiteStatus status) {
    final c = context.dash;
    final w = widget.website;
    final hp = hostPort(w.url);

    Widget row(String k, Widget v) => Padding(
          padding: const EdgeInsets.symmetric(vertical: 7),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              SizedBox(
                width: 84,
                child: Text(k, style: TextStyle(color: c.muted, fontSize: 12.5)),
              ),
              Expanded(child: v),
            ],
          ),
        );

    Text val(String s) => Text(
          s,
          style: TextStyle(color: c.text, fontSize: 13, fontWeight: FontWeight.w500),
        );

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        row('Host', SelectableText(hp.host, style: TextStyle(color: c.text, fontSize: 13))),
        row('Port', val(hp.port?.toString() ?? 'default')),
        row('Dept', val(w.departmentName.isEmpty ? '—' : w.departmentName)),
        row('Tag', Align(alignment: Alignment.centerLeft, child: TagChip(w.type))),
        row(
          'Latency',
          val(status.latencyMs == null ? '—' : '${status.latencyMs} ms'),
        ),
        row(
          'Last check',
          val(status.lastCheck == null ? '—' : hms(status.lastCheck!)),
        ),
        if (status.lastSeen != null)
          row('Last seen', val(relativeTime(status.lastSeen))),
        const SizedBox(height: 8),
        Text(
          'Latency = dashboard → API → site round-trip.',
          style: TextStyle(color: c.muted, fontSize: 11.5),
        ),
      ],
    );
  }
}
