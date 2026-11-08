import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:liferadar/data/live_news.dart';
import 'package:liferadar_core/liferadar_core.dart';
import 'package:shared_preferences/shared_preferences.dart';

String _feed(String generatedAt, List<StrikeStatus> statuses) => jsonEncode({
  'generatedAt': generatedAt,
  'strikes': [
    for (final (i, st) in statuses.indexed)
      TransitStrike(
        id: 's$i',
        mode: TransitMode.rail,
        operator: '공항철도',
        regions: const ['인천', '서울'],
        status: st,
        quote: '공항철도 노조 13일 경고 파업',
        start: DateTime(2026, 11, 13),
        articleTitle: '공항철도 노조 13일 경고 파업',
        url: 'https://news.example.com/$i',
        publishedAt: DateTime(2026, 11, 8),
      ).toJson(),
  ],
});

http.Client _serve(String body) =>
    MockClient((_) async => http.Response.bytes(utf8.encode(body), 200));

void main() {
  late SharedPreferences prefs;
  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    prefs = await SharedPreferences.getInstance();
  });

  test('더 최신 news.json은 받아들이고 캐시한다, 활성 파업만 골라낸다', () async {
    final fresh = await LiveNews.fetch(
      prefs,
      NewsFeed.empty,
      url: 'u',
      client: _serve(
        _feed('2026-11-08T03:00:00Z', [
          StrikeStatus.scheduled,
          StrikeStatus.withdrawn,
          StrikeStatus.ended,
        ]),
      ),
    );
    expect(fresh!.strikes, hasLength(3));
    expect(fresh.active.single.id, 's0'); // 철회·종료는 경고하지 않는다
    expect(LiveNews.cached(prefs).strikes, hasLength(3));
  });

  test('오래된 파일·오프라인이면 null — 캐시 유지', () async {
    final current = NewsFeed.parse(
      _feed('2026-11-08T06:00:00Z', [StrikeStatus.scheduled]),
    );
    expect(
      await LiveNews.fetch(
        prefs,
        current,
        url: 'u',
        client: _serve(_feed('2026-11-08T03:00:00Z', [])),
      ),
      isNull,
    );
    expect(
      await LiveNews.fetch(
        prefs,
        current,
        url: 'u',
        client: MockClient((_) => throw http.ClientException('offline')),
      ),
      isNull,
    );
  });
}
