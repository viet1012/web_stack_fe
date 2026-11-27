import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../models/submission.dart';
import '../models/website.dart';
import '../services/auth_store.dart';
import '../services/preview_image.dart';
import '../services/submission_store.dart';
import '../services/website_service.dart';
import '../theme/dash_theme.dart';
import 'login_dialog.dart' show ensureLoggedIn;
import 'form_ui.dart';

/// Dialog "Thêm website" (hoặc sửa & gửi lại khi có [edit]).
/// Gọi sau [ensureLoggedIn]. Trả về Submission đã lưu, null nếu huỷ.
Future<Submission?> showUploadDialog(
  BuildContext context, {
  required List<String> departments,
  required List<Website> systemSites,
  Submission? edit,
  VoidCallback? onOpenMine,
}) {
  return showDashDialog<Submission>(
    context,
    builder: (_) => UploadDialog(
      departments: departments,
      systemSites: systemSites,
      edit: edit,
      onOpenMine: onOpenMine,
    ),
  );
}

class UploadDialog extends StatefulWidget {
  final List<String> departments;

  /// Site hệ thống (từ BE) — để báo trùng URL.
  final List<Website> systemSites;
  final Submission? edit;
  final VoidCallback? onOpenMine;

  const UploadDialog({
    super.key,
    required this.departments,
    required this.systemSites,
    this.edit,
    this.onOpenMine,
  });

  @override
  State<UploadDialog> createState() => _UploadDialogState();
}

class _UploadDialogState extends State<UploadDialog> {
  late final _url = TextEditingController(text: widget.edit?.url ?? '');
  late final _name = TextEditingController(text: widget.edit?.name ?? '');
  late final _note = TextEditingController(text: widget.edit?.note ?? '');
  final _urlFocus = FocusNode();
  final _nameFocus = FocusNode();
  final _deptMenu = MenuController();

  /// Chuyển sang ô Tên và bôi đen sẵn → gõ để thay, Enter để giữ.
  void _focusName() {
    _nameFocus.requestFocus();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      _name.selection =
          TextSelection(baseOffset: 0, extentOffset: _name.text.length);
    });
  }

  /// Enter ở ô Tên → mở danh sách Phòng ban (nếu chưa chọn).
  void _openDept() {
    _nameFocus.unfocus();
    if (_dept == null) _deptMenu.open();
  }

  late SiteVisibility _vis = widget.edit?.visibility ?? SiteVisibility.public;
  late String? _dept = widget.edit?.department;

  /// Người dùng đã tự gõ tên → không tự điền đè nữa.
  late bool _nameTouched = widget.edit != null;

  /// Chỉ hiện lỗi sau khi rời ô / bấm gửi (không báo lỗi khi đang gõ).
  bool _urlBlurred = false;
  bool _tried = false;
  bool _busy = false;

  /// Đã lưu xong → chuyển sang màn "thành công".
  Submission? _done;

  /// Ảnh xem trước tự tải lên (data URL). null → tự chụp màn hình.
  late String? _image = widget.edit?.previewImage;
  String? _imageError;
  bool _picking = false;

  Future<void> _pickImage() async {
    if (_picking) return;
    setState(() => _picking = true);
    final r = await pickPreviewImage();
    if (!mounted) return;
    setState(() {
      _picking = false;
      if (r == null) return; // huỷ chọn
      _imageError = r.error;
      if (r.dataUrl != null) _image = r.dataUrl;
    });
  }

  bool get _isEdit => widget.edit != null;
  bool get _public => _vis == SiteVisibility.public;

  /// IT (admin) thêm / sửa → hiện ngay, không cần duyệt.
  bool get _needsReview => _public && !auth.isAdmin;

  @override
  void initState() {
    super.initState();
    _urlFocus.addListener(() {
      if (_urlFocus.hasFocus) return;
      // Rời ô URL: chuẩn hoá + gợi ý tên từ host.
      final (url, _) = normalizeUrl(_url.text);
      setState(() {
        _urlBlurred = true;
        if (url != null && url != _url.text) _url.text = url;
        if (url != null && !_nameTouched && _name.text.trim().isEmpty) {
          final s = suggestNameFromUrl(url);
          if (s != null) _name.text = s;
        }
      });
      if (url != null && !_nameTouched) _fetchTitle(url);
    });
  }

  /// URL đang/đã lấy tên — tránh gọi lại khi blur nhiều lần cùng URL.
  String? _titleUrl;
  bool _fetchingTitle = false;

  /// Lấy tên website từ BE (title trang) rồi điền vào "Tên hiển thị".
  /// Không đè nếu user đã tự gõ tên, hoặc URL đã đổi trong lúc chờ.
  Future<void> _fetchTitle(String url) async {
    if (_titleUrl == url) return;
    _titleUrl = url;
    setState(() => _fetchingTitle = true);
    final title = await WebsiteService.fetchPageTitle(url);
    if (!mounted || _titleUrl != url) return;
    setState(() {
      _fetchingTitle = false;
      if (title != null && !_nameTouched) {
        final t = title.length > 40 ? title.substring(0, 40).trim() : title;
        // Đang đứng ở ô Tên → bôi đen để gõ thay được ngay.
        _name.value = TextEditingValue(
          text: t,
          selection: _nameFocus.hasFocus
              ? TextSelection(baseOffset: 0, extentOffset: t.length)
              : TextSelection.collapsed(offset: t.length),
        );
      }
    });
  }

  @override
  void dispose() {
    _url.dispose();
    _name.dispose();
    _note.dispose();
    _urlFocus.dispose();
    _nameFocus.dispose();
    super.dispose();
  }

  // ------------------------------------------------------------
  // VALIDATION
  // ------------------------------------------------------------

  String? get _urlError {
    if (!_urlBlurred && !_tried) return null;
    final (url, err) = normalizeUrl(_url.text);
    if (err != null) return err;
    final key = _key(url!);
    for (final w in widget.systemSites) {
      if (w.id == widget.edit?.id) continue;
      if (_key(w.url) == key) return 'Đã có trên dashboard: “${w.name}”';
    }
    final dup = submissions.byUrl(url);
    if (dup != null && dup.id != widget.edit?.id) {
      return dup.owner == auth.user?.username
          ? 'Bạn đã thêm website này rồi (“${dup.name}”)'
          : 'Website này đã được người khác đăng ký';
    }
    return null;
  }

  /// Lỗi BE trả về khi gửi (trùng URL, hết phiên, mất mạng…).
  String? _serverError;

  String? get _nameError =>
      _tried && _name.text.trim().isEmpty ? 'Nhập tên hiển thị' : null;

  String? get _deptError => _tried && _dept == null ? 'Chọn phòng ban' : null;

  /// Khoá so trùng giống BE: bỏ scheme, lowercase, bỏ "/" cuối.
  static String _key(String url) => url
      .trim()
      .toLowerCase()
      .replaceFirst(RegExp(r'^https?://'), '')
      .replaceFirst(RegExp(r'/+$'), '');

  Future<void> _submit() async {
    setState(() => _tried = true);
    if (_urlError != null || _nameError != null || _deptError != null) return;
    if (!auth.loggedIn || _busy) return;

    setState(() {
      _busy = true;
      _serverError = null;
    });
    final (url, _) = normalizeUrl(_url.text);
    final note = _needsReview ? _note.text.trim() : '';
    try {
      final s = _isEdit
          ? await submissions.update(
              widget.edit!.id,
              name: _name.text.trim(),
              url: url!,
              department: _dept!,
              visibility: _vis,
              note: note,
              previewImage: _image,
            )
          : await submissions.submit(
              name: _name.text.trim(),
              url: url!,
              department: _dept!,
              visibility: _vis,
              note: note,
              previewImage: _image,
            );
      if (!mounted) return;
      setState(() {
        _busy = false;
        _done = s;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _busy = false;
        _serverError = apiErrorMessage(e, 'Không gửi được, vui lòng thử lại');
      });
      // Hết phiên → mở lại đăng nhập; đăng nhập xong bấm gửi lại.
      if (!auth.loggedIn) {
        await ensureLoggedIn(context, reason: 'Phiên đăng nhập đã hết hạn.');
      }
    }
  }

  // ------------------------------------------------------------
  // BUILD
  // ------------------------------------------------------------

  @override
  Widget build(BuildContext context) {
    final done = _done;
    return AnimatedSwitcher(
      duration: Motion.of(context),
      switchInCurve: Motion.curve,
      child: done == null
          ? KeyedSubtree(key: const ValueKey('form'), child: _form(context))
          : KeyedSubtree(
              key: const ValueKey('done'),
              child: _Success(
                submission: done,
                onClose: () => Navigator.of(context).pop(done),
                onOpenMine: widget.onOpenMine == null
                    ? null
                    : () {
                        Navigator.of(context).pop(done);
                        widget.onOpenMine!();
                      },
              ),
            ),
    );
  }

  Widget _form(BuildContext context) {
    final c = context.dash;
    final narrow = MediaQuery.sizeOf(context).width < 520;

    final options = [
      _VisibilityOption(
        selected: _public,
        icon: LucideIcons.globe,
        title: 'Public',
        body: 'Ai cũng xem được, không cần đăng nhập.',
        tagIcon: auth.isAdmin ? LucideIcons.zap : LucideIcons.clock,
        tag: auth.isAdmin ? 'Hiện ngay (IT)' : 'Cần IT duyệt',
        tagWarn: !auth.isAdmin,
        onTap: () => setState(() => _vis = SiteVisibility.public),
      ),
      _VisibilityOption(
        selected: !_public,
        icon: LucideIcons.lock,
        title: 'Private',
        body: 'Chỉ bạn và IT thấy. Phải đăng nhập.',
        tagIcon: LucideIcons.zap,
        tag: 'Hiện ngay',
        tagWarn: false,
        onTap: () => setState(() => _vis = SiteVisibility.private),
      ),
    ];

    final nameField = Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      mainAxisSize: MainAxisSize.min,
      children: [
        FieldLabel(
          'Tên hiển thị',
          trailing: ListenableBuilder(
            listenable: _name,
            builder: (_, _) => Text(
              '${_name.text.length}/40',
              style: TextStyle(
                color: c.faint,
                fontSize: 11.5,
                fontFeatures: const [FontFeature.tabularFigures()],
              ),
            ),
          ),
        ),
        DashTextField(
          controller: _name,
          focusNode: _nameFocus,
          icon: LucideIcons.type,
          hint: _fetchingTitle ? 'Đang lấy tên website…' : 'vd. Quản lý khuôn',
          maxLength: 40,
          textInputAction: TextInputAction.next,
          error: _nameError,
          onSubmitted: (_) => _openDept(),
          onChanged: (_) {
            _nameTouched = true;
            if (_tried) setState(() {});
          },
        ),
      ],
    );

    final deptField = Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      mainAxisSize: MainAxisSize.min,
      children: [
        const FieldLabel('Phòng ban'),
        DashSelectField(
          options: widget.departments,
          value: _dept,
          controller: _deptMenu,
          icon: LucideIcons.building2,
          hint: 'Chọn phòng ban',
          createLabel: 'Thêm phòng ban mới',
          createHint: 'Tên phòng ban mới',
          error: _deptError,
          onChanged: (d) => setState(() => _dept = d),
        ),
      ],
    );

    return DashDialog(
      icon: _isEdit ? LucideIcons.pencil : LucideIcons.globe,
      title: _isEdit ? 'Sửa website' : 'Thêm website',
      subtitle: _isEdit
          ? 'Sửa thông tin rồi gửi lại.'
          : 'Đăng ký website nội bộ để hiện trên dashboard.',
      onClose: () => Navigator.of(context).pop(),
      footer: Row(
        children: [
          Icon(
            _needsReview
                ? LucideIcons.shieldCheck
                : (_public ? LucideIcons.globe : LucideIcons.eyeOff),
            size: 15,
            color: c.muted,
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              _needsReview
                  ? 'Hiện công khai sau khi IT phê duyệt.'
                  : _public
                  ? 'Hiện công khai ngay.'
                  : 'Hiện ngay — chỉ bạn và IT thấy.',
              style: TextStyle(color: c.muted, fontSize: 12.5, height: 1.35),
            ),
          ),
          const SizedBox(width: 12),
          if (!narrow) ...[
            DashButton.ghost(
              label: 'Huỷ',
              onPressed: () => Navigator.of(context).pop(),
            ),
            const SizedBox(width: 6),
          ],
          DashButton(
            label: _needsReview
                ? (_isEdit ? 'Gửi lại' : 'Gửi duyệt')
                : (_isEdit ? 'Lưu' : 'Thêm website'),
            icon: _needsReview ? LucideIcons.send : LucideIcons.plus,
            loading: _busy,
            onPressed: _submit,
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Lý do bị từ chối (khi sửa & gửi lại).
          if (_isEdit && widget.edit!.isRejected) ...[
            _RejectNote(submission: widget.edit!),
            const SizedBox(height: 18),
          ],

          // 1. URL
          const FieldLabel('Địa chỉ website'),
          DashTextField(
            controller: _url,
            focusNode: _urlFocus,
            autofocus: !_isEdit,
            mono: true,
            icon: LucideIcons.link,
            hint: 'http://192.168.1.10:8080',
            keyboardType: TextInputType.url,
            textInputAction: TextInputAction.next,
            error: _urlError,
            helper: 'Website phải truy cập được từ mạng nội bộ.',
            onSubmitted: (_) {
              // Hợp lệ → sang ô Tên; sai → ở lại ô URL để sửa.
              if (normalizeUrl(_url.text).$2 == null) {
                _focusName();
              } else {
                _urlFocus.requestFocus();
              }
            },
            onChanged: (_) {
              if (_urlBlurred || _tried) setState(() {});
            },
          ),
          const SizedBox(height: 18),

          // 2 + 3. Tên · Phòng ban — chung 1 hàng (màn hẹp: xếp dọc).
          if (narrow) ...[
            nameField,
            const SizedBox(height: 18),
            deptField,
          ] else
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(flex: 3, child: nameField),
                const SizedBox(width: 12),
                Expanded(flex: 2, child: deptField),
              ],
            ),
          const SizedBox(height: 18),

          // 4. Ảnh xem trước (tuỳ chọn) — bỏ trống → tự chụp màn hình.
          const FieldLabel('Ảnh xem trước', optional: true),
          _PreviewPicker(
            image: _image,
            error: _imageError,
            busy: _picking,
            onPick: _pickImage,
            onRemove: () => setState(() {
              _image = null;
              _imageError = null;
            }),
          ),
          const SizedBox(height: 22),

          // 5. Ai xem được?
          const FieldLabel('Ai có thể xem?'),
          narrow
              ? Column(
                  children: [options[0], const SizedBox(height: 8), options[1]],
                )
              : IntrinsicHeight(
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Expanded(child: options[0]),
                      const SizedBox(width: 10),
                      Expanded(child: options[1]),
                    ],
                  ),
                ),

          // 6. Ghi chú cho admin — chỉ khi Public (Private không cần duyệt).
          AnimatedSize(
            duration: Motion.of(context),
            curve: Motion.curve,
            alignment: Alignment.topCenter,
            child: _needsReview
                ? Padding(
                    padding: const EdgeInsets.only(top: 18),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        const FieldLabel('Ghi chú cho IT', optional: true),
                        DashTextField(
                          controller: _note,
                          hint:
                              'Website dùng để làm gì, ai dùng? Giúp IT '
                              'duyệt nhanh hơn.',
                          maxLines: 3,
                          maxLength: 200,
                        ),
                      ],
                    ),
                  )
                : const SizedBox(width: double.infinity),
          ),

          // Lỗi từ máy chủ khi gửi.
          if (_serverError != null) ...[
            const SizedBox(height: 16),
            _ErrorNote(text: _serverError!),
          ],
        ],
      ),
    );
  }
}

class _ErrorNote extends StatelessWidget {
  final String text;
  const _ErrorNote({required this.text});

  @override
  Widget build(BuildContext context) {
    final t = context.tone;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: t.offBg,
        borderRadius: BorderRadius.circular(10),
      ),
      child: Row(
        children: [
          Icon(LucideIcons.circleAlert, size: 15, color: t.offFg),
          const SizedBox(width: 8),
          Expanded(
            child: Text(text, style: TextStyle(color: t.offFg, fontSize: 13)),
          ),
        ],
      ),
    );
  }
}

// ============================================================
// VISIBILITY OPTION — thẻ chọn lớn (radio)
// ============================================================

class _VisibilityOption extends StatelessWidget {
  final bool selected;
  final IconData icon;
  final String title;
  final String body;
  final IconData tagIcon;
  final String tag;
  final bool tagWarn;
  final VoidCallback onTap;

  const _VisibilityOption({
    required this.selected,
    required this.icon,
    required this.title,
    required this.body,
    required this.tagIcon,
    required this.tag,
    required this.tagWarn,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final c = context.dash;
    final t = context.tone;

    return Semantics(
      button: true,
      selected: selected,
      label: '$title. $body $tag',
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(12),
          child: AnimatedContainer(
            duration: Motion.of(context, Motion.fast),
            curve: Motion.curve,
            padding: const EdgeInsets.fromLTRB(14, 13, 14, 13),
            decoration: BoxDecoration(
              color: selected ? c.surface2 : c.surface,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: selected ? c.text : c.border,
                width: selected ? 1.5 : 1,
              ),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Icon(icon, size: 17, color: c.text),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        title,
                        style: TextStyle(
                          color: c.text,
                          fontSize: 14,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                    _Radio(selected: selected),
                  ],
                ),
                const SizedBox(height: 6),
                Text(
                  body,
                  style: TextStyle(color: c.muted, fontSize: 12.5, height: 1.4),
                ),
                const SizedBox(height: 10),
                MiniChip(
                  label: tag,
                  icon: tagIcon,
                  fg: tagWarn ? t.slowFg : t.okFg,
                  bg: tagWarn ? t.slowBg : t.okBg,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _Radio extends StatelessWidget {
  final bool selected;
  const _Radio({required this.selected});

  @override
  Widget build(BuildContext context) {
    final c = context.dash;
    return AnimatedContainer(
      duration: Motion.of(context, Motion.fast),
      width: 18,
      height: 18,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        border: Border.all(
          color: selected ? c.text : c.faint,
          width: selected ? 5.5 : 1.5,
        ),
      ),
    );
  }
}

// ============================================================
// PREVIEW PICKER — ảnh xem trước (tuỳ chọn)
// ============================================================

/// Khung nằm ngang gọn: ô ảnh 16:9 bên trái + mô tả/nút bên phải.
/// Chưa có ảnh → viền nét đứt, bấm cả khung để chọn; ghi rõ "tự chụp màn
/// hình" để người dùng biết bỏ trống vẫn ổn.
class _PreviewPicker extends StatelessWidget {
  final String? image;
  final String? error;
  final bool busy;
  final VoidCallback onPick;
  final VoidCallback onRemove;

  const _PreviewPicker({
    required this.image,
    required this.error,
    required this.busy,
    required this.onPick,
    required this.onRemove,
  });

  @override
  Widget build(BuildContext context) {
    final c = context.dash;
    final t = context.tone;
    final has = image != null;
    final narrow = MediaQuery.sizeOf(context).width < 520;
    final thumbW = narrow ? 104.0 : 128.0;

    final thumb = ClipRRect(
      borderRadius: BorderRadius.circular(8),
      child: SizedBox(
        width: thumbW,
        child: AspectRatio(
          aspectRatio: 16 / 9,
          child: has
              ? Image(
                  image: previewImageProvider(image!),
                  fit: BoxFit.cover,
                  alignment: Alignment.topCenter,
                  gaplessPlayback: true,
                )
              : ColoredBox(
                  color: c.surface2,
                  child: Center(
                    child: busy
                        ? SizedBox(
                            width: 18,
                            height: 18,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              color: c.muted,
                            ),
                          )
                        : Icon(LucideIcons.imagePlus, size: 22, color: c.muted),
                  ),
                ),
        ),
      ),
    );

    final text = Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          has ? 'Đã chọn ảnh' : 'Tự động chụp màn hình',
          style: TextStyle(
            color: c.text,
            fontSize: 13.5,
            fontWeight: FontWeight.w600,
          ),
        ),
        const SizedBox(height: 2),
        Text(
          has
              ? 'Hiện trên thẻ website thay cho ảnh chụp tự động.'
              : 'Hoặc tải ảnh lên · PNG, JPG, WebP · tự thu nhỏ',
          style: TextStyle(color: c.muted, fontSize: 12.5, height: 1.4),
        ),
        const SizedBox(height: 8),
        Wrap(
          spacing: 6,
          runSpacing: 6,
          children: [
            DashButton.secondary(
              label: has ? 'Đổi ảnh' : 'Chọn ảnh',
              icon: LucideIcons.upload,
              height: 32,
              loading: busy && has,
              onPressed: onPick,
            ),
            if (has)
              DashButton.ghost(
                label: 'Bỏ ảnh',
                icon: LucideIcons.trash2,
                height: 32,
                onPressed: onRemove,
              ),
          ],
        ),
      ],
    );

    final box = Padding(
      padding: const EdgeInsets.all(10),
      child: Row(
        children: [
          thumb,
          const SizedBox(width: 14),
          Expanded(child: text),
        ],
      ),
    );

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      mainAxisSize: MainAxisSize.min,
      children: [
        has
            ? DecoratedBox(
                decoration: BoxDecoration(
                  color: c.surface,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: c.border),
                ),
                child: box,
              )
            // Chưa có ảnh: cả khung bấm được, viền nét đứt.
            : Material(
                color: Colors.transparent,
                child: InkWell(
                  onTap: busy ? null : onPick,
                  borderRadius: BorderRadius.circular(12),
                  child: CustomPaint(
                    painter: _DashedBorder(
                      color: error != null ? t.offFg : c.faint,
                      radius: 12,
                    ),
                    child: box,
                  ),
                ),
              ),
        FieldMessage(error: error),
      ],
    );
  }
}

class _DashedBorder extends CustomPainter {
  final Color color;
  final double radius;
  const _DashedBorder({required this.color, required this.radius});

  @override
  void paint(Canvas canvas, Size size) {
    final path = Path()
      ..addRRect(
        RRect.fromRectAndRadius(
          (Offset.zero & size).deflate(.5),
          Radius.circular(radius),
        ),
      );
    final paint = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1;
    const dash = 5.0, gap = 4.0;
    for (final m in path.computeMetrics()) {
      for (var d = 0.0; d < m.length; d += dash + gap) {
        canvas.drawPath(m.extractPath(d, d + dash), paint);
      }
    }
  }

  @override
  bool shouldRepaint(_DashedBorder old) =>
      old.color != color || old.radius != radius;
}

class _RejectNote extends StatelessWidget {
  final Submission submission;
  const _RejectNote({required this.submission});

  @override
  Widget build(BuildContext context) {
    final t = context.tone;
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: t.offBg,
        borderRadius: BorderRadius.circular(10),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(LucideIcons.messageSquareWarning, size: 16, color: t.offFg),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'IT đã từ chối',
                  style: TextStyle(
                    color: t.offFg,
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  submission.rejectReason ?? '',
                  style: TextStyle(color: t.offFg, fontSize: 13, height: 1.4),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// ============================================================
// SUCCESS
// ============================================================

class _Success extends StatelessWidget {
  final Submission submission;
  final VoidCallback onClose;
  final VoidCallback? onOpenMine;

  const _Success({
    required this.submission,
    required this.onClose,
    this.onOpenMine,
  });

  @override
  Widget build(BuildContext context) {
    final c = context.dash;
    final t = context.tone;
    final s = submission;
    final pending = s.isPending;

    return DashDialog(
      maxWidth: 480,
      icon: pending ? LucideIcons.send : LucideIcons.circleCheck,
      title: pending ? 'Đã gửi yêu cầu duyệt' : 'Đã thêm website',
      onClose: onClose,
      footer: Row(
        mainAxisAlignment: MainAxisAlignment.end,
        children: [
          if (onOpenMine != null) ...[
            DashButton.secondary(
              label: 'Website của tôi',
              icon: LucideIcons.folderOpen,
              onPressed: onOpenMine,
            ),
            const SizedBox(width: 8),
          ],
          DashButton(label: 'Xong', onPressed: onClose),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text.rich(
            TextSpan(
              children: [
                TextSpan(
                  text: '“${s.name}”',
                  style: TextStyle(color: c.text, fontWeight: FontWeight.w600),
                ),
                TextSpan(
                  text: pending
                      ? ' sẽ hiện cho mọi người sau khi IT phê duyệt. '
                            'Bạn có thể theo dõi ở mục Website của tôi.'
                      : s.isPrivate
                      ? ' đã hiện trên dashboard — chỉ bạn và IT thấy.'
                      : ' đã hiện công khai trên dashboard.',
                ),
              ],
            ),
            style: TextStyle(color: c.muted, fontSize: 14, height: 1.5),
          ),
          if (pending) ...[
            const SizedBox(height: 22),
            Row(
              children: [
                _Step(
                  icon: LucideIcons.check,
                  label: 'Đã gửi',
                  fg: t.okFg,
                  bg: t.okBg,
                ),
                _StepLine(color: t.okFg),
                _Step(
                  icon: LucideIcons.clock,
                  label: 'IT duyệt',
                  fg: t.slowFg,
                  bg: t.slowBg,
                  current: true,
                ),
                _StepLine(color: c.border),
                _Step(
                  icon: LucideIcons.globe,
                  label: 'Hiện công khai',
                  fg: c.faint,
                  bg: c.surface2,
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }
}

class _Step extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color fg;
  final Color bg;
  final bool current;

  const _Step({
    required this.icon,
    required this.label,
    required this.fg,
    required this.bg,
    this.current = false,
  });

  @override
  Widget build(BuildContext context) {
    final c = context.dash;
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 34,
          height: 34,
          decoration: BoxDecoration(
            color: bg,
            shape: BoxShape.circle,
            border: current ? Border.all(color: fg, width: 1.5) : null,
          ),
          child: Icon(icon, size: 16, color: fg),
        ),
        const SizedBox(height: 6),
        Text(
          label,
          style: TextStyle(
            color: current ? c.text : c.muted,
            fontSize: 12,
            fontWeight: current ? FontWeight.w600 : FontWeight.w500,
          ),
        ),
      ],
    );
  }
}

class _StepLine extends StatelessWidget {
  final Color color;
  const _StepLine({required this.color});

  @override
  Widget build(BuildContext context) => Expanded(
    child: Container(
      height: 2,
      margin: const EdgeInsets.only(bottom: 20, left: 6, right: 6),
      decoration: BoxDecoration(
        color: color,
        borderRadius: BorderRadius.circular(2),
      ),
    ),
  );
}
