import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../theme/dash_theme.dart';
import 'theme_curtain.dart';

/// Nội dung popover "Giao diện": Sáng/Tối + lưới chủ đề màu theo lĩnh vực.
/// Đặt trong `MenuAnchor.menuChildren` (nút ở header).
class ThemePanel extends StatelessWidget {
  const ThemePanel({super.key});

  static const _width = 324.0;
  static const _pad = 14.0;
  static const _gap = 8.0;

  @override
  Widget build(BuildContext context) {
    final c = context.dash;
    final screen = MediaQuery.sizeOf(context).width;
    final width = (screen - 24).clamp(240.0, _width);
    final tileW = (width - _pad * 2 - _gap) / 2;

    return SizedBox(
      width: width,
      child: Padding(
        padding: const EdgeInsets.all(_pad),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              'Giao diện',
              style: displayText(size: 14, weight: FontWeight.w600, color: c.text),
            ),
            const SizedBox(height: 10),
            const _ModeSwitch(),
            const SizedBox(height: 16),
            Text(
              'CHỦ ĐỀ MÀU',
              style: TextStyle(
                color: c.faint,
                fontSize: 10.5,
                fontWeight: FontWeight.w600,
                letterSpacing: .8,
              ),
            ),
            const SizedBox(height: 8),
            ValueListenableBuilder<DashPalette>(
              valueListenable: ThemeController.palette,
              builder: (context, current, _) => Wrap(
                spacing: _gap,
                runSpacing: _gap,
                children: [
                  for (final p in DashPalette.all)
                    SizedBox(
                      width: tileW,
                      child: _PaletteTile(
                        palette: p,
                        selected: p.id == current.id,
                      ),
                    ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ------------------------------------------------------------
// SÁNG / TỐI
// ------------------------------------------------------------

class _ModeSwitch extends StatelessWidget {
  const _ModeSwitch();

  void _set(BuildContext context, Brightness target) {
    final current = Theme.of(context).brightness;
    if (current == target) return;
    final curtain = ThemeCurtain.of(context);
    if (curtain != null) {
      curtain.toggle();
    } else {
      ThemeController.toggle(current);
    }
  }

  @override
  Widget build(BuildContext context) {
    final c = context.dash;
    final dark = context.isDark;
    Widget seg(Brightness b, IconData icon, String label) {
      final on = (b == Brightness.dark) == dark;
      return Expanded(
        child: Semantics(
          button: true,
          selected: on,
          child: Material(
            color: on ? c.surface : Colors.transparent,
            elevation: on ? 1 : 0,
            shadowColor: c.shadow,
            borderRadius: BorderRadius.circular(7),
            child: InkWell(
              onTap: () => _set(context, b),
              borderRadius: BorderRadius.circular(7),
              hoverColor: on ? Colors.transparent : c.border.withValues(alpha: .5),
              child: SizedBox(
                height: 30,
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(
                      icon,
                      size: 15,
                      color: on
                          ? (b == Brightness.dark ? c.brand : c.text)
                          : c.muted,
                    ),
                    const SizedBox(width: 6),
                    Text(
                      label,
                      style: TextStyle(
                        color: on ? c.text : c.muted,
                        fontSize: 13,
                        fontWeight: on ? FontWeight.w600 : FontWeight.w500,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      );
    }

    return Container(
      padding: const EdgeInsets.all(3),
      decoration: BoxDecoration(
        color: c.surface2,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: c.border),
      ),
      child: Row(
        children: [
          seg(Brightness.light, LucideIcons.sun, 'Sáng'),
          const SizedBox(width: 3),
          seg(Brightness.dark, LucideIcons.moon, 'Tối'),
        ],
      ),
    );
  }
}

// ------------------------------------------------------------
// Ô CHỦ ĐỀ
// ------------------------------------------------------------

class _PaletteTile extends StatelessWidget {
  final DashPalette palette;
  final bool selected;

  const _PaletteTile({required this.palette, required this.selected});

  @override
  Widget build(BuildContext context) {
    final c = context.dash;
    final p = palette.of(Theme.of(context).brightness);
    return Semantics(
      label: palette.name,
      child: Material(
        color: selected ? c.surface2 : Colors.transparent,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(10),
          side: BorderSide(
            color: selected ? c.brand : c.border,
            width: selected ? 1.5 : 1,
          ),
        ),
        child: InkWell(
          onTap: () => ThemeController.setPalette(palette),
          borderRadius: BorderRadius.circular(10),
          hoverColor: c.surface2,
          child: Padding(
            padding: EdgeInsets.all(selected ? 6.5 : 7),
            child: Row(
              children: [
                _Swatch(colors: p),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    palette.name,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      color: c.text,
                      fontSize: 13,
                      fontWeight: selected ? FontWeight.w600 : FontWeight.w500,
                    ),
                  ),
                ),
                if (selected) Icon(LucideIcons.check, size: 15, color: c.brand),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// "Cửa sổ thu nhỏ" vẽ bằng màu của chủ đề: nền · thanh nhấn · thẻ · nút.
class _Swatch extends StatelessWidget {
  final DashColors colors;
  const _Swatch({required this.colors});

  @override
  Widget build(BuildContext context) {
    final p = colors;
    return Container(
      width: 36,
      height: 36,
      padding: const EdgeInsets.all(5),
      decoration: BoxDecoration(
        color: p.bg,
        borderRadius: BorderRadius.circular(9),
        border: Border.all(color: p.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 12,
                height: 5,
                decoration: BoxDecoration(
                  color: p.brand,
                  borderRadius: BorderRadius.circular(3),
                ),
              ),
              const Spacer(),
              Container(
                width: 5,
                height: 5,
                decoration: BoxDecoration(
                  color: p.ink,
                  shape: BoxShape.circle,
                ),
              ),
            ],
          ),
          const SizedBox(height: 4),
          Expanded(
            child: Container(
              decoration: BoxDecoration(
                color: p.surface,
                borderRadius: BorderRadius.circular(3),
                border: Border.all(color: p.border, width: .8),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
