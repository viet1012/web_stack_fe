import 'website.dart';

/// Ai được xem site người dùng thêm vào.
/// - public: ai cũng xem được (không cần đăng nhập) — PHẢI được admin duyệt.
/// - private: chỉ người thêm + admin — hiện ngay, không cần duyệt.
enum SiteVisibility { public, private }

/// Trạng thái duyệt. Private luôn là [live] ngay khi thêm.
enum ReviewStatus { pending, live, rejected }

/// 1 website do người dùng đăng ký (URL) lên dashboard.
class Submission {
  /// Âm → chưa có trên BE (dữ liệu mock), tránh trùng id site hệ thống.
  final int id;
  final String name;
  final String url;
  final String department;
  final String note;
  final SiteVisibility visibility;
  final ReviewStatus status;
  final String owner;
  final DateTime createdAt;

  /// Thời điểm admin duyệt / từ chối.
  final DateTime? reviewedAt;
  final String? reviewedBy;
  final String? rejectReason;

  /// Ảnh xem trước tự tải lên (mock: data URL JPEG đã thu nhỏ).
  /// null → hệ thống tự chụp màn hình như site thường.
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
    this.note = '',
    this.reviewedAt,
    this.reviewedBy,
    this.rejectReason,
    this.previewImage,
  });

  bool get isPrivate => visibility == SiteVisibility.private;
  bool get isPending => status == ReviewStatus.pending;
  bool get isLive => status == ReviewStatus.live;
  bool get isRejected => status == ReviewStatus.rejected;

  Submission copyWith({
    String? name,
    String? url,
    String? department,
    String? note,
    SiteVisibility? visibility,
    ReviewStatus? status,
    DateTime? createdAt,
    DateTime? reviewedAt,
    String? reviewedBy,
    String? rejectReason,
    bool clearReview = false,
    // Ảnh: truyền record để phân biệt "không đổi" (null) với "xoá ảnh" ((null,)).
    (String?,)? previewImage,
  }) => Submission(
    id: id,
    owner: owner,
    name: name ?? this.name,
    url: url ?? this.url,
    department: department ?? this.department,
    note: note ?? this.note,
    visibility: visibility ?? this.visibility,
    status: status ?? this.status,
    createdAt: createdAt ?? this.createdAt,
    reviewedAt: clearReview ? null : (reviewedAt ?? this.reviewedAt),
    reviewedBy: clearReview ? null : (reviewedBy ?? this.reviewedBy),
    rejectReason: clearReview ? null : (rejectReason ?? this.rejectReason),
    previewImage: previewImage == null ? this.previewImage : previewImage.$1,
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
    previewImage: previewImage,
  );
}
