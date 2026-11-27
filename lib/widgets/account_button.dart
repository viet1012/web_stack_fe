import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../services/auth_store.dart';
import '../services/submission_store.dart';
import '../theme/dash_theme.dart';
import 'dash_ui.dart' show HoverSurface;
import 'form_ui.dart';

/// Góc phải header:
/// - Chưa đăng nhập → nút "Đăng nhập".
/// - Đã đăng nhập → avatar chữ cái; admin có chấm vàng + số site chờ duyệt.
///   Bấm → menu: Website của tôi · Duyệt website (admin) · Đăng xuất.
class AccountButton extends StatelessWidget {
  final VoidCallback onLogin;
  final VoidCallback onMySites;
  final VoidCallback onReview;

  /// Màn hẹp: nút đăng nhập chỉ còn icon.
  final bool compact;

  const AccountButton({
    super.key,
    required this.onLogin,
    required this.onMySites,
    required this.onReview,
    this.compact = false,
  });

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: Listenable.merge([auth, submissions]),
      builder: (context, _) {
        final user = auth.user;
        if (user == null) return _loginButton(context);
        return _menu(context, user);
      },
    );
  }

  Widget _loginButton(BuildContext context) {
    final c = context.dash;
    return Tooltip(
      message: 'Đăng nhập để thêm website & xem site Private',
      child: HoverSurface(
        onTap: onLogin,
        radius: 10,
        color: c.surface,
        hoverColor: c.surface2,
        borderColor: c.border,
        child: SizedBox(
          height: 36,
          width: compact ? 36 : null,
          child: Padding(
            padding: EdgeInsets.symmetric(horizontal: compact ? 0 : 12),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(LucideIcons.logIn, size: 17, color: c.text),
                if (!compact) ...[
                  const SizedBox(width: 8),
                  Text(
                    'Đăng nhập',
                    style: TextStyle(
                      color: c.text,
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _menu(BuildContext context, AppUser user) {
    final c = context.dash;
    final t = context.tone;
    final pending = user.isAdmin ? submissions.pending.length : 0;
    final mine = submissions.mine(user);
    final myPending = mine.where((s) => s.isPending).length;
    final myRejected = mine.where((s) => s.isRejected).length;

    Widget item(
      IconData icon,
      String label,
      VoidCallback onTap, {
      Widget? trailing,
      Color? fg,
    }) => MenuItemButton(
      onPressed: onTap,
      leadingIcon: Icon(icon, size: 16, color: fg ?? c.textSoft),
      trailingIcon: trailing,
      style: MenuItemButton.styleFrom(
        foregroundColor: fg ?? c.text,
        textStyle: const TextStyle(fontSize: 13.5, fontWeight: FontWeight.w500),
        minimumSize: const Size(240, 40),
        padding: const EdgeInsets.symmetric(horizontal: 14),
      ),
      child: Text(label),
    );

    return MenuAnchor(
      style: dashMenuStyle(c),
      alignmentOffset: const Offset(-206, 6),
      menuChildren: [
        // Thông tin tài khoản
        Padding(
          padding: const EdgeInsets.fromLTRB(14, 8, 14, 10),
          child: Row(
            children: [
              _Avatar(user: user, size: 36),
              const SizedBox(width: 10),
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    user.displayName,
                    style: TextStyle(
                      color: c.text,
                      fontSize: 13.5,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    user.isAdmin ? 'Quản trị viên' : 'Người dùng',
                    style: TextStyle(color: c.muted, fontSize: 12),
                  ),
                ],
              ),
            ],
          ),
        ),
        Divider(height: 1, color: c.border),
        const SizedBox(height: 4),
        item(
          LucideIcons.folderOpen,
          'Website của tôi',
          onMySites,
          trailing: myRejected > 0
              ? CountBadge(myRejected, fg: t.offFg, bg: t.offBg)
              : myPending > 0
              ? CountBadge(myPending, fg: t.slowFg, bg: t.slowBg)
              : mine.isNotEmpty
              ? CountBadge(mine.length)
              : null,
        ),
        if (user.isAdmin)
          item(
            LucideIcons.shieldCheck,
            'Duyệt website',
            onReview,
            trailing: pending > 0
                ? CountBadge(pending, fg: t.slowFg, bg: t.slowBg)
                : null,
          ),
        const SizedBox(height: 4),
        Divider(height: 1, color: c.border),
        const SizedBox(height: 4),
        item(LucideIcons.logOut, 'Đăng xuất', auth.logout),
      ],
      builder: (context, ctrl, _) {
        final dot = pending > 0 || myRejected > 0;
        return Tooltip(
          message: pending > 0
              ? '${user.displayName} · $pending website chờ duyệt'
              : myRejected > 0
              ? '${user.displayName} · $myRejected website bị từ chối'
              : user.displayName,
          child: MouseRegion(
            cursor: SystemMouseCursors.click,
            child: GestureDetector(
              onTap: () => ctrl.isOpen ? ctrl.close() : ctrl.open(),
              child: Stack(
                clipBehavior: Clip.none,
                children: [
                  _Avatar(user: user, size: 38, ring: true),
                  // Có việc cần xử lý → chấm báo (vàng = chờ duyệt, đỏ = bị từ chối).
                  if (dot)
                    Positioned(
                      right: -2,
                      top: -2,
                      child: Container(
                        width: 12,
                        height: 12,
                        decoration: BoxDecoration(
                          color: pending > 0 ? Brand.yellow : t.offFg,
                          shape: BoxShape.circle,
                          border: Border.all(color: c.bg, width: 2),
                        ),
                      ),
                    ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }
}

class _Avatar extends StatelessWidget {
  final AppUser user;
  final double size;
  final bool ring;
  const _Avatar({required this.user, required this.size, this.ring = false});

  @override
  Widget build(BuildContext context) {
    final c = context.dash;
    return Container(
      width: size,
      height: size,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: user.isAdmin ? Brand.yellow : c.ink,
        shape: BoxShape.circle,
        border: ring ? Border.all(color: c.border, width: 1) : null,
      ),
      child: Text(
        user.initials,
        style: displayText(
          size: size * .36,
          weight: FontWeight.w700,
          color: user.isAdmin ? const Color(0xFF111827) : c.onInk,
        ),
      ),
    );
  }
}
