import 'dart:convert';
import 'dart:math' as math;

import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'website_service.dart';

/// unknown  = chưa check / request lỗi / BE không trả url này (xám "Not checked")
/// offline  = CHỈ khi BE trả online == false
enum SiteState { unknown, checking, online, authRequired, offline }

@immutable
class SiteStatus {
  final SiteState state;
  final int? latencyMs;
  final DateTime? lastCheck;

  /// Lần cuối BE trả online == true. null → không hiện "last seen".
  final DateTime? lastSeen;

  const SiteStatus({
    required this.state,
    this.latencyMs,
    this.lastCheck,
    this.lastSeen,
  });

  bool get isOnline => state == SiteState.online;
  bool get isAuthRequired => state == SiteState.authRequired;
  bool get isOffline => state == SiteState.offline;
  bool get isChecking => state == SiteState.checking;
  bool get isUnknown => state == SiteState.unknown;

  /// Online hoặc cần đăng nhập (site vẫn sống) → tính là online khi đếm/lọc.
  bool get isReachable => isOnline || isAuthRequired;
}

/// Trạng thái từng URL nằm trong 1 ValueNotifier riêng → card tự update
/// tại chỗ, không rebuild cả grid. Key = normUrl(url) ở mọi nơi.
/// [runVersion] chỉ tăng khi 1 lượt check kết thúc (dùng để re-sort/filter).
class StatusStore extends ChangeNotifier {
  static const _lastSeenKey = 'dash.lastSeen.v2';
  static const concurrency = 6;

  final Map<String, ValueNotifier<SiteStatus>> _items = {};
  final Map<String, DateTime> _lastSeen = {};
  final ValueNotifier<int> runVersion = ValueNotifier(0);

  bool running = false;
  DateTime? lastRun;
  int _generation = 0;

  ValueNotifier<SiteStatus> of(String url) {
    final key = normUrl(url);
    return _items.putIfAbsent(
      key,
      () => ValueNotifier(
        SiteStatus(state: SiteState.unknown, lastSeen: _lastSeen[key]),
      ),
    );
  }

  SiteStatus get(String url) => of(url).value;

  Future<void> loadLastSeen() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final raw = prefs.getString(_lastSeenKey);
      if (raw == null) return;
      final map = Map<String, dynamic>.from(jsonDecode(raw));
      map.forEach((url, ms) {
        _lastSeen[normUrl(url)] = DateTime.fromMillisecondsSinceEpoch(ms as int);
      });
    } catch (_) {}
  }

  Future<void> _saveLastSeen() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(
        _lastSeenKey,
        jsonEncode(
          _lastSeen.map((k, v) => MapEntry(k, v.millisecondsSinceEpoch)),
        ),
      );
    } catch (_) {}
  }

  void _apply(String key, StatusResult? r, DateTime now) {
    final old = of(key).value;

    // Lỗi request / thiếu trong response / online == null → unknown.
    if (r == null || r.online == null) {
      of(key).value = SiteStatus(
        state: SiteState.unknown,
        lastCheck: now,
        lastSeen: _lastSeen[key],
      );
      return;
    }

    final online = r.online!;
    if (online) _lastSeen[key] = now;

    of(key).value = SiteStatus(
      state: !online
          ? SiteState.offline
          : (r.authRequired ? SiteState.authRequired : SiteState.online),
      latencyMs: online ? r.latencyMs : null,
      lastCheck: now,
      lastSeen: _lastSeen[key] ?? old.lastSeen,
    );
  }

  /// POST /check-status mỗi URL (body = [url]), song song tối đa [concurrency].
  /// [markChecking]: refresh tay → hiện "Checking…" cho tất cả;
  /// auto-refresh → giữ trạng thái cũ, chỉ cập nhật khi có kết quả.
  Future<void> probeAll(
    Iterable<String> urls, {
    bool markChecking = true,
  }) async {
    final originals = <String, String>{};
    for (final u in urls) {
      final t = u.trim();
      if (t.isNotEmpty) originals.putIfAbsent(normUrl(t), () => t);
    }
    final keys = originals.keys.toList();
    final generation = ++_generation;

    if (markChecking) {
      for (final key in keys) {
        final old = of(key).value;
        of(key).value = SiteStatus(
          state: SiteState.checking,
          latencyMs: old.latencyMs,
          lastCheck: old.lastCheck,
          lastSeen: old.lastSeen,
        );
      }
    }

    running = true;
    notifyListeners();

    var next = 0;

    Future<void> worker() async {
      while (next < keys.length) {
        final key = keys[next++];
        StatusResult? r;
        try {
          final res = await WebsiteService.checkStatusBatch([originals[key]!]);
          r = res[key];
        } catch (e) {
          debugPrint('[check-status] $key failed: $e');
        }
        if (generation != _generation) return;
        _apply(key, r, DateTime.now());
        notifyListeners();
      }
    }

    await Future.wait(
      List.generate(math.min(concurrency, keys.length), (_) => worker()),
    );

    if (generation != _generation) return;

    running = false;
    lastRun = DateTime.now();
    runVersion.value++;
    notifyListeners();
    _saveLastSeen();
  }

  void retain(Set<String> urls) {
    final keep = urls.map(normUrl).toSet();
    _items.removeWhere((key, _) => !keep.contains(key));
  }

  @override
  void dispose() {
    _generation++;
    for (final n in _items.values) {
      n.dispose();
    }
    runVersion.dispose();
    super.dispose();
  }
}
