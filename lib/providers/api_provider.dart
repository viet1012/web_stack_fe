import 'package:flutter/foundation.dart';
import 'package:uuid/uuid.dart';
import '../models/api_endpoint.dart';
import '../services/storage_service.dart';
import '../services/api_runner_service.dart';

class ApiProvider extends ChangeNotifier {
  List<ApiEndpoint> _endpoints = [];
  List<ApiResponse> _history = [];
  ApiResponse? _lastResponse;
  bool _isLoading = false;
  bool _isRunning = false;
  String _searchQuery = '';
  String? _activeGroup;

  static const _uuid = Uuid();

  // ── Getters ──────────────────────────────────────────────────────────

  List<ApiEndpoint> get endpoints {
    var list = List<ApiEndpoint>.from(_endpoints);
    if (_activeGroup != null) {
      list = list.where((e) => e.groupName == _activeGroup).toList();
    }
    if (_searchQuery.isNotEmpty) {
      final q = _searchQuery.toLowerCase();
      list = list
          .where(
            (e) =>
                e.name.toLowerCase().contains(q) ||
                e.path.toLowerCase().contains(q) ||
                e.baseUrl.toLowerCase().contains(q) ||
                e.description.toLowerCase().contains(q),
          )
          .toList();
    }
    return list;
  }

  List<ApiResponse> get history => List.unmodifiable(_history);
  ApiResponse? get lastResponse => _lastResponse;
  bool get isLoading => _isLoading;
  bool get isRunning => _isRunning;
  String get searchQuery => _searchQuery;
  String? get activeGroup => _activeGroup;

  List<String> get groups {
    final set = <String>{};
    for (final e in _endpoints) {
      set.add(e.groupName);
    }
    return set.toList()..sort();
  }

  // ── Init ─────────────────────────────────────────────────────────────

  Future<void> load() async {
    _isLoading = true;
    notifyListeners();
    _endpoints = await StorageService.instance.loadEndpoints();
    _history = await StorageService.instance.loadHistory();
    _isLoading = false;
    notifyListeners();
  }

  // ── Filtering ─────────────────────────────────────────────────────────

  void setSearch(String query) {
    _searchQuery = query;
    notifyListeners();
  }

  void setGroup(String? group) {
    _activeGroup = group;
    notifyListeners();
  }

  // ── CRUD ─────────────────────────────────────────────────────────────

  Future<void> add(ApiEndpoint endpoint) async {
    final e = endpoint.copyWith(id: _uuid.v4(), createdAt: DateTime.now());
    _endpoints.add(e);
    await _persistEndpoints();
  }

  Future<void> update(ApiEndpoint endpoint) async {
    final idx = _endpoints.indexWhere((e) => e.id == endpoint.id);
    if (idx == -1) return;
    _endpoints[idx] = endpoint.copyWith(updatedAt: DateTime.now());
    await _persistEndpoints();
  }

  Future<void> remove(String id) async {
    _endpoints.removeWhere((e) => e.id == id);
    await _persistEndpoints();
  }

  // ── Run ───────────────────────────────────────────────────────────────

  Future<ApiResponse?> run(ApiEndpoint endpoint) async {
    _isRunning = true;
    _lastResponse = null;
    notifyListeners();

    try {
      final response = await ApiRunnerService.instance.run(endpoint);
      _lastResponse = response;
      _history.insert(0, response);
      if (_history.length > 50) _history = _history.take(50).toList();
      await StorageService.instance.addHistory(response);
      return response;
    } finally {
      _isRunning = false;
      notifyListeners();
    }
  }

  Future<void> clearHistory() async {
    _history.clear();
    await StorageService.instance.clearHistory();
    notifyListeners();
  }

  // ── Helpers ───────────────────────────────────────────────────────────

  Future<void> _persistEndpoints() async {
    await StorageService.instance.saveEndpoints(_endpoints);
    notifyListeners();
  }

  ApiEndpoint? getById(String id) {
    try {
      return _endpoints.firstWhere((e) => e.id == id);
    } catch (_) {
      return null;
    }
  }
}
