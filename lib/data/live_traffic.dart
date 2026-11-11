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
  const TrafficFeed({
    this.notices = const [],
    this.generatedAt,
    this.its = const [],
    this.itsFetchedAt,
    this.schemaVersion = 1,
    this.sourceStates = const {},
    this.withdrawals = const [],
  });

  static const empty = TrafficFeed();

  final List<TrafficWithdrawal> withdrawals;
  final int schemaVersion;
  final Map<String, dynamic> sourceStates;
  final List<TrafficNotice> notices;
  final DateTime? generatedAt;
  final List<TrafficNotice> its;
  final DateTime? itsFetchedAt;

  TrafficFeed copyWith({TrafficFeed? feed, List<TrafficNotice>? its, DateTime? itsFetchedAt}) => TrafficFeed(
    notices: feed?.notices ?? notices,
    withdrawals: feed?.withdrawals ?? withdrawals,
    schemaVersion: feed?.schemaVersion ?? schemaVersion,
    sourceStates: feed?.sourceStates ?? sourceStates,
    generatedAt: feed?.generatedAt ?? generatedAt,
    its: its ?? this.its,
    itsFetchedAt: itsFetchedAt ?? this.itsFetchedAt,
  );

  static TrafficFeed parse(String raw) {
    final j = jsonDecode(raw) as Map<String, dynamic>;
    final schema = j['schemaVersion'] ?? 1;
    if (schema != 1 && schema != 2) throw const FormatException('Unsupported traffic schema');
    if (j['notices'] is! List || (schema == 2 && (j['sourceStates'] is! Map || j['sources'] is! List))) {
      throw const FormatException('Incomplete traffic envelope');
    }
    final notices = <TrafficNotice>[];
    for (final n in (j['notices'] as List? ?? const [])) {
      try {
        final notice = TrafficNotice.fromJson((n as Map).cast<String, dynamic>());
        if (schema == 2 && notice.lastSeenAt == null) continue;
        notices.add(notice);
      } catch (_) {
        // 깨진 항목 하나가 전체 목록을 멈추지 않게 한다.
      }
    }
    return TrafficFeed(
      notices: notices,
      withdrawals: [
        for (final w in (j['withdrawals'] as List? ?? const []))
          TrafficWithdrawal.fromJson((w as Map).cast<String, dynamic>()),
      ],
      schemaVersion: schema as int,
      sourceStates: (j['sourceStates'] as Map? ?? {}).cast<String, dynamic>(),
      generatedAt: j['generatedAt'] == null ? null : trafficInstant(j['generatedAt'] as String),
    );
  }

  Map<String, dynamic> sourceStatesAt(DateTime now) => {
    for (final e in sourceStates.entries.where((e) => e.value is Map))
      e.key: () {
        final state = (e.value as Map).cast<String, dynamic>();
        if (state['status'] == 'disabled') return state;
        DateTime? seen;
        try {
          seen = state['lastSuccessAt'] is String ? trafficInstant(state['lastSuccessAt'] as String) : null;
        } catch (_) {}
        final maxAge = Duration(hours: e.key == 'utic' ? 6 : 24);
        return {
          ...state,
          if (seen == null || seen.isAfter(trafficUtc(now)) || trafficUtc(now).difference(seen) > maxAge)
            'status': 'unavailable',
        };
      }(),
  };

  /// [now] 기준으로 보여줄 공지 (두 출처 합침, id 중복 제거). 기준은 수집기와 같은
  /// [TrafficNotice.isRelevantAt].
  List<TrafficNotice> activeAt(DateTime now) =>
      TrafficMerger.merge([...notices, ...its], now: now, withdrawals: withdrawals).where((n) {
        if (!n.isRelevantAt(now)) return false;
        // UTIC has the stricter shared 6h TTL. Existing sources retain the 3h cadence
        // with a bounded 24h offline fallback; publishing never refreshes this clock.
        if (n.source == 'utic') return true;
        final seen = n.lastSeenAt ?? (n.source == 'its' ? itsFetchedAt : null);
        return seen == null ||
            (!trafficUtc(seen).isAfter(trafficUtc(now)) &&
                trafficUtc(now).difference(trafficUtc(seen)) <= const Duration(hours: 24));
      }).toList();
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
    final at = trafficUtc(now ?? DateTime.now().toUtc());
    try {
      final res = await c.get(ItsTraffic.uri(key)).timeout(const Duration(seconds: 20));
      if (res.statusCode != 200) return null;
      final payload = jsonDecode(utf8.decode(res.bodyBytes)) as Map<String, dynamic>;
      final rows = ItsTraffic.rows(payload);
      if (!ItsTraffic.isComplete(payload)) return null;
      final notices = [for (final r in rows) ?ItsTraffic.parse(r)]
          .where((n) => n.isRelevantAt(at))
          .map((n) => n.withMetadata({'fetchedAt': at.toIso8601String(), 'lastSeenAt': at.toIso8601String()}))
          .toList();
      await prefs.setString(
        itsPrefsKey,
        jsonEncode({
          'fetchedAt': at.toUtc().toIso8601String(),
          'notices': [for (final n in notices) n.toJson()],
        }),
      );
      return notices;
    } catch (e) {
      debugPrint('LiveTraffic ITS: request failed');
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
      var res = await c.get(Uri.parse(url)).timeout(const Duration(seconds: 20));
      // The production data branch may still publish the original contract.
      // Only fall back to the real TOPIS feed, never to bundled/demo notices.
      if (res.statusCode == 404 && url == Env.trafficUrl) {
        res = await c.get(Uri.parse(url.replaceFirst('traffic-v2.json', 'traffic.json')))
            .timeout(const Duration(seconds: 20));
      }
      if (res.statusCode != 200) return null;
      final raw = utf8.decode(res.bodyBytes);
      final feed = TrafficFeed.parse(raw);
      final at = feed.generatedAt;
      if (at == null || (current.generatedAt != null && !at.isAfter(current.generatedAt!))) return null;
      await prefs.setString(prefsKey, raw);
      return feed;
    } catch (e) {
      debugPrint('LiveTraffic: request failed');
      return null;
    } finally {
      if (client == null) c.close();
    }
  }
}
