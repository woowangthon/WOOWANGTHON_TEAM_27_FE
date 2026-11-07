import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

import 'package:liferadar_core/liferadar_core.dart';

/// `tool/collect_events.dart`가 수집한 실제 행사 (assets/data/events.json).
class EventFeed {
  const EventFeed({this.events = const [], this.generatedAt, this.sources = const []});

  static const empty = EventFeed();
  static const asset = 'assets/data/events.json';

  final List<RadarEvent> events;
  final DateTime? generatedAt;

  /// 출처 이름 (출처 표시용).
  final List<String> sources;

  bool get isEmpty => events.isEmpty;

  static EventFeed parse(String raw) {
    final j = jsonDecode(raw) as Map<String, dynamic>;
    final events = <RadarEvent>[];
    for (final e in (j['events'] as List? ?? const [])) {
      try {
        events.add(RadarEvent.fromJson((e as Map).cast<String, dynamic>()));
      } catch (_) {
        // 깨진 항목 하나가 전체 목록을 멈추지 않게 한다.
      }
    }
    return EventFeed(
      events: events,
      generatedAt: DateTime.tryParse(j['generatedAt'] as String? ?? ''),
      sources: [for (final s in (j['sources'] as List? ?? const [])) (s as Map)['name'] as String],
    );
  }

  /// 에셋이 없거나 손상되었으면 빈 피드 (앱은 샘플로 동작한다).
  static Future<EventFeed> load([AssetBundle? bundle]) async {
    try {
      return parse(await (bundle ?? rootBundle).loadString(asset));
    } catch (e) {
      debugPrint('EventFeed: $e');
      return empty;
    }
  }

  /// 사용 가능한 피드: 생성 시각이 있고 행사가 충분함 (반쯤 쓰인 파일·빈 파일이 아님).
  bool get isUsable => generatedAt != null && events.length >= minEvents;
  static const minEvents = 20;

  /// [other]보다 더 최신인지.
  bool isNewerThan(EventFeed other) =>
      generatedAt != null && (other.generatedAt == null || generatedAt!.isAfter(other.generatedAt!));

  /// 둘 중 더 최신인 것 (사용 가능한 것 중에서).
  static EventFeed newest(EventFeed a, EventFeed b) {
    if (!b.isUsable) return a;
    if (!a.isUsable) return b;
    return b.isNewerThan(a) ? b : a;
  }
}
