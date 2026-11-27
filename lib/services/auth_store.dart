import 'dart:convert';
import 'dart:html' as html;

import 'package:flutter/foundation.dart';

enum UserRole { user, admin }

@immutable
class AppUser {
  final String username;
  final String displayName;
  final UserRole role;

  const AppUser({
    required this.username,
    required this.displayName,
    required this.role,
  });

  bool get isAdmin => role == UserRole.admin;

  /// 2 chữ cái cho avatar: "lan.nguyen" → "LN", "admin" → "AD".
  String get initials {
    final parts = displayName
        .trim()
        .split(RegExp(r'[\s._\-]+'))
        .where((p) => p.isNotEmpty)
        .toList();
    if (parts.isEmpty) return '?';
    if (parts.length == 1) {
      final p = parts.first;
      return p.substring(0, p.length.clamp(1, 2)).toUpperCase();
    }
    return (parts.first[0] + parts.last[0]).toUpperCase();
  }

  Map<String, dynamic> toJson() => {
    'username': username,
    'displayName': displayName,
    'role': role.name,
  };

  static AppUser? fromJson(Map<String, dynamic> j) {
    final u = j['username'];
    if (u is! String || u.isEmpty) return null;
    return AppUser(
      username: u,
      displayName: (j['displayName'] as String?) ?? u,
      role: j['role'] == 'admin' ? UserRole.admin : UserRole.user,
    );
  }
}

/// ĐĂNG NHẬP — **MOCK** (chưa nối backend).
///
/// - Tên đăng nhập `admin` → quyền admin (duyệt site Public).
/// - Tên khác → người dùng thường. Mật khẩu bất kỳ (≥ 4 ký tự).
/// - Chỉ lưu username/role ở localStorage (KHÔNG lưu mật khẩu) để F5 không
///   bị đăng xuất. Khi có BE: thay [login] bằng POST /api/auth/login.
class AuthStore extends ValueNotifier<AppUser?> {
  AuthStore._() : super(_restore());

  static final instance = AuthStore._();

  static const _key = 'itpro.mockUser';

  static AppUser? _restore() {
    try {
      final raw = html.window.localStorage[_key];
      if (raw == null || raw.isEmpty) return null;
      return AppUser.fromJson(Map<String, dynamic>.from(jsonDecode(raw)));
    } catch (_) {
      return null;
    }
  }

  AppUser? get user => value;
  bool get loggedIn => value != null;
  bool get isAdmin => value?.isAdmin ?? false;

  /// Trả về null nếu thành công, ngược lại là thông báo lỗi.
  Future<String?> login(String username, String password) async {
    await Future.delayed(const Duration(milliseconds: 650));
    final u = username.trim().toLowerCase();
    if (u.isEmpty || password.length < 4) {
      return 'Sai tên đăng nhập hoặc mật khẩu';
    }
    value = AppUser(
      username: u,
      displayName: u,
      role: u == 'admin' ? UserRole.admin : UserRole.user,
    );
    try {
      html.window.localStorage[_key] = jsonEncode(value!.toJson());
    } catch (_) {}
    return null;
  }

  void logout() {
    value = null;
    try {
      html.window.localStorage.remove(_key);
    } catch (_) {}
  }
}

final auth = AuthStore.instance;
