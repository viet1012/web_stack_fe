import 'dart:convert';
import 'dart:html' as html;

import 'package:flutter/foundation.dart';

import '../models/website.dart';
import 'package:dio/dio.dart';

/// Key URL chung cho FE ↔ BE: trim, lowercase, bỏ "/" cuối.
String normUrl(String url) {
  var u = url.trim().toLowerCase();
  while (u.endsWith('/')) {
    u = u.substring(0, u.length - 1);
  }
  return u;
}

@immutable
class StatusResult {
  final bool? online;
  final bool authRequired;
  final int? latencyMs;

  /// Chứng chỉ tự ký / không hợp lệ — site vẫn online.
  final bool certWarning;

  const StatusResult({
    required this.online,
    required this.authRequired,
    required this.latencyMs,
    this.certWarning = false,
  });
}

/// Đường dẫn tương đối của BE ("/api/uploads/…") → URL tuyệt đối.
String? resolveApiUrl(String? path) {
  if (path == null || path.isEmpty) return null;
  if (path.startsWith('/')) return '${WebsiteService.dio.options.baseUrl}$path';
  return path;
}

/// Lỗi BE dạng { code, message } → message tiếng Việt để hiện cho người dùng.
String apiErrorMessage(Object e, [String fallback = 'Có lỗi xảy ra, vui lòng thử lại']) {
  if (e is DioException) {
    final d = e.response?.data;
    if (d is Map && d['message'] is String) return d['message'] as String;
    switch (e.response?.statusCode) {
      case 401:
        return 'Phiên đăng nhập đã hết hạn, vui lòng đăng nhập lại';
      case 403:
        return 'Bạn không có quyền thực hiện thao tác này';
      case 404:
        return 'Không tìm thấy website (có thể đã bị xoá)';
    }
    if (e.response == null) return 'Không kết nối được máy chủ';
  }
  return fallback;
}

/// Địa chỉ BE server (dev_manager_be chạy trên 192.168.122.16).
const kServerApi = 'http://192.168.122.16:9095';

/// Địa chỉ BE khi chạy BE ở máy dev.
const kLocalApi = 'http://localhost:9999';

/// Chọn BE tự động — KHÔNG cần sửa code khi đổi dev ↔ server:
/// 1. `--dart-define=API_BASE=...` (vd. chạy FE ở máy dev nhưng dùng BE server).
/// 2. Trang mở ở localhost / 127.0.0.1 → BE ở máy dev ([kLocalApi]).
/// 3. Còn lại (mở từ server / máy khác) → BE server ([kServerApi]).
String resolveApiBase() {
  const override = String.fromEnvironment('API_BASE');
  if (override.isNotEmpty) return override;
  final host = Uri.base.host;
  final local = host == 'localhost' || host == '127.0.0.1' || host.isEmpty;
  return local ? kLocalApi : kServerApi;
}

class WebsiteService {
  static final Dio dio = Dio(
    BaseOptions(
      baseUrl: resolveApiBase(),
      connectTimeout: const Duration(seconds: 10),
      receiveTimeout: const Duration(seconds: 10),
      headers: {'Content-Type': 'application/json'},
    ),
  );

  // init interceptor (log request/response)
  static void init() {
    debugPrint('[API] ${dio.options.baseUrl}');
    if (kDebugMode) {
      dio.interceptors.add(
        LogInterceptor(requestBody: true, responseBody: true),
      );
    }
  }

  // GET ALL
  static Future<List<Website>> fetchWebsites() async {
    try {
      final response = await dio.get('/api/websites');

      final List data = response.data;

      return data.map((e) => Website.fromJson(e)).toList();
    } on DioException catch (e) {
      throw Exception(handleError(e));
    }
  }

  // CHECK WEB ACTIVE
  static Map<String, bool> _cache = {};
  static DateTime? _lastFetch;
  static const int _cacheSeconds = 300; // ?? ch?nh ? dây

  static Future<Map<String, bool>> checkBatch(
    List<String> urls, {
    bool force = false,
  }) async {
    try {
      if (!force &&
          _lastFetch != null &&
          DateTime.now().difference(_lastFetch!).inSeconds < _cacheSeconds) {
        return _cache;
      }

      final res = await dio.post('/api/websites/check-batch', data: urls);

      final result = Map<String, bool>.from(res.data);

      _cache = result;
      _lastFetch = DateTime.now();

      return result;
    } catch (e) {
      return _cache; // gi? tr?ng thái cu
    }
  }

  // ============================================================
  // ENDPOINTS (đổi tại đây nếu BE khác path)
  // ============================================================

  static const _statusPath = '/api/websites/status';
  static const _screenshotPath = '/api/screenshot';
  static const _screenshotMetaPath = '/api/screenshot/meta';
  static const _screenshotRefreshPath = '/api/screenshot/refresh';

  // STATUS: 1 request lấy trạng thái tất cả site do BE check.
  // Chấp nhận 2 dạng response:
  //   [ { id, online, authRequired, latencyMs, certWarning }, ... ]
  //   { "<id>": { online, authRequired, latencyMs, certWarning }, ... }
  // Trả về map theo id. Lỗi request → throw, để caller gán "unknown"
  // chứ không phải offline.
  static bool _loggedStatusRaw = false;

  static Future<Map<int, StatusResult>> fetchStatus({
    Duration timeout = const Duration(seconds: 20),
  }) async {
    final res = await dio.get(_statusPath).timeout(timeout);

    if (!_loggedStatusRaw) {
      _loggedStatusRaw = true;
      html.window.console.debug(
        '[status] raw response: ${jsonEncode(res.data)}',
      );
    }

    final out = <int, StatusResult>{};
    final data = res.data;

    void add(dynamic id, dynamic v) {
      final key = id is int ? id : int.tryParse('$id');
      if (key == null || v is! Map) return;
      final online = v['online'] ?? v['status'];
      out[key] = StatusResult(
        // null = BE không nói rõ → unknown, không phải offline.
        online: online is bool ? online : null,
        authRequired: v['authRequired'] == true,
        latencyMs: (v['latencyMs'] as num?)?.toInt(),
        certWarning: v['certWarning'] == true,
      );
    }

    if (data is Map) {
      data.forEach(add);
    } else if (data is List) {
      for (final v in data) {
        if (v is Map) add(v['id'], v);
      }
    }
    return out;
  }

  // SCREENSHOT META: { state: ok|loading|blank|offline, capturedAt, hasImage }
  static Future<Map<String, dynamic>?> fetchScreenshotMeta(String url) async {
    try {
      final res = await dio.get(
        _screenshotMetaPath,
        queryParameters: {'url': url},
      );
      return Map<String, dynamic>.from(res.data as Map);
    } catch (_) {
      return null;
    }
  }

  // Chụp lại: không truyền url → tất cả site.
  static Future<bool> refreshScreenshots({String? url}) async {
    try {
      await dio.post(_screenshotRefreshPath, queryParameters: {'url': ?url});
      return true;
    } catch (_) {
      return false;
    }
  }

  // Ảnh screenshot. Phải encode URL (?, &, # bị cắt → ảnh lỗi);
  // t = capturedAt để cache-bust khi có ảnh mới.
  static String screenshotUrl(String url, {Object? t}) {
    final q =
        'url=${Uri.encodeQueryComponent(url)}'
        '${t == null ? '' : '&t=${Uri.encodeQueryComponent('$t')}'}';
    return '${dio.options.baseUrl}$_screenshotPath?$q';
  }

  // PAGE TITLE: BE đọc <title>/og:title của trang. 200 {title} | 204 không có.
  // Lỗi/timeout → null (chỉ là gợi ý, không chặn form).
  static Future<String?> fetchPageTitle(String url) async {
    try {
      final res = await dio.get(
        '/api/websites/page-title',
        queryParameters: {'url': url},
        options: Options(receiveTimeout: const Duration(seconds: 12)),
      );
      final t = res.data is Map ? res.data['title'] : null;
      return t is String && t.trim().isNotEmpty ? t.trim() : null;
    } catch (_) {
      return null;
    }
  }

  // FAVICON: 200 = ảnh, 204 = không có. Cùng baseUrl với các API khác.
  static String faviconUrl(int siteId) =>
      '${dio.options.baseUrl}/api/websites/$siteId/favicon';

  // FILTER
  static Future<List<Website>> filter({
    String? department,
    String? type,
    bool? status,
  }) async {
    try {
      final response = await dio.get(
        '/api/websites',
        queryParameters: {
          if (department != null) 'department': department,
          if (type != null) 'type': type,
          if (status != null) 'status': status,
        },
      );

      final List data = response.data;

      return data.map((e) => Website.fromJson(e)).toList();
    } on DioException catch (e) {
      throw Exception(handleError(e));
    }
  }

  // ERROR HANDLE
  static String handleError(DioException e) {
    if (e.type == DioExceptionType.connectionTimeout) {
      return "Timeout kết nối server";
    }

    if (e.type == DioExceptionType.badResponse) {
      return "Server lỗi: ${e.response?.statusCode}";
    }

    if (e.type == DioExceptionType.unknown) {
      return "Không kết nối được server";
    }

    return "Lỗi không xác định";
  }
}
