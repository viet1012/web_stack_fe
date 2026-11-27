import 'dart:convert';
import 'dart:html' as html;

import 'package:flutter/foundation.dart';

import '../models/submission.dart';
import '../models/website.dart';
import 'auth_store.dart';

/// WEBSITE DO NGƯỜI DÙNG THÊM — **MOCK** (chưa nối backend).
///
/// Lưu ở localStorage (`itpro.mockSubmissions`) để F5 không mất dữ liệu thử.
/// Khi có BE, thay từng hàm bằng API tương ứng (xem README mục "Thêm website").
class SubmissionStore extends ChangeNotifier {
  SubmissionStore._() {
    _load();
  }

  static final instance = SubmissionStore._();

  static const _key = 'itpro.mockSubmissions';

  final List<Submission> _items = [];
  int _nextId = -1;

  List<Submission> get items => List.unmodifiable(_items);

  /// Site hiện trên lưới cho [user]:
  /// Public đã duyệt (ai cũng thấy) + Private của chính mình (admin thấy hết).
  List<Website> visibleFor(AppUser? user) => [
    for (final s in _items)
      if (s.isLive &&
          (!s.isPrivate ||
              (user != null && (user.isAdmin || s.owner == user.username))))
        s.toWebsite(),
  ];

  /// Mới nhất lên đầu.
  List<Submission> mine(AppUser user) =>
      _items.where((s) => s.owner == user.username).toList()
        ..sort((a, b) => b.createdAt.compareTo(a.createdAt));

  /// Hàng chờ duyệt cho admin — cũ nhất lên đầu (xử lý theo thứ tự gửi).
  List<Submission> get pending =>
      _items.where((s) => s.isPending).toList()
        ..sort((a, b) => a.createdAt.compareTo(b.createdAt));

  /// Đã xử lý (public đã duyệt / bị từ chối) — mới xử lý lên đầu.
  List<Submission> get reviewed =>
      _items.where((s) => !s.isPending && s.reviewedAt != null).toList()
        ..sort((a, b) => b.reviewedAt!.compareTo(a.reviewedAt!));

  Submission? byUrl(String url) {
    final k = _norm(url);
    for (final s in _items) {
      if (_norm(s.url) == k && !s.isRejected) return s;
    }
    return null;
  }

  // ------------------------------------------------------------
  // ACTIONS
  // ------------------------------------------------------------

  Future<Submission> submit({
    required AppUser owner,
    required String name,
    required String url,
    required String department,
    required SiteVisibility visibility,
    String note = '',
    String? previewImage,
  }) async {
    await Future.delayed(const Duration(milliseconds: 700));
    final s = Submission(
      id: _nextId--,
      name: name,
      url: url,
      department: department,
      note: note,
      previewImage: previewImage,
      visibility: visibility,
      // Private không cần duyệt → hiện ngay.
      status: visibility == SiteVisibility.private
          ? ReviewStatus.live
          : ReviewStatus.pending,
      owner: owner.username,
      createdAt: DateTime.now(),
    );
    _items.add(s);
    _changed();
    return s;
  }

  /// Sửa site (vd. sửa site bị từ chối rồi gửi lại). Đổi sang Public hoặc
  /// sửa site Public → quay về chờ duyệt.
  Future<Submission> update(
    int id, {
    required String name,
    required String url,
    required String department,
    required SiteVisibility visibility,
    String note = '',
    String? previewImage,
  }) async {
    await Future.delayed(const Duration(milliseconds: 700));
    final i = _items.indexWhere((s) => s.id == id);
    final s = _items[i].copyWith(
      name: name,
      url: url,
      department: department,
      note: note,
      previewImage: (previewImage,),
      visibility: visibility,
      status: visibility == SiteVisibility.private
          ? ReviewStatus.live
          : ReviewStatus.pending,
      createdAt: DateTime.now(),
      clearReview: true,
    );
    _items[i] = s;
    _changed();
    return s;
  }

  void approve(int id, AppUser by) => _set(
    id,
    (s) => s.copyWith(
      status: ReviewStatus.live,
      reviewedAt: DateTime.now(),
      reviewedBy: by.username,
    ),
  );

  void reject(int id, AppUser by, String reason) => _set(
    id,
    (s) => s.copyWith(
      status: ReviewStatus.rejected,
      reviewedAt: DateTime.now(),
      reviewedBy: by.username,
      rejectReason: reason,
    ),
  );

  /// Xoá (rút lại site đang chờ / gỡ site của mình). Trả về bản đã xoá để
  /// hoàn tác.
  Submission? remove(int id) {
    final i = _items.indexWhere((s) => s.id == id);
    if (i < 0) return null;
    final s = _items.removeAt(i);
    _changed();
    return s;
  }

  /// Hoàn tác: đặt lại đúng bản cũ (sau khi xoá / duyệt / từ chối).
  void restore(Submission old) {
    final i = _items.indexWhere((s) => s.id == old.id);
    if (i < 0) {
      _items.add(old);
    } else {
      _items[i] = old;
    }
    _changed();
  }

  void _set(int id, Submission Function(Submission) f) {
    final i = _items.indexWhere((s) => s.id == id);
    if (i < 0) return;
    _items[i] = f(_items[i]);
    _changed();
  }

  // ------------------------------------------------------------
  // PERSIST (mock)
  // ------------------------------------------------------------

  void _changed() {
    notifyListeners();
    try {
      html.window.localStorage[_key] = jsonEncode(_items.map(_toJson).toList());
    } catch (_) {}
  }

  void _load() {
    try {
      final raw = html.window.localStorage[_key];
      if (raw != null && raw.isNotEmpty) {
        for (final j in jsonDecode(raw) as List) {
          _items.add(_fromJson(Map<String, dynamic>.from(j)));
        }
      }
    } catch (_) {
      _items.clear();
    }
    if (_items.isEmpty) _seed();
    for (final s in _items) {
      if (s.id <= _nextId) _nextId = s.id - 1;
    }
  }

  void _seed() {
    final now = DateTime.now();
    _items.addAll([
      Submission(
        id: -1,
        name: 'Quản lý khuôn',
        url: 'http://192.168.122.40:8080',
        department: 'PRO',
        note: 'Theo dõi lịch bảo trì & tuổi thọ khuôn cho tổ sản xuất.',
        visibility: SiteVisibility.public,
        status: ReviewStatus.pending,
        owner: 'lan.nguyen',
        createdAt: now.subtract(const Duration(hours: 2)),
      ),
      Submission(
        id: -2,
        name: 'Đặt phòng họp',
        url: 'http://192.168.122.45:3000',
        department: 'HR',
        visibility: SiteVisibility.public,
        status: ReviewStatus.pending,
        owner: 'minh.tran',
        createdAt: now.subtract(const Duration(minutes: 25)),
      ),
      Submission(
        id: -3,
        name: 'Kaizen Board',
        url: 'http://192.168.122.52:3000',
        department: 'TE',
        note: 'Bảng đề xuất cải tiến của phòng TE.',
        visibility: SiteVisibility.public,
        status: ReviewStatus.live,
        owner: 'hoa.pham',
        createdAt: now.subtract(const Duration(days: 3)),
        reviewedAt: now.subtract(const Duration(days: 2)),
        reviewedBy: 'admin',
      ),
      Submission(
        id: -4,
        name: 'Báo cáo cá nhân',
        url: 'http://192.168.122.61:5000',
        department: 'IT',
        visibility: SiteVisibility.private,
        status: ReviewStatus.live,
        owner: 'minh.tran',
        createdAt: now.subtract(const Duration(days: 1)),
      ),
    ]);
  }

  static Map<String, dynamic> _toJson(Submission s) => {
    'id': s.id,
    'name': s.name,
    'url': s.url,
    'department': s.department,
    'note': s.note,
    'visibility': s.visibility.name,
    'status': s.status.name,
    'owner': s.owner,
    'createdAt': s.createdAt.millisecondsSinceEpoch,
    'reviewedAt': s.reviewedAt?.millisecondsSinceEpoch,
    'reviewedBy': s.reviewedBy,
    'rejectReason': s.rejectReason,
    'previewImage': s.previewImage,
  };

  static Submission _fromJson(Map<String, dynamic> j) {
    DateTime? t(Object? v) =>
        v is num ? DateTime.fromMillisecondsSinceEpoch(v.toInt()) : null;
    return Submission(
      id: (j['id'] as num).toInt(),
      name: j['name'] as String,
      url: j['url'] as String,
      department: j['department'] as String? ?? '',
      note: j['note'] as String? ?? '',
      visibility: SiteVisibility.values.byName(j['visibility'] as String),
      status: ReviewStatus.values.byName(j['status'] as String),
      owner: j['owner'] as String,
      createdAt: t(j['createdAt']) ?? DateTime.now(),
      reviewedAt: t(j['reviewedAt']),
      reviewedBy: j['reviewedBy'] as String?,
      rejectReason: j['rejectReason'] as String?,
      previewImage: j['previewImage'] as String?,
    );
  }
}

final submissions = SubmissionStore.instance;

String _norm(String url) => url
    .trim()
    .toLowerCase()
    .replaceFirst(RegExp(r'^https?://'), '')
    .replaceFirst(RegExp(r'/+$'), '');
