import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../models/submission.dart';
import '../services/auth_store.dart';
import '../services/preview_image.dart';
import '../services/submission_store.dart';
import '../services/website_service.dart' show apiErrorMessage;
import '../theme/dash_theme.dart';
import 'dash_ui.dart' show breakableHost, openInNewTab;
import 'form_ui.dart';
import 'site_icons.dart';

/// Lý do từ chối hay dùng — bấm để điền nhanh.
const _quickReasons = [
  'Không truy cập được URL',
  'Trùng với website đã có',
  'Không phải website nội bộ',
  'Tên chưa rõ ràng',
];

/// Panel bên phải cho ADMIN: duyệt / từ chối site Public.
class ReviewPanel extends StatefulWidget {
  const ReviewPanel({super.key});

  @override
  State<ReviewPanel> createState() => _ReviewPanelState();
}

class _ReviewPanelState extends State<ReviewPanel> {
  bool _history = false;

  /// Đang gửi duyệt / từ chối → khoá nút của site đó.
  final Set<int> _busy = {};

  void _snack(String text, {VoidCallback? undo}) {
    final m = ScaffoldMessenger.of(context);
    m.hideCurrentSnackBar();
    m.showSnackBar(
      SnackBar(
        content: Text(text),
        action: undo == null
            ? null
            : SnackBarAction(
                label: 'Hoàn tác',
                textColor: context.dash.onInk,
                onPressed: undo,
              ),
      ),
    );
  }

  /// Hoàn tác duyệt / từ chối → đưa về lại hàng chờ.
  Future<void> _reopen(Submission s) async {
    try {
      await submissions.reopen(s.id);
    } catch (e) {
      if (mounted) _snack(apiErrorMessage(e, 'Không hoàn tác được'));
    }
  }

  Future<void> _run(
    Submission s,
    Future<Submission> Function() action,
    String done,
  ) async {
    if (!auth.isAdmin || _busy.contains(s.id)) return;
    setState(() => _busy.add(s.id));
    try {
      await action();
      if (mounted) _snack(done, undo: () => _reopen(s));
    } catch (e) {
      if (mounted) _snack(apiErrorMessage(e));
    } finally {
      if (mounted) setState(() => _busy.remove(s.id));
    }
  }

  void _approve(Submission s) => _run(
    s,
    () => submissions.approve(s.id),
    'Đã phê duyệt “${s.name}” — đang hiện công khai',
  );

  void _reject(Submission s, String reason) => _run(
    s,
    () => submissions.reject(s.id, reason),
    'Đã từ chối “${s.name}”',
  );

  @override
  Widget build(BuildContext context) {
    final c = context.dash;

    return ListenableBuilder(
      listenable: submissions,
      builder: (context, _) {
        final pending = submissions.pending;
        final reviewed = submissions.reviewed;

        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            PanelHeader(
              icon: LucideIcons.shieldCheck,
              title: 'Duyệt website',
              subtitle: pending.isEmpty
                  ? 'Không có yêu cầu nào đang chờ.'
                  : '${pending.length} website Public đang chờ duyệt.',
              onClose: () => Navigator.of(context).maybePop(),
            ),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: _Segment(
                history: _history,
                pending: pending.length,
                reviewed: reviewed.length,
                onChanged: (v) => setState(() => _history = v),
              ),
            ),
            const SizedBox(height: 12),
            Divider(height: 1, color: c.border),
            Expanded(
              child: AnimatedSwitcher(
                duration: Motion.of(context, Motion.fast),
                child: _history
                    ? _list(
                        key: const ValueKey('h'),
                        items: reviewed,
                        empty: 'Chưa xử lý yêu cầu nào',
                        builder: (s) => _HistoryItem(s: s),
                      )
                    : _list(
                        key: const ValueKey('p'),
                        items: pending,
                        empty: 'Không còn website nào chờ duyệt',
                        emptyIcon: LucideIcons.circleCheck,
                        builder: (s) => AbsorbPointer(
                          key: ValueKey(s.id),
                          absorbing: _busy.contains(s.id),
                          child: AnimatedOpacity(
                            opacity: _busy.contains(s.id) ? .5 : 1,
                            duration: Motion.of(context, Motion.fast),
                            child: _PendingItem(
                              s: s,
                              onApprove: () => _approve(s),
                              onReject: (r) => _reject(s, r),
                            ),
                          ),
                        ),
                      ),
              ),
            ),
          ],
        );
      },
    );
  }

  Widget _list({
    required Key key,
    required List<Submission> items,
    required String empty,
    IconData emptyIcon = LucideIcons.inbox,
    required Widget Function(Submission) builder,
  }) {
    final c = context.dash;
    if (items.isEmpty) {
      return Center(
        key: key,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 56,
              height: 56,
              decoration: BoxDecoration(
                color: c.surface2,
                shape: BoxShape.circle,
              ),
              child: Icon(emptyIcon, size: 24, color: c.muted),
            ),
            const SizedBox(height: 12),
            Text(empty, style: TextStyle(color: c.muted, fontSize: 13.5)),
          ],
        ),
      );
    }
    return ListView.separated(
      key: key,
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 24),
      itemCount: items.length,
      separatorBuilder: (_, _) => const SizedBox(height: 10),
      itemBuilder: (_, i) => builder(items[i]),
    );
  }
}

// ============================================================
// PENDING ITEM — duyệt / từ chối (nhập lý do ngay trong thẻ)
// ============================================================

class _PendingItem extends StatefulWidget {
  final Submission s;
  final VoidCallback onApprove;
  final ValueChanged<String> onReject;

  const _PendingItem({
    required this.s,
    required this.onApprove,
    required this.onReject,
  });

  @override
  State<_PendingItem> createState() => _PendingItemState();
}

class _PendingItemState extends State<_PendingItem> {
  bool _rejecting = false;
  final _reason = TextEditingController();

  @override
  void dispose() {
    _reason.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final c = context.dash;
    final t = context.tone;
    final s = widget.s;

    return AnimatedContainer(
      duration: Motion.of(context, Motion.fast),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: c.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: _rejecting ? t.offBorder : c.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Tên + URL (bấm để mở thử)
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              SiteIcon(website: s.toWebsite(), size: 40),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      s.name,
                      style: TextStyle(
                        color: c.text,
                        fontSize: 14.5,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Tooltip(
                      message: 'Mở thử trong tab mới',
                      child: InkWell(
                        onTap: () => openInNewTab(s.url),
                        borderRadius: BorderRadius.circular(4),
                        child: Text.rich(
                          TextSpan(
                            children: [
                              TextSpan(text: breakableHost(s.url)),
                              const WidgetSpan(
                                alignment: PlaceholderAlignment.middle,
                                child: Padding(
                                  padding: EdgeInsets.only(left: 5),
                                  child: Icon(
                                    LucideIcons.externalLink,
                                    size: 12,
                                  ),
                                ),
                              ),
                            ],
                          ),
                          style: monoText(size: 12, color: c.hostText),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          // Người gửi · phòng ban · thời gian
          Wrap(
            spacing: 6,
            runSpacing: 6,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              MiniChip(
                label: s.ownerLabel,
                icon: LucideIcons.user,
                fg: c.textSoft,
                bg: c.surface2,
              ),
              MiniChip(label: s.department, fg: c.textSoft, bg: c.surface2),
              Text(
                'Gửi ${timeAgoVi(s.submittedAt)}',
                style: TextStyle(color: c.faint, fontSize: 12),
              ),
            ],
          ),
          if (s.note.isNotEmpty) ...[
            const SizedBox(height: 10),
            Container(
              padding: const EdgeInsets.fromLTRB(12, 9, 12, 9),
              decoration: BoxDecoration(
                color: c.surface2,
                borderRadius: BorderRadius.circular(8),
                border: Border(left: BorderSide(color: c.faint, width: 2)),
              ),
              child: Text(
                s.note,
                style: TextStyle(color: c.textSoft, fontSize: 13, height: 1.45),
              ),
            ),
          ],
          // Ảnh xem trước người gửi tự tải lên (không có → sẽ tự chụp).
          if (s.previewImage != null) ...[
            const SizedBox(height: 10),
            Align(
              alignment: Alignment.centerLeft,
              child: Container(
                width: 200,
                clipBehavior: Clip.antiAlias,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: c.border),
                ),
                child: AspectRatio(
                  aspectRatio: 16 / 9,
                  child: Image(
                    image: previewImageProvider(s.previewImage!),
                    fit: BoxFit.cover,
                    alignment: Alignment.topCenter,
                  ),
                ),
              ),
            ),
          ],
          const SizedBox(height: 12),
          AnimatedSize(
            duration: Motion.of(context),
            curve: Motion.curve,
            alignment: Alignment.topCenter,
            child: _rejecting ? _rejectForm(context) : _actions(context),
          ),
        ],
      ),
    );
  }

  Widget _actions(BuildContext context) => Row(
    children: [
      Expanded(
        child: DashButton.secondary(
          label: 'Từ chối',
          icon: LucideIcons.x,
          height: 36,
          expand: true,
          onPressed: () => setState(() => _rejecting = true),
        ),
      ),
      const SizedBox(width: 8),
      Expanded(
        child: DashButton(
          label: 'Phê duyệt',
          icon: LucideIcons.check,
          kind: DashButtonKind.success,
          height: 36,
          expand: true,
          onPressed: widget.onApprove,
        ),
      ),
    ],
  );

  Widget _rejectForm(BuildContext context) {
    final c = context.dash;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          'Lý do từ chối',
          style: TextStyle(
            color: c.text,
            fontSize: 13,
            fontWeight: FontWeight.w600,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          'Người gửi sẽ thấy lý do này để sửa và gửi lại.',
          style: TextStyle(color: c.muted, fontSize: 12),
        ),
        const SizedBox(height: 8),
        Wrap(
          spacing: 6,
          runSpacing: 6,
          children: [
            for (final r in _quickReasons)
              ActionChip(
                label: Text(r),
                onPressed: () => setState(() {
                  _reason.text = r;
                  _reason.selection = TextSelection.collapsed(offset: r.length);
                }),
                labelStyle: TextStyle(color: c.textSoft, fontSize: 12),
                backgroundColor: c.surface2,
                side: BorderSide.none,
                visualDensity: VisualDensity.compact,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(99),
                ),
              ),
          ],
        ),
        const SizedBox(height: 8),
        DashTextField(
          controller: _reason,
          autofocus: true,
          hint: 'Nhập lý do…',
          maxLines: 2,
          maxLength: 160,
          onChanged: (_) => setState(() {}),
        ),
        const SizedBox(height: 10),
        Row(
          mainAxisAlignment: MainAxisAlignment.end,
          children: [
            DashButton.ghost(
              label: 'Huỷ',
              height: 36,
              onPressed: () => setState(() {
                _rejecting = false;
                _reason.clear();
              }),
            ),
            const SizedBox(width: 6),
            DashButton(
              label: 'Xác nhận từ chối',
              kind: DashButtonKind.danger,
              height: 36,
              onPressed: _reason.text.trim().isEmpty
                  ? null
                  : () => widget.onReject(_reason.text.trim()),
            ),
          ],
        ),
      ],
    );
  }
}

// ============================================================
// HISTORY ITEM
// ============================================================

class _HistoryItem extends StatelessWidget {
  final Submission s;
  const _HistoryItem({required this.s});

  @override
  Widget build(BuildContext context) {
    final c = context.dash;
    final t = context.tone;
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: c.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: c.border),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SiteIcon(website: s.toWebsite(), size: 34),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        s.name,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          color: c.text,
                          fontSize: 13.5,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    ReviewChip(s.status),
                  ],
                ),
                const SizedBox(height: 3),
                Text(
                  '${s.ownerLabel} · ${s.department} · '
                  '${s.isRejected ? 'từ chối' : 'duyệt'} bởi '
                  '${s.reviewerLabel ?? '—'} ${timeAgoVi(s.reviewedAt!)}',
                  style: TextStyle(color: c.muted, fontSize: 12),
                ),
                if (s.isRejected && (s.rejectReason ?? '').isNotEmpty) ...[
                  const SizedBox(height: 4),
                  Text(
                    'Lý do: ${s.rejectReason}',
                    style: TextStyle(color: t.offFg, fontSize: 12),
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// 2 tab: Chờ duyệt (n) / Đã xử lý (n).
class _Segment extends StatelessWidget {
  final bool history;
  final int pending;
  final int reviewed;
  final ValueChanged<bool> onChanged;

  const _Segment({
    required this.history,
    required this.pending,
    required this.reviewed,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    final c = context.dash;
    final t = context.tone;

    Widget seg(String label, int n, bool on, VoidCallback tap, {bool warn = false}) =>
        Expanded(
          child: Material(
            color: Colors.transparent,
            child: InkWell(
              onTap: tap,
              borderRadius: BorderRadius.circular(8),
              child: AnimatedContainer(
                duration: Motion.of(context, Motion.fast),
                height: 34,
                decoration: BoxDecoration(
                  color: on ? c.surface : Colors.transparent,
                  borderRadius: BorderRadius.circular(8),
                  boxShadow: on
                      ? [
                          BoxShadow(
                            color: c.shadow,
                            blurRadius: 4,
                            offset: const Offset(0, 1),
                          ),
                        ]
                      : const [],
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text(
                      label,
                      style: TextStyle(
                        color: on ? c.text : c.muted,
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(width: 6),
                    CountBadge(
                      n,
                      fg: warn && n > 0 ? t.slowFg : c.muted,
                      bg: warn && n > 0 ? t.slowBg : c.surface2,
                    ),
                  ],
                ),
              ),
            ),
          ),
        );

    return Container(
      padding: const EdgeInsets.all(3),
      decoration: BoxDecoration(
        color: c.surface2,
        borderRadius: BorderRadius.circular(10),
      ),
      child: Row(
        children: [
          seg('Chờ duyệt', pending, !history, () => onChanged(false), warn: true),
          seg('Đã xử lý', reviewed, history, () => onChanged(true)),
        ],
      ),
    );
  }
}
