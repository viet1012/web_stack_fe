import 'dart:convert';

enum HttpMethod { GET, POST, PUT, DELETE, PATCH }

extension HttpMethodExt on HttpMethod {
  String get label => name;
}

class ApiHeader {
  final String key;
  final String value;
  final bool enabled;

  const ApiHeader({
    required this.key,
    required this.value,
    this.enabled = true,
  });

  Map<String, dynamic> toJson() => {
    'key': key, 'value': value, 'enabled': enabled,
  };

  factory ApiHeader.fromJson(Map<String, dynamic> json) => ApiHeader(
    key: json['key'] as String,
    value: json['value'] as String,
    enabled: json['enabled'] as bool? ?? true,
  );
}

class ApiEndpoint {
  final String id;
  final String name;
  final String baseUrl;
  final String path;
  final HttpMethod method;
  final String description;
  final List<ApiHeader> headers;
  final String body;         // JSON body string
  final String groupName;    // folder/group
  final DateTime createdAt;
  final DateTime? updatedAt;

  const ApiEndpoint({
    required this.id,
    required this.name,
    required this.baseUrl,
    required this.path,
    this.method = HttpMethod.GET,
    this.description = '',
    this.headers = const [],
    this.body = '',
    this.groupName = 'Default',
    required this.createdAt,
    this.updatedAt,
  });

  String get fullUrl => '$baseUrl$path';

  ApiEndpoint copyWith({
    String? id,
    String? name,
    String? baseUrl,
    String? path,
    HttpMethod? method,
    String? description,
    List<ApiHeader>? headers,
    String? body,
    String? groupName,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return ApiEndpoint(
      id: id ?? this.id,
      name: name ?? this.name,
      baseUrl: baseUrl ?? this.baseUrl,
      path: path ?? this.path,
      method: method ?? this.method,
      description: description ?? this.description,
      headers: headers ?? this.headers,
      body: body ?? this.body,
      groupName: groupName ?? this.groupName,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }

  Map<String, dynamic> toJson() => {
    'id': id,
    'name': name,
    'baseUrl': baseUrl,
    'path': path,
    'method': method.label,
    'description': description,
    'headers': headers.map((h) => h.toJson()).toList(),
    'body': body,
    'groupName': groupName,
    'createdAt': createdAt.toIso8601String(),
    'updatedAt': updatedAt?.toIso8601String(),
  };

  factory ApiEndpoint.fromJson(Map<String, dynamic> json) => ApiEndpoint(
    id: json['id'] as String,
    name: json['name'] as String,
    baseUrl: json['baseUrl'] as String,
    path: json['path'] as String,
    method: HttpMethod.values.firstWhere(
          (m) => m.label == json['method'],
      orElse: () => HttpMethod.GET,
    ),
    description: json['description'] as String? ?? '',
    headers: (json['headers'] as List? ?? [])
        .map((h) => ApiHeader.fromJson(h as Map<String, dynamic>))
        .toList(),
    body: json['body'] as String? ?? '',
    groupName: json['groupName'] as String? ?? 'Default',
    createdAt: DateTime.parse(json['createdAt'] as String),
    updatedAt: json['updatedAt'] != null
        ? DateTime.parse(json['updatedAt'] as String)
        : null,
  );

  String toJsonString() => jsonEncode(toJson());
}

class ApiResponse {
  final int statusCode;
  final String body;
  final Map<String, String> headers;
  final Duration duration;
  final DateTime timestamp;
  final String endpointId;
  final String endpointName;

  const ApiResponse({
    required this.statusCode,
    required this.body,
    required this.headers,
    required this.duration,
    required this.timestamp,
    required this.endpointId,
    required this.endpointName,
  });

  String get statusText {
    const map = {
      200: 'OK', 201: 'Created', 204: 'No Content',
      301: 'Moved Permanently', 302: 'Found',
      400: 'Bad Request', 401: 'Unauthorized', 403: 'Forbidden',
      404: 'Not Found', 422: 'Unprocessable Entity',
      500: 'Internal Server Error', 502: 'Bad Gateway',
      503: 'Service Unavailable',
    };
    return map[statusCode] ?? 'Unknown';
  }

  String get sizeLabel {
    final bytes = body.length;
    if (bytes < 1024) return '${bytes} B';
    if (bytes < 1024 * 1024) return '${(bytes / 1024).toStringAsFixed(1)} KB';
    return '${(bytes / (1024 * 1024)).toStringAsFixed(1)} MB';
  }

  String get durationLabel {
    final ms = duration.inMilliseconds;
    if (ms < 1000) return '${ms}ms';
    return '${(ms / 1000).toStringAsFixed(1)}s';
  }

  dynamic get parsedBody {
    try {
      return jsonDecode(body);
    } catch (_) {
      return null;
    }
  }

  bool get isJson => parsedBody != null;

  Map<String, dynamic> toJson() => {
    'statusCode': statusCode,
    'body': body,
    'headers': headers,
    'durationMs': duration.inMilliseconds,
    'timestamp': timestamp.toIso8601String(),
    'endpointId': endpointId,
    'endpointName': endpointName,
  };

  factory ApiResponse.fromJson(Map<String, dynamic> json) => ApiResponse(
    statusCode: json['statusCode'] as int,
    body: json['body'] as String,
    headers: Map<String, String>.from(json['headers'] as Map),
    duration: Duration(milliseconds: json['durationMs'] as int),
    timestamp: DateTime.parse(json['timestamp'] as String),
    endpointId: json['endpointId'] as String,
    endpointName: json['endpointName'] as String,
  );
}