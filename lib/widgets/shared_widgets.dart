import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../theme/app_theme.dart';
import '../models/api_endpoint.dart';

// ── Method Badge ──────────────────────────────────────────────────────────────

class MethodBadge extends StatelessWidget {
  final HttpMethod method;
  final double fontSize;

  const MethodBadge({super.key, required this.method, this.fontSize = 10});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
      decoration: BoxDecoration(
        color: method.label.methodBgColor,
        borderRadius: BorderRadius.circular(5),
      ),
      child: Text(
        method.label,
        style: TextStyle(
          color: method.label.methodColor,
          fontSize: fontSize,
          fontWeight: FontWeight.w700,
          letterSpacing: 0.04,
        ),
      ),
    );
  }
}

// ── Status Dot ────────────────────────────────────────────────────────────────

class StatusDot extends StatelessWidget {
  final bool isOnline;
  final double size;

  const StatusDot({super.key, required this.isOnline, this.size = 7});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: isOnline ? AppTheme.statusOnline : AppTheme.statusOffline,
      ),
    );
  }
}

// ── Tag Chip ──────────────────────────────────────────────────────────────────

class TagChip extends StatelessWidget {
  final String label;

  const TagChip({super.key, required this.label});

  Color get _bg {
    switch (label.toLowerCase()) {
      case 'production':
        return AppTheme.methodGetBg;
      case 'staging':
        return AppTheme.methodPutBg;
      case 'dev':
        return AppTheme.methodPostBg;
      case 'admin':
        return AppTheme.methodPatchBg;
      default:
        return AppTheme.bgTertiary;
    }
  }

  Color get _fg {
    switch (label.toLowerCase()) {
      case 'production':
        return AppTheme.methodGet;
      case 'staging':
        return AppTheme.methodPut;
      case 'dev':
        return AppTheme.methodPost;
      case 'admin':
        return AppTheme.methodPatch;
      default:
        return AppTheme.textSecondary;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
      decoration: BoxDecoration(
        color: _bg,
        borderRadius: BorderRadius.circular(5),
      ),
      child: Text(
        label,
        style: TextStyle(color: _fg, fontSize: 10, fontWeight: FontWeight.w500),
      ),
    );
  }
}

// ── Search Bar ────────────────────────────────────────────────────────────────

class AppSearchBar extends StatelessWidget {
  final String hint;
  final ValueChanged<String> onChanged;
  final TextEditingController? controller;

  const AppSearchBar({
    super.key,
    required this.hint,
    required this.onChanged,
    this.controller,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 36,
      decoration: BoxDecoration(
        color: AppTheme.bgSecondary,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: AppTheme.border, width: 0.5),
      ),
      child: Row(
        children: [
          const SizedBox(width: 10),
          const Icon(Icons.search, color: AppTheme.textMuted, size: 15),
          const SizedBox(width: 8),
          Expanded(
            child: TextField(
              controller: controller,
              onChanged: onChanged,
              style: const TextStyle(
                color: AppTheme.textSecondary,
                fontSize: 13,
              ),
              decoration: InputDecoration(
                hintText: hint,
                hintStyle: const TextStyle(
                  color: AppTheme.textMuted,
                  fontSize: 13,
                ),
                border: InputBorder.none,
                isDense: true,
                contentPadding: EdgeInsets.zero,
              ),
            ),
          ),
          const SizedBox(width: 10),
        ],
      ),
    );
  }
}

// ── Section Header ────────────────────────────────────────────────────────────

class SectionHeader extends StatelessWidget {
  final String title;
  final int? count;
  final Widget? action;

  const SectionHeader({
    super.key,
    required this.title,
    this.count,
    this.action,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 2),
      child: Row(
        children: [
          Text(
            title.toUpperCase(),
            style: const TextStyle(
              color: AppTheme.textMuted,
              fontSize: 11,
              fontWeight: FontWeight.w500,
              letterSpacing: 0.06,
            ),
          ),
          if (count != null) ...[
            const SizedBox(width: 8),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
              decoration: BoxDecoration(
                color: AppTheme.bgTertiary,
                borderRadius: BorderRadius.circular(10),
              ),
              child: Text(
                '$count',
                style: const TextStyle(color: AppTheme.textMuted, fontSize: 10),
              ),
            ),
          ],
          const Spacer(),
          if (action != null) action!,
        ],
      ),
    );
  }
}

// ── Copy Button ───────────────────────────────────────────────────────────────

class CopyButton extends StatefulWidget {
  final String text;
  final String? label;

  const CopyButton({super.key, required this.text, this.label});

  @override
  State<CopyButton> createState() => _CopyButtonState();
}

class _CopyButtonState extends State<CopyButton> {
  bool _copied = false;

  Future<void> _copy() async {
    await Clipboard.setData(ClipboardData(text: widget.text));
    setState(() => _copied = true);
    await Future.delayed(const Duration(seconds: 2));
    if (mounted) setState(() => _copied = false);
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: _copy,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
        decoration: BoxDecoration(
          color: _copied ? AppTheme.methodGetBg : AppTheme.bgTertiary,
          borderRadius: BorderRadius.circular(5),
          border: Border.all(
            color: _copied ? AppTheme.statusOnline : AppTheme.border,
            width: 0.5,
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              _copied ? Icons.check : Icons.copy,
              size: 11,
              color: _copied ? AppTheme.statusOnline : AppTheme.textMuted,
            ),
            const SizedBox(width: 4),
            Text(
              _copied ? 'Copied!' : (widget.label ?? 'Copy'),
              style: TextStyle(
                fontSize: 10,
                color: _copied ? AppTheme.statusOnline : AppTheme.textMuted,
                fontWeight: FontWeight.w500,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ── Empty State ───────────────────────────────────────────────────────────────

class EmptyState extends StatelessWidget {
  final String emoji;
  final String title;
  final String? subtitle;
  final Widget? action;

  const EmptyState({
    super.key,
    required this.emoji,
    required this.title,
    this.subtitle,
    this.action,
  });

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(emoji, style: const TextStyle(fontSize: 40)),
          const SizedBox(height: 12),
          Text(
            title,
            style: const TextStyle(
              color: AppTheme.textSecondary,
              fontSize: 15,
              fontWeight: FontWeight.w500,
            ),
          ),
          if (subtitle != null) ...[
            const SizedBox(height: 6),
            Text(
              subtitle!,
              style: const TextStyle(color: AppTheme.textMuted, fontSize: 13),
              textAlign: TextAlign.center,
            ),
          ],
          if (action != null) ...[const SizedBox(height: 16), action!],
        ],
      ),
    );
  }
}
