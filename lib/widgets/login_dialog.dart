import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../services/auth_store.dart';
import '../theme/dash_theme.dart';
import 'form_ui.dart';

/// Đã đăng nhập → true ngay. Chưa → mở dialog đăng nhập, trả về kết quả.
/// [reason] hiện dưới tiêu đề, vd. "Đăng nhập để thêm website".
Future<bool> ensureLoggedIn(BuildContext context, {String? reason}) async {
  if (auth.loggedIn) return true;
  final ok = await showDashDialog<bool>(
    context,
    builder: (_) => LoginDialog(reason: reason),
  );
  return ok == true;
}

class LoginDialog extends StatefulWidget {
  final String? reason;
  const LoginDialog({super.key, this.reason});

  @override
  State<LoginDialog> createState() => _LoginDialogState();
}

class _LoginDialogState extends State<LoginDialog> {
  final _user = TextEditingController();
  final _pass = TextEditingController();
  final _passFocus = FocusNode();
  bool _show = false;
  bool _busy = false;
  String? _error;

  @override
  void dispose() {
    _user.dispose();
    _pass.dispose();
    _passFocus.dispose();
    super.dispose();
  }

  bool get _canSubmit =>
      _user.text.trim().isNotEmpty && _pass.text.isNotEmpty && !_busy;

  Future<void> _submit() async {
    if (!_canSubmit) return;
    setState(() {
      _busy = true;
      _error = null;
    });
    final err = await auth.login(_user.text, _pass.text);
    if (!mounted) return;
    if (err == null) {
      Navigator.of(context).pop(true);
    } else {
      setState(() {
        _busy = false;
        _error = err;
      });
      _passFocus.requestFocus();
      _pass.selection = TextSelection(
        baseOffset: 0,
        extentOffset: _pass.text.length,
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final c = context.dash;
    final t = context.tone;

    return DashDialog(
      maxWidth: 420,
      icon: LucideIcons.logIn,
      title: 'Đăng nhập',
      subtitle: widget.reason ?? 'Dùng tài khoản nội bộ của bạn.',
      onClose: () => Navigator.of(context).pop(false),
      child: AutofillGroup(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const SizedBox(height: 4),
            const FieldLabel('Tên đăng nhập'),
            DashTextField(
              controller: _user,
              autofocus: true,
              icon: LucideIcons.user,
              hint: 'vd. lan.nguyen',
              textInputAction: TextInputAction.next,
              autofillHints: const [AutofillHints.username],
              onChanged: (_) => setState(() => _error = null),
              onSubmitted: (_) => _passFocus.requestFocus(),
            ),
            const SizedBox(height: 16),
            const FieldLabel('Mật khẩu'),
            DashTextField(
              controller: _pass,
              focusNode: _passFocus,
              obscure: !_show,
              icon: LucideIcons.lock,
              hint: '••••••••',
              textInputAction: TextInputAction.done,
              autofillHints: const [AutofillHints.password],
              onChanged: (_) => setState(() => _error = null),
              onSubmitted: (_) => _submit(),
              suffix: Tooltip(
                message: _show ? 'Ẩn mật khẩu' : 'Hiện mật khẩu',
                child: IconButton(
                  onPressed: () => setState(() => _show = !_show),
                  icon: Icon(
                    _show ? LucideIcons.eyeOff : LucideIcons.eye,
                    size: 17,
                  ),
                  color: c.muted,
                  visualDensity: VisualDensity.compact,
                ),
              ),
            ),
            // Lỗi đăng nhập: 1 dòng nền đỏ nhạt, không popup.
            AnimatedSize(
              duration: Motion.of(context, Motion.fast),
              curve: Motion.curve,
              child: _error == null
                  ? const SizedBox(width: double.infinity, height: 0)
                  : Container(
                      margin: const EdgeInsets.only(top: 14),
                      padding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 10,
                      ),
                      decoration: BoxDecoration(
                        color: t.offBg,
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Row(
                        children: [
                          Icon(LucideIcons.circleAlert, size: 15, color: t.offFg),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              _error!,
                              style: TextStyle(color: t.offFg, fontSize: 13),
                            ),
                          ),
                        ],
                      ),
                    ),
            ),
            const SizedBox(height: 20),
            DashButton(
              label: _busy ? 'Đang đăng nhập…' : 'Đăng nhập',
              loading: _busy,
              expand: true,
              height: 44,
              onPressed: _canSubmit ? _submit : null,
            ),
            const SizedBox(height: 16),
            // Ghi chú bản demo (xoá khi nối BE thật).
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: c.surface2,
                borderRadius: BorderRadius.circular(10),
              ),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Icon(LucideIcons.flaskConical, size: 14, color: c.muted),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text.rich(
                      TextSpan(
                        children: [
                          const TextSpan(text: 'Bản demo: nhập '),
                          TextSpan(
                            text: 'admin',
                            style: monoText(size: 12, color: c.text),
                          ),
                          const TextSpan(
                            text:
                                ' để có quyền duyệt; tên khác là người dùng '
                                'thường. Mật khẩu bất kỳ (≥ 4 ký tự).',
                          ),
                        ],
                      ),
                      style: TextStyle(color: c.muted, fontSize: 12, height: 1.45),
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
