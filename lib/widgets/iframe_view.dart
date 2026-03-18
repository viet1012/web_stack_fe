import 'dart:html' as html;
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'dart:ui_web' as ui_web;

class IframeView extends StatelessWidget {
  final String url;
  final double scale; // Tỷ lệ zoom để nhìn full page

  const IframeView({
    super.key,
    required this.url,
    this.scale = 0.3, // Mặc định scale 30% để nhìn full page
  });

  @override
  Widget build(BuildContext context) {
    final viewId = 'iframe-${url.hashCode}';

    // ignore: undefined_prefixed_name
    ui_web.platformViewRegistry.registerViewFactory(viewId, (int viewId) {
      // Tạo container wrapper
      final container = html.DivElement()
        ..style.width = '100%'
        ..style.height = '100%'
        ..style.overflow = 'hidden'
        ..style.position = 'relative';

      // Tạo iframe với transform scale
      final iframe = html.IFrameElement()
        ..src = url
        ..style.border = 'none'
        ..style.pointerEvents = 'none'
        ..style.position = 'absolute'
        ..style.top = '0'
        ..style.left = '0'
        ..style.transformOrigin = 'top left'
        ..style.transform =
            'scale($scale)' // Scale để nhìn full page
        ..style.width =
            '${100 / scale}%' // Tăng width tương ứng
        ..style.height =
            '${100 / scale}%' // Tăng height tương ứng
        ..allow = 'fullscreen';

      container.children.add(iframe);
      return container;
    });

    return HtmlElementView(viewType: viewId);
  }
}
