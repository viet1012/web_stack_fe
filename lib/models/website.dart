class Website {
  final int id;
  final String name;
  final String url;
  final String departmentName;
  final String type;
  final bool status;

  Website({
    required this.id,
    required this.name,
    required this.url,
    required this.departmentName,
    required this.type,
    required this.status,
  });

  factory Website.fromJson(Map<String, dynamic> json) {
    return Website(
      id: json['id'],
      name: json['name'],
      url: json['url'],
      departmentName: json['departmentName'] ?? '',
      type: json['type'] ?? '',
      status: json['status'] ?? false,
    );
  }
}
