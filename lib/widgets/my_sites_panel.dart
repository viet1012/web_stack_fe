import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../models/submission.dart';
import '../services/auth_store.dart';
import '../services/submission_store.dart';
import '../theme/dash_theme.dart';
import 'dash_ui.dart' show breakableHost, openInNewTab;
import 'form_ui.dart';
import 'site_icons.dart';

enum _Tab { all, pending, live, rejected }

/// Panel bên phải "Website của tôi": theo dõi trạng thái duyệt, sửa & gửi
/// lại site bị từ chối, rút lại / gỡ site.
class MySitesPanel extends StatefulWidget {
  final VoidCallback onAdd;
  final ValueChanged<Submission> onEdit;

  const MySitesPanel({super.key, required this.onAdd, required this.onEdit});

  @override
  State<MySitesPanel> createState() => _MySitesPanelState();
}

class _MySitesPanelState extends State<MySitesPanel> {
  _Tab _tab = _Tab.all;

  bool _match(Submission s) => switch (_tab) {
    _Tab.all => true,
    _Tab.pending => s.isPending,
    _Tab.live => s.isLive,
    _Tab.rejected => s.isRejected,
  };

  void _remove(Submission s) {
    final old = submissions.remove(s.id);
    if (old == null) return;
    final m = ScaffoldMessenger.of(context);
    m.hideCurrentSnackBar();
    m.showSnackBar(
      SnackBar(
        content: Text(
          s.isPending ? 'Đã rút lại “${s.name}”' : 'Đã gỡ “${s.name}”',
        ),
        action: SnackBarAction(
          label: 'Hoàn tác',
          textColor: context.dash.onInk,
          onPressed: () => submissions.restore(old),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final c = context.dash;

    return ListenableBuilder(
      listenable: Listenable.merge([submissions, auth]),
      builder: (context, _) {
        final user = auth.user;
        final mine = user == null ? <Submission>[] : submissions.mine(user);
        int n(_Tab t) => switch (t) {
          _Tab.all => mine.length,
          _Tab.pending => mine.where((s) => s.isPending).length,
          _Tab.live => mine.where((s) => s.isLive).length,
          _Tab.rejected => mine.where((s) => s.isRejected).length,
        };
        final list = mine.where(_match).toList();
        final pending = n(_Tab.pending);

        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            PanelHeader(
              icon: LucideIcons.folderOpen,
              title: 'Website của tôi',
              subtitle: mine.isEmpty
                  ? 'Website bạn đã thêm sẽ hiện ở đây.'
                  : '${mine.length} website'
                        '${pending > 0 ? ' · $pending chờ duyệt' : ''}',
              onClose: () => Navigator.of(context).maybePop(),
            ),
            if (mine.isNotEmpty) ...[
              SizedBox(
                height: 34,
                child: ListView(
                  scrollDirection: Axis.horizontal,
                  padding: const EdgeInsets.symmetric(horizontal: 20),
                  children: [
                    for (final t in _Tab.values) ...[
                      _TabPill(
                        label: switch (t) {
                          _Tab.all => 'Tất cả',
                          _Tab.pending => 'Chờ duyệt',
                          _Tab.live => 'Đang hiển thị',
                          _Tab.rejected => 'Bị từ chối',
                        },
                        count: n(t),
                        selected: _tab == t,
                        onTap: () => setState(() => _tab = t),
                      ),
                      const SizedBox(width: 6),
                    ],
                  ],
                ),
              ),
              const SizedBox(height: 12),
              Divider(height: 1, color: c.border),
            ],
            Expanded(
              child: mine.isEmpty
                  ? _Empty(onAdd: widget.onAdd)
                  : list.isEmpty
                  ? Center(
                      child: Text(
                        'Không có website nào ở mục này',
                        style: TextStyle(color: c.muted, fontSize: 13),
                      ),
                    )
                  : ListView.separated(
                      padding: const EdgeInsets.fromLTRB(20, 16, 20, 20),
                      itemCount: list.length,
                      separatorBuilder: (_, _) => const SizedBox(height: 10),
                      itemBuilder: (_, i) => _MyItem(
                        key: ValueKey(list[i].id),
                        s: list[i],
                        onEdit: () => widget.onEdit(list[i]),
                        onRemove: () => _remove(list[i]),
                      ),
                    ),
            ),
            if (mine.isNotEmpty)
              Container(
                padding: const EdgeInsets.fromLTRB(20, 12, 20, 14),
                decoration: BoxDecoration(
                  color: c.bg,
                  border: Border(top: BorderSide(color: c.border)),
                ),
                child: DashButton(
                  label: 'Thêm website',
                  icon: LucideIcons.plus,
                  expand: true,
                  onPressed: widget.onAdd,
                ),
              ),
          ],
        );
      },
    );
  }
}

class _MyItem extends StatelessWidget {
  final Submission s;
  final VoidCallback onEdit;
  final VoidCallback onRemove;

  const _MyItem({
    super.key,
    required this.s,
    required this.onEdit,
    required this.onRemove,
  });

  @override
  Widget build(BuildContext context) {
    final c = context.dash;
    final t = context.tone;

    return Container(
      padding: const EdgeInsets.fromLTRB(12, 12, 6, 12),
      decoration: BoxDecoration(
        color: c.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: s.isRejected ? t.offBorder : c.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              SiteIcon(website: s.toWebsite(), size: 38),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      s.name,
                      style: TextStyle(
                        color: c.text,
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      breakableHost(s.url),
                      style: monoText(size: 11.5, color: c.hostText),
                    ),
                  ],
                ),
              ),
              _ItemMenu(s: s, onEdit: onEdit, onRemove: onRemove),
            ],
          ),
          const SizedBox(height: 10),
          Padding(
            padding: const EdgeInsets.only(right: 6),
            child: Wrap(
              spacing: 6,
              runSpacing: 6,
              crossAxisAlignment: WrapCrossAlignment.center,
              children: [
                ReviewChip(s.status),
                VisibilityChip(s.visibility),
                MiniChip(label: s.department, fg: c.textSoft, bg: c.surface2),
                Text(
                  s.reviewedAt != null && !s.isPending
                      ? '${s.isRejected ? 'Từ chối' : 'Duyệt'} '
                            '${timeAgoVi(s.reviewedAt!)}'
                      : 'Thêm ${timeAgoVi(s.createdAt)}',
                  style: TextStyle(color: c.faint, fontSize: 12),
                ),
              ],
            ),
          ),
          if (s.isRejected) ...[
            const SizedBox(height: 10),
            Padding(
              padding: const EdgeInsets.only(right: 6),
              child: Container(
                width: double.infinity,
                padding: const EdgeInsets.fromLTRB(12, 10, 10, 10),
                decoration: BoxDecoration(
                  color: t.offBg,
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Row(
                  children: [
                    Expanded(
                      child: Text.rich(
                        TextSpan(
                          children: [
                            const TextSpan(
                              text: 'Lý do: ',
                              style: TextStyle(fontWeight: FontWeight.w700),
                            ),
                            TextSpan(text: s.rejectReason ?? '—'),
                          ],
                        ),
                        style: TextStyle(
                          color: t.offFg,
                          fontSize: 12.5,
                          height: 1.4,
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    DashButton.secondary(
                      label: 'Sửa & gửi lại',
                      icon: LucideIcons.pencil,
                      height: 32,
                      onPressed: onEdit,
                    ),
                  ],
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

/// Menu "…" của từng site: Mở · Sửa · Rút lại / Gỡ.
class _ItemMenu extends StatelessWidget {
  final Submission s;
  final VoidCallback onEdit;
  final VoidCallback onRemove;

  const _ItemMenu({
    required this.s,
    required this.onEdit,
    required this.onRemove,
  });

  @override
  Widget build(BuildContext context) {
    final c = context.dash;
    final t = context.tone;

    Widget item(IconData icon, String label, VoidCallback onTap, [Color? fg]) =>
        MenuItemButton(
          onPressed: onTap,
          leadingIcon: Icon(icon, size: 15, color: fg ?? c.textSoft),
          style: MenuItemButton.styleFrom(
            foregroundColor: fg ?? c.text,
            textStyle: const TextStyle(fontSize: 13.5),
            minimumSize: const Size(180, 38),
          ),
          child: Text(label),
        );

    return MenuAnchor(
      alignmentOffset: const Offset(-150, 0),
      style: dashMenuStyle(c),
      menuChildren: [
        if (s.isLive) item(LucideIcons.externalLink, 'Mở website', () => openInNewTab(s.url)),
        item(LucideIcons.pencil, 'Sửa', onEdit),
        item(
          s.isPending ? LucideIcons.undo2 : LucideIcons.trash2,
          s.isPending ? 'Rút lại yêu cầu' : 'Gỡ website',
          onRemove,
          t.offFg,
        ),
      ],
      builder: (_, ctrl, _) => Tooltip(
        message: 'Tuỳ chọn',
        child: IconButton(
          onPressed: () => ctrl.isOpen ? ctrl.close() : ctrl.open(),
          icon: const Icon(LucideIcons.ellipsis, size: 18),
          color: c.muted,
          visualDensity: VisualDensity.compact,
          style: IconButton.styleFrom(
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
          ),
        ),
      ),
    );
  }
}

class _TabPill extends StatelessWidget {
  final String label;
  final int count;
  final bool selected;
  final VoidCallback onTap;

  const _TabPill({
    required this.label,
    required this.count,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final c = context.dash;
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(99),
        child: AnimatedContainer(
          duration: Motion.of(context, Motion.fast),
          padding: const EdgeInsets.only(left: 12, right: 5),
          decoration: BoxDecoration(
            color: selected ? c.ink : c.surface,
            borderRadius: BorderRadius.circular(99),
            border: Border.all(color: selected ? c.ink : c.border),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                label,
                style: TextStyle(
                  color: selected ? c.onInk : c.textSoft,
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(width: 6),
              CountBadge(
                count,
                fg: selected ? c.ink : c.muted,
                bg: selected ? c.onInk : c.surface2,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _Empty extends StatelessWidget {
  final VoidCallback onAdd;
  const _Empty({required this.onAdd});

  @override
  Widget build(BuildContext context) {
    final c = context.dash;
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 64,
              height: 64,
              decoration: BoxDecoration(
                color: c.surface2,
                shape: BoxShape.circle,
              ),
              child: Icon(LucideIcons.globe, size: 28, color: c.muted),
            ),
            const SizedBox(height: 16),
            Text(
              'Chưa có website nào',
              style: displayText(size: 16, weight: FontWeight.w700, color: c.text),
            ),
            const SizedBox(height: 6),
            Text(
              'Thêm website nội bộ để cả công ty cùng dùng,\n'
              'hoặc để riêng bạn xem.',
              textAlign: TextAlign.center,
              style: TextStyle(color: c.muted, fontSize: 13, height: 1.5),
            ),
            const SizedBox(height: 18),
            DashButton(
              label: 'Thêm website',
              icon: LucideIcons.plus,
              onPressed: onAdd,
            ),
          ],
        ),
      ),
    );
  }
}
