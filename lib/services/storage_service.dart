import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/website.dart';
import '../models/api_endpoint.dart';

class StorageService {
  static const _websitesKey = 'dm_websites';
  static const _endpointsKey = 'dm_endpoints';
  static const _historyKey = 'dm_history';

  static StorageService? _instance;
  static StorageService get instance => _instance ??= StorageService._();
  StorageService._();

  SharedPreferences? _prefs;

  Future<void> init() async {
    _prefs = await SharedPreferences.getInstance();
  }

  // ── Websites ──────────────────────────────────────────────────────────

  Future<List<Website>> loadWebsites() async {
    final raw = _prefs?.getString(_websitesKey);
    if (raw == null) return _defaultWebsites();
    try {
      final list = jsonDecode(raw) as List;
      return list
          .map((e) => Website.fromJson(e as Map<String, dynamic>))
          .toList();
    } catch (_) {
      return _defaultWebsites();
    }
  }

  Future<void> saveWebsites(List<Website> websites) async {
    final json = jsonEncode(websites.map((w) => w.toJson()).toList());
    await _prefs?.setString(_websitesKey, json);
  }

  // ── Endpoints ─────────────────────────────────────────────────────────

  Future<List<ApiEndpoint>> loadEndpoints() async {
    final raw = _prefs?.getString(_endpointsKey);
    if (raw == null) return _defaultEndpoints();
    try {
      final list = jsonDecode(raw) as List;
      return list
          .map((e) => ApiEndpoint.fromJson(e as Map<String, dynamic>))
          .toList();
    } catch (_) {
      return _defaultEndpoints();
    }
  }

  Future<void> saveEndpoints(List<ApiEndpoint> endpoints) async {
    final json = jsonEncode(endpoints.map((e) => e.toJson()).toList());
    await _prefs?.setString(_endpointsKey, json);
  }

  // ── Response History ──────────────────────────────────────────────────

  Future<List<ApiResponse>> loadHistory() async {
    final raw = _prefs?.getString(_historyKey);
    if (raw == null) return [];
    try {
      final list = jsonDecode(raw) as List;
      return list
          .map((e) => ApiResponse.fromJson(e as Map<String, dynamic>))
          .toList()
        ..sort((a, b) => b.timestamp.compareTo(a.timestamp));
    } catch (_) {
      return [];
    }
  }

  Future<void> addHistory(ApiResponse response) async {
    final current = await loadHistory();
    current.insert(0, response);
    // Keep only last 50
    final trimmed = current.take(50).toList();
    final json = jsonEncode(trimmed.map((r) => r.toJson()).toList());
    await _prefs?.setString(_historyKey, json);
  }

  Future<void> clearHistory() async {
    await _prefs?.remove(_historyKey);
  }

  // ── Default seed data ─────────────────────────────────────────────────

  List<Website> _defaultWebsites() => [
    Website(
      id: 'w1',
      name: 'HeatGuide Dashboard',
      url: 'http://192.168.122.15:5000/',
      description: 'Internal admin panel',
      emoji: '🔥', // nhiệt / heat
      tags: ['production', 'Flutter'],
      isOnline: true,
      createdAt: DateTime.now(),
    ),
    Website(
      id: 'w2',
      name: 'Cost Monitoring',
      url: 'http://192.168.122.15:5001/',
      description: 'Internal admin panel',
      emoji: '💰', // tiền / cost
      tags: ['production', 'Flutter'],
      isOnline: true,
      createdAt: DateTime.now(),
    ),
    Website(
      id: 'w3',
      name: 'MA Monitoring',
      url: 'http://192.168.122.15:5002/',
      description: 'Internal admin panel',
      emoji: '📈', // monitoring / growth
      tags: ['production', 'Flutter'],
      isOnline: true,
      createdAt: DateTime.now(),
    ),
    Website(
      id: 'w4',
      name: 'Molybden Dashboard',
      url: 'http://192.168.122.15:5004/',
      description: 'Internal admin panel',
      emoji: '⚙️', // kim loại / machine
      tags: ['production', 'Flutter'],
      isOnline: true,
      createdAt: DateTime.now(),
    ),
    Website(
      id: 'w5',
      name: 'Packing PO Monitoring',
      url: 'http://192.168.122.16:5004/',
      description: 'Internal admin panel',
      emoji: '📦', // đóng gói
      tags: ['production', 'Flutter'],
      isOnline: true,
      createdAt: DateTime.now(),
    ),
    Website(
      id: 'w6',
      name: 'S-PATROL',
      url: 'https://spcspatrol-misumig.msappproxy.net/',
      description: 'Internal admin panel',
      emoji: '🛡️', // patrol / bảo vệ
      tags: ['production', 'Flutter'],
      isOnline: true,
      createdAt: DateTime.now(),
    ),
  ];

  List<ApiEndpoint> _defaultEndpoints() => [
    ApiEndpoint(
      id: 'a1',
      name: 'Get All Users',
      baseUrl: 'https://api.mycompany.com',
      path: '/api/v1/users',
      method: HttpMethod.GET,
      description: 'Fetch paginated user list',
      headers: [
        const ApiHeader(key: 'Authorization', value: 'Bearer {{TOKEN}}'),
        const ApiHeader(key: 'Content-Type', value: 'application/json'),
      ],
      groupName: 'Users',
      createdAt: DateTime.now(),
    ),
    ApiEndpoint(
      id: 'a2',
      name: 'Create Order',
      baseUrl: 'https://api.mycompany.com',
      path: '/api/v1/orders',
      method: HttpMethod.POST,
      description: 'Create a new order',
      headers: [
        const ApiHeader(key: 'Authorization', value: 'Bearer {{TOKEN}}'),
        const ApiHeader(key: 'Content-Type', value: 'application/json'),
      ],
      body: '{\n  "userId": 1,\n  "items": [],\n  "total": 0\n}',
      groupName: 'Orders',
      createdAt: DateTime.now(),
    ),
    ApiEndpoint(
      id: 'a3',
      name: 'Update Product',
      baseUrl: 'https://api.mycompany.com',
      path: '/api/v1/products/{id}',
      method: HttpMethod.PUT,
      description: 'Update product by ID',
      headers: [
        const ApiHeader(key: 'Authorization', value: 'Bearer {{TOKEN}}'),
        const ApiHeader(key: 'Content-Type', value: 'application/json'),
      ],
      groupName: 'Products',
      createdAt: DateTime.now(),
    ),
    ApiEndpoint(
      id: 'a4',
      name: 'Delete User',
      baseUrl: 'https://api.mycompany.com',
      path: '/api/v1/users/{id}',
      method: HttpMethod.DELETE,
      description: 'Admin only – delete a user',
      headers: [
        const ApiHeader(key: 'Authorization', value: 'Bearer {{TOKEN}}'),
      ],
      groupName: 'Users',
      createdAt: DateTime.now(),
    ),
  ];
}
