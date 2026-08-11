import 'dart:ui';
import 'package:flutter/material.dart';

import 'DevTeamBackgroundPainter.dart';
import 'animated_logo.dart';

class Sidebar extends StatefulWidget {
  final List<String> departments;
  final String selected;
  final Function(String) onSelect;

  const Sidebar({
    super.key,
    required this.departments,
    required this.selected,
    required this.onSelect,
  });

  @override
  State<Sidebar> createState() => _SidebarState();
}

class _SidebarState extends State<Sidebar> {
  bool collapsed = false;

  IconData getIcon(String name) {
    switch (name.toLowerCase()) {
      case 'it':
        return Icons.memory;
      case 'hr':
        return Icons.groups;
      case 'production':
        return Icons.precision_manufacturing;
      case 'report':
        return Icons.bar_chart;
      default:
        return Icons.dashboard_customize;
    }
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedContainer(
      duration: const Duration(milliseconds: 350),
      width: collapsed ? 75 : 240,
      child: ClipRRect(
        child: Stack(
          children: [
            /// 🔥 BACKGROUND GRADIENT
            /// 1. BACKGROUND
            Positioned.fill(
              child: Container(
                decoration: const BoxDecoration(
                  gradient: LinearGradient(
                    colors: [
                      Color(0xFF020617),
                      Color(0xFF020617),
                      Color(0xFF071126),
                      Color(0xFF0F172A),
                    ],
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                  ),
                ),
              ),
            ),

            /// 2. GLASS
            Positioned.fill(
              child: BackdropFilter(
                filter: ImageFilter.blur(
                  sigmaX: 12,
                  sigmaY: 12,
                ),
                child: Container(
                  color: Colors.white.withOpacity(0.015),
                ),
              ),
            ),

            /// 3. DEV TEAM
            Positioned.fill(
              child: IgnorePointer(
                child: CustomPaint(
                  painter: collapsed
                      ? const CollapsedDevPainter()
                      : const DevTeamBackgroundPainter(),
                ),
              ),
            ),
            Column(
              children: [
                const SizedBox(height: 20),

                if (collapsed)
                  SizedBox(
                    height: 40,
                    child: Center(
                      child: IconButton(
                        padding: EdgeInsets.zero,
                        constraints: const BoxConstraints(
                          minWidth: 40,
                          minHeight: 40,
                        ),
                        icon: const Icon(
                          Icons.menu,
                          color: Color(0xFF94A3B8),
                          size: 22,
                        ),
                        onPressed: () {
                          setState(() {
                            collapsed = false;
                          });
                        },
                      ),
                    ),
                  )
                else
                  SizedBox(
                    height: 40,
                    child: Padding(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 12,
                      ),
                      child: Row(
                        children: [
                          const Expanded(
                            child: Align(
                              alignment: Alignment.centerLeft,
                              child: AnimatedLogo(),
                            ),
                          ),

                          IconButton(
                            padding: EdgeInsets.zero,
                            constraints: const BoxConstraints(
                              minWidth: 40,
                              minHeight: 40,
                            ),
                            icon: const Icon(
                              Icons.menu_open,
                              color: Color(0xFF94A3B8),
                              size: 22,
                            ),
                            onPressed: () {
                              setState(() {
                                collapsed = true;
                              });
                            },
                          ),
                        ],
                      ),
                    ),
                  ),

                const SizedBox(height: 10),

                Divider(color: Colors.white.withOpacity(0.05), thickness: 1),

                /// 🔥 MENU
                Expanded(
                  child: ListView(
                    padding: const EdgeInsets.only(top: 10),
                    children: widget.departments.map((dep) {
                      final isActive = dep == widget.selected;

                      return MouseRegion(
                        cursor: SystemMouseCursors.click,
                        child: AnimatedContainer(
                          duration: const Duration(milliseconds: 250),
                          margin: const EdgeInsets.symmetric(
                            horizontal: 10,
                            vertical: 6,
                          ),
                          decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(14),

                            /// 🔥 ACTIVE GRADIENT NEON
                            gradient: isActive
                                ? LinearGradient(
                                    colors: [
                                      const Color(0xFF3B82F6).withOpacity(0.25),
                                      const Color(0xFF6366F1).withOpacity(0.15),
                                    ],
                                    begin: Alignment.topLeft,
                                    end: Alignment.bottomRight,
                                  )
                                : null,

                            /// 🔥 BORDER GLOW
                            border: Border.all(
                              color: isActive
                                  ? const Color(0xFF3B82F6).withOpacity(0.6)
                                  : Colors.transparent,
                            ),

                            /// 🔥 SHADOW GLOW
                            boxShadow: isActive
                                ? [
                                    BoxShadow(
                                      color: const Color(
                                        0xFF3B82F6,
                                      ).withOpacity(0.35),
                                      blurRadius: 20,
                                      spreadRadius: 1,
                                    ),
                                  ]
                                : [],
                          ),
                          child: ListTile(
                            contentPadding: EdgeInsets.symmetric(
                              horizontal: collapsed ? 10 : 16,
                              vertical: 4,
                            ),

                            leading: Icon(
                              getIcon(dep),
                              size: 20,
                              color: isActive
                                  ? const Color(0xFF60A5FA)
                                  : const Color(0xFF64748B),
                            ),

                            title: collapsed
                                ? null
                                : Text(
                                    dep,
                                    style: TextStyle(
                                      color: isActive
                                          ? const Color(0xFFE2E8F0)
                                          : const Color(0xFF94A3B8),
                                      fontWeight: isActive
                                          ? FontWeight.w600
                                          : FontWeight.w400,
                                      letterSpacing: 0.3,
                                    ),
                                  ),

                            onTap: () => widget.onSelect(dep),
                          ),
                        ),
                      );
                    }).toList(),
                  ),
                ),

                /// 🔥 FOOTER
                if (!collapsed)
                  Padding(
                    padding: const EdgeInsets.all(12),
                    child: Text(
                      "v1.0 Dashboard",
                      style: TextStyle(
                        color: Colors.white.withOpacity(0.3),
                        fontSize: 11,
                      ),
                    ),
                  ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
class CollapsedDevPainter extends CustomPainter {
  const CollapsedDevPainter();

  static const _cyan = Color(0xFF22D3EE);
  static const _blue = Color(0xFF3B82F6);

  @override
  void paint(Canvas canvas, Size size) {
    if (size.width <= 0 || size.height <= 0) return;

    final center = Offset(
      size.width / 2,
      size.height * 0.68,
    );

    final glow = Paint()
      ..color = _cyan.withOpacity(.10)
      ..maskFilter = const MaskFilter.blur(
        BlurStyle.normal,
        18,
      );

    canvas.drawCircle(
      center,
      28,
      glow,
    );

    final line = Paint()
      ..color = _cyan.withOpacity(.45)
      ..strokeWidth = 1.5
      ..style = PaintingStyle.stroke;

    final soft = Paint()
      ..color = _blue.withOpacity(.25)
      ..strokeWidth = 1
      ..style = PaintingStyle.stroke;

    // HEAD
    canvas.drawCircle(
      Offset(center.dx, center.dy - 26),
      8,
      line,
    );

    // BODY
    final body = Path()
      ..moveTo(center.dx - 12, center.dy - 14)
      ..quadraticBezierTo(
        center.dx,
        center.dy - 20,
        center.dx + 12,
        center.dy - 14,
      )
      ..lineTo(center.dx + 14, center.dy + 7)
      ..lineTo(center.dx - 14, center.dy + 7)
      ..close();

    canvas.drawPath(body, line);

    // LAPTOP
    final laptop = RRect.fromRectAndRadius(
      Rect.fromCenter(
        center: Offset(center.dx, center.dy + 18),
        width: 32,
        height: 20,
      ),
      const Radius.circular(3),
    );

    canvas.drawRRect(
      laptop,
      line,
    );

    canvas.drawCircle(
      Offset(center.dx, center.dy + 18),
      2,
      line,
    );

    // CIRCUIT
    for (int i = 0; i < 3; i++) {
      final y = size.height * (.42 + i * .08);

      canvas.drawLine(
        Offset(5, y),
        Offset(size.width - 5, y),
        soft,
      );
    }
  }

  @override
  bool shouldRepaint(
      covariant CollapsedDevPainter oldDelegate,
      ) {
    return false;
  }
}