import 'dart:html' as html;

import 'package:flutter/material.dart';

/// Render trang ở viewport cố định (mặc định 1440x900) rồi CSS-scale
/// cho vừa khung → thumbnail giống màn hình thật, không bị vỡ layout.
///
/// Dùng HtmlElementView.fromTagName: element tạo 1 lần cho mỗi widget,
/// không đăng ký lại view factory mỗi lần build (bug cũ).
class IframeView extends StatefulWidget {
  final String url;
  final Size viewport;
  final bool interactive;
  final VoidCallback? onLoad;

  /// Đổi giá trị để reload iframe.
  final int reloadToken;

  const IframeView({
    super.key,
    required this.url,
    this.viewport = const Size(1440, 900),
    this.interactive = false,
    this.onLoad,
    this.reloadToken = 0,
  });

  @override
  State<IframeView> createState() => _IframeViewState();
}

class _IframeViewState extends State<IframeView> {
  html.IFrameElement? _iframe;
  Size _box = Size.zero;

  @override
  void didUpdateWidget(covariant IframeView oldWidget) {
    super.didUpdateWidget(oldWidget);
    final iframe = _iframe;
    if (iframe == null) return;
    if (oldWidget.url != widget.url ||
        oldWidget.reloadToken != widget.reloadToken) {
      iframe.src = widget.url;
    }
  }

  void _applyLayout() {
    final iframe = _iframe;
    if (iframe == null || _box.width <= 0) return;

    final scale = _box.width / widget.viewport.width;
    final height = (_box.height / scale)
        .clamp(widget.viewport.height, double.infinity)
        .toDouble();

    iframe.style
      ..width = '${widget.viewport.width}px'
      ..height = '${height}px'
      ..transform = 'scale($scale)';
  }

  void _onCreated(Object element) {
    final host = element as html.Element;
    final pointer = widget.interactive ? 'auto' : 'none';

    host.style
      ..width = '100%'
      ..height = '100%'
      ..overflow = 'hidden'
      ..position = 'relative'
      ..pointerEvents = pointer;

    final iframe = html.IFrameElement()
      ..src = widget.url
      ..setAttribute('loading', 'lazy')
      ..setAttribute('referrerpolicy', 'no-referrer')
      ..style.border = 'none'
      ..style.position = 'absolute'
      ..style.top = '0'
      ..style.left = '0'
      ..style.transformOrigin = 'top left'
      ..style.pointerEvents = pointer
      ..style.background = 'transparent';

    if (!widget.interactive) iframe.tabIndex = -1;

    iframe.onLoad.listen((_) => widget.onLoad?.call());

    host.children.add(iframe);
    _iframe = iframe;
    _applyLayout();
  }

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        _box = constraints.biggest;
        _applyLayout();
        return HtmlElementView.fromTagName(
          tagName: 'div',
          isVisible: true,
          onElementCreated: _onCreated,
        );
      },
    );
  }
}

/// Trang https không load được iframe/ảnh http (mixed content).
bool isMixedContent(String url) =>
    html.window.location.protocol == 'https:' &&
    url.trim().toLowerCase().startsWith('http:');
