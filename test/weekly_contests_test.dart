import 'dart:convert';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:liferadar/data/weekly_contests.dart';
import 'package:liferadar/data/providers.dart';
import 'package:liferadar/services/calendar_api.dart';
import 'package:liferadar_core/liferadar_core.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

final now = DateTime.parse('2026-11-13T00:00:00Z');
Map<String, dynamic> event(DateTime checked) => {
  'id': 'contest-linkareer-test-final',
  'source': 'contest-linkareer',
  'title': {'ko': '현장 공모전'},
  'description': {'ko': '본선'},
  'category': 'contest',
  'tags': ['contest'],
  'applicationStart': '2026-11-10',
  'deadline': '2026-11-29',
  'start': '2026-12-07',
  'end': '2026-12-07',
  'eventDatePrecision': 'date',
  'venue': '검증된 현장',
  'city': '서울',
  'lat': 37.55,
  'lng': 126.92,
  'applicationStatus': 'open',
  'deadlinePrecision': 'date',
  'lastVerifiedAt': checked.toIso8601String(),
  'eligibilityText': '대학생',
  'url': 'https://linkareer.com/activity/1',
};
http.Response response(
  DateTime at, {
  bool empty = false,
  bool broken = false,
}) => http.Response.bytes(
  utf8.encode(
    jsonEncode({
      'generatedAt': at.toIso8601String(),
      'sources': [
        {
          'id': 'contest-linkareer',
          'name': '링커리어',
          'status': 'success',
          'coverage': 'complete',
          'count': empty ? 0 : 1,
          'verifiedAt': at.toIso8601String(),
        },
      ],
      'events': [
        if (!empty) {...event(at), if (broken) 'lat': 0},
      ],
    }),
  ),
  200,
);

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  test(
    'dedicated contest layer includes verified venue dates beyond recommendation horizon',
    () async {
      SharedPreferences.setMockInitialValues({});
      final p = await SharedPreferences.getInstance();
      final onsite = RadarEvent.fromJson({
        ...event(now),
        'start': '2027-01-10',
        'end': '2027-01-10',
      });
      final scope = ProviderContainer(
        overrides: [
          sharedPrefsProvider.overrideWithValue(p),
          nowProvider.overrideWithValue(now),
          eventsProvider.overrideWithValue([onsite]),
        ],
      );
      addTearDown(scope.dispose);
      expect(scope.read(mapEventsProvider), isEmpty);
      expect(scope.read(mapContestEventsProvider).single.id, onsite.id);
    },
  );
  test(
    'bounded direct scans advance past closed notices instead of repeating the first page',
    () async {
      SharedPreferences.setMockInitialValues({});
      final p = await SharedPreferences.getInstance();
      final seen = <String>[];
      final client = MockClient((r) async {
        if (r.url.path == '/list/contest') {
          return http.Response.bytes(
            utf8.encode(
              '<script type="application/ld+json">${jsonEncode({
                '@type': 'ItemList',
                'itemListElement': [
                  for (final id in [42, 43]) {'@type': 'ListItem', 'name': '한빛 공모전', 'url': 'https://linkareer.com/activity/$id'},
                ],
              })}</script>',
            ),
            200,
          );
        }
        final id = r.url.pathSegments.last;
        seen.add(id);
        return http.Response.bytes(
          utf8.encode(
            '<script id="__NEXT_DATA__">${jsonEncode({
              'props': {
                'pageProps': {
                  '__APOLLO_STATE__': {
                    'Activity:$id': {
                      'type': 3,
                      'title': '한빛 공모전 $id',
                      'organizationName': '한빛기관',
                      'recruitStartAt': DateTime.utc(2026, 10, 1).millisecondsSinceEpoch,
                      'recruitCloseAt': DateTime.utc(2026, 11, id == '42' ? 1 : 29, 14, 59).millisecondsSinceEpoch,
                      'detailText': {'__ref': 'ActivityText:7'},
                    },
                    'ActivityText:7': {'text': '<p>참가자격: 누구나 참여 가능</p>'},
                  },
                },
              },
            })}</script>',
          ),
          200,
        );
      });
      final collector = WeeklyContests(
        p,
        client: client,
        endpoints: {'contest-linkareer': ''},
        directEnabled: true,
        directCollector: PublicContestCollector(
          client,
          limit: 1,
          sleep: (_) async {},
        ),
      );
      final first = (await collector.collect(now))!;
      expect(first.events, isEmpty);
      expect(first.sourceMetadata.single['collectionStatus'], 'partial');
      final next = (await collector.collect(
        now.add(const Duration(hours: 6)),
      ))!;
      expect(seen, ['42', '43']);
      expect(next.events.single.id, 'contest-linkareer-43-notice');
      expect(next.sourceMetadata.single['collectionStatus'], 'success');
    },
  );
  test(
    'direct public collection reaches cache and map, skips next week and preserves failures',
    () async {
      SharedPreferences.setMockInitialValues({});
      final p = await SharedPreferences.getInstance();
      var failed = false;
      var requests = 0;
      final detail =
          '<script id="__NEXT_DATA__">${jsonEncode({
            'props': {
              'pageProps': {
                '__APOLLO_STATE__': {
                  'Activity:42': {
                    'type': 3,
                    'title': '한빛 AI 공모전',
                    'organizationName': '한빛기관',
                    'recruitStartAt': DateTime.utc(2026, 11, 1).millisecondsSinceEpoch,
                    'recruitCloseAt': DateTime.utc(2026, 11, 29, 14, 59).millisecondsSinceEpoch,
                    'detailText': {'__ref': 'ActivityText:7'},
                  },
                  'ActivityText:7': {'text': '<p>참가자격: 대학생 및 휴학생</p><p>대회 일시: 2026.12.7</p><p>행사 장소: 한빛센터</p>'},
                },
              },
            },
          })}</script>';
      final client = MockClient((r) async {
        requests++;
        if (r.url.path == '/list/contest') {
          return http.Response.bytes(
            utf8.encode(
              '<script type="application/ld+json">${jsonEncode({
                '@type': 'ItemList',
                'itemListElement': [
                  {'@type': 'ListItem', 'name': '한빛 공모전', 'url': 'https://linkareer.com/activity/42'},
                ],
              })}</script>',
            ),
            200,
          );
        }
        if (failed) return http.Response('blocked', 403);
        return http.Response.bytes(utf8.encode(detail), 200);
      });
      final direct = PublicContestCollector(
        client,
        sleep: (_) async {},
        geocode: (_) async => const ContestVenue(
          '한빛센터',
          '서울 마포구 한빛로 10',
          GeoPoint(37.55, 126.92),
        ),
      );
      final seed = EventFeed(
        events: [
          RadarEvent.fromJson({
            ...event(now.subtract(const Duration(days: 7))),
            'id': 'contest-linkareer-old-session',
            'url': 'https://linkareer.com/activity/42',
          }),
        ],
        sourceMetadata: [
          {
            'id': 'contest-linkareer',
            'name': '링커리어',
            'verifiedAt': now
                .subtract(const Duration(days: 7))
                .toIso8601String(),
          },
        ],
      );
      final collector = WeeklyContests(
        p,
        client: client,
        endpoints: {'contest-linkareer': ''},
        directEnabled: true,
        directCollector: direct,
        seed: seed,
      );
      final first = (await collector.collect(now))!;
      expect(first.events.single.placeless, isFalse);
      final mapScope = ProviderContainer(
        overrides: [
          sharedPrefsProvider.overrideWithValue(p),
          nowProvider.overrideWithValue(now),
          eventsProvider.overrideWithValue(first.events),
        ],
      );
      addTearDown(mapScope.dispose);
      expect(
        mapScope.read(mapEventsProvider).single.id,
        first.events.single.id,
      );
      expect(first.events.single.id, 'contest-linkareer-42-20261207');
      expect(
        seed.withMissingContestSourceFrom(first).events.single.id,
        first.events.single.id,
      );
      expect(await collector.collect(now.add(const Duration(days: 6))), isNull);
      expect(requests, 2);
      failed = true;
      final partial = (await collector.collect(
        now.add(const Duration(days: 7)),
      ))!;
      expect(partial.events.single.lastVerifiedAt, now);
      expect(partial.sourceMetadata.single['status'], 'partial');
      expect(
        partial
            .withMissingContestSourceFrom(first)
            .sourceMetadata
            .single['status'],
        'partial',
      );
      expect(
        p.getString('weekly_contests:contest-linkareer:success'),
        now.toIso8601String(),
      );
    },
  );
  Future<SharedPreferences> prefs() async {
    SharedPreferences.setMockInitialValues({});
    return SharedPreferences.getInstance();
  }

  test(
    'collects initially, skips within seven days, refreshes at seven days',
    () async {
      final p = await prefs();
      var calls = 0;
      var at = now;
      final collector = WeeklyContests(
        p,
        endpoints: {'contest-linkareer': 'https://collector.test/linkareer'},
        client: MockClient((_) async {
          calls++;
          return response(at);
        }),
      );
      final first = await collector.collect(at);
      expect(first!.events.single.verificationTtlHours, 192);
      expect(await collector.collect(at.add(const Duration(days: 6))), isNull);
      expect(calls, 1);
      at = at.add(const Duration(days: 7));
      expect(await collector.collect(at), isNotNull);
      expect(calls, 2);
      expect(collector.cached()!.events.single.lastVerifiedAt, at);
    },
  );
  test(
    'bad coordinates or failed source keep cache and use six-hour retry',
    () async {
      final p = await prefs();
      var at = now;
      var broken = false;
      var calls = 0;
      final collector = WeeklyContests(
        p,
        endpoints: {'contest-linkareer': 'https://collector.test/linkareer'},
        client: MockClient((_) async {
          calls++;
          return response(at, broken: broken);
        }),
      );
      await collector.collect(at);
      at = now.add(const Duration(days: 7));
      broken = true;
      expect(await collector.collect(at), isNull);
      expect(collector.cached()!.events.single.lastVerifiedAt, now);
      expect(await collector.collect(at.add(const Duration(hours: 1))), isNull);
      expect(calls, 2);
      at = at.add(const Duration(hours: 6));
      broken = false;
      expect(await collector.collect(at), isNotNull);
      expect(calls, 3);
    },
  );
  test(
    'authoritative empty snapshot removes previous source contests',
    () async {
      final p = await prefs();
      var at = now;
      var empty = false;
      final collector = WeeklyContests(
        p,
        endpoints: {'contest-linkareer': 'https://collector.test/linkareer'},
        client: MockClient((_) async => response(at, empty: empty)),
      );
      final old = (await collector.collect(at))!;
      at = at.add(const Duration(days: 7));
      empty = true;
      final fresh = (await collector.collect(at))!;
      expect(old.withMissingContestSourceFrom(fresh).events, isEmpty);
    },
  );
  test('unconfigured endpoints do not make network requests', () async {
    final collector = WeeklyContests(
      await prefs(),
      endpoints: {},
      client: MockClient((_) async => throw StateError('unexpected request')),
    );
    expect(await collector.collect(now), isNull);
  });
  test(
    'onsite dates drive map horizon; deadline calendar has no onsite location',
    () async {
      final e = RadarEvent.fromJson(event(now));
      final container = ProviderContainer(
        overrides: [
          sharedPrefsProvider.overrideWithValue(await prefs()),
          nowProvider.overrideWithValue(now),
          eventsProvider.overrideWithValue([e]),
        ],
      );
      addTearDown(container.dispose);
      expect(container.read(mapEventsProvider).single.id, e.id);
      final calendar = CalendarApi.eventBody(e, title: '접수 마감');
      expect(calendar['start'], {'date': '2026-11-29'});
      expect(calendar.containsKey('location'), isFalse);
      final closed = RadarEvent.fromJson({
        ...e.toJson(),
        'applicationStatus': 'cancelled',
      });
      final other = ProviderContainer(
        overrides: [
          sharedPrefsProvider.overrideWithValue(await prefs()),
          nowProvider.overrideWithValue(now),
          eventsProvider.overrideWithValue([closed]),
        ],
      );
      addTearDown(other.dispose);
      expect(other.read(mapEventsProvider), isEmpty);
    },
  );
}
