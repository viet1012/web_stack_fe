import 'dart:html' as html;
import 'dart:ui';
import 'package:flutter/material.dart';
import '../models/website.dart';
import 'package:flutter/services.dart';
import '../services/website_service.dart';
import 'glass_card.dart';
import 'iframe_view.dart';
import 'dart:async';

class WebsiteCard extends StatefulWidget {
  final Website website;
  final bool? isAlive;
  const WebsiteCard({super.key, required this.website, required this.isAlive});

  @override
  State<WebsiteCard> createState() => _WebsiteCardState();
}

class _WebsiteCardState extends State<WebsiteCard> {
  bool hover = false;
  bool copied = false;

  Color getTypeColor(String type) {
    switch (type.toLowerCase()) {
      case 'production':
        return const Color(0xFF22C55E);
      case 'dev':
        return const Color(0xFF8B5CF6);
      case 'report':
        return const Color(0xFFF59E0B);
      case 'test':
        return const Color(0xFF3B82F6);
      default:
        return const Color(0xFF9CA3AF);
    }
  }

  void copyUrl(String url) async {
    await Clipboard.setData(ClipboardData(text: url));

    setState(() => copied = true);

    Future.delayed(const Duration(seconds: 1), () {
      if (mounted) {
        setState(() => copied = false);
      }
    });

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: const Text("Copied to clipboard"),
        duration: const Duration(milliseconds: 800),
        backgroundColor: const Color(0xFF1F2937),
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  Widget buildStatus() {
    if (widget.isAlive == null) {
      return const SizedBox(
        width: 18,
        height: 18,
        child: CircularProgressIndicator(strokeWidth: 2),
      );
    }

    return Icon(
      widget.isAlive! ? Icons.check_circle : Icons.cancel,
      size: 18,
      color: widget.isAlive!
          ? const Color(0xFF22C55E)
          : const Color(0xFFEF4444),
    );
  }

  @override
  Widget build(BuildContext context) {
    final w = widget.website;

    return MouseRegion(
      onEnter: (_) => setState(() => hover = true),
      onExit: (_) => setState(() => hover = false),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 250),
        curve: Curves.easeOut,
        transform: Matrix4.identity()
          ..translate(0, hover ? -6 : 0)
          ..scale(hover ? 1.03 : 1),

        child: GestureDetector(
          onTap: () => html.window.open(w.url, "_blank"),

          child: ClipRRect(
            borderRadius: BorderRadius.circular(18),
            child: Stack(
              children: [
                /// 🔥 Background fallback (khi chưa hover)
                Positioned.fill(
                  child: Container(
                    decoration: BoxDecoration(
                      color: const Color(0xFF0B132B),
                      borderRadius: BorderRadius.circular(18),
                    ),
                  ),
                ),

                /// 🔥 IFRAME (chỉ hiện khi hover)
                AnimatedOpacity(
                  duration: const Duration(milliseconds: 300),
                  opacity: hover ? 1 : 0,
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(18),
                    child: hover
                        ? IframeView(url: w.url) // 🔥 chỉ load khi hover
                        : const SizedBox(),
                  ),
                ),

                /// 🔥 overlay tối để đọc text
                Positioned.fill(
                  child: Container(
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(18),
                      gradient: LinearGradient(
                        colors: [
                          Colors.black.withOpacity(0.65),
                          Colors.black.withOpacity(0.2),
                        ],
                        begin: Alignment.bottomCenter,
                        end: Alignment.topCenter,
                      ),
                    ),
                  ),
                ),

                /// 🔥 Glass UI content
                GlassCard(
                  child: Container(
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(18),

                      /// 🔥 hover border
                      border: Border.all(
                        color: hover
                            ? const Color(0xFF3B82F6).withOpacity(0.6)
                            : Colors.white.withOpacity(0.08),
                      ),

                      /// 🔥 thêm gradient nhẹ cho đẹp
                      gradient: LinearGradient(
                        colors: [
                          Colors.white.withOpacity(0.06),
                          Colors.white.withOpacity(0.01),
                        ],
                      ),
                    ),
                    child: Padding(
                      padding: const EdgeInsets.all(16),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          /// Title + status
                          Row(
                            children: [
                              Expanded(
                                child: Text(
                                  w.name,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: const TextStyle(
                                    color: Colors.white,
                                    fontSize: 20,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ),

                              buildStatus(),
                            ],
                          ),

                          const SizedBox(height: 6),

                          Text(
                            w.url,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                              color: Color(0xFF9CA3AF),
                              fontSize: 14,
                              fontWeight: FontWeight.bold,
                            ),
                          ),

                          const SizedBox(height: 12),

                          /// Type badge
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 10,
                              vertical: 4,
                            ),
                            decoration: BoxDecoration(
                              color: getTypeColor(w.type).withOpacity(0.15),
                              borderRadius: BorderRadius.circular(20),
                            ),
                            child: Text(
                              w.type,
                              style: TextStyle(
                                color: getTypeColor(w.type),
                                fontSize: 11,
                              ),
                            ),
                          ),

                          const Spacer(),

                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Text(
                                w.departmentName,
                                style: const TextStyle(
                                  color: Color(0xFF6B7280),
                                  fontSize: 16,
                                ),
                              ),

                              Row(
                                children: [
                                  /// COPY
                                  GestureDetector(
                                    behavior: HitTestBehavior.opaque,
                                    onTap: () {
                                      copyUrl(w.url);
                                    },
                                    child: AnimatedContainer(
                                      duration: const Duration(
                                        milliseconds: 200,
                                      ),
                                      padding: const EdgeInsets.all(6),
                                      margin: const EdgeInsets.only(right: 8),
                                      decoration: BoxDecoration(
                                        borderRadius: BorderRadius.circular(8),
                                        color: copied
                                            ? const Color(
                                                0xFF22C55E,
                                              ).withOpacity(0.2)
                                            : Colors.white.withOpacity(0.05),
                                      ),
                                      child: AnimatedSwitcher(
                                        duration: const Duration(
                                          milliseconds: 200,
                                        ),
                                        child: Icon(
                                          copied ? Icons.check : Icons.copy,
                                          key: ValueKey(copied),
                                          size: 22,
                                          color: copied
                                              ? const Color(0xFF22C55E)
                                              : const Color(0xFF6B7280),
                                        ),
                                      ),
                                    ),
                                  ),

                                  /// OPEN
                                  GestureDetector(
                                    onTap: () =>
                                        html.window.open(w.url, "_blank"),
                                    child: Icon(
                                      Icons.open_in_new,
                                      size: 22,
                                      color: hover
                                          ? const Color(0xFF3B82F6)
                                          : const Color(0xFF6B7280),
                                    ),
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
