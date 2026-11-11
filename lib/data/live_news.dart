import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:liferadar_core/liferadar_core.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../core/env.dart';

/// 뉴스에서 판독한 대중교통 파업 (`news.json`). 공식 공지가 아니므로 홈에는 참고 카드로만 나온다.
class NewsFeed {
  const NewsFeed({this.strikes = const [], this.generatedAt, this.trafficImpacts = const [], this.extractionFailures = const [], this.transportReferences = const []});

  static const empty = NewsFeed();

  final List<TransitStrike> strikes;
  final DateTime? generatedAt;
  final List<NewsTrafficImpact> trafficImpacts;
  final List<Map<String, dynamic>> extractionFailures;
  final List<TrafficReference> transportReferences;

  static NewsFeed parse(String raw) {
    final j = jsonDecode(raw) as Map<String, dynamic>;
    final strikes = <TransitStrike>[];
    for (final s in (j['strikes'] as List? ?? const [])) {
      try {
        strikes.add(TransitStrike.fromJson((s as Map).cast<String, dynamic>()));
      } catch (_) {
        // 깨진 항목 하나가 전체를 멈추지 않게 한다.
      }
    }
    return NewsFeed(
      strikes: strikes,
      generatedAt: DateTime.tryParse(j['generatedAt'] as String? ?? ''),
      trafficImpacts: [
        if (j['newsTrafficSchemaVersion'] == '1.0')
          for (final row in j['trafficImpacts'] as List? ?? const [])
            // Malformed verified records reject the update as a whole. Keeping
            // the old cache prevents a bad item from silently removing warnings.
            NewsTrafficImpact.fromJson((row as Map).cast<String, dynamic>()),
      ],
      extractionFailures: [for (final row in j['extractionFailures'] as List? ?? const []) (row as Map).cast<String, dynamic>()],
      transportReferences: [for (final row in j['transportReferences'] as List? ?? const []) TrafficReference.fromJson((row as Map).cast<String, dynamic>())],
    );
  }

  /// 앞으로 이동에 영향을 줄 수 있는 파업만 (예고·조건부·진행 중).
  List<TransitStrike> get active => [
    for (final s in strikes)
      if (s.isActive) s,
  ];
}

abstract final class LiveNews {
  static const prefsKey = 'news_feed_cache';

  static NewsFeed cached(SharedPreferences prefs) {
    final raw = prefs.getString(prefsKey);
    if (raw == null) return NewsFeed.empty;
    try {
      return NewsFeed.parse(raw);
    } catch (_) {
      return NewsFeed.empty;
    }
  }

  /// 더 최신이면 반환하고 캐시한다. 받지 못하면 null — 이전 캐시를 그대로 쓴다.
  static Future<NewsFeed?> fetch(
    SharedPreferences prefs,
    NewsFeed current, {
    http.Client? client,
    String url = Env.newsUrl,
  }) async {
    if (url.isEmpty) return null;
    final c = client ?? http.Client();
    try {
      final res = await c
          .get(Uri.parse(url))
          .timeout(const Duration(seconds: 20));
      if (res.statusCode != 200) return null;
      final raw = utf8.decode(res.bodyBytes);
      final feed = NewsFeed.parse(raw);
      final at = feed.generatedAt;
      if (at == null) return null;
      if (current.generatedAt != null && !at.isAfter(current.generatedAt!)) {
        return null;
      }
      await prefs.setString(prefsKey, raw);
      return feed;
    } catch (e) {
      debugPrint('LiveNews: $e');
      return null;
    } finally {
      if (client == null) c.close();
    }
  }
}
