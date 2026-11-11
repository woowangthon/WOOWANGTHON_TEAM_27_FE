// Boundary tests use isolated HTTP fixtures. Production verification is a
// separate real-network run of tool/verify_live_travel.dart using this service.
import 'dart:convert';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:liferadar_core/liferadar_core.dart';
import 'package:liferadar_core/src/sources/topis_public.dart';
import 'package:liferadar/data/providers.dart';
import 'package:liferadar/data/notifications.dart';
import 'package:flutter/material.dart';
import 'package:liferadar/data/travel_impact.dart';
import 'app_test.dart' show pumpApp;

final _now = DateTime(2026, 11, 11, 13);
final _place = TopisPublic.tmToWgs84(200000, 450000);
Plan _plan({DateTime? start, String source = 'local'}) => Plan(
  id: 'own',
  title: 'Competition',
  source: source,
  start: start ?? _now.add(const Duration(hours: 1)),
  end: (start ?? _now.add(const Duration(hours: 1))).add(const Duration(hours: 1)),
  location: _place,
  locationText: 'Destination',
  city: '서울',
);

TravelImpactService _service({
  int trafficState = 1,
  bool outage = false,
  bool stale = false,
  bool restricted = false,
  bool withdrawn = false,
  bool noTransitRoute = false,
  bool sampleEvent = false,
}) => TravelImpactService(
  kakaoKey: 'unit-test',
  googleKey: 'unit-test',
  itsKey: '',
  client: MockClient((request) async {
    http.Response ok(Object value) => http.Response.bytes(utf8.encode(jsonEncode(value)), 200);
    if (outage) return http.Response('unavailable', 503);
    final generated = (stale ? _now.subtract(const Duration(days: 5)) : _now).toUtc().toIso8601String();
    if (request.url.path.endsWith('selectAccList.do'))
      return ok({
        'rows': [
          if (restricted && utf8.decode(request.bodyBytes).contains('sIngYn=Y'))
            {
              'accId': 1,
              'accType': 'A10',
              'accDtype': '10B03',
              'accRoadCode': '009',
              'accInfo': '행사로 버스노선 우회 운행',
              'posX': 200000,
              'posY': 450000,
              'occrDate': '20261111',
              'occrTime': '1200',
              'clrDate': '20261111',
              'clrTime': '1600',
              'nowTime': '202611111300',
            },
        ],
      });
    if (request.url.path.endsWith('traffic-v2.json')) return http.Response('not found', 404);
    if (request.url.path.endsWith('traffic.json')) return ok({'generatedAt': generated, 'notices': []});
    if (request.url.path.endsWith('news.json'))
      return ok({
        'generatedAt': generated,
        'strikes': [
          TransitStrike(
            id: 'strike',
            mode: TransitMode.rail,
            operator: 'Rail operator',
            regions: const ['전국'],
            status: withdrawn ? StrikeStatus.withdrawn : StrikeStatus.scheduled,
            quote: '11월 11일 파업 예정',
            articleTitle: 'Rail notice',
            url: 'https://news.example/strike',
            publishedAt: _now,
            start: DateTime(2026, 11, 11),
          ).toJson(),
        ],
      });
    if (request.url.path.endsWith('events.json'))
      return ok({
        'generatedAt': generated,
        'events': [
          RadarEvent(
            id: 'event',
            title: const LocalizedText(ko: '행사', en: 'Event'),
            description: const LocalizedText(ko: '', en: ''),
            category: EventCategory.festival,
            tags: const [],
            start: _now,
            end: _now.add(const Duration(hours: 3)),
            venue: 'Venue',
            city: '서울',
            location: _place,
            source: sampleEvent ? 'sample' : 'public-api',
            url: 'https://events.example/event',
          ).toJson(),
        ],
      });
    if (request.url.host == 'apis-navi.kakaomobility.com')
      return ok({
        'routes': [
          {
            'result_code': 0,
            'summary': {'distance': 1000, 'duration': 600},
            'sections': [
              {
                'roads': [
                  {
                    'name': 'Road',
                    'distance': 1000,
                    'traffic_state': trafficState,
                    'vertexes': [_place.lng, _place.lat, _place.lng + 0.001, _place.lat],
                  },
                ],
              },
            ],
          },
        ],
      });
    if (request.url.host == 'routes.googleapis.com')
      return ok({
        'routes': [
          if (!noTransitRoute)
            {
              'distanceMeters': 1000,
              'duration': '600s',
              'polyline': {'encodedPolyline': '_p~iF~ps|U_ulLnnqC_mqNvxq`@'},
              'legs': [
                {
                  'steps': [
                    {
                      'transitDetails': {
                        'transitLine': {
                          'name': 'KTX',
                          'vehicle': {'type': 'HIGH_SPEED_TRAIN'},
                        },
                      },
                    },
                  ],
                },
              ],
            },
        ],
      });
    return http.Response('unknown source', 404);
  }),
);

class _Enabled extends NotificationsController {
  @override
  bool build() => true;
}

class _QuietFeed extends EventFeedController {
  @override
  EventFeed build() => EventFeed.empty;
}

void main() {
  test('observed impassable road code is distinguished from congestion', () async {
    final service = _service(trafficState: 6);
    addTearDown(service.close);
    final report = await service.check(_plan(), now: _now, origin: _place);
    expect(report.insights.any((i) => i.title.ko == '현재 경로에 통행 불가 구간'), isTrue);
  });

  test('online appointment never becomes a travel alert', () async {
    final service = _service();
    addTearDown(service.close);
    final report = await service.check(
      _plan().copyWith(attendance: 'online'),
      now: _now,
      origin: _place,
    );
    expect(report.insights, isEmpty);
    expect(report.sources.single.name, '이동 대상');
  });

  test('production starts without sample events or appointments, including after disconnect', () async {
    SharedPreferences.setMockInitialValues({});
    final prefs = await SharedPreferences.getInstance();
    final c = ProviderContainer(
      overrides: [
        sharedPrefsProvider.overrideWithValue(prefs),
        liveEventsEnabledProvider.overrideWithValue(true),
        eventFeedProvider.overrideWith(_QuietFeed.new),
      ],
    );
    addTearDown(c.dispose);
    expect(c.read(eventsProvider), isEmpty);
    expect(c.read(plansProvider), isEmpty);
    c.read(plansProvider.notifier).resetToSample();
    expect(c.read(plansProvider), isEmpty);
  });

  test('current congestion is measured, and car travel excludes rail strike', () async {
    final service = _service();
    addTearDown(service.close);
    final report = await service.check(_plan(), now: _now, origin: _place);
    expect(report.route?.distanceMeters, 1000);
    expect(report.insights.any((i) => i.id.startsWith('travel:road:') && i.notificationEligible == true), isTrue);
    expect(report.insights.any((i) => i.id.startsWith('travel:strike:')), isFalse);
    expect(report.insights.any((i) => i.id.startsWith('travel:event:')), isTrue);
  });

  test('unknown road state is never reported as free flowing', () async {
    final service = _service(trafficState: 0);
    addTearDown(service.close);
    final report = await service.check(_plan(), now: _now, origin: _place);
    expect(report.insights.any((i) => i.id.startsWith('travel:road:')), isFalse);
    expect(report.sources.any((s) => s.name == '도로 소통 관측 범위' && !s.ok), isTrue);
  });

  test('current congestion does not alert for tomorrow and samples are excluded', () async {
    final service = _service(sampleEvent: true);
    addTearDown(service.close);
    final report = await service.check(
      _plan(start: _now.add(const Duration(days: 1))),
      now: _now,
      origin: _place,
    );
    expect(report.insights.firstWhere((i) => i.id.startsWith('travel:road:')).notificationEligible, isFalse);
    expect(report.insights.any((i) => i.id.startsWith('travel:event:')), isFalse);
    expect(() => service.check(_plan(source: 'sample'), now: _now), throwsArgumentError);
  });

  test('rail strike is a possible restriction with source; withdrawal removes it', () async {
    final service = _service();
    addTearDown(service.close);
    final report = await service.check(_plan(), now: _now, origin: _place, mode: TravelMode.transit);
    final strike = report.insights.firstWhere((i) => i.id.startsWith('travel:strike:'));
    expect(strike.body.ko, contains('전체 운행 중단 여부는 확인되지 않았습니다'));
    expect(strike.sources.single.url, 'https://news.example/strike');
    final withdrawn = _service(withdrawn: true);
    addTearDown(withdrawn.close);
    final after = await withdrawn.check(_plan(), now: _now, origin: _place, mode: TravelMode.transit);
    expect(after.insights.any((i) => i.id.startsWith('travel:strike:')), isFalse);
  });

  test('route lookup failure does not become a confirmed service suspension', () async {
    final service = _service(noTransitRoute: true);
    addTearDown(service.close);
    final report = await service.check(_plan(), now: _now, origin: _place, mode: TravelMode.transit);
    expect(report.route, isNull);
    expect(report.sources.any((s) => s.name == '대중교통 경로' && !s.ok && s.detail.contains('단정하지 않습니다')), isTrue);
  });

  test('stale feeds and network failure never manufacture warnings or normal status', () async {
    final stale = _service(stale: true);
    addTearDown(stale.close);
    final report = await stale.check(_plan(), now: _now);
    expect(report.insights, isEmpty);
    expect(report.incomplete, isTrue);
    final outage = _service(outage: true);
    addTearDown(outage.close);
    final unavailable = await outage.check(_plan(), now: _now, origin: _place);
    expect(unavailable.insights, isEmpty);
    expect(unavailable.sources.every((s) => !s.ok), isTrue);
  });

  test('official bus restriction matches time and proximity without requiring a fabricated line ID', () async {
    final service = _service(restricted: true);
    addTearDown(service.close);
    final report = await service.check(_plan(), now: _now);
    final restriction = report.insights.firstWhere((i) => i.id.startsWith('travel:transit:'));
    expect(restriction.body.ko, contains('행사로 버스노선 우회 운행'));
    expect(restriction.sources.single.url, 'https://topis.seoul.go.kr/?accId=1');
    expect(restriction.notificationEligible, isTrue);
    expect(report.matches(_plan(), null), isTrue);
    expect(report.matches(_plan(start: _now.add(const Duration(hours: 2))), null), isFalse);
  });

  test('actual service findings reach notification sender once, without demo fallback', () async {
    final service = _service();
    addTearDown(service.close);
    final plan = _plan();
    final report = await service.check(plan, now: _now, origin: _place);
    SharedPreferences.setMockInitialValues({});
    final prefs = await SharedPreferences.getInstance();
    final sent = <String>[];
    final c = ProviderContainer(
      overrides: [
        sharedPrefsProvider.overrideWithValue(prefs),
        nowProvider.overrideWithValue(_now),
        notificationsEnabledProvider.overrideWith(_Enabled.new),
        systemNotificationSenderProvider.overrideWithValue((title, body, {tag}) async {
          sent.add(title);
          return true;
        }),
      ],
    );
    addTearDown(c.dispose);
    c.read(plansProvider.notifier).setPlans([plan]);
    final notifier = c.read(signalNotifierProvider);
    await notifier.dispatch(report.insights);
    expect(sent, isNotEmpty);
    final count = sent.length;
    await notifier.dispatch(report.insights);
    expect(sent.length, count);
  });

  testWidgets('saved plan opens the live check screen and shows findings with source status', (tester) async {
    final service = _service();
    addTearDown(service.close);
    await pumpApp(
      tester,
      now: _now,
      interests: ['ai'],
      overrides: [travelImpactServiceProvider.overrideWithValue(service)],
    );
    final c = ProviderScope.containerOf(tester.element(find.byType(MaterialApp)));
    await c.read(plansProvider.notifier).saveLocal(_plan());
    await tester.tap(find.byIcon(Icons.event_note_outlined).last);
    await tester.pumpAndSettle();
    await tester.tap(find.text('Competition'));
    await tester.pumpAndSettle();
    await tester.ensureVisible(find.text('Check travel impact'));
    await tester.tap(find.text('Check travel impact'));
    await tester.pumpAndSettle();
    expect(find.text('Check latest information'), findsOneWidget);
    expect(find.textContaining('Some sources could not be checked'), findsOneWidget);
    await tester.scrollUntilVisible(
      find.textContaining('Nearby event: possible traffic impact'),
      200,
      scrollable: find.byType(Scrollable).last,
    );
    expect(find.textContaining('Nearby event: possible traffic impact'), findsOneWidget);
  });
}
