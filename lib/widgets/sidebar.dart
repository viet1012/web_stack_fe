import 'dart:ui';
import 'package:flutter/material.dart';

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
            Container(
              decoration: const BoxDecoration(
                gradient: LinearGradient(
                  colors: [
                    Color(0xFF020617),
                    Color(0xFF020617),
                    Color(0xFF020617),
                    Color(0xFF0F172A),
                  ],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
              ),
            ),

            /// 🔥 GLASS LAYER
            BackdropFilter(
              filter: ImageFilter.blur(sigmaX: 25, sigmaY: 25),
              child: Container(
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.03),
                  border: const Border(
                    right: BorderSide(color: Color(0xFF1F2937)),
                  ),
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
