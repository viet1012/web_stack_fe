import 'dart:html' as html;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../models/website.dart';
import 'glass_card.dart';
import 'iframe_view.dart';

class WebsiteCard extends StatefulWidget {
  final Website website;
  final bool? isAlive;

  const WebsiteCard({super.key, required this.website, required this.isAlive});

  @override
  State<WebsiteCard> createState() => _WebsiteCardState();
}

class _WebsiteCardState extends State<WebsiteCard>
    with SingleTickerProviderStateMixin {
  bool hover = false;
  bool copied = false;
  late AnimationController _borderController;

  @override
  void initState() {
    super.initState();
    _borderController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 3),
    );

    if (widget.isAlive == true) {
      _borderController.repeat();
    }
  }

  @override
  void didUpdateWidget(covariant WebsiteCard oldWidget) {
    super.didUpdateWidget(oldWidget);

    if (widget.isAlive == true && !_borderController.isAnimating) {
      _borderController.repeat();
    } else if (widget.isAlive != true && _borderController.isAnimating) {
      _borderController.stop();
    }
  }

  @override
  void dispose() {
    _borderController.dispose();
    super.dispose();
  }

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
      if (mounted) setState(() => copied = false);
    });
  }

  @override
  Widget build(BuildContext context) {
    final w = widget.website;
    final width = MediaQuery.of(context).size.width;

    final isMobile = width < 600;
    final isTablet = width < 1024;

    final borderRadius = isMobile ? 12.0 : 18.0;
    final padding = isMobile ? 10.0 : 14.0;

    return MouseRegion(
      onEnter: (_) => setState(() => hover = true),
      onExit: (_) => setState(() => hover = false),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 250),
        transform: Matrix4.identity()
          ..translate(0, hover ? (isMobile ? -2 : -6) : 0)
          ..scale(hover ? 1.02 : 1),
        child: GestureDetector(
          onTap: () => html.window.open(w.url, "_blank"),
          child: Stack(
            children: [
              /// ===== Animated border =====
              if (widget.isAlive == true)
                Positioned.fill(
                  child: AnimatedBuilder(
                    animation: _borderController,
                    builder: (_, __) {
                      return Container(
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(borderRadius),
                          gradient: SweepGradient(
                            transform: GradientRotation(
                              _borderController.value * 6.28,
                            ),
                            colors: const [
                              Color(0xFF22C55E),
                              Color(0xFF3B82F6),
                              Color(0xFF8B5CF6),
                              Color(0xFFF59E0B),
                              Color(0xFF22C55E),
                            ],
                          ),
                        ),
                      );
                    },
                  ),
                ),

              /// ===== Card content =====
              Padding(
                padding: EdgeInsets.all(widget.isAlive == true ? 1.2 : 0),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(borderRadius - 1),
                  child: Container(
                    decoration: const BoxDecoration(color: Color(0xFF0B132B)),
                    child: Stack(
                      children: [
                        /// ===== IFRAME (desktop only) =====
                        if (!isMobile)
                          AnimatedOpacity(
                            duration: const Duration(milliseconds: 300),
                            opacity: hover ? 1 : 0,
                            child: hover
                                ? IframeView(url: w.url)
                                : const SizedBox(),
                          ),

                        /// overlay
                        Positioned.fill(
                          child: Container(
                            decoration: BoxDecoration(
                              gradient: LinearGradient(
                                colors: [
                                  Colors.black.withOpacity(0.7),
                                  Colors.black.withOpacity(0.2),
                                ],
                                begin: Alignment.bottomCenter,
                                end: Alignment.topCenter,
                              ),
                            ),
                          ),
                        ),

                        /// ===== CONTENT =====
                        Padding(
                          padding: EdgeInsets.all(padding),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              /// ===== HEADER =====
                              Row(
                                children: [
                                  Expanded(
                                    child: Text(
                                      w.name,
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                      style: TextStyle(
                                        color: Colors.white,
                                        fontSize: isMobile
                                            ? 15
                                            : (isTablet ? 17 : 19),
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                  ),
                                  const SizedBox(width: 6),
                                  _buildStatus(isMobile),
                                ],
                              ),

                              const SizedBox(height: 6),

                              /// URL
                              Text(
                                w.url,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: TextStyle(
                                  color: const Color(0xFF9CA3AF),
                                  fontSize: isMobile ? 11 : 13,
                                ),
                              ),

                              const SizedBox(height: 10),

                              /// TYPE
                              Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 8,
                                  vertical: 3,
                                ),
                                decoration: BoxDecoration(
                                  color: getTypeColor(w.type).withOpacity(0.15),
                                  borderRadius: BorderRadius.circular(20),
                                ),
                                child: Text(
                                  w.type,
                                  style: TextStyle(
                                    color: getTypeColor(w.type),
                                    fontSize: isMobile ? 9 : 11,
                                  ),
                                ),
                              ),

                              /// ===== FLEXIBLE SPACE =====
                              const Expanded(child: SizedBox()),

                              /// ===== FOOTER =====
                              Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    w.departmentName,
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    style: TextStyle(
                                      color: const Color(0xFF6B7280),
                                      fontSize: isMobile ? 12 : 14,
                                    ),
                                  ),

                                  const SizedBox(height: 6),

                                  Row(
                                    mainAxisAlignment: MainAxisAlignment.end,
                                    children: [
                                      _copyBtn(isMobile),
                                      _openBtn(isMobile),
                                    ],
                                  ),
                                ],
                              ),
                            ],
                          ),
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
    );
  }

  Widget _buildStatus(bool isMobile) {
    if (widget.isAlive == null) {
      return SizedBox(
        width: 14,
        height: 14,
        child: CircularProgressIndicator(strokeWidth: 1.5),
      );
    }

    return Icon(
      widget.isAlive! ? Icons.check_circle : Icons.cancel,
      size: 16,
      color: widget.isAlive!
          ? const Color(0xFF22C55E)
          : const Color(0xFFEF4444),
    );
  }

  Widget _copyBtn(bool isMobile) {
    return GestureDetector(
      onTap: () => copyUrl(widget.website.url),
      child: Container(
        padding: const EdgeInsets.all(6),
        margin: const EdgeInsets.only(right: 6),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(6),
          color: copied
              ? const Color(0xFF22C55E).withOpacity(0.2)
              : Colors.white.withOpacity(0.05),
        ),
        child: Icon(
          copied ? Icons.check : Icons.copy,
          size: 18,
          color: copied ? const Color(0xFF22C55E) : const Color(0xFF6B7280),
        ),
      ),
    );
  }

  Widget _openBtn(bool isMobile) {
    return GestureDetector(
      onTap: () => html.window.open(widget.website.url, "_blank"),
      child: Icon(
        Icons.open_in_new,
        size: 18,
        color: hover ? const Color(0xFF3B82F6) : const Color(0xFF6B7280),
      ),
    );
  }
}
