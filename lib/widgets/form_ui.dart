import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../models/submission.dart';
import '../theme/dash_theme.dart';

// ============================================================
// DIALOG / SIDE PANEL
// ============================================================

/// Dialog giữa màn hình: mờ nền + fade/scale nhẹ (đồng bộ Preview dialog).
Future<T?> showDashDialog<T>(
  BuildContext context, {
  required WidgetBuilder builder,
  bool dismissible = true,
}) {
  return showGeneralDialog<T>(
    context: context,
    barrierDismissible: dismissible,
    barrierLabel: 'Đóng',
    barrierColor: Colors.black.withValues(alpha: .5),
    transitionDuration: Motion.of(context),
    pageBuilder: (ctx, _, _) => builder(ctx),
    transitionBuilder: (_, anim, _, child) {
      final a = CurvedAnimation(parent: anim, curve: Motion.curve);
      return FadeTransition(
        opacity: a,
        child: ScaleTransition(
          scale: Tween(begin: .97, end: 1.0).animate(a),
          child: child,
        ),
      );
    },
  );
}

/// Panel trượt từ phải vào, cao hết màn hình. Có ScaffoldMessenger riêng →
/// SnackBar (vd. "Hoàn tác") hiện TRONG panel, không bị lớp mờ che.
Future<T?> showSidePanel<T>(
  BuildContext context, {
  required WidgetBuilder builder,
  double width = 460,
}) {
  return showGeneralDialog<T>(
    context: context,
    barrierDismissible: true,
    barrierLabel: 'Đóng',
    barrierColor: Colors.black.withValues(alpha: .4),
    transitionDuration: Motion.of(context, const Duration(milliseconds: 280)),
    pageBuilder: (ctx, _, _) {
      final c = ctx.dash;
      final w = MediaQuery.sizeOf(ctx).width;
      return Align(
        alignment: Alignment.centerRight,
        child: SizedBox(
          width: w < width + 40 ? w : width,
          height: double.infinity,
          child: ScaffoldMessenger(
            child: Scaffold(
              backgroundColor: c.surface,
              body: DecoratedBox(
                decoration: BoxDecoration(
                  border: Border(left: BorderSide(color: c.border)),
                ),
                child: SafeArea(child: Builder(builder: builder)),
              ),
            ),
          ),
        ),
      );
    },
    transitionBuilder: (_, anim, _, child) {
      final a = CurvedAnimation(parent: anim, curve: Motion.curve);
      return SlideTransition(
        position: Tween(
          begin: const Offset(1, 0),
          end: Offset.zero,
        ).animate(a),
        child: child,
      );
    },
  );
}

/// Khung dialog: header (icon · tiêu đề · mô tả · nút đóng) / nội dung cuộn /
/// footer viền trên.
class DashDialog extends StatelessWidget {
  final IconData icon;
  final String title;
  final String? subtitle;
  final Widget child;
  final Widget? footer;
  final double maxWidth;
  final VoidCallback? onClose;

  const DashDialog({
    super.key,
    required this.icon,
    required this.title,
    this.subtitle,
    required this.child,
    this.footer,
    this.maxWidth = 560,
    this.onClose,
  });

  @override
  Widget build(BuildContext context) {
    final c = context.dash;
    final size = MediaQuery.sizeOf(context);
    final small = size.width < 600;

    return Center(
      child: Padding(
        padding: EdgeInsets.all(small ? 12 : 24),
        child: ConstrainedBox(
          constraints: BoxConstraints(
            maxWidth: maxWidth,
            maxHeight: size.height - (small ? 24 : 48),
          ),
          child: Material(
            color: c.surface,
            clipBehavior: Clip.antiAlias,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16),
              side: BorderSide(color: c.border),
            ),
            elevation: 0,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                PanelHeader(
                  icon: icon,
                  title: title,
                  subtitle: subtitle,
                  onClose: onClose ?? () => Navigator.of(context).maybePop(),
                ),
                Flexible(
                  child: SingleChildScrollView(
                    padding: EdgeInsets.fromLTRB(
                      small ? 18 : 24,
                      4,
                      small ? 18 : 24,
                      20,
                    ),
                    child: child,
                  ),
                ),
                if (footer != null)
                  Container(
                    padding: EdgeInsets.fromLTRB(
                      small ? 18 : 24,
                      14,
                      small ? 18 : 24,
                      14,
                    ),
                    decoration: BoxDecoration(
                      color: c.bg,
                      border: Border(top: BorderSide(color: c.border)),
                    ),
                    child: footer,
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// Header chung cho dialog & side panel.
class PanelHeader extends StatelessWidget {
  final IconData icon;
  final String title;
  final String? subtitle;
  final VoidCallback onClose;
  final Widget? trailing;

  const PanelHeader({
    super.key,
    required this.icon,
    required this.title,
    this.subtitle,
    required this.onClose,
    this.trailing,
  });

  @override
  Widget build(BuildContext context) {
    final c = context.dash;
    final small = MediaQuery.sizeOf(context).width < 600;
    return Padding(
      padding: EdgeInsets.fromLTRB(small ? 18 : 24, 20, 14, 16),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 40,
            height: 40,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: c.surface2,
              borderRadius: BorderRadius.circular(11),
            ),
            child: Icon(icon, size: 19, color: c.text),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const SizedBox(height: 1),
                Text(
                  title,
                  style: displayText(
                    size: 18,
                    weight: FontWeight.w700,
                    color: c.text,
                    letterSpacing: -.2,
                  ),
                ),
                if (subtitle != null) ...[
                  const SizedBox(height: 2),
                  Text(
                    subtitle!,
                    style: TextStyle(color: c.muted, fontSize: 13, height: 1.4),
                  ),
                ],
              ],
            ),
          ),
          if (trailing != null) ...[const SizedBox(width: 8), trailing!],
          const SizedBox(width: 4),
          Tooltip(
            message: 'Đóng (Esc)',
            child: IconButton(
              onPressed: onClose,
              icon: const Icon(LucideIcons.x, size: 18),
              color: c.muted,
              visualDensity: VisualDensity.compact,
              style: IconButton.styleFrom(
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ============================================================
// BUTTON
// ============================================================

enum DashButtonKind { primary, secondary, ghost, success, danger }

/// Nút chuẩn 40px. [primary] = nền ink (đen ở Light / trắng ở Dark) — mỗi
/// màn chỉ nên có 1 nút primary.
class DashButton extends StatelessWidget {
  final String label;
  final IconData? icon;
  final VoidCallback? onPressed;
  final DashButtonKind kind;
  final bool loading;
  final bool expand;
  final double height;

  const DashButton({
    super.key,
    required this.label,
    this.icon,
    required this.onPressed,
    this.kind = DashButtonKind.primary,
    this.loading = false,
    this.expand = false,
    this.height = 40,
  });

  const DashButton.secondary({
    super.key,
    required this.label,
    this.icon,
    required this.onPressed,
    this.loading = false,
    this.expand = false,
    this.height = 40,
  }) : kind = DashButtonKind.secondary;

  const DashButton.ghost({
    super.key,
    required this.label,
    this.icon,
    required this.onPressed,
    this.loading = false,
    this.expand = false,
    this.height = 40,
  }) : kind = DashButtonKind.ghost;

  @override
  Widget build(BuildContext context) {
    final c = context.dash;
    final t = context.tone;
    final dark = context.isDark;

    final (Color bg, Color fg, Color? side) = switch (kind) {
      DashButtonKind.primary => (c.ink, c.onInk, null),
      DashButtonKind.secondary => (c.surface, c.text, c.border),
      DashButtonKind.ghost => (Colors.transparent, c.textSoft, null),
      DashButtonKind.success => (
        dark ? t.okFg : const Color(0xFF15803D),
        dark ? const Color(0xFF0D1015) : Colors.white,
        null,
      ),
      DashButtonKind.danger => (t.offBg, t.offFg, t.offBorder),
    };
    final disabled = onPressed == null || loading;

    final content = Row(
      mainAxisSize: expand ? MainAxisSize.max : MainAxisSize.min,
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        if (loading)
          SizedBox(
            width: 15,
            height: 15,
            child: CircularProgressIndicator(strokeWidth: 2, color: fg),
          )
        else if (icon != null)
          Icon(icon, size: 16),
        if (loading || icon != null) const SizedBox(width: 8),
        Text(label),
      ],
    );

    return SizedBox(
      height: height,
      width: expand ? double.infinity : null,
      child: TextButton(
        onPressed: disabled ? null : onPressed,
        style: TextButton.styleFrom(
          backgroundColor: bg,
          foregroundColor: fg,
          disabledBackgroundColor: loading
              ? bg
              : (kind == DashButtonKind.ghost ? Colors.transparent : c.surface2),
          disabledForegroundColor: loading ? fg : c.faint,
          overlayColor: kind == DashButtonKind.primary ? c.onInk : c.text,
          padding: const EdgeInsets.symmetric(horizontal: 16),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(10),
            side: side == null ? BorderSide.none : BorderSide(color: side),
          ),
          textStyle: const TextStyle(fontSize: 13.5, fontWeight: FontWeight.w600),
        ),
        child: content,
      ),
    );
  }
}

// ============================================================
// TEXT FIELD
// ============================================================

/// Nhãn trên ô nhập + chữ "Tùy chọn" mờ.
class FieldLabel extends StatelessWidget {
  final String text;
  final bool optional;
  final Widget? trailing;
  const FieldLabel(this.text, {super.key, this.optional = false, this.trailing});

  @override
  Widget build(BuildContext context) {
    final c = context.dash;
    return Padding(
      padding: const EdgeInsets.only(bottom: 7),
      child: Row(
        children: [
          Text(
            text,
            style: TextStyle(
              color: c.text,
              fontSize: 13,
              fontWeight: FontWeight.w600,
            ),
          ),
          if (optional) ...[
            const SizedBox(width: 6),
            Text('Tùy chọn', style: TextStyle(color: c.faint, fontSize: 12)),
          ],
          const Spacer(),
          ?trailing,
        ],
      ),
    );
  }
}

class DashTextField extends StatelessWidget {
  final TextEditingController controller;
  final FocusNode? focusNode;
  final String? hint;
  final IconData? icon;
  final String? error;
  final String? helper;
  final bool mono;
  final bool obscure;
  final bool autofocus;
  final int maxLines;
  final int? maxLength;
  final Widget? suffix;
  final TextInputType? keyboardType;
  final TextInputAction? textInputAction;
  final ValueChanged<String>? onChanged;
  final ValueChanged<String>? onSubmitted;
  final Iterable<String>? autofillHints;

  const DashTextField({
    super.key,
    required this.controller,
    this.focusNode,
    this.hint,
    this.icon,
    this.error,
    this.helper,
    this.mono = false,
    this.obscure = false,
    this.autofocus = false,
    this.maxLines = 1,
    this.maxLength,
    this.suffix,
    this.keyboardType,
    this.textInputAction,
    this.onChanged,
    this.onSubmitted,
    this.autofillHints,
  });

  @override
  Widget build(BuildContext context) {
    final c = context.dash;
    final style = mono
        ? monoText(size: 13.5, color: c.text)
        : TextStyle(color: c.text, fontSize: 14);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      mainAxisSize: MainAxisSize.min,
      children: [
        TextField(
          controller: controller,
          focusNode: focusNode,
          autofocus: autofocus,
          obscureText: obscure,
          maxLines: maxLines,
          minLines: 1,
          keyboardType: keyboardType,
          textInputAction: textInputAction,
          onChanged: onChanged,
          onSubmitted: onSubmitted,
          autofillHints: autofillHints,
          inputFormatters: maxLength != null
              ? [LengthLimitingTextInputFormatter(maxLength)]
              : null,
          style: style,
          decoration: dashInputDecoration(
            context,
            hint: hint,
            icon: icon,
            error: error != null,
            suffix: suffix,
            mono: mono,
          ),
        ),
        FieldMessage(error: error, helper: helper),
      ],
    );
  }
}

/// Decoration chung cho ô nhập & ô chọn → cao, viền, bo góc giống hệt nhau.
InputDecoration dashInputDecoration(
  BuildContext context, {
  String? hint,
  IconData? icon,
  bool error = false,
  bool focused = false,
  Widget? suffix,
  bool mono = false,
}) {
  final c = context.dash;
  final t = context.tone;
  OutlineInputBorder b(Color color, [double w = 1]) => OutlineInputBorder(
    borderRadius: BorderRadius.circular(10),
    borderSide: BorderSide(color: color, width: w),
  );
  final idle = error ? t.offFg : (focused ? c.text : c.border);
  return InputDecoration(
    isDense: true,
    hintText: hint,
    hintStyle: (mono ? monoText(size: 13.5) : const TextStyle()).copyWith(
      color: c.faint,
      fontSize: mono ? 13.5 : 14,
    ),
    filled: true,
    fillColor: c.surface,
    contentPadding: EdgeInsets.symmetric(
      horizontal: icon == null ? 14 : 12,
      vertical: 12,
    ),
    prefixIcon: icon == null
        ? null
        : Icon(icon, size: 17, color: error ? t.offFg : c.muted),
    prefixIconConstraints: const BoxConstraints(minWidth: 42),
    suffixIcon: suffix,
    // Mặc định suffix ép cao 48px → ô chọn cao hơn ô nhập, chữ lệch.
    suffixIconConstraints: const BoxConstraints(minWidth: 40),
    border: b(c.border),
    enabledBorder: b(idle, focused ? 1.5 : 1),
    focusedBorder: b(error ? t.offFg : c.text, 1.5),
  );
}

/// Dòng lỗi (đỏ, có icon) hoặc gợi ý (xám) dưới ô nhập; co giãn mượt.
class FieldMessage extends StatelessWidget {
  final String? error;
  final String? helper;
  const FieldMessage({super.key, this.error, this.helper});

  @override
  Widget build(BuildContext context) {
    final c = context.dash;
    final t = context.tone;
    return AnimatedSize(
      duration: Motion.of(context, Motion.fast),
      curve: Motion.curve,
      alignment: Alignment.topLeft,
      child: error != null
          ? Padding(
              padding: const EdgeInsets.only(top: 6),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Padding(
                    padding: const EdgeInsets.only(top: 1),
                    child: Icon(
                      LucideIcons.circleAlert,
                      size: 13,
                      color: t.offFg,
                    ),
                  ),
                  const SizedBox(width: 6),
                  Expanded(
                    child: Text(
                      error!,
                      style: TextStyle(
                        color: t.offFg,
                        fontSize: 12.5,
                        height: 1.35,
                      ),
                    ),
                  ),
                ],
              ),
            )
          : helper != null
          ? Padding(
              padding: const EdgeInsets.only(top: 6),
              child: Text(
                helper!,
                style: TextStyle(color: c.muted, fontSize: 12.5),
              ),
            )
          : const SizedBox(width: double.infinity),
    );
  }
}

// ============================================================
// SELECT FIELD — ô chọn 1 giá trị (dropdown), cùng kiểu ô nhập
// ============================================================

class DashSelectField extends StatefulWidget {
  final List<String> options;
  final String? value;
  final ValueChanged<String> onChanged;
  final String? hint;
  final IconData? icon;
  final String? error;

  /// Nhãn hiển thị cho từng giá trị (mặc định = chính giá trị).
  final String Function(String)? labelOf;

  /// Truyền vào nếu cần mở menu từ bên ngoài (vd. Enter ở ô trước).
  final MenuController? controller;

  /// Khác null → cuối menu có mục "＋ [createLabel]": bấm vào thì ô chuyển
  /// sang nhập tay (Enter = xác nhận, Esc = huỷ). Giá trị nhập trùng một
  /// option (không phân biệt hoa thường) → chọn option đó.
  final String? createLabel;
  final String? createHint;
  final int createMaxLength;

  const DashSelectField({
    super.key,
    required this.options,
    required this.value,
    required this.onChanged,
    this.hint,
    this.icon,
    this.error,
    this.labelOf,
    this.controller,
    this.createLabel,
    this.createHint,
    this.createMaxLength = 30,
  });

  @override
  State<DashSelectField> createState() => _DashSelectFieldState();
}

class _DashSelectFieldState extends State<DashSelectField> {
  late final _ctrl = widget.controller ?? MenuController();
  bool _open = false;

  /// Đang nhập giá trị mới.
  bool _creating = false;
  final _newCtrl = TextEditingController();
  final _newFocus = FocusNode();

  String _label(String v) => widget.labelOf?.call(v) ?? v;

  @override
  void dispose() {
    _newCtrl.dispose();
    _newFocus.dispose();
    super.dispose();
  }

  void _startCreate() {
    _newCtrl.clear();
    setState(() => _creating = true);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _newFocus.requestFocus();
    });
  }

  void _cancelCreate() => setState(() => _creating = false);

  void _confirmCreate() {
    final v = _newCtrl.text.trim().replaceAll(RegExp(r'\s+'), ' ');
    if (v.isEmpty) return _cancelCreate();
    final same = widget.options.where(
      (o) => o.toLowerCase() == v.toLowerCase(),
    );
    widget.onChanged(same.isNotEmpty ? same.first : v);
    setState(() => _creating = false);
  }

  Widget _createField(BuildContext context) {
    final c = context.dash;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      mainAxisSize: MainAxisSize.min,
      children: [
        Focus(
          onKeyEvent: (_, e) {
            if (e is KeyDownEvent && e.logicalKey == LogicalKeyboardKey.escape) {
              _cancelCreate();
              return KeyEventResult.handled;
            }
            return KeyEventResult.ignored;
          },
          child: DashTextField(
            controller: _newCtrl,
            focusNode: _newFocus,
            icon: LucideIcons.plus,
            hint: widget.createHint ?? 'Nhập tên mới',
            maxLength: widget.createMaxLength,
            textInputAction: TextInputAction.done,
            onSubmitted: (_) => _confirmCreate(),
            suffix: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                IconButton(
                  tooltip: 'Xác nhận (Enter)',
                  onPressed: _confirmCreate,
                  icon: Icon(LucideIcons.check, size: 16, color: c.text),
                  visualDensity: VisualDensity.compact,
                ),
                IconButton(
                  tooltip: 'Huỷ (Esc)',
                  onPressed: _cancelCreate,
                  icon: Icon(LucideIcons.x, size: 16, color: c.muted),
                  visualDensity: VisualDensity.compact,
                ),
              ],
            ),
          ),
        ),
        FieldMessage(error: widget.error),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final c = context.dash;
    final value = widget.value;
    if (_creating) return _createField(context);

    // Giá trị vừa nhập mới (chưa có trong danh sách) vẫn hiện trong menu.
    final options = [
      ...widget.options,
      if (value != null && !widget.options.contains(value)) value,
    ];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      mainAxisSize: MainAxisSize.min,
      children: [
        LayoutBuilder(
          builder: (context, cons) => MenuAnchor(
            controller: _ctrl,
            onOpen: () => setState(() => _open = true),
            onClose: () => setState(() => _open = false),
            alignmentOffset: const Offset(0, 4),
            style: dashMenuStyle(c).copyWith(
              minimumSize: WidgetStatePropertyAll(Size(cons.maxWidth, 0)),
              maximumSize: WidgetStatePropertyAll(Size(cons.maxWidth, 320)),
            ),
            menuChildren: [
              for (final o in options)
                MenuItemButton(
                  onPressed: () => widget.onChanged(o),
                  trailingIcon: o == value
                      ? Icon(LucideIcons.check, size: 15, color: c.text)
                      : null,
                  style: MenuItemButton.styleFrom(
                    foregroundColor: c.text,
                    backgroundColor: o == value ? c.surface2 : null,
                    minimumSize: Size(cons.maxWidth, 38),
                    padding: const EdgeInsets.symmetric(horizontal: 14),
                    textStyle: TextStyle(
                      fontSize: 13.5,
                      fontWeight: o == value
                          ? FontWeight.w600
                          : FontWeight.w500,
                    ),
                  ),
                  child: Text(_label(o)),
                ),
              if (widget.createLabel != null) ...[
                Divider(height: 9, color: c.border),
                MenuItemButton(
                  onPressed: _startCreate,
                  leadingIcon: Icon(LucideIcons.plus, size: 15, color: c.text),
                  style: MenuItemButton.styleFrom(
                    foregroundColor: c.text,
                    minimumSize: Size(cons.maxWidth, 38),
                    padding: const EdgeInsets.symmetric(horizontal: 14),
                    textStyle: const TextStyle(
                      fontSize: 13.5,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  child: Text(widget.createLabel!),
                ),
              ],
            ],
            builder: (context, ctrl, _) => MouseRegion(
              cursor: SystemMouseCursors.click,
              child: GestureDetector(
                behavior: HitTestBehavior.opaque,
                onTap: () => ctrl.isOpen ? ctrl.close() : ctrl.open(),
                child: InputDecorator(
                  isEmpty: value == null,
                  isFocused: _open,
                  textAlignVertical: TextAlignVertical.center,
                  decoration: dashInputDecoration(
                    context,
                    hint: widget.hint,
                    icon: widget.icon,
                    error: widget.error != null,
                    focused: _open,
                  ),
                  // Mũi tên nằm trong child (không dùng suffixIcon — suffixIcon
                  // ép cao 48px làm ô chọn cao hơn ô nhập & chữ bị lệch).
                  child: Row(
                    children: [
                      Expanded(
                        child: Text(
                          value == null ? '' : _label(value),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(color: c.text, fontSize: 14),
                        ),
                      ),
                      const SizedBox(width: 8),
                      AnimatedRotation(
                        turns: _open ? .5 : 0,
                        duration: Motion.of(context, Motion.fast),
                        child: Icon(
                          LucideIcons.chevronDown,
                          size: 16,
                          color: c.muted,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
        FieldMessage(error: widget.error),
      ],
    );
  }
}

// ============================================================
// CHIPS: visibility / trạng thái duyệt
// ============================================================

class MiniChip extends StatelessWidget {
  final String label;
  final IconData? icon;
  final Color fg;
  final Color bg;
  const MiniChip({
    super.key,
    required this.label,
    this.icon,
    required this.fg,
    required this.bg,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 22,
      padding: const EdgeInsets.symmetric(horizontal: 8),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(99),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (icon != null) ...[
            Icon(icon, size: 11.5, color: fg),
            const SizedBox(width: 4),
          ],
          Text(
            label,
            style: TextStyle(
              color: fg,
              fontSize: 11.5,
              fontWeight: FontWeight.w600,
              height: 1,
            ),
          ),
        ],
      ),
    );
  }
}

class VisibilityChip extends StatelessWidget {
  final SiteVisibility visibility;
  const VisibilityChip(this.visibility, {super.key});

  @override
  Widget build(BuildContext context) {
    final c = context.dash;
    final private = visibility == SiteVisibility.private;
    return Tooltip(
      message: private
          ? 'Chỉ người thêm và admin xem được'
          : 'Ai cũng xem được, không cần đăng nhập',
      child: MiniChip(
        label: private ? 'Private' : 'Public',
        icon: private ? LucideIcons.lock : LucideIcons.globe,
        fg: c.textSoft,
        bg: c.surface2,
      ),
    );
  }
}

class ReviewChip extends StatelessWidget {
  final ReviewStatus status;
  const ReviewChip(this.status, {super.key});

  @override
  Widget build(BuildContext context) {
    final t = context.tone;
    return switch (status) {
      ReviewStatus.pending => MiniChip(
        label: 'Chờ duyệt',
        icon: LucideIcons.clock,
        fg: t.slowFg,
        bg: t.slowBg,
      ),
      ReviewStatus.live => MiniChip(
        label: 'Đang hiển thị',
        icon: LucideIcons.circleCheck,
        fg: t.okFg,
        bg: t.okBg,
      ),
      ReviewStatus.rejected => MiniChip(
        label: 'Bị từ chối',
        icon: LucideIcons.circleX,
        fg: t.offFg,
        bg: t.offBg,
      ),
    };
  }
}

/// Số đếm tròn nhỏ (badge trên tab / menu).
class CountBadge extends StatelessWidget {
  final int count;
  final Color? fg;
  final Color? bg;
  const CountBadge(this.count, {super.key, this.fg, this.bg});

  @override
  Widget build(BuildContext context) {
    final c = context.dash;
    return Container(
      constraints: const BoxConstraints(minWidth: 20),
      height: 20,
      padding: const EdgeInsets.symmetric(horizontal: 6),
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: bg ?? c.surface2,
        borderRadius: BorderRadius.circular(99),
      ),
      child: Text(
        '$count',
        style: TextStyle(
          color: fg ?? c.muted,
          fontSize: 11.5,
          fontWeight: FontWeight.w700,
          height: 1,
          fontFeatures: const [FontFeature.tabularFigures()],
        ),
      ),
    );
  }
}

// ============================================================
// HELPERS
// ============================================================

/// Kiểu menu thả xuống (MenuAnchor): nền surface, viền, bo 12.
MenuStyle dashMenuStyle(DashColors c) => MenuStyle(
  backgroundColor: WidgetStatePropertyAll(c.surface),
  surfaceTintColor: const WidgetStatePropertyAll(Colors.transparent),
  elevation: const WidgetStatePropertyAll(8),
  shadowColor: WidgetStatePropertyAll(c.shadow),
  padding: const WidgetStatePropertyAll(EdgeInsets.symmetric(vertical: 6)),
  shape: WidgetStatePropertyAll(
    RoundedRectangleBorder(
      borderRadius: BorderRadius.circular(12),
      side: BorderSide(color: c.border),
    ),
  ),
);

/// "vừa xong" / "25 phút trước" / "2 giờ trước" / "3 ngày trước" / dd/MM/yyyy.
String timeAgoVi(DateTime t) {
  final d = DateTime.now().difference(t);
  if (d.inMinutes < 1) return 'vừa xong';
  if (d.inMinutes < 60) return '${d.inMinutes} phút trước';
  if (d.inHours < 24) return '${d.inHours} giờ trước';
  if (d.inDays < 7) return '${d.inDays} ngày trước';
  String two(int n) => n.toString().padLeft(2, '0');
  return '${two(t.day)}/${two(t.month)}/${t.year}';
}

/// Chuẩn hoá URL người dùng nhập: thêm http:// nếu thiếu, bỏ "/" cuối.
/// Trả về (url, null) nếu hợp lệ, (null, lỗi) nếu không.
(String?, String?) normalizeUrl(String input) {
  var s = input.trim();
  if (s.isEmpty) return (null, 'Nhập địa chỉ website');
  if (s.contains(' ')) return (null, 'Địa chỉ không được chứa khoảng trắng');
  if (s.contains('\\')) {
    return (null, 'Dùng dấu "/" thay cho "\\". Sửa thành: ${s.replaceAll('\\', '/')}');
  }

  // Tự sửa phần đầu thiếu "//" hoặc ":": "http:192…", "http:/192…", "http//192…"
  final head = RegExp(r'^(https?)(:/?|//)(?!/)', caseSensitive: false)
      .firstMatch(s);
  if (head != null && !s.contains('://')) {
    s = '${head.group(1)!.toLowerCase()}://${s.substring(head.end)}';
  }
  final schemeMatch =
      RegExp(r'^([a-z][a-z0-9+.\-]*)://', caseSensitive: false).firstMatch(s);
  if (schemeMatch != null) {
    final scheme = schemeMatch.group(1)!.toLowerCase();
    if (scheme != 'http' && scheme != 'https') {
      return (null,
          '"$scheme://" không hợp lệ — chỉ dùng http:// hoặc https://');
    }
  } else {
    s = 'http://$s';
  }

  // Tách host[:port] để báo lỗi cụ thể trước khi parse.
  final rest = s.substring(s.indexOf('://') + 3);
  final authority = rest.split(RegExp(r'[/?#]')).first;
  if (authority.isEmpty || authority.startsWith(':')) {
    return (null, 'Thiếu địa chỉ máy (IP hoặc tên miền) trước dấu ":"');
  }
  if (authority.contains(',')) {
    return (null,
        'Dùng dấu chấm "." thay cho dấu phẩy ",". Sửa thành: ${s.replaceAll(',', '.')}');
  }
  final colon = authority.lastIndexOf(':');
  final host = colon >= 0 ? authority.substring(0, colon) : authority;
  final portStr = colon >= 0 ? authority.substring(colon + 1) : null;
  if (host.contains(':')) {
    return (null, 'Có nhiều hơn một dấu ":" trong "$authority"');
  }
  if (portStr != null) {
    final port = int.tryParse(portStr);
    if (portStr.isEmpty) {
      return (null, 'Thiếu số cổng sau dấu ":" (vd: $host:8080)');
    }
    if (port == null || port < 1 || port > 65535) {
      return (null, 'Cổng "$portStr" không hợp lệ — phải là số từ 1 đến 65535');
    }
  }
  if (RegExp(r'^[\d.]+$').hasMatch(host)) {
    final parts = host.split('.');
    if (parts.length != 4 || parts.any((p) => p.isEmpty)) {
      return (null,
          'IP "$host" chưa đúng — cần đủ 4 phần, vd: 192.168.122.16');
    }
    final bad = parts.firstWhere((p) => int.parse(p) > 255, orElse: () => '');
    if (bad.isNotEmpty) {
      return (null, 'IP "$host" sai ở phần "$bad" — mỗi phần chỉ từ 0 đến 255');
    }
  } else if (!(host.contains('.') || host == 'localhost' || portStr != null)) {
    return (null,
        '"$host" thiếu tên miền hoặc cổng — vd: $host.local hoặc $host:8080');
  }

  final uri = Uri.tryParse(s);
  if (uri == null || uri.host.isEmpty) {
    return (null, 'Địa chỉ chưa đúng. Ví dụ: http://192.168.122.16:8080');
  }
  while (s.endsWith('/')) {
    s = s.substring(0, s.length - 1);
  }
  return (s, null);
}

/// Gợi ý tên từ host: "kaizen-board.local" → "Kaizen Board". IP → null.
String? suggestNameFromUrl(String url) {
  final host = Uri.tryParse(url)?.host ?? '';
  if (host.isEmpty || RegExp(r'^[\d.]+$').hasMatch(host)) return null;
  final first = host.split('.').first;
  if (first.isEmpty || first == 'www' || first == 'localhost') return null;
  return first
      .split(RegExp(r'[-_]+'))
      .where((p) => p.isNotEmpty)
      .map((p) => p[0].toUpperCase() + p.substring(1))
      .join(' ');
}
