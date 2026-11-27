import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../theme/dash_theme.dart';
import 'team_art.dart' show DeptHealth;

const kAllDept = 'ALL';

Color _deptDot(BuildContext context, String name) =>
    name == kAllDept ? context.dash.text : context.dash.faint;

String _deptLabel(String name) => name == kAllDept ? 'All sites' : name;

/// [compact] = màn hẹp: logo + chip phòng ban, xếp trên nội dung.
class Sidebar extends StatelessWidget {
  /// Có cả "ALL" ở đầu.
  final List<DeptHealth> departments;
  final String selected;
  final ValueChanged<String> onSelect;
  final int online;
  final int total;
  final bool compact;

  /// Màn rộng: thu gọn thành rail 64px (chỉ ô viết tắt phòng ban).
  final bool collapsed;
  final VoidCallback? onToggleCollapsed;

  /// Chỉ dùng ở [compact]: nút Thêm website + tài khoản, đặt bên phải logo.
  final Widget? actions;

  static const double wideWidth = 232;
  static const double railWidth = 64;

  /// Phím tắt đóng/mở sidebar (xử lý ở Dashboard, hiện trong tooltip).
  static String get shortcutLabel =>
      defaultTargetPlatform == TargetPlatform.macOS ? '⌘B' : 'Ctrl+B';

  const Sidebar({
    super.key,
    required this.departments,
    required this.selected,
    required this.onSelect,
    required this.online,
    required this.total,
    this.compact = false,
    this.collapsed = false,
    this.onToggleCollapsed,
    this.actions,
  });

  @override
  Widget build(BuildContext context) {
    if (compact) return _buildCompact(context);
    final c = context.dash;

    // KHÔNG LAG: nội dung rail/wide có độ rộng CỐ ĐỊNH (OverflowBox) → khi
    // animate độ rộng chỉ đổi vùng cắt (ClipRect); nội dung không build lại,
    // không layout lại từng frame. RepaintBoundary giữ nội dung đã vẽ.
    // Rail ↔ wide đổi bằng cross-fade ngắn.
    return AnimatedContainer(
      duration: Motion.of(context),
      curve: Motion.curve,
      width: collapsed ? railWidth : wideWidth,
      decoration: BoxDecoration(
        color: c.surface,
        border: Border(right: BorderSide(color: c.border)),
      ),
      child: ClipRect(
        child: OverflowBox(
          alignment: Alignment.topLeft,
          minWidth: wideWidth,
          maxWidth: wideWidth,
          child: RepaintBoundary(
            child: AnimatedSwitcher(
              duration: Motion.of(context, Motion.fast),
              switchInCurve: Curves.easeOut,
              switchOutCurve: Curves.easeIn,
              layoutBuilder: (current, previous) => Stack(
                fit: StackFit.expand,
                children: [...previous, ?current],
              ),
              child: collapsed
                  ? Align(
                      key: const ValueKey('rail'),
                      alignment: Alignment.topLeft,
                      child: SizedBox(
                        width: railWidth,
                        height: double.infinity,
                        child: _buildRail(context),
                      ),
                    )
                  : KeyedSubtree(
                      key: const ValueKey('wide'),
                      child: _buildWide(context),
                    ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _toggleButton(DashColors c, {required bool expand}) => Tooltip(
    message: expand
        ? 'Mở rộng sidebar ($shortcutLabel)'
        : 'Thu gọn sidebar ($shortcutLabel)',
    child: IconButton(
      onPressed: onToggleCollapsed,
      icon: Icon(
        expand ? LucideIcons.panelLeftOpen : LucideIcons.panelLeftClose,
        size: 18,
      ),
      color: c.muted,
      visualDensity: VisualDensity.compact,
      padding: const EdgeInsets.all(6),
      constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
      style: IconButton.styleFrom(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
      ),
    ),
  );

  // ------------------------------------------------------------
  // RAIL (thu gọn)
  // ------------------------------------------------------------

  Widget _buildRail(BuildContext context) {
    final c = context.dash;

    return Column(
      children: [
        const SizedBox(height: 16),
        const BrandMark(),
        const SizedBox(height: 10),
        if (onToggleCollapsed != null) _toggleButton(c, expand: true),
        const SizedBox(height: 6),
        Expanded(
          child: ListView(
            // Không khung bao: các ô bo tròn đứng riêng, thoáng hơn.
            padding: const EdgeInsets.fromLTRB(0, 4, 0, 12),
            children: [
              for (final d in departments) ...[
                _RailItem(
                  dept: d,
                  active: d.name == selected,
                  onTap: () => onSelect(d.name),
                ),
                if (d.name == kAllDept)
                  Padding(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 18,
                      vertical: 6,
                    ),
                    child: Divider(height: 1, color: c.border),
                  ),
              ],
            ],
          ),
        ),
        Padding(
          padding: const EdgeInsets.only(bottom: 14),
          child: _HealthLine(online: online, total: total, stacked: true),
        ),
      ],
    );
  }

  // ------------------------------------------------------------
  // WIDE
  // ------------------------------------------------------------

  Widget _buildWide(BuildContext context) {
    final c = context.dash;
    final depts = departments.where((d) => d.name != kAllDept).toList();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(18, 14, 10, 14),
          child: Row(
            children: [
              const Expanded(
                child: Align(
                  alignment: Alignment.centerLeft,
                  child: BrandLogo(),
                ),
              ),
              if (onToggleCollapsed != null) _toggleButton(c, expand: false),
            ],
          ),
        ),
        Expanded(
          child: ListView(
            // Không khung bao (đồng bộ rail): các hàng bo tròn đứng riêng.
            padding: const EdgeInsets.fromLTRB(12, 0, 12, 12),
            children: [
              for (final d in departments.where((d) => d.name == kAllDept))
                _NavItem(
                  dept: d,
                  active: d.name == selected,
                  onTap: () => onSelect(d.name),
                ),

              // Tiêu đề nhóm
              Padding(
                padding: const EdgeInsets.fromLTRB(10, 18, 8, 8),
                child: Row(
                  children: [
                    Text(
                      'DEPARTMENTS',
                      style: TextStyle(
                        color: c.muted,
                        fontSize: 11.5,
                        fontWeight: FontWeight.w700,
                        letterSpacing: .9,
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(child: Divider(height: 1, color: c.border)),
                    const SizedBox(width: 8),
                    _CountPill(
                      text: '${depts.length}',
                      fg: c.muted,
                      bg: c.surface2,
                    ),
                  ],
                ),
              ),
              for (final d in depts)
                _NavItem(
                  dept: d,
                  active: d.name == selected,
                  onTap: () => onSelect(d.name),
                ),
            ],
          ),
        ),
        // Tình trạng hệ thống: 1 dòng nhỏ, không chiếm chỗ.
        Container(
          padding: const EdgeInsets.fromLTRB(20, 11, 16, 13),
          decoration: BoxDecoration(
            border: Border(top: BorderSide(color: c.border)),
          ),
          child: Align(
            alignment: Alignment.centerLeft,
            child: _HealthLine(online: online, total: total),
          ),
        ),
      ],
    );
  }

  Widget _buildCompact(BuildContext context) {
    final c = context.dash;
    return Container(
      padding: const EdgeInsets.fromLTRB(16, 10, 16, 10),
      decoration: BoxDecoration(
        color: c.surface,
        border: Border(bottom: BorderSide(color: c.border)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              const BrandLogo(),
              const Spacer(),
              _HealthLine(online: online, total: total),
              if (actions != null) ...[const SizedBox(width: 14), actions!],
            ],
          ),
          const SizedBox(height: 8),
          SizedBox(
            height: 32,
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              itemCount: departments.length,
              separatorBuilder: (_, _) => const SizedBox(width: 6),
              itemBuilder: (context, i) {
                final d = departments[i];
                return _DeptPill(
                  dept: d,
                  active: d.name == selected,
                  onTap: () => onSelect(d.name),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}

// ============================================================
// LOGO
// ============================================================

class BrandLogo extends StatelessWidget {
  const BrandLogo({super.key});

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        const BrandMark(),
        const SizedBox(width: 10),
        Text(
          'IT PRO',
          style: displayText(
            size: 17,
            weight: FontWeight.w700,
            color: context.dash.text,
            letterSpacing: .2,
          ),
        ),
      ],
    );
  }
}

/// Logo IT Pro (assets/logo.png, resize từ web/favicon.png).
/// Dùng riêng khi sidebar thu gọn. Lỗi tải → ô vàng cũ.
class BrandMark extends StatelessWidget {
  const BrandMark({super.key});

  @override
  Widget build(BuildContext context) {
    return Image.asset(
      'assets/logo.png',
      width: 32,
      height: 32,
      filterQuality: FilterQuality.medium,
      errorBuilder: (_, _, _) => Container(
        width: 32,
        height: 32,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: Brand.yellow,
          borderRadius: BorderRadius.circular(8),
        ),
        child: const Icon(
          LucideIcons.server,
          size: 17,
          color: Color(0xFF111827),
        ),
      ),
    );
  }
}

// ============================================================
// RAIL ITEM (sidebar thu gọn)
// ============================================================

class _RailItem extends StatelessWidget {
  final DeptHealth dept;
  final bool active;
  final VoidCallback onTap;

  const _RailItem({
    required this.dept,
    required this.active,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final c = context.dash;
    final d = dept;
    final tip =
        '${_deptLabel(d.name)} · ${d.total} site'
        '${d.offline > 0 ? ' · ${d.offline} offline' : ''}';

    return Tooltip(
      message: tip,
      preferBelow: false,
      verticalOffset: 0,
      margin: const EdgeInsets.only(left: 56),
      // Ô vuông bo tròn 40px ở giữa rail: đang chọn = nền vàng đặc + chữ tối
      // (không thanh vàng bên trái, không nền tràn cả hàng).
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 3),
        child: Stack(
          clipBehavior: Clip.none,
          alignment: Alignment.center,
          children: [
            Center(
              child: AnimatedContainer(
                duration: Motion.of(context, Motion.fast),
                curve: Motion.curve,
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(12),
                  boxShadow: active
                      ? [
                          BoxShadow(
                            color: Brand.yellow.withValues(alpha: .35),
                            blurRadius: 10,
                            offset: const Offset(0, 2),
                          ),
                        ]
                      : const [],
                ),
                child: _HoverTile(
                  height: 40,
                  radius: 12,
                  gap: 0,
                  active: active,
                  activeColor: Brand.yellow,
                  idleColor: c.surface2,
                  hoverColor: c.border,
                  onTap: onTap,
                  semanticLabel: tip,
                  child: Center(child: _RailLabel(name: d.name, active: active)),
                ),
              ),
            ),
            // Badge số site offline (thay chấm đỏ không rõ số lượng).
            if (d.offline > 0)
              Positioned(
                right: 6,
                top: -3,
                child: Container(
                  constraints: const BoxConstraints(minWidth: 15),
                  height: 15,
                  padding: const EdgeInsets.symmetric(horizontal: 3),
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    color: context.tone.offFg,
                    borderRadius: BorderRadius.circular(99),
                    border: Border.all(color: c.bg, width: 1.5),
                  ),
                  child: Text(
                    d.offline > 9 ? '9+' : '${d.offline}',
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 8.5,
                      fontWeight: FontWeight.w700,
                      height: 1,
                    ),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

/// Chữ viết tắt phòng ban (hoặc icon lưới cho "All") trong ô rail.
/// Đang chọn (nền vàng) → chữ tối để đủ tương phản ở cả Light/Dark.
class _RailLabel extends StatelessWidget {
  final String name;
  final bool active;
  final double size;
  const _RailLabel({required this.name, required this.active, this.size = 12.5});

  @override
  Widget build(BuildContext context) {
    final c = context.dash;
    final color = active ? const Color(0xFF111827) : c.textSoft;
    if (name == kAllDept) {
      return Icon(LucideIcons.layoutGrid, size: size + 4.5, color: color);
    }
    // Giữ nguyên tên tới 3 ký tự (KVH, PRO, HR…); dài hơn mới cắt còn 3.
    final n = name.trim();
    final abbr = n.isEmpty
        ? '?'
        : n.substring(0, n.length.clamp(1, 3)).toUpperCase();
    return Text(
      abbr,
      maxLines: 1,
      softWrap: false,
      style: displayText(
        // 3 ký tự → nhỏ hơn 1 chút để vừa ô (rail 40px, hàng mở rộng 32px).
        size: abbr.length >= 3 ? size - 1 : size,
        weight: FontWeight.w700,
        color: color,
        letterSpacing: abbr.length >= 3 ? 0 : .3,
      ),
    );
  }
}

// ============================================================
// HOVER TILE — hover KHÔNG rebuild gì cả
// ============================================================

/// Mục bấm được trong sidebar.
///
/// Hover chỉ đổi 1 `ValueNotifier<bool>`; nền được vẽ bởi `CustomPainter`
/// lắng nghe notifier đó (`super(repaint:)`) → hover = **chỉ repaint 1 ô**,
/// không build, không layout, không animation. Không dùng `InkWell`
/// (InkWell tự setState khi hover → rebuild).
class _HoverTile extends StatefulWidget {
  final double height;
  final bool active;
  final VoidCallback onTap;
  final String? semanticLabel;
  final Widget child;

  /// Bo góc nền; khoảng cách trên/dưới mỗi ô.
  final double radius;
  final double gap;

  /// null → màu mặc định (navActive / surface / không nền).
  final Color? activeColor;
  final Color? hoverColor;
  final Color? idleColor;

  const _HoverTile({
    required this.height,
    required this.active,
    required this.onTap,
    required this.child,
    this.semanticLabel,
    this.radius = 8,
    this.gap = 1,
    this.activeColor,
    this.hoverColor,
    this.idleColor,
  });

  @override
  State<_HoverTile> createState() => _HoverTileState();
}

class _HoverTileState extends State<_HoverTile> {
  final _hover = ValueNotifier(false);

  /// Focus bằng bàn phím (Tab) → vẽ viền focus; Enter/Space = bấm.
  final _focus = ValueNotifier(false);

  late final _actions = <Type, Action<Intent>>{
    ActivateIntent: CallbackAction<ActivateIntent>(
      onInvoke: (_) {
        widget.onTap();
        return null;
      },
    ),
  };

  @override
  void dispose() {
    _hover.dispose();
    _focus.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final c = context.dash;
    return RepaintBoundary(
      child: Padding(
        padding: EdgeInsets.symmetric(vertical: widget.gap),
        child: Semantics(
          button: true,
          selected: widget.active,
          label: widget.semanticLabel,
          child: FocusableActionDetector(
            actions: _actions,
            mouseCursor: SystemMouseCursors.click,
            onShowHoverHighlight: (v) => _hover.value = v,
            onShowFocusHighlight: (v) => _focus.value = v,
            child: GestureDetector(
              behavior: HitTestBehavior.opaque,
              onTap: widget.onTap,
              child: CustomPaint(
                painter: _HoverBgPainter(
                  hover: _hover,
                  focus: _focus,
                  active: widget.active,
                  activeColor: widget.activeColor ?? c.navActive,
                  hoverColor: widget.hoverColor ?? c.surface,
                  idleColor: widget.idleColor,
                  focusColor: c.text,
                  radius: widget.radius,
                ),
                child: SizedBox(height: widget.height, child: widget.child),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _HoverBgPainter extends CustomPainter {
  final ValueNotifier<bool> hover;
  final ValueNotifier<bool> focus;
  final bool active;
  final Color activeColor;
  final Color hoverColor;
  final Color? idleColor;
  final Color focusColor;
  final double radius;

  _HoverBgPainter({
    required this.hover,
    required this.focus,
    required this.active,
    required this.activeColor,
    required this.hoverColor,
    required this.idleColor,
    required this.focusColor,
    required this.radius,
  }) : super(repaint: Listenable.merge([hover, focus]));

  @override
  void paint(Canvas canvas, Size size) {
    final r = RRect.fromRectAndRadius(
      Offset.zero & size,
      Radius.circular(radius),
    );
    final bg = active
        ? activeColor
        : hover.value
        ? hoverColor
        : idleColor;
    if (bg != null) canvas.drawRRect(r, Paint()..color = bg);
    if (focus.value) {
      canvas.drawRRect(
        r.deflate(1),
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = 2
          ..color = focusColor,
      );
    }
  }

  @override
  bool shouldRepaint(_HoverBgPainter old) =>
      old.active != active ||
      old.activeColor != activeColor ||
      old.hoverColor != hoverColor ||
      old.idleColor != idleColor ||
      old.radius != radius ||
      old.focusColor != focusColor ||
      old.hover != hover ||
      old.focus != focus;
}

/// Màu sức khoẻ theo tỉ lệ online: đủ → xanh, ≥80% → vàng, thấp hơn → đỏ.
Color _healthColor(BuildContext context, int online, int total) {
  final t = context.tone;
  if (total == 0 || online >= total) return t.okFg;
  return online / total >= .8 ? t.slowFg : t.offFg;
}

// ============================================================
// SYSTEM HEALTH — 1 dòng gọn: chấm màu + "21/24 online"
// ============================================================

class _HealthLine extends StatelessWidget {
  final int online;
  final int total;

  /// Rail: chấm trên, số dưới (hẹp 64px).
  final bool stacked;

  const _HealthLine({
    required this.online,
    required this.total,
    this.stacked = false,
  });

  @override
  Widget build(BuildContext context) {
    final c = context.dash;
    final color = _healthColor(context, online, total);
    final down = total - online;
    final tip = total == 0
        ? 'Chưa có site'
        : down == 0
        ? 'Tất cả $total site đang online'
        : '$down site offline';
    final style = TextStyle(
      color: c.muted,
      fontSize: stacked ? 10.5 : 12,
      fontWeight: FontWeight.w500,
      fontFeatures: const [FontFeature.tabularFigures()],
    );

    return Tooltip(
      message: tip,
      child: stacked
          ? Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                _Dot(color: color),
                const SizedBox(height: 5),
                Text('$online/$total', style: style),
              ],
            )
          : Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                _Dot(color: color),
                const SizedBox(width: 8),
                Text('$online/$total online', style: style),
              ],
            ),
    );
  }
}

// ============================================================
// NAV ITEM (wide)
// ============================================================

class _NavItem extends StatelessWidget {
  final DeptHealth dept;
  final bool active;
  final VoidCallback onTap;

  const _NavItem({
    required this.dept,
    required this.active,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final c = context.dash;
    final d = dept;

    // Đồng bộ với rail: hàng bo tròn 12; đang chọn = nền vàng đặc + chữ tối
    // + bóng vàng nhẹ. Hover chỉ đổi nền (xem _HoverTile) — không rebuild.
    const ink = Color(0xFF111827);
    final onActive = ink.withValues(alpha: .1);

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: AnimatedContainer(
        duration: Motion.of(context, Motion.fast),
        curve: Motion.curve,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(12),
          boxShadow: active
              ? [
                  BoxShadow(
                    color: Brand.yellow.withValues(alpha: .3),
                    blurRadius: 12,
                    offset: const Offset(0, 3),
                  ),
                ]
              : const [],
        ),
        child: _HoverTile(
          height: 44,
          radius: 12,
          gap: 0,
          active: active,
          activeColor: Brand.yellow,
          hoverColor: c.surface2,
          onTap: onTap,
          child: Row(
            children: [
              const SizedBox(width: 6),
              // Ô viết tắt 32px bo 10 — cùng kiểu ô rail, nhỏ hơn.
              Container(
                width: 32,
                height: 32,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: active ? onActive : c.surface2,
                  borderRadius: BorderRadius.circular(10),
                ),
                child: _RailLabel(name: d.name, active: active, size: 11.5),
              ),
              const SizedBox(width: 11),
              Expanded(
                child: Text(
                  _deptLabel(d.name),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: active ? ink : c.textSoft,
                    fontSize: 14,
                    fontWeight: active ? FontWeight.w700 : FontWeight.w500,
                    letterSpacing: .1,
                  ),
                ),
              ),
              if (d.offline > 0) ...[
                Tooltip(
                  message: '${d.offline} site offline',
                  child: _CountPill(
                    text: '${d.offline}',
                    fg: context.tone.offFg,
                    bg: active ? Colors.white : context.tone.offBg,
                    icon: LucideIcons.wifiOff,
                  ),
                ),
                const SizedBox(width: 4),
              ],
              Tooltip(
                message: '${d.total} site',
                child: _CountPill(
                  text: '${d.total}',
                  fg: active ? ink : c.muted,
                  bg: active ? onActive : c.surface2,
                ),
              ),
              const SizedBox(width: 10),
            ],
          ),
        ),
      ),
    );
  }
}

class _CountPill extends StatelessWidget {
  final String text;
  final Color fg;
  final Color bg;
  final IconData? icon;

  const _CountPill({
    required this.text,
    required this.fg,
    required this.bg,
    this.icon,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      constraints: const BoxConstraints(minWidth: 24),
      height: 20,
      padding: const EdgeInsets.symmetric(horizontal: 6),
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(99),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (icon != null) ...[
            Icon(icon, size: 10, color: fg),
            const SizedBox(width: 2),
          ],
          Text(
            text,
            style: TextStyle(
              color: fg,
              fontSize: 11.5,
              fontWeight: FontWeight.w600,
              height: 1,
              fontFeatures: const [FontFeature.tabularFigures()],
            ),
          ),
        ],
      ),
    );
  }
}

// ============================================================
// DEPT PILL (compact)
// ============================================================

class _DeptPill extends StatelessWidget {
  final DeptHealth dept;
  final bool active;
  final VoidCallback onTap;

  const _DeptPill({
    required this.dept,
    required this.active,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final c = context.dash;
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(999),
        child: AnimatedContainer(
          duration: Motion.of(context, Motion.fast),
          curve: Motion.curve,
          padding: const EdgeInsets.symmetric(horizontal: 12),
          decoration: BoxDecoration(
            color: active ? c.navActive : c.surface,
            borderRadius: BorderRadius.circular(999),
            border: Border.all(color: active ? c.navActive : c.border),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              _Dot(color: _deptDot(context, dept.name)),
              const SizedBox(width: 7),
              Text(
                _deptLabel(dept.name),
                style: TextStyle(
                  color: c.text,
                  fontSize: 13,
                  fontWeight: active ? FontWeight.w600 : FontWeight.w500,
                ),
              ),
              const SizedBox(width: 6),
              Text(
                '${dept.total}',
                style: TextStyle(color: c.muted, fontSize: 12),
              ),
              // Phòng có site offline → số offline màu đỏ ngay trên chip.
              if (dept.offline > 0) ...[
                const SizedBox(width: 6),
                Icon(LucideIcons.wifiOff, size: 11, color: context.tone.offFg),
                const SizedBox(width: 2),
                Text(
                  '${dept.offline}',
                  style: TextStyle(
                    color: context.tone.offFg,
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

class _Dot extends StatelessWidget {
  final Color color;
  const _Dot({required this.color});

  @override
  Widget build(BuildContext context) => Container(
    width: 8,
    height: 8,
    decoration: BoxDecoration(color: color, shape: BoxShape.circle),
  );
}
