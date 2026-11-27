import '../services/website_service.dart' show resolveApiUrl;
import 'website.dart';

/// Ai được xem site người dùng thêm vào.
/// - public: ai cũng xem được (không cần đăng nhập) — người thường thêm thì
///   PHẢI được admin (IT) duyệt; admin thêm thì hiện ngay.
/// - private: chỉ người thêm + admin — hiện ngay, không cần duyệt.
enum SiteVisibility { public, private }

/// Trạng thái duyệt. Private luôn là [live] ngay khi thêm.
enum ReviewStatus { pending, live, rejected }

/// 1 website do người dùng đăng ký (URL) lên dashboard — từ /api/submissions.
class Submission {
  final int id;
  final String name;
  final String url;
  final String department;
  final String note;
  final SiteVisibility visibility;
  final ReviewStatus status;

  /// Mã NV người thêm.
  final String owner;
  final String? ownerName;
  final DateTime createdAt;

  /// Lần sửa / gửi lại gần nhất (null = chưa sửa).
  final DateTime? updatedAt;

  /// Thời điểm admin duyệt / từ chối.
  final DateTime? reviewedAt;
  final String? reviewedBy;
  final String? reviewedByName;
  final String? rejectReason;

  /// Ảnh xem trước tự tải lên: URL tuyệt đối (đã lưu trên BE) hoặc data URL
  /// (vừa chọn, chưa gửi). null → hệ thống tự chụp màn hình như site thường.
  final String? previewImage;

  const Submission({
    required this.id,
    required this.name,
    required this.url,
    required this.department,
    required this.visibility,
    required this.status,
    required this.owner,
    required this.createdAt,
    this.ownerName,
    this.note = '',
    this.updatedAt,
    this.reviewedAt,
    this.reviewedBy,
    this.reviewedByName,
    this.rejectReason,
    this.previewImage,
  });

  bool get isPrivate => visibility == SiteVisibility.private;
  bool get isPending => status == ReviewStatus.pending;
  bool get isLive => status == ReviewStatus.live;
  bool get isRejected => status == ReviewStatus.rejected;

  /// Lúc gửi (gửi lại sau khi sửa → tính từ lúc sửa).
  DateTime get submittedAt => updatedAt ?? createdAt;

  String get ownerLabel =>
      (ownerName ?? '').trim().isEmpty ? owner : ownerName!.trim();

  String? get reviewerLabel =>
      (reviewedByName ?? '').trim().isEmpty ? reviewedBy : reviewedByName;

  factory Submission.fromJson(Map<String, dynamic> j) {
    DateTime? t(Object? v) =>
        v is String ? DateTime.tryParse(v)?.toLocal() : null;
    return Submission(
      id: (j['id'] as num).toInt(),
      name: '${j['name'] ?? ''}',
      url: '${j['url'] ?? ''}',
      department: '${j['department'] ?? ''}',
      note: (j['note'] as String?) ?? '',
      visibility: j['visibility'] == 'private'
          ? SiteVisibility.private
          : SiteVisibility.public,
      status: switch (j['status']) {
        'pending' => ReviewStatus.pending,
        'rejected' => ReviewStatus.rejected,
        _ => ReviewStatus.live,
      },
      owner: '${j['owner'] ?? ''}',
      ownerName: j['ownerName'] as String?,
      createdAt: t(j['createdAt']) ?? DateTime.now(),
      updatedAt: t(j['updatedAt']),
      reviewedAt: t(j['reviewedAt']),
      reviewedBy: j['reviewedBy'] as String?,
      reviewedByName: j['reviewedByName'] as String?,
      rejectReason: j['rejectReason'] as String?,
      previewImage: resolveApiUrl(j['previewUrl'] as String?),
    );
  }

  /// Admin (IT) sửa 1 site bất kỳ trên dashboard (kể cả site hệ thống) →
  /// dựng sẵn dữ liệu cho form sửa. PUT /api/submissions/{id} cho admin sửa
  /// được mọi site.
  factory Submission.fromWebsite(Website w) => Submission(
    id: w.id,
    name: w.name,
    url: w.url,
    department: w.departmentName,
    visibility: w.isPrivate ? SiteVisibility.private : SiteVisibility.public,
    status: ReviewStatus.live,
    owner: w.owner ?? '',
    ownerName: w.ownerName,
    createdAt: DateTime.now(),
    previewImage: w.previewImage,
  );

  /// Dùng để hiện lên lưới card như site thường.
  Website toWebsite() => Website(
    id: id,
    name: name,
    url: url,
    departmentName: department,
    type: '',
    status: true,
    isPrivate: isPrivate,
    owner: owner,
    ownerName: ownerName,
    previewImage: previewImage,
  );
}
