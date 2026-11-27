class Website {
  final int id;
  final String name;
  final String url;
  final String departmentName;
  final String type;
  final bool status;

  /// Tên icon (kiểu lucide: "bar-chart", "factory"...). null → suy từ tên site,
  /// không khớp → globe. Xem widgets/site_icons.dart.
  final String? icon;

  /// URL favicon tùy chỉnh — BE ưu tiên dùng khi trả /api/sites/{id}/favicon.
  final String? iconUrl;

  /// Chứng chỉ tự ký / không hợp lệ (BE). Giá trị mới nhất lấy từ
  /// /api/websites/status (SiteStatus.certWarning).
  final bool certWarning;

  /// Site do người dùng thêm, chế độ Private: chỉ người thêm + admin thấy.
  final bool isPrivate;

  /// Username người thêm site (null = site hệ thống do IT cấu hình).
  final String? owner;

  /// Ảnh xem trước người dùng tự tải lên (URL hoặc data URL). null → dùng
  /// ảnh chụp tự động (/api/screenshot) như bình thường.
  final String? previewImage;

  Website({
    required this.id,
    required this.name,
    required this.url,
    required this.departmentName,
    required this.type,
    required this.status,
    this.icon,
    this.iconUrl,
    this.certWarning = false,
    this.isPrivate = false,
    this.owner,
    this.previewImage,
  });

  factory Website.fromJson(Map<String, dynamic> json) {
    return Website(
      id: json['id'],
      name: json['name'],
      url: json['url'],
      departmentName: json['departmentName'] ?? '',
      type: json['type'] ?? '',
      status: json['status'] ?? false,
      icon: json['icon'] as String?,
      iconUrl: json['iconUrl'] as String?,
      certWarning: json['certWarning'] == true,
      isPrivate: json['visibility'] == 'private',
      owner: json['owner'] as String?,
      previewImage: json['previewUrl'] as String?,
    );
  }
}
