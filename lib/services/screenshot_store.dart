import 'dart:async';
import 'dart:convert';
import 'dart:html' as html;
import 'dart:math' as math;

import 'package:flutter/foundation.dart';

import 'website_service.dart';

enum ShotState { unknown, ok, loading, blank, offline }

@immutable
class ShotMeta {
  final ShotState state;
  final DateTime? capturedAt;

  /// Raw capturedAt từ BE, dùng nguyên văn làm cache-bust `t=`.
  final Object? capturedRaw;
  final bool hasImage;

  /// Đã poll quá 60s mà vẫn loading → xử lý như blank.
  final bool pollExpired;

  const ShotMeta({
    this.state = ShotState.unknown,
    this.capturedAt,
    this.capturedRaw,
    this.hasImage = false,
    this.pollExpired = false,
  });

  bool get isLoading => state == ShotState.loading && !pollExpired;

  factory ShotMeta.fromJson(Map<String, dynamic> m) {
    final raw = m['capturedAt'];
    DateTime? at;
    if (raw is num) {
      // Java Instant dạng số = epoch giây (có phần thập phân); ms thì > 1e11.
      at = DateTime.fromMillisecondsSinceEpoch(
        raw < 1e11 ? (raw * 1000).round() : raw.toInt(),
      );
    } else if (raw is String) {
      at = DateTime.tryParse(raw)?.toLocal() ??
          (int.tryParse(raw) == null
              ? null
              : DateTime.fromMillisecondsSinceEpoch(int.parse(raw)));
    }

    final state = switch ('${m['state']}'.toLowerCase()) {
      'ok' => ShotState.ok,
      'loading' => ShotState.loading,
      'blank' => ShotState.blank,
      'offline' => ShotState.offline,
      _ => ShotState.unknown,
    };

    return ShotMeta(
      state: state,
      capturedAt: at,
      capturedRaw: raw,
      hasImage: m['hasImage'] == true || state == ShotState.ok,
    );
  }

  ShotMeta expired() => ShotMeta(
        state: state,
        capturedAt: capturedAt,
        capturedRaw: capturedRaw,
        hasImage: hasImage,
        pollExpired: true,
      );
}

/// Meta screenshot từng URL (ValueNotifier riêng → thumbnail update tại chỗ).
/// state == loading → poll /meta mỗi 5s, dừng sau 60s.
///
/// Meta lần trước được lưu localStorage → mở lại trang là hiện NGAY ảnh cũ
/// (cùng `t=` → browser cache), không phải chờ /meta; /meta về thì cập nhật.
class ScreenshotStore {
  static const concurrency = 6;
  static const pollEvery = Duration(seconds: 5);
  static const pollMax = Duration(seconds: 60);
  static const _storageKey = 'itpro.shots';

  final Map<String, ValueNotifier<ShotMeta>> _items = {};
  final Map<String, Timer> _polls = {};
  final Map<String, Map<String, dynamic>> _saved = _load();
  Timer? _saveTimer;
  bool _disposed = false;

  ValueNotifier<ShotMeta> of(String url) => _items.putIfAbsent(url, () {
        final cached = _saved[url];
        if (cached == null) return ValueNotifier(const ShotMeta());
        // Chỉ dùng cache để hiện ảnh cũ; không coi là "loading" để tránh skeleton.
        final m = ShotMeta.fromJson(cached);
        return ValueNotifier(
          m.hasImage
              ? ShotMeta(
                  state: ShotState.ok,
                  capturedAt: m.capturedAt,
                  capturedRaw: m.capturedRaw,
                  hasImage: true,
                )
              : const ShotMeta(),
        );
      });

  static Map<String, Map<String, dynamic>> _load() {
    try {
      final raw = html.window.localStorage[_storageKey];
      if (raw == null) return {};
      final m = jsonDecode(raw) as Map;
      return {
        for (final e in m.entries)
          if (e.value is Map) '${e.key}': Map<String, dynamic>.from(e.value),
      };
    } catch (_) {
      return {};
    }
  }

  void _remember(String url, Map<String, dynamic> json) {
    // Chỉ nhớ khi có ảnh; ảnh mất (hasImage=false) → xoá khỏi cache.
    if (json['hasImage'] == true || '${json['state']}' == 'ok') {
      _saved[url] = {
        'state': json['state'],
        'capturedAt': json['capturedAt'],
        'hasImage': true,
      };
    } else {
      _saved.remove(url);
    }
    _saveTimer?.cancel();
    _saveTimer = Timer(const Duration(milliseconds: 500), _persist);
  }

  void _persist() {
    try {
      html.window.localStorage[_storageKey] = jsonEncode(_saved);
    } catch (_) {}
  }

  Future<void> fetchAll(Iterable<String> urls) async {
    final list = urls.where((u) => u.trim().isNotEmpty).toSet().toList();
    var next = 0;

    Future<void> worker() async {
      while (next < list.length && !_disposed) {
        await fetchOne(list[next++]);
      }
    }

    await Future.wait(
      List.generate(math.min(concurrency, list.length), (_) => worker()),
    );
  }

  Future<void> fetchOne(String url, {DateTime? pollStart}) async {
    final json = await WebsiteService.fetchScreenshotMeta(url);
    if (_disposed || json == null) return;

    var meta = ShotMeta.fromJson(json);
    final prev = of(url).value;
    // BE đang chụp (loading) mà không báo ảnh → giữ ảnh cũ đã biết.
    if (meta.state == ShotState.loading && !meta.hasImage && prev.hasImage) {
      meta = ShotMeta(
        state: ShotState.loading,
        capturedAt: prev.capturedAt,
        capturedRaw: prev.capturedRaw,
        hasImage: true,
      );
    } else {
      _remember(url, json);
    }
    of(url).value = meta;

    if (meta.state == ShotState.loading) {
      _schedulePoll(url, pollStart ?? DateTime.now());
    } else {
      _polls.remove(url)?.cancel();
    }
  }

  void _schedulePoll(String url, DateTime start) {
    _polls.remove(url)?.cancel();
    if (DateTime.now().difference(start) >= pollMax) {
      of(url).value = of(url).value.expired();
      return;
    }
    _polls[url] = Timer(pollEvery, () {
      _polls.remove(url);
      fetchOne(url, pollStart: start);
    });
  }

  /// POST /refresh (không url = tất cả) rồi đọc lại meta.
  Future<void> refreshAll(Iterable<String> urls) async {
    await WebsiteService.refreshScreenshots();
    if (_disposed) return;
    await fetchAll(urls);
  }

  Future<void> refreshOne(String url) async {
    await WebsiteService.refreshScreenshots(url: url);
    if (_disposed) return;
    await fetchOne(url);
  }

  void retain(Set<String> urls) {
    _items.removeWhere((url, _) => !urls.contains(url));
    final before = _saved.length;
    _saved.removeWhere((url, _) => !urls.contains(url));
    if (_saved.length != before) _persist();
    _polls.removeWhere((url, t) {
      if (urls.contains(url)) return false;
      t.cancel();
      return true;
    });
  }

  void dispose() {
    _disposed = true;
    if (_saveTimer?.isActive ?? false) {
      _saveTimer!.cancel();
      _persist();
    }
    for (final t in _polls.values) {
      t.cancel();
    }
    _polls.clear();
    for (final n in _items.values) {
      n.dispose();
    }
  }
}
