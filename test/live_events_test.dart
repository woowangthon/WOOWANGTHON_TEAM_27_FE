import 'dart:convert';

import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:liferadar/data/event_feed.dart';
import 'package:liferadar/data/live_events.dart';
import 'package:liferadar_core/demo.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// 행사 [n]개짜리 피드 JSON (샘플을 반복하고 id만 다르게).
String _feedJson(String generatedAt, {int n = 30}) => jsonEncode({
      'generatedAt': generatedAt,
      'sources': [
        {'name': 'TourAPI'},
      ],
      'events': [
        for (var i = 0; i < n; i++) {...sampleEvents[i % sampleEvents.length].toJson(), 'id': 'ev-$i'},
      ],
    });

class _Bundle extends CachingAssetBundle {
  _Bundle(this.raw);
  final String raw;
  @override
  Future<ByteData> load(String key) async => ByteData.sublistView(utf8.encode(raw));
}

http.Client _serve(String body, {int status = 200}) =>
    MockClient((_) async => http.Response.bytes(utf8.encode(body), status));

void main() {
  late SharedPreferences prefs;
  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    prefs = await SharedPreferences.getInstance();
  });

  final current = EventFeed.parse(_feedJson('2026-11-07T02:00:00'));

  test('더 최신 피드는 받아들이고 캐시한다', () async {
    final fresh = await LiveEvents.fetch(prefs, current, client: _serve(_feedJson('2026-11-08T06:00:00')), url: 'u');
    expect(fresh, isNotNull);
    expect(fresh!.generatedAt, DateTime(2026, 11, 8, 6));
    expect(prefs.getString(LiveEvents.prefsKey), isNotNull);
  });

  test('오래됨, 너무 작음, 깨짐, HTTP 오류, 인터넷 없음 — 바뀌지 않는다', () async {
    Future<EventFeed?> get(http.Client c) => LiveEvents.fetch(prefs, current, client: c, url: 'u');
    expect(await get(_serve(_feedJson('2026-11-06T00:00:00'))), isNull); // 더 오래됨
    expect(await get(_serve(_feedJson('2026-11-09T00:00:00', n: 3))), isNull); // 반쯤 쓰인 파일
    expect(await get(_serve('{"events": [')), isNull); // 깨진 JSON
    expect(await get(_serve('not found', status: 404)), isNull);
    expect(await get(MockClient((_) => throw http.ClientException('Failed to fetch'))), isNull);
    expect(prefs.getString(LiveEvents.prefsKey), isNull);
  });

  test('시작 시: 에셋과 캐시 중 더 최신인 것', () async {
    final bundle = _Bundle(_feedJson('2026-11-07T02:00:00'));
    expect((await LiveEvents.initial(prefs, bundle: bundle)).generatedAt, DateTime(2026, 11, 7, 2));

    await prefs.setString(LiveEvents.prefsKey, _feedJson('2026-11-10T06:00:00'));
    expect((await LiveEvents.initial(prefs, bundle: bundle)).generatedAt, DateTime(2026, 11, 10, 6));

    // 새 APK가 캐시보다 최신이면 — APK의 데이터.
    await prefs.setString(LiveEvents.prefsKey, _feedJson('2026-11-01T06:00:00'));
    expect((await LiveEvents.initial(prefs, bundle: bundle)).generatedAt, DateTime(2026, 11, 7, 2));
  });
}
