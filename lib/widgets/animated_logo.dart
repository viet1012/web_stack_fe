import 'package:flutter/material.dart';

class AnimatedLogo extends StatefulWidget {
  const AnimatedLogo({super.key});

  @override
  State<AnimatedLogo> createState() => _AnimatedLogoState();
}

class _AnimatedLogoState extends State<AnimatedLogo>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;

  bool hover = false;

  @override
  void initState() {
    super.initState();

    _controller = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 3),
    )..repeat();
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
        scale: hover ? 1.1 : 1,
        duration: const Duration(milliseconds: 250),

        child: AnimatedBuilder(
          animation: _controller,
          builder: (context, child) {
            return ShaderMask(
              shaderCallback: (bounds) {
                return LinearGradient(
                  begin: Alignment(-1 + _controller.value * 2, 0),
                  end: Alignment(1 + _controller.value * 2, 0),
                  colors: const [
                    Color(0xFF22C55E),
                    Color(0xFF06B6D4),
                    Color(0xFF6366F1),
                    Color(0xFFEC4899),
                    Color(0xFF22C55E),
                  ],
                ).createShader(bounds);
              },
              child: Text(
                "IT PRO",
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 22,
                  fontWeight: FontWeight.w700,
                  letterSpacing: 1.4,

                  /// 🔥 glow effect
                  shadows: [
                    Shadow(
                      color: hover
                          ? const Color(0xFF3B82F6)
                          : const Color(0xFF3B82F6).withOpacity(0.5),
                      blurRadius: hover ? 20 : 10,
                    ),
                  ],
                ),
              ),
            );
          },
        ),
      ),
    );
  }
}
