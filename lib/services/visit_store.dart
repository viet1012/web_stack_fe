import 'dart:convert';
import 'dart:html' as html;

import 'package:flutter/foundation.dart';

/// Lượt mở site, lưu localStorage `itpro.visits` = {siteId: [timestamps ms]}.
/// Chỉ giữ 30 ngày gần nhất.
class VisitStore extends ChangeNotifier {
  static const _key = 'itpro.visits';
  static const _keep = Duration(days: 30);

  final Map<String, List<int>> _visits = {};

  void load() {
    try {
      final raw = html.window.localStorage[_key];
      if (raw == null || raw.isEmpty) return;
      final map = jsonDecode(raw);
      if (map is! Map) return;
      map.forEach((k, v) {
        if (v is List) {
          _visits['$k'] = v.whereType<num>().map((e) => e.toInt()).toList();
        }
      });
      if (_prune()) _save();
    } catch (_) {}
  }

  int count(int siteId) => _visits['$siteId']?.length ?? 0;

  bool get isEmpty => _visits.isEmpty;

  void record(int siteId) {
    _visits.putIfAbsent('$siteId', () => []).add(
          DateTime.now().millisecondsSinceEpoch,
        );
    _prune();
    _save();
    notifyListeners();
  }

  /// Xoá toàn bộ lượt mở của [siteId] (gỡ khỏi Frequently visited).
  void forget(int siteId) {
    if (_visits.remove('$siteId') == null) return;
    _save();
    notifyListeners();
  }

  bool _prune() {
    final cutoff = DateTime.now().subtract(_keep).millisecondsSinceEpoch;
    var changed = false;
    _visits.removeWhere((_, list) {
      final before = list.length;
      list.removeWhere((t) => t < cutoff);
      if (list.length != before) changed = true;
      return list.isEmpty;
    });
    return changed;
  }

  void _save() {
    try {
      html.window.localStorage[_key] = jsonEncode(_visits);
    } catch (_) {}
  }
}
