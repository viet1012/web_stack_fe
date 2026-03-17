import 'dart:convert';

enum WebsiteTag { production, staging, dev, admin }

extension WebsiteTagExt on WebsiteTag {
  String get label {
    switch (this) {
      case WebsiteTag.production:
        return 'production';
      case WebsiteTag.staging:
        return 'staging';
      case WebsiteTag.dev:
        return 'dev';
      case WebsiteTag.admin:
        return 'admin';
    }
  }
}

class Website {
  final String id;
  final String name;
  final String url;
  final String description;
  final String emoji;
  final List<String> tags;
  final bool isOnline;
  final DateTime createdAt;
  final DateTime? updatedAt;

  const Website({
    required this.id,
    required this.name,
    required this.url,
    this.description = '',
    this.emoji = '🌐',
    this.tags = const [],
    this.isOnline = false,
    required this.createdAt,
    this.updatedAt,
  });

  Website copyWith({
    String? id,
    String? name,
    String? url,
    String? description,
    String? emoji,
    List<String>? tags,
    bool? isOnline,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return Website(
      id: id ?? this.id,
      name: name ?? this.name,
      url: url ?? this.url,
      description: description ?? this.description,
      emoji: emoji ?? this.emoji,
      tags: tags ?? this.tags,
      isOnline: isOnline ?? this.isOnline,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }

  Map<String, dynamic> toJson() => {
    'id': id,
    'name': name,
    'url': url,
    'description': description,
    'emoji': emoji,
    'tags': tags,
    'isOnline': isOnline,
    'createdAt': createdAt.toIso8601String(),
    'updatedAt': updatedAt?.toIso8601String(),
  };

  factory Website.fromJson(Map<String, dynamic> json) => Website(
    id: json['id'] as String,
    name: json['name'] as String,
    url: json['url'] as String,
    description: json['description'] as String? ?? '',
    emoji: json['emoji'] as String? ?? '🌐',
    tags: List<String>.from(json['tags'] as List? ?? []),
    isOnline: json['isOnline'] as bool? ?? false,
    createdAt: DateTime.parse(json['createdAt'] as String),
    updatedAt: json['updatedAt'] != null
        ? DateTime.parse(json['updatedAt'] as String)
        : null,
  );

  String toJsonString() => jsonEncode(toJson());

  /// Display URL without scheme
  String get displayUrl {
    return url.replaceAll('https://', '').replaceAll('http://', '');
  }
}
