import 'dart:html' as html;
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'dart:ui_web' as ui_web;

class IframeView extends StatelessWidget {
  final String url;

  const IframeView({super.key, required this.url});

  @override
  Widget build(BuildContext context) {
    final viewId = 'iframe-${url.hashCode}';

    // ignore: undefined_prefixed_name
    ui_web.platformViewRegistry.registerViewFactory(viewId, (int viewId) {
      final iframe = html.IFrameElement()
        ..src = url
        ..style.border = 'none'
        ..style.pointerEvents = 'none'
        ..style.width = '100%'
        ..style.height = '100%'
        ..allow = 'fullscreen';
      return iframe;
    });

    return HtmlElementView(viewType: viewId);
  }
}
