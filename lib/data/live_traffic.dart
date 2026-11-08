import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

import '../core/env.dart';
import 'package:liferadar_core/liferadar_core.dart';

/// 공식 교통 영향 목록.
/// - [notices]: BE가 3시간마다 게시하는 `traffic.json` (서울 TOPIS)
/// - [its]: 앱이 기기에서 직접 조회한 국가교통정보센터 전국 돌발상황 (해외 서버에서는 차단됨)
class TrafficFeed {
  const TrafficFeed({this.notices = const [], this.generatedAt, this.its = const [], this.itsFetchedAt});

  static const empty = TrafficFeed();

  final List<TrafficNotice> notices;
  final DateTime? generatedAt;
  final List<TrafficNotice> its;
  final DateTime? itsFetchedAt;

  TrafficFeed copyWith({TrafficFeed? feed, List<TrafficNotice>? its, DateTime? itsFetchedAt}) => TrafficFeed(
        notices: feed?.notices ?? notices,
        generatedAt: feed?.generatedAt ?? generatedAt,
        its: its ?? this.its,
        itsFetchedAt: itsFetchedAt ?? this.itsFetchedAt,
      );

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

  /// [now] 기준으로 보여줄 공지 (두 출처 합침, id 중복 제거). 기준은 수집기와 같은
  /// [TrafficNotice.isRelevantAt].
  List<TrafficNotice> activeAt(DateTime now) => {
        for (final n in [...notices, ...its])
          if (n.isRelevantAt(now)) n.id: n,
      }.values.toList();
}

abstract final class LiveTraffic {
  static const prefsKey = 'traffic_feed_cache';

  static const itsPrefsKey = 'its_traffic_cache';

  static TrafficFeed cached(SharedPreferences prefs) {
    var feed = TrafficFeed.empty;
    final raw = prefs.getString(prefsKey);
    if (raw != null) {
      try {
        feed = TrafficFeed.parse(raw);
      } catch (_) {}
    }
    final itsRaw = prefs.getString(itsPrefsKey);
    if (itsRaw != null) {
      try {
        final j = jsonDecode(itsRaw) as Map<String, dynamic>;
        feed = feed.copyWith(
          its: [for (final n in j['notices'] as List) TrafficNotice.fromJson((n as Map).cast<String, dynamic>())],
          itsFetchedAt: DateTime.tryParse(j['fetchedAt'] as String? ?? ''),
        );
      } catch (_) {}
    }
    return feed;
  }

  /// 국가교통정보센터 전국 돌발상황을 기기에서 직접 조회한다. 성공하면 현재 유효한 공지만
  /// 캐시하고 반환하며, 실패(키 없음·오프라인·오류)하면 null — 이전 캐시를 그대로 쓴다.
  static Future<List<TrafficNotice>?> fetchIts(
    SharedPreferences prefs, {
    http.Client? client,
    String key = Env.itsApiKey,
    DateTime? now,
  }) async {
    if (key.isEmpty) return null;
    final c = client ?? http.Client();
    final at = now ?? DateTime.now();
    try {
      final res = await c.get(ItsTraffic.uri(key)).timeout(const Duration(seconds: 20));
      if (res.statusCode != 200) return null;
      final rows = ItsTraffic.rows(jsonDecode(utf8.decode(res.bodyBytes)) as Map<String, dynamic>);
      final notices = [for (final r in rows) ?ItsTraffic.parse(r)].where((n) => n.isRelevantAt(at)).toList();
      await prefs.setString(
        itsPrefsKey,
        jsonEncode({'fetchedAt': at.toUtc().toIso8601String(), 'notices': [for (final n in notices) n.toJson()]}),
      );
      return notices;
    } catch (e) {
      debugPrint('LiveTraffic ITS: $e');
      return null;
    } finally {
      if (client == null) c.close();
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
