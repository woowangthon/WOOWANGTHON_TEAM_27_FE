import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:liferadar/data/event_feed.dart';
import 'package:liferadar_core/demo.dart';

void main() {
  test('EventFeed: toJson → parse 결과가 같고 깨진 항목은 건너뛴다', () {
    final e = sampleEvents.first;
    final raw = jsonEncode({
      'generatedAt': '2026-11-07T02:00:00Z',
      'sources': [
        {'name': '서울 열린데이터광장 · 서울시 문화행사'},
      ],
      'events': [
        e.toJson(),
        {'id': 'broken'},
      ],
    });
    final feed = EventFeed.parse(raw);
    expect(feed.events, hasLength(1));
    expect(feed.events.single.id, e.id);
    expect(feed.events.single.title.en, e.title.en);
    expect(feed.events.single.location.lat, closeTo(e.location.lat, 1e-9));
    expect(feed.sources, ['서울 열린데이터광장 · 서울시 문화행사']);
    expect(feed.generatedAt, DateTime.utc(2026, 11, 7, 2));
  });
}
