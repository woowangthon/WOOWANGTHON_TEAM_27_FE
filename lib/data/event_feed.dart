import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

import 'package:liferadar_core/liferadar_core.dart';

/// `tool/collect_events.dart`가 수집한 실제 행사 (assets/data/events.json).
class EventFeed {
  const EventFeed({this.events = const [], this.generatedAt, this.sources = const [], this.sourceMetadata = const []});

  static const empty = EventFeed();
  static const asset = 'assets/data/events.json';
  static const contestsAsset = 'assets/data/contests.json';
  // Removed API: reject its old cached/remote records as well as bundled data.
  static const _removedSources = {'kstartup', 'contest-kstartup'};
  static bool _removed(RadarEvent e) => _removedSources.contains(e.source) || e.id.startsWith('kstartup-');

  final List<RadarEvent> events;
  final DateTime? generatedAt;

  /// 출처 이름 (출처 표시용).
  final List<String> sources;
  final List<Map<String, dynamic>> sourceMetadata;

  /// Merge application sources independently of the general feed timestamp.
  /// A newer APK snapshot must supersede an older cached source snapshot.
  EventFeed withMissingContestSourceFrom(EventFeed previous) {
    final merged = events.where((e)=>!_removed(e)).toList();
    final metadata = sourceMetadata.where((s)=>!_removedSources.contains(s['id'])).toList();
    final names = {...sources};
    DateTime? observed(Map<String, dynamic> m, DateTime? fallback) =>
        DateTime.tryParse('${m['cacheSnapshot'] == true && m['coverage'] == 'incremental-public-pages' ? m['snapshotAt'] : m['verifiedAt'] ?? m['lastSuccessAt'] ?? ''}') ?? fallback;
    for (final old in previous.sourceMetadata) {
      final source = old['id'];
      if (_removedSources.contains(source)) continue;
      if (source is! String || !(source == 'sotong-contest' || source.startsWith('contest-'))) continue;
      final current = metadata.where((m) => m['id'] == source).firstOrNull;
      final oldAt = observed(old, previous.generatedAt);
      final currentAt = current == null ? null : observed(current, generatedAt);
      final currentFailed = current != null && ['failed','partial','disabled'].contains(current['status']) &&
          !(current['cacheSnapshot'] == true && current['coverage'] == 'incremental-public-pages');
      if (current != null && !currentFailed && (oldAt == null || (currentAt != null && !oldAt.isAfter(currentAt)))) continue;
      merged.removeWhere((e) => e.source == source);
      // Older apps classified the same stable K-Startup IDs as startupSupport.
      final replacementIds = previous.events.where((e) => e.source == source).map((e) => e.id).toSet();
      merged.removeWhere((e) => replacementIds.contains(e.id));
      final ids = merged.map((e) => e.id).toSet();
      merged.addAll(previous.events.where((e) => e.source == source && !ids.contains(e.id)));
      metadata.removeWhere((m) => m['id'] == source);
      metadata.add(old);
      if (old['name'] is String) names.add(old['name'] as String);
    }
    return EventFeed(
      events: merged, generatedAt: generatedAt,
      sources: names.toList(), sourceMetadata: metadata,
    );
  }

  Map<String, dynamic> toJson() => {
    'generatedAt': generatedAt?.toUtc().toIso8601String(),
    'sources': sourceMetadata.isNotEmpty ? sourceMetadata : [for (final name in sources) {'name': name}],
    'events': events.map((e) => e.toJson()).toList(),
  };

  bool get isEmpty => events.isEmpty;

  static EventFeed parse(String raw) {
    final j = jsonDecode(raw) as Map<String, dynamic>;
    final events = <RadarEvent>[];
    for (final e in (j['events'] as List? ?? const [])) {
      try {
        final event=RadarEvent.fromJson((e as Map).cast<String, dynamic>());
        if (!_removed(event)) events.add(event);
      } catch (_) {
        // 깨진 항목 하나가 전체 목록을 멈추지 않게 한다.
      }
    }
    return EventFeed(
      events: events,
      generatedAt: DateTime.tryParse(j['generatedAt'] as String? ?? ''),
      sources: [for (final s in (j['sources'] as List? ?? const [])) if (!_removedSources.contains((s as Map)['id'])) s['name'] as String],
      sourceMetadata: [for (final s in (j['sources'] as List? ?? const [])) if (!_removedSources.contains((s as Map)['id'])) s.cast<String, dynamic>()],
    );
  }

  /// 에셋이 없거나 손상되었으면 빈 피드 (앱은 샘플로 동작한다).
  static Future<EventFeed> load([AssetBundle? bundle]) async {
    try {
      final b = bundle ?? rootBundle;
      final feed = parse(await b.loadString(asset));
      try {
        return feed.withMissingContestSourceFrom(parse(await b.loadString(contestsAsset)));
      } catch (_) {
        return feed;
      }
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
