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
    );
  }
}
