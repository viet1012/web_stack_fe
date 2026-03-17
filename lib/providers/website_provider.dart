import 'package:flutter/foundation.dart';
import 'package:uuid/uuid.dart';
import '../models/website.dart';
import '../services/storage_service.dart';

class WebsiteProvider extends ChangeNotifier {
  List<Website> _websites = [];
  String _searchQuery = '';
  bool _isLoading = false;

  static const _uuid = Uuid();

  List<Website> get websites {
    if (_searchQuery.isEmpty) return List.unmodifiable(_websites);
    final q = _searchQuery.toLowerCase();
    return _websites
        .where(
          (w) =>
              w.name.toLowerCase().contains(q) ||
              w.url.toLowerCase().contains(q) ||
              w.tags.any((t) => t.toLowerCase().contains(q)),
        )
        .toList();
  }

  bool get isLoading => _isLoading;
  String get searchQuery => _searchQuery;

  int get onlineCount => _websites.where((w) => w.isOnline).length;

  Future<void> load() async {
    _isLoading = true;
    notifyListeners();
    _websites = await StorageService.instance.loadWebsites();
    _isLoading = false;
    notifyListeners();
  }

  void setSearch(String query) {
    _searchQuery = query;
    notifyListeners();
  }

  Future<void> add(Website website) async {
    final w = website.copyWith(id: _uuid.v4(), createdAt: DateTime.now());
    _websites.add(w);
    await _persist();
  }

  Future<void> update(Website website) async {
    final idx = _websites.indexWhere((w) => w.id == website.id);
    if (idx == -1) return;
    _websites[idx] = website.copyWith(updatedAt: DateTime.now());
    await _persist();
  }

  Future<void> remove(String id) async {
    _websites.removeWhere((w) => w.id == id);
    await _persist();
  }

  Future<void> toggleOnline(String id) async {
    final idx = _websites.indexWhere((w) => w.id == id);
    if (idx == -1) return;
    _websites[idx] = _websites[idx].copyWith(
      isOnline: !_websites[idx].isOnline,
    );
    await _persist();
  }

  Future<void> _persist() async {
    await StorageService.instance.saveWebsites(_websites);
    notifyListeners();
  }

  Website? getById(String id) {
    try {
      return _websites.firstWhere((w) => w.id == id);
    } catch (_) {
      return null;
    }
  }
}
