import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart' show AssetBundle;
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

import '../core/env.dart';
import 'event_feed.dart';

/// 실제 행사를 최신으로 유지하는 방법:
/// 1) 앱은 APK에 포함된(또는 이전에 받아 캐시된) 피드로 즉시 열린다 — 오프라인에서도;
/// 2) 이후 [Env.eventsUrl]에서 최신 `events.json`을 받는다 (GitHub Actions가 매일 갱신);
/// 3) 새 피드를 검증하고 더 최신이면 화면에 반영하고 캐시에 저장한다.
abstract final class LiveEvents {
  static const prefsKey = 'events_feed_cache';

  /// main()에서: 에셋과 캐시 중 더 최신인 것.
  static Future<EventFeed> initial(SharedPreferences prefs, {AssetBundle? bundle}) async {
    final bundled = await EventFeed.load(bundle);
    final raw = prefs.getString(prefsKey);
    if (raw == null) return bundled;
    try {
      return EventFeed.newest(bundled, await EventFeed.parseInBackground(raw)).withMissingContestSourceFrom(bundled);
    } catch (_) {
      return bundled;
    }
  }

  /// 인터넷에서 새 피드를 받는다. 더 최신이고 올바르면 반환하고 캐시하며, 아니면 null.
  static Future<EventFeed?> fetch(
    SharedPreferences prefs,
    EventFeed current, {
    http.Client? client,
    String url = Env.eventsUrl,
  }) async {
    if (url.isEmpty) return null;
    final c = client ?? http.Client();
    try {
      final res = await c.get(Uri.parse(url)).timeout(const Duration(seconds: 20));
      if (res.statusCode != 200) {
        debugPrint('LiveEvents: HTTP ${res.statusCode}');
        return null;
      }
      final raw = utf8.decode(res.bodyBytes);
      final feed = await EventFeed.parseInBackground(raw);
      if (!feed.isUsable || !feed.isNewerThan(current)) return null;
      final merged = feed.withMissingContestSourceFrom(current);
      // 받은 원문이 아니라 합친 피드를 캐시한다 (인코딩도 백그라운드에서).
      await prefs.setString(prefsKey, kIsWeb ? jsonEncode(merged.toJson()) : await compute(_encode, merged));
      return merged;
    } catch (e) {
      debugPrint('LiveEvents: $e'); // 인터넷 없음 — 기존 피드로 계속한다
      return null;
    } finally {
      if (client == null) c.close();
    }
  }
}

String _encode(EventFeed f) => jsonEncode(f.toJson());
