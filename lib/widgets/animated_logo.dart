import 'dart:math';

import 'package:flutter/material.dart';

import '../theme/dash_theme.dart';
import 'dash_ui.dart';

class AnimatedLogo extends StatefulWidget {
  const AnimatedLogo({super.key});

  @override
  State<AnimatedLogo> createState() => _AnimatedLogoState();
}

class _AnimatedLogoState extends State<AnimatedLogo>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 2400),
  );

  bool hover = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (Motion.reduced(context)) {
      _controller.stop();
    } else if (!_controller.isAnimating) {
      _controller.repeat(reverse: true);
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return MouseRegion(
      onEnter: (_) => setState(() => hover = true),
      onExit: (_) => setState(() => hover = false),
      child: AnimatedScale(
        scale: hover ? 1.12 : 1,
        duration: const Duration(milliseconds: 250),
        curve: Curves.easeOutBack,
        // Lắc nhẹ như nhãn dán truyện tranh (-3° ↔ 1°).
        child: AnimatedBuilder(
          animation: _controller,
          builder: (context, child) => Transform.rotate(
            angle: (-3 + 4 * Curves.easeInOut.transform(_controller.value)) *
                pi /
                180,
            child: child,
          ),
          // Tách layer: mỗi frame chỉ xoay, không vẽ lại chữ.
          child: const RepaintBoundary(
            child: ComicText('IT PRO', size: 32, letterSpacing: 2),
          ),
        ),
      ),
    );
  }
}
