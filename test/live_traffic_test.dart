import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:liferadar/data/live_traffic.dart';
import 'package:liferadar_core/liferadar_core.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// 국가교통정보센터 eventInfo 응답 형식 (실제 응답을 줄인 예시).
String _itsBody() => jsonEncode({
  'header': {'resultCode': 0, 'resultMsg': 'SUCCESS'},
  'body': {
    'totalCount': 3,
    'items': [
      {
        'eventType': '공사',
        'eventDetailType': '시설물보수작업',
        'startDate': '20260824000000',
        'endDate': '20261130000000',
        'coordX': '127.3845',
        'coordY': '36.3504',
        'linkId': '1',
        'roadName': '한밭대로',
        'message': '1차로 부분통제',
        'lanesBlocked': '',
      },
      {
        'eventType': '기타돌발',
        'eventDetailType': '차량증가/정체',
        'startDate': '20261108090000',
        'endDate': '',
        'coordX': '127.0',
        'coordY': '37.0',
        'linkId': '2',
        'roadName': '경부선',
        'message': '',
      },
      {
        'eventType': '공사',
        'eventDetailType': '',
        'startDate': '20260101000000',
        'endDate': '20260301000000',
        'coordX': '127.0',
        'coordY': '37.0',
        'linkId': '3',
        'roadName': '끝난공사',
        'message': '',
      },
    ],
  },
});

TrafficNotice _topis(String id) => TrafficNotice(
  id: id,
  kind: TrafficKind.event,
  title: '[통제] 행사',
  detail: '[통제] 행사',
  start: DateTime(2026, 11, 8, 9),
  end: DateTime(2026, 11, 8, 22),
  location: const GeoPoint(37.57, 126.98),
  source: 'seoul-topis',
  sourceName: '서울시 TOPIS',
);

void main() {
  late SharedPreferences prefs;
  final now = DateTime(2026, 11, 8, 12);
  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    prefs = await SharedPreferences.getInstance();
  });

  test('ITS를 기기에서 조회: 대상 유형·유효한 공지만 남기고 캐시한다', () async {
    final its = await LiveTraffic.fetchIts(
      prefs,
      key: 'k',
      now: now,
      client: MockClient((r) async {
        expect(r.url.port, 9443);
        return http.Response.bytes(utf8.encode(_itsBody()), 200);
      }),
    );
    expect(its, isNotNull);
    expect(its!.single.title, '[한밭대로] 공사 · 시설물보수작업'); // 정체 제외, 끝난 공사 제외
    final cached = LiveTraffic.cached(prefs);
    expect(cached.its.single.id, its.single.id);
  });

  test('키가 없거나 오프라인이면 null — 이전 캐시를 유지한다', () async {
    expect(await LiveTraffic.fetchIts(prefs, key: '', now: now), isNull);
    await LiveTraffic.fetchIts(
      prefs,
      key: 'k',
      now: now,
      client: MockClient((_) async => http.Response.bytes(utf8.encode(_itsBody()), 200)),
    );
    final offline = await LiveTraffic.fetchIts(
      prefs,
      key: 'k',
      now: now,
      client: MockClient((_) => throw http.ClientException('Failed host lookup')),
    );
    expect(offline, isNull);
    expect(LiveTraffic.cached(prefs).its, hasLength(1));
  });

  test('activeAt: 서울(TOPIS)과 전국(ITS)을 합치고 id 중복을 없앤다', () {
    final its = TrafficNotice.fromJson(_topis('its-1').toJson()..['source'] = 'its');
    final feed = TrafficFeed(notices: [_topis('t1')], its: [its, its]);
    expect([for (final n in feed.activeAt(now)) n.id], unorderedEquals(['t1', 'its-1']));
    expect(feed.activeAt(DateTime(2026, 11, 9)), isEmpty); // 다음 날에는 끝난 공지
  });
  test('partial counts and malformed eligible ITS rows cannot clear the last good device cache', () async {
    await LiveTraffic.fetchIts(
      prefs,
      key: 'synthetic',
      now: now,
      client: MockClient((_) async => http.Response.bytes(utf8.encode(_itsBody()), 200)),
    );
    final saved = prefs.getString(LiveTraffic.itsPrefsKey);
    final partial = jsonDecode(_itsBody()) as Map<String, dynamic>;
    (partial['body'] as Map)['items'] = [];
    final failed = await LiveTraffic.fetchIts(
      prefs,
      key: 'synthetic',
      now: now.add(const Duration(minutes: 1)),
      client: MockClient((_) async => http.Response.bytes(utf8.encode(jsonEncode(partial)), 200)),
    );
    expect(failed, isNull);
    expect(prefs.getString(LiveTraffic.itsPrefsKey), saved);
    final malformed = jsonDecode(_itsBody()) as Map<String, dynamic>;
    ((malformed['body'] as Map)['items'] as List).first['coordX'] = 'invalid';
    final invalid = await LiveTraffic.fetchIts(
      prefs,
      key: 'synthetic',
      now: now.add(const Duration(minutes: 1)),
      client: MockClient((_) async => http.Response.bytes(utf8.encode(jsonEncode(malformed)), 200)),
    );
    expect(invalid, isNull);
    expect(prefs.getString(LiveTraffic.itsPrefsKey), saved);
    final empty = {
      'header': {'resultCode': 0},
      'body': {'totalCount': 0, 'items': []},
    };
    final cleared = await LiveTraffic.fetchIts(
      prefs,
      key: 'synthetic',
      now: now.add(const Duration(minutes: 1)),
      client: MockClient((_) async => http.Response(jsonEncode(empty), 200)),
    );
    expect(cleared, isEmpty);
    expect(LiveTraffic.cached(prefs).its, isEmpty);
  });
}
