import 'package:flutter/material.dart';
import 'dart:math' as math;

class RocketLoadingScreen extends StatefulWidget {
  final VoidCallback? onComplete;

  const RocketLoadingScreen({super.key, this.onComplete});

  @override
  State<RocketLoadingScreen> createState() => _RocketLoadingScreenState();
}

class _RocketLoadingScreenState extends State<RocketLoadingScreen>
    with TickerProviderStateMixin {
  late AnimationController _rocketController;
  late AnimationController _smokeController;
  late AnimationController _starController;

  late Animation<double> _rocketAnimation;
  late Animation<double> _rotationAnimation;
  late Animation<double> _smokeAnimation;

  @override
  void initState() {
    super.initState();

    // Rocket flying animation
    _rocketController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 2000),
    );

    _rocketAnimation = Tween<double>(begin: 0.8, end: -0.5).animate(
      CurvedAnimation(parent: _rocketController, curve: Curves.easeInOut),
    );

    _rotationAnimation = Tween<double>(begin: 0, end: 0.3).animate(
      CurvedAnimation(parent: _rocketController, curve: Curves.easeInOut),
    );

    // Smoke animation
    _smokeController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 500),
    );

    _smokeAnimation = Tween<double>(
      begin: 0,
      end: 1,
    ).animate(CurvedAnimation(parent: _smokeController, curve: Curves.easeOut));

    // Stars animation
    _starController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1000),
    );

    _rocketController.repeat();
    _smokeController.repeat();
    _starController.repeat();
  }

  @override
  void dispose() {
    _rocketController.dispose();
    _smokeController.dispose();
    _starController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [Color(0xFF0B132B), Color(0xFF1C2541), Color(0xFF0F172A)],
        ),
      ),
      child: Stack(
        children: [
          // Animated stars background
          ...List.generate(20, (index) {
            return AnimatedBuilder(
              animation: _starController,
              builder: (context, child) {
                final random = math.Random(index);
                final x = random.nextDouble();
                final y = random.nextDouble();
                final size = random.nextDouble() * 3 + 1;
                final speed = random.nextDouble() * 0.5 + 0.5;

                return Positioned(
                  left: MediaQuery.of(context).size.width * x,
                  top:
                      MediaQuery.of(context).size.height *
                      ((y + _starController.value * speed) % 1),
                  child: Container(
                    width: size,
                    height: size,
                    decoration: BoxDecoration(
                      color: Colors.white.withOpacity(0.8),
                      shape: BoxShape.circle,
                      boxShadow: [
                        BoxShadow(
                          color: Colors.white.withOpacity(0.5),
                          blurRadius: 4,
                          spreadRadius: 1,
                        ),
                      ],
                    ),
                  ),
                );
              },
            );
          }),

          // Rocket with smoke trail
          Center(
            child: AnimatedBuilder(
              animation: _rocketController,
              builder: (context, child) {
                return Transform.translate(
                  offset: Offset(
                    0,
                    MediaQuery.of(context).size.height * _rocketAnimation.value,
                  ),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      // Rocket
                      Transform.rotate(
                        angle: _rotationAnimation.value,
                        child: ShaderMask(
                          shaderCallback: (bounds) => const LinearGradient(
                            colors: [
                              Color(0xFF22C55E),
                              Color(0xFF3B82F6),
                              Color(0xFF8B5CF6),
                              Color(0xFF67460A),
                              Color(0xFF22C55E),
                            ],
                            begin: Alignment.topLeft,
                            end: Alignment.bottomRight,
                          ).createShader(bounds),
                          child: const Icon(
                            Icons.rocket,
                            size: 80,
                            color: Colors.white,
                          ),
                        ),
                      ),

                      // Smoke trail
                      const SizedBox(height: 10),
                      AnimatedBuilder(
                        animation: _smokeAnimation,
                        builder: (context, child) {
                          return Column(
                            children: List.generate(5, (index) {
                              final opacity = 1 - (index * 0.2);
                              final scale = 1 - (index * 0.15);
                              final delay = index * 0.1;

                              return Transform.scale(
                                scale: scale * _smokeAnimation.value,
                                child: Container(
                                  margin: const EdgeInsets.only(bottom: 8),
                                  width: 30,
                                  height: 30,
                                  decoration: BoxDecoration(
                                    shape: BoxShape.circle,
                                    gradient: RadialGradient(
                                      colors: [
                                        const Color(0xFFF59E0B).withOpacity(
                                          opacity * _smokeAnimation.value,
                                        ),
                                        Colors.transparent,
                                      ],
                                    ),
                                  ),
                                ),
                              );
                            }),
                          );
                        },
                      ),
                    ],
                  ),
                );
              },
            ),
          ),

          // Loading text
          Positioned(
            bottom: 100,
            left: 0,
            right: 0,
            child: Column(
              children: [
                const Text(
                  "Đang khởi động...",
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 24,
                    fontWeight: FontWeight.bold,
                    letterSpacing: 1.2,
                  ),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 16),
                SizedBox(
                  width: 200,
                  child: LinearProgressIndicator(
                    backgroundColor: Colors.white.withOpacity(0.2),
                    valueColor: const AlwaysStoppedAnimation<Color>(
                      Color(0xFF3B82F6),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// Transition animation khi load xong
class ExplodeTransition extends StatefulWidget {
  final Widget child;
  final bool show;

  const ExplodeTransition({super.key, required this.child, required this.show});

  @override
  State<ExplodeTransition> createState() => _ExplodeTransitionState();
}

class _ExplodeTransitionState extends State<ExplodeTransition>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _scaleAnimation;
  late Animation<double> _fadeAnimation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 800),
    );

    _scaleAnimation = Tween<double>(
      begin: 0.3,
      end: 1.0,
    ).animate(CurvedAnimation(parent: _controller, curve: Curves.elasticOut));

    _fadeAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(
        parent: _controller,
        curve: const Interval(0.0, 0.5, curve: Curves.easeIn),
      ),
    );

    if (widget.show) {
      _controller.forward();
    }
  }

  @override
  void didUpdateWidget(ExplodeTransition oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.show && !oldWidget.show) {
      _controller.forward();
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (!widget.show) {
      return const SizedBox.shrink();
    }

    return AnimatedBuilder(
      animation: _controller,
      builder: (context, child) {
        return Transform.scale(
          scale: _scaleAnimation.value,
          child: Opacity(opacity: _fadeAnimation.value, child: widget.child),
        );
      },
    );
  }
}
