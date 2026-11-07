import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

import '../core/env.dart';
import 'package:liferadar_core/liferadar_core.dart';

/// 공식 교통 영향 목록 (`traffic.json`, GitHub Actions가 3시간마다 갱신).
class TrafficFeed {
  const TrafficFeed({this.notices = const [], this.generatedAt});

  static const empty = TrafficFeed();

  final List<TrafficNotice> notices;
  final DateTime? generatedAt;

  static TrafficFeed parse(String raw) {
    final j = jsonDecode(raw) as Map<String, dynamic>;
    final notices = <TrafficNotice>[];
    for (final n in (j['notices'] as List? ?? const [])) {
      try {
        notices.add(TrafficNotice.fromJson((n as Map).cast<String, dynamic>()));
      } catch (_) {
        // 깨진 항목 하나가 전체 목록을 멈추지 않게 한다.
      }
    }
    return TrafficFeed(notices: notices, generatedAt: DateTime.tryParse(j['generatedAt'] as String? ?? ''));
  }

  /// [now] 기준 아직 끝나지 않은 공지.
  List<TrafficNotice> activeAt(DateTime now) => [
        for (final n in notices)
          if (n.end == null ? !n.start.isBefore(DateTime(now.year, now.month, now.day)) : n.end!.isAfter(now)) n,
      ];
}

abstract final class LiveTraffic {
  static const prefsKey = 'traffic_feed_cache';

  static TrafficFeed cached(SharedPreferences prefs) {
    final raw = prefs.getString(prefsKey);
    if (raw == null) return TrafficFeed.empty;
    try {
      return TrafficFeed.parse(raw);
    } catch (_) {
      return TrafficFeed.empty;
    }
  }

  /// 더 최신이고 올바르면 반환하고 캐시한다. 빈 목록도 올바른 응답이다
  /// ("현재 공지 없음"). 받지 못하면 기존 정보를 유지한다 — 이는 "영향 없음"을 뜻하지 않는다.
  static Future<TrafficFeed?> fetch(
    SharedPreferences prefs,
    TrafficFeed current, {
    http.Client? client,
    String url = Env.trafficUrl,
  }) async {
    if (url.isEmpty) return null;
    final c = client ?? http.Client();
    try {
      final res = await c.get(Uri.parse(url)).timeout(const Duration(seconds: 20));
      if (res.statusCode != 200) return null;
      final raw = utf8.decode(res.bodyBytes);
      final feed = TrafficFeed.parse(raw);
      final at = feed.generatedAt;
      if (at == null || (current.generatedAt != null && !at.isAfter(current.generatedAt!))) return null;
      await prefs.setString(prefsKey, raw);
      return feed;
    } catch (e) {
      debugPrint('LiveTraffic: $e');
      return null;
    } finally {
      if (client == null) c.close();
    }
  }
}
