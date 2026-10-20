import 'package:flutter/material.dart';

import '../theme/dash_theme.dart';
import 'animated_logo.dart';
import 'team_art.dart';

const kAllDept = 'ALL';

IconData deptIcon(String name) {
  switch (name.toLowerCase()) {
    case 'all':
      return Icons.apps_rounded;
    case 'hr':
      return Icons.groups_rounded;
    case 'it':
      return Icons.memory_rounded;
    case 'kvh':
      return Icons.apartment_rounded;
    case 'ma':
      return Icons.build_rounded;
    case 'pc':
      return Icons.event_note_rounded;
    case 'pro':
    case 'production':
      return Icons.precision_manufacturing_rounded;
    case 'te':
      return Icons.engineering_rounded;
    default:
      return Icons.folder_rounded;
  }
}

class Sidebar extends StatelessWidget {
  /// Có cả "ALL" ở đầu.
  final List<DeptHealth> departments;
  final String selected;
  final ValueChanged<String> onSelect;
  final int online;
  final int total;

  const Sidebar({
    super.key,
    required this.departments,
    required this.selected,
    required this.onSelect,
    required this.online,
    required this.total,
  });

  @override
  Widget build(BuildContext context) {
    final c = context.dash;

    return Container(
      width: 240,
      decoration: BoxDecoration(
        color: c.surface,
        border: Border(right: BorderSide(color: c.border)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const Padding(
            padding: EdgeInsets.fromLTRB(20, 22, 20, 18),
            child: Align(alignment: Alignment.centerLeft, child: AnimatedLogo()),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 0, 20, 8),
            child: Text(
              'DEPARTMENTS',
              style: TextStyle(
                color: c.muted,
                fontSize: 11,
                fontWeight: FontWeight.w600,
                letterSpacing: .8,
              ),
            ),
          ),
          Expanded(
            child: ListView(
              padding: const EdgeInsets.symmetric(horizontal: 10),
              children: [
                for (final d in departments)
                  _NavItem(
                    dept: d,
                    active: d.name == selected,
                    onTap: () => onSelect(d.name),
                  ),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 8, 20, 0),
            child: Text(
              'IT TEAM',
              style: TextStyle(
                color: c.muted,
                fontSize: 11,
                fontWeight: FontWeight.w600,
                letterSpacing: .8,
              ),
            ),
          ),
          SizedBox(
            height: 180,
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 6, 16, 16),
              child: TeamArt(
                depts: departments.where((d) => d.name != kAllDept).toList(),
                online: online,
                total: total,
                selected: selected,
                onSelect: onSelect,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _NavItem extends StatefulWidget {
  final DeptHealth dept;
  final bool active;
  final VoidCallback onTap;

  const _NavItem({
    required this.dept,
    required this.active,
    required this.onTap,
  });

  @override
  State<_NavItem> createState() => _NavItemState();
}

class _NavItemState extends State<_NavItem> {
  bool _hover = false;

  @override
  Widget build(BuildContext context) {
    final c = context.dash;
    final active = widget.active;
    final d = Motion.of(context, Motion.fast);

    final bg = active
        ? c.accent.withValues(alpha: .16)
        : (_hover ? c.surface2 : Colors.transparent);
    final fg = active ? c.text : (_hover ? c.text : c.muted);

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: Semantics(
        selected: active,
        button: true,
        child: Material(
          color: Colors.transparent,
          child: InkWell(
            onTap: widget.onTap,
            onHover: (v) => setState(() => _hover = v),
            borderRadius: BorderRadius.circular(10),
            focusColor: c.accent.withValues(alpha: .22),
            child: AnimatedContainer(
              duration: d,
              curve: Motion.curve,
              height: 40,
              decoration: BoxDecoration(
                color: bg,
                borderRadius: BorderRadius.circular(10),
              ),
              child: Row(
                children: [
                  // Thanh chỉ báo bên trái
                  AnimatedContainer(
                    duration: d,
                    curve: Motion.curve,
                    width: 3,
                    height: active ? 20 : 0,
                    margin: const EdgeInsets.only(right: 9),
                    decoration: BoxDecoration(
                      color: c.accent,
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                  Icon(
                    deptIcon(widget.dept.name),
                    size: 18,
                    color: active ? c.accent : fg,
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      widget.dept.name,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        color: fg,
                        fontSize: 13.5,
                        fontWeight: active ? FontWeight.w700 : FontWeight.w500,
                      ),
                    ),
                  ),
                  CountBadge(
                    count: widget.dept.total,
                    alert: widget.dept.offline > 0,
                    active: active,
                  ),
                  const SizedBox(width: 10),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class CountBadge extends StatelessWidget {
  final int count;
  final bool alert;
  final bool active;

  const CountBadge({
    super.key,
    required this.count,
    required this.alert,
    this.active = false,
  });

  @override
  Widget build(BuildContext context) {
    final c = context.dash;
    return Stack(
      clipBehavior: Clip.none,
      children: [
        Container(
          constraints: const BoxConstraints(minWidth: 24),
          padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
          decoration: BoxDecoration(
            color: active ? c.accent : c.surface2,
            borderRadius: BorderRadius.circular(999),
            border: Border.all(color: active ? c.accent : c.border),
          ),
          child: Text(
            '$count',
            textAlign: TextAlign.center,
            style: TextStyle(
              color: active ? Colors.white : c.muted,
              fontSize: 11,
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
        if (alert)
          Positioned(
            right: -2,
            top: -2,
            child: Tooltip(
              message: 'Has offline sites',
              child: Container(
                width: 8,
                height: 8,
                decoration: BoxDecoration(
                  color: c.bad,
                  shape: BoxShape.circle,
                  border: Border.all(color: c.surface, width: 1.5),
                ),
              ),
            ),
          ),
      ],
    );
  }
}

/// < 900px: sidebar thành thanh chip ngang.
class DeptChipBar extends StatelessWidget {
  final List<DeptHealth> departments;
  final String selected;
  final ValueChanged<String> onSelect;

  const DeptChipBar({
    super.key,
    required this.departments,
    required this.selected,
    required this.onSelect,
  });

  @override
  Widget build(BuildContext context) {
    final c = context.dash;
    return SizedBox(
      height: 44,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
        itemCount: departments.length,
        separatorBuilder: (_, _) => const SizedBox(width: 8),
        itemBuilder: (context, i) {
          final d = departments[i];
          final active = d.name == selected;
          return Material(
            color: Colors.transparent,
            child: InkWell(
              onTap: () => onSelect(d.name),
              borderRadius: BorderRadius.circular(999),
              child: AnimatedContainer(
                duration: Motion.of(context, Motion.fast),
                curve: Motion.curve,
                padding: const EdgeInsets.fromLTRB(10, 0, 6, 0),
                decoration: BoxDecoration(
                  color: active ? c.accent.withValues(alpha: .16) : c.surface,
                  borderRadius: BorderRadius.circular(999),
                  border: Border.all(color: active ? c.accent : c.border),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(deptIcon(d.name), size: 15, color: active ? c.accent : c.muted),
                    const SizedBox(width: 6),
                    Text(
                      d.name,
                      style: TextStyle(
                        color: active ? c.text : c.muted,
                        fontSize: 13,
                        fontWeight: active ? FontWeight.w700 : FontWeight.w500,
                      ),
                    ),
                    const SizedBox(width: 6),
                    CountBadge(count: d.total, alert: d.offline > 0, active: active),
                  ],
                ),
              ),
            ),
          );
        },
      ),
    );
  }
}
