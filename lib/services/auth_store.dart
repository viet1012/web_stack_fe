import 'dart:convert';
import 'dart:html' as html;

import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';

import 'website_service.dart';

enum UserRole { user, admin }

@immutable
class AppUser {
  /// Mã nhân viên (trim + UPPER) — dùng làm `owner`.
  final String username;
  final String displayName;
  final UserRole role;

  const AppUser({
    required this.username,
    required this.displayName,
    required this.role,
  });

  bool get isAdmin => role == UserRole.admin;

  /// 2 chữ cái cho avatar: "Nguyễn Văn Lan" → "NL", "12345" → "12".
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

  /// Từ GET /api/auth/me của dev_manager_be.
  static AppUser fromMe(Map<String, dynamic> j) {
    final id = '${j['employeeId'] ?? ''}';
    final name = '${j['name'] ?? ''}'.trim();
    return AppUser(
      username: id,
      displayName: name.isEmpty ? id : name,
      role: j['role'] == 'admin' ? UserRole.admin : UserRole.user,
    );
  }
}

/// ĐĂNG NHẬP — mã NV + mật khẩu (bảng HSE_Patrol_Account).
///
/// - Login / logout: gọi dev_manager_be `/api/auth/login|logout` — BE tự kiểm
///   tài khoản + tạo session. Trả về
///   token + user (vai trò từ quyền app ITPRO).
/// - FE KHÔNG tự suy ra admin.
/// - Lưu token + thông tin hiển thị ở localStorage (không lưu mật khẩu).
///   Mở lại trang → hiện ngay theo bản lưu, rồi hỏi lại /me để xác nhận.
/// - API trả 401 → tự đăng xuất (token hết hạn / bị thu hồi).
class AuthStore extends ValueNotifier<AppUser?> {
  AuthStore._() : super(null) {
    _restore();
    WebsiteService.dio.interceptors.add(
      InterceptorsWrapper(
        onRequest: (o, h) {
          final t = _token;
          if (t != null && !o.headers.containsKey('Authorization')) {
            o.headers['Authorization'] = 'Bearer $t';
          }
          h.next(o);
        },
        onError: (e, h) {
          // Gửi token mà bị 401 → phiên đã hết hạn.
          if (e.response?.statusCode == 401 &&
              e.requestOptions.headers['Authorization'] != null &&
              _token != null) {
            _clear();
          }
          h.next(e);
        },
      ),
    );
    if (_token != null) refresh();
  }

  static final instance = AuthStore._();

  static const _key = 'itpro.auth';

  static Dio get _dio => WebsiteService.dio;

  String? _token;

  AppUser? get user => value;
  bool get loggedIn => value != null;
  bool get isAdmin => value?.isAdmin ?? false;

  void _restore() {
    try {
      final raw = html.window.localStorage[_key];
      if (raw == null || raw.isEmpty) return;
      final j = Map<String, dynamic>.from(jsonDecode(raw));
      final t = j['token'];
      final exp = DateTime.tryParse('${j['expiresAt'] ?? ''}');
      if (t is! String || t.isEmpty) return;
      // Hết hạn tuyệt đối (7 ngày) → bỏ. ExpiresAt trượt nên chỉ dùng tham khảo.
      if (exp != null && exp.isBefore(DateTime.now().subtract(const Duration(days: 7)))) {
        return;
      }
      _token = t;
      value = AppUser.fromJson(Map<String, dynamic>.from(j['user'] as Map));
    } catch (_) {
      _token = null;
      value = null;
    }
  }

  void _persist(String? expiresAt) {
    try {
      html.window.localStorage[_key] = jsonEncode({
        'token': _token,
        'expiresAt': expiresAt,
        'user': value?.toJson(),
      });
    } catch (_) {}
  }

  void _clear() {
    _token = null;
    try {
      html.window.localStorage.remove(_key);
    } catch (_) {}
    value = null;
  }

  /// Hỏi lại BE thông tin + vai trò. 401 → đăng xuất (interceptor xử lý).
  Future<void> refresh() async {
    if (_token == null) return;
    try {
      final res = await _dio.get('/api/auth/me');
      final u = AppUser.fromMe(Map<String, dynamic>.from(res.data as Map));
      value = u;
      _persist(res.data['expiresAt'] as String?);
    } catch (_) {
      // Mất mạng / BE lỗi → giữ bản lưu, thử lại lần sau.
    }
  }

  /// Trả về null nếu thành công, ngược lại là thông báo lỗi (tiếng Việt).
  Future<String?> login(String employeeId, String password) async {
    final id = employeeId.trim().toUpperCase();
    if (id.isEmpty || password.isEmpty) {
      return 'Nhập mã nhân viên và mật khẩu';
    }
    try {
      final res = await _dio.post(
        '/api/auth/login',
        data: {'employeeId': id, 'password': password},
        options: Options(receiveTimeout: const Duration(seconds: 20)),
      );
      final d = Map<String, dynamic>.from(res.data as Map);
      final token = '${d['token'] ?? ''}';
      if (token.isEmpty) return 'Đăng nhập thất bại, vui lòng thử lại';
      _token = token;
      value = AppUser.fromMe(Map<String, dynamic>.from(d['user'] as Map));
      _persist(d['expiresAt'] as String?);
      return null;
    } on DioException catch (e) {
      final code = e.response?.statusCode;
      if (code == 400 || code == 401) {
        return _message(e) ?? 'Sai mã nhân viên hoặc mật khẩu';
      }
      if (code == 429 || code == 403 || code == 502) {
        return _message(e) ?? 'Không đăng nhập được, vui lòng thử lại';
      }
      return 'Không kết nối được máy chủ dashboard';
    }
  }

  Future<void> logout() async {
    final t = _token;
    _clear();
    if (t == null) return;
    try {
      await _dio.post(
        '/api/auth/logout',
        options: Options(headers: {'Authorization': 'Bearer $t'}),
      );
    } catch (_) {}
  }

  static String? _message(DioException e) {
    final d = e.response?.data;
    if (d is Map && d['message'] is String) return d['message'] as String;
    return null;
  }
}

final auth = AuthStore.instance;
