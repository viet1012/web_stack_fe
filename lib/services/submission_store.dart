import 'package:flutter/foundation.dart';

import '../models/submission.dart';
import 'auth_store.dart';
import 'website_service.dart';

/// WEBSITE DO NGƯỜI DÙNG THÊM — gọi /api/submissions (dev_manager_be).
///
/// Giữ bản sao trong bộ nhớ: [mine] (của tôi), [pending] / [reviewed] (admin).
/// Tự tải lại khi đăng nhập / đăng xuất. Mọi kiểm tra quyền làm ở BE.
/// Hàm ghi ném [DioException] khi lỗi → dùng [apiErrorMessage] để hiện lỗi.
class SubmissionStore extends ChangeNotifier {
  SubmissionStore._() {
    auth.addListener(_onAuth);
    if (auth.loggedIn) load();
  }

  static final instance = SubmissionStore._();

  static final _dio = WebsiteService.dio;
  static const _base = '/api/submissions';

  List<Submission> _mine = [];
  List<Submission> _pending = [];
  List<Submission> _reviewed = [];

  /// Mỗi lần thêm / sửa / duyệt / xoá thành công → tăng. Dashboard nghe để
  /// tải lại danh sách site.
  final changes = ValueNotifier<int>(0);

  /// Đăng nhập / đăng xuất / BE xác nhận lại vai trò → tải lại.
  void _onAuth() {
    if (auth.user == null) {
      _mine = [];
      _pending = [];
      _reviewed = [];
      notifyListeners();
    } else {
      load();
    }
  }

  // ------------------------------------------------------------
  // READ
  // ------------------------------------------------------------

  /// Mới gửi nhất lên đầu.
  List<Submission> mine(AppUser user) => List.unmodifiable(_mine);

  /// Hàng chờ duyệt cho admin — gửi sớm nhất lên đầu.
  List<Submission> get pending => List.unmodifiable(_pending);

  /// Đã xử lý — mới xử lý lên đầu.
  List<Submission> get reviewed => List.unmodifiable(_reviewed);

  /// Site của tôi có cùng URL (để báo trùng ngay trên form).
  Submission? byUrl(String url) {
    final k = _norm(url);
    for (final s in [..._mine, ..._pending]) {
      if (_norm(s.url) == k && !s.isRejected) return s;
    }
    return null;
  }

  Future<void> load() async {
    if (!auth.loggedIn) return;
    try {
      final res = await _dio.get('$_base/mine');
      _mine = _list(res.data);
      if (auth.isAdmin) {
        final r = await Future.wait([
          _dio.get(_base, queryParameters: {'status': 'pending'}),
          _dio.get(_base, queryParameters: {'status': 'reviewed'}),
        ]);
        _pending = _list(r[0].data);
        _reviewed = _list(r[1].data);
      } else {
        _pending = [];
        _reviewed = [];
      }
      notifyListeners();
    } catch (e) {
      debugPrint('[SUBMISSIONS LOAD ERROR] $e');
    }
  }

  // ------------------------------------------------------------
  // ACTIONS
  // ------------------------------------------------------------

  Future<Submission> submit({
    required String name,
    required String url,
    required String department,
    required SiteVisibility visibility,
    String note = '',
    String? previewImage,
  }) async {
    final res = await _dio.post(
      _base,
      data: _body(name, url, department, visibility, note, previewImage),
    );
    return _done(Submission.fromJson(Map<String, dynamic>.from(res.data)));
  }

  /// Sửa site. Người thường sửa site Public / đổi sang Public → chờ duyệt lại.
  Future<Submission> update(
    int id, {
    required String name,
    required String url,
    required String department,
    required SiteVisibility visibility,
    String note = '',
    String? previewImage,
  }) async {
    final res = await _dio.put(
      '$_base/$id',
      data: _body(name, url, department, visibility, note, previewImage),
    );
    return _done(Submission.fromJson(Map<String, dynamic>.from(res.data)));
  }

  Future<Submission> approve(int id) => _post('$_base/$id/approve');

  Future<Submission> reject(int id, String reason) =>
      _post('$_base/$id/reject', {'reason': reason});

  /// Hoàn tác duyệt / từ chối → về lại hàng chờ (admin).
  Future<Submission> reopen(int id) => _post('$_base/$id/reopen');

  /// Xoá (rút lại site đang chờ / gỡ site). Hoàn tác bằng [restore].
  Future<void> remove(int id) async {
    await _dio.delete('$_base/$id');
    await _reloadAfterChange();
  }

  /// Hoàn tác xoá.
  Future<Submission> restore(int id) => _post('$_base/$id/restore');

  // ------------------------------------------------------------
  // internal
  // ------------------------------------------------------------

  Future<Submission> _post(String path, [Object? data]) async {
    final res = await _dio.post(path, data: data);
    return _done(Submission.fromJson(Map<String, dynamic>.from(res.data)));
  }

  Future<Submission> _done(Submission s) async {
    await _reloadAfterChange();
    return s;
  }

  Future<void> _reloadAfterChange() async {
    changes.value++;
    await load();
  }

  static Map<String, dynamic> _body(
    String name,
    String url,
    String department,
    SiteVisibility visibility,
    String note,
    String? image,
  ) {
    final isNew = image != null && image.startsWith('data:');
    return {
      'name': name,
      'url': url,
      'department': department,
      'visibility': visibility.name,
      'note': note,
      // Ảnh mới: gửi data URL. Giữ ảnh cũ: gửi lại đường dẫn tương đối.
      'previewImage': isNew ? image : null,
      'previewUrl': isNew ? null : _relative(image),
    };
  }

  static String? _relative(String? url) {
    if (url == null) return null;
    final base = WebsiteService.dio.options.baseUrl;
    return url.startsWith(base) ? url.substring(base.length) : url;
  }

  static List<Submission> _list(Object? data) => [
    if (data is List)
      for (final j in data)
        if (j is Map) Submission.fromJson(Map<String, dynamic>.from(j)),
  ];
}

final submissions = SubmissionStore.instance;

String _norm(String url) => url
    .trim()
    .toLowerCase()
    .replaceFirst(RegExp(r'^https?://'), '')
    .replaceFirst(RegExp(r'/+$'), '');
