import 'dart:convert';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:liferadar_core/liferadar_core.dart';
import 'package:liferadar/data/live_news.dart';
import 'package:liferadar/data/news_traffic.dart';
import 'package:liferadar/data/notifications.dart';
import 'package:liferadar/data/plan_routes.dart';
import 'package:liferadar/data/providers.dart';
import 'package:liferadar/services/google_api.dart';

final _from = Plan(
  id: 'a',
  title: '출발 일정',
  start: DateTime(2026, 11, 10, 8),
  end: DateTime(2026, 11, 10, 9),
  locationText: '서울시청',
  city: '서울',
  source: 'local',
  location: const GeoPoint(37.5663, 126.9779),
);
final _to = _from.copyWith(
  id: 'b',
  title: '도착 일정',
  start: DateTime(2026, 11, 10, 10),
  end: DateTime(2026, 11, 10, 11),
);
Map<String, dynamic> _time(String value) => {
  'date': '2026-11-10',
  'time': value,
  'timezone': 'Asia/Seoul',
  'open_ended': false,
};
NewsFeed _feed({String status = 'ANNOUNCED', int version = 1}) =>
    NewsFeed.parse(
      jsonEncode({
        'generatedAt': '2026-11-09T00:00:00Z',
        'newsTrafficSchemaVersion': '1.0',
        'strikes': [],
        'trafficImpacts': [
          {
            'id': 'fixture-impact',
            'event_id': 'fixture-event',
            'version': version,
            'type': 'STRIKE',
            'status': status,
            'assertion': 'planned',
            'event_name': '서울 버스 파업',
            'source_url': 'https://news.example/fixture',
            'body_verified': true,
            'demo': false,
            'period': {'start': _time('08:00'), 'end': _time('11:00')},
            'scope': [
              {'region': '서울', 'reference_id': 'fixture:101', 'raw': '101번 버스'},
            ],
            'modes': ['bus'],
            'exceptions': [],
            'evidence': [
              {'quote': '서울 101번 버스 파업 예고'},
            ],
          },
        ],
      }),
    );

class _Feed extends NewsFeedController {
  @override
  NewsFeed build() => _feed();
  void replace(NewsFeed next) => state = next;
}

class _Enabled extends NotificationsController {
  @override
  bool build() => true;
}

class _Google extends GoogleApi {
  @override
  Future<List<DailyWeather>> dailyForecast(
    GeoPoint p, {
    String lang = 'ko',
  }) async => [];
}

Future<ProviderContainer> _container(SystemNotificationSender sender) async {
  SharedPreferences.setMockInitialValues({'session': '{"kind":"guest"}'});
  final prefs = await SharedPreferences.getInstance();
  final c = ProviderContainer(
    overrides: [
      sharedPrefsProvider.overrideWithValue(prefs),
      nowProvider.overrideWithValue(DateTime(2026, 11, 9)),
      newsFeedProvider.overrideWith(_Feed.new),
      notificationsEnabledProvider.overrideWith(_Enabled.new),
      systemNotificationSenderProvider.overrideWithValue(sender),
      googleApiProvider.overrideWithValue(_Google()),
    ],
  );
  addTearDown(c.dispose);
  c.read(plansProvider.notifier).setPlans([_from, _to]);
  return c;
}

Future<void> _saveTrip(
  ProviderContainer c, {
  Set<String> modes = const {'bus'},
  Set<String> facilityIds = const {'fixture:101'},
}) => c
    .read(planRoutesProvider.notifier)
    .save(
      PlanRoute.fromSearch(
        from: _from,
        to: _to,
        origin: _from.locationText,
        destination: _to.locationText,
        originLocation: _from.location!,
        destinationLocation: _to.location!,
        departure: _from.end,
        route: TravelRoute(
          distanceMeters: 1000,
          durationSeconds: 2400,
          mode: TravelMode.transit,
          transitLines: const ['101번 버스'],
          transportModes: modes,
          facilityIds: facilityIds,
        ),
      ),
    );

void main() {
  test(
    'versioned regional reference maps provider line into verified route ID',
    () async {
      final c = await _container((title, body, {tag}) async => true);
      (c.read(newsFeedProvider.notifier) as _Feed).replace(
        NewsFeed(
          trafficImpacts: _feed().trafficImpacts,
          transportReferences: [
            TrafficReference.fromJson({
              'id': 'fixture:101',
              'raw': '101번 버스',
              'region': '서울',
              'mode': 'bus',
              'source': 'synthetic test reference',
              'as_of': '2026-11-09',
            }),
          ],
        ),
      );
      await _saveTrip(c, facilityIds: {});
      expect(c.read(tripsByPlanIdProvider)['b']!.facilityIds, {'fixture:101'});
      expect(
        c
            .read(newsTrafficDecisionsProvider)
            .singleWhere((e) => e.planId == 'b')
            .decision,
        NewsTrafficDecision.recommend,
      );
    },
  );
  test(
    'clock refresh does not replace synchronized schedules with samples',
    () async {
      SharedPreferences.setMockInitialValues({});
      final prefs = await SharedPreferences.getInstance();
      var clock = DateTime(2026, 11, 9);
      final c = ProviderContainer(
        overrides: [
          sharedPrefsProvider.overrideWithValue(prefs),
          nowProvider.overrideWith((ref) => clock),
        ],
      );
      addTearDown(c.dispose);
      c.read(plansProvider.notifier).setPlans([_from, _to]);
      clock = clock.add(const Duration(minutes: 1));
      c.invalidate(nowProvider);
      c.read(nowProvider);
      expect(c.read(plansProvider).map((p) => p.id), ['a', 'b']);
    },
  );
  test(
    'saved route → verified feed → insight → notification, duplicate suppressed',
    () async {
      final delivered = <String?>[];
      final c = await _container((title, body, {tag}) async {
        delivered.add(tag);
        return true;
      });
      await _saveTrip(c);
      final insights = c
          .read(baseInsightsProvider)
          .where((i) => i.id.startsWith('news-traffic:'))
          .toList();
      final target = insights.singleWhere((i) => i.planId == 'b');
      expect(target.notificationEligible, isTrue);
      await c.read(signalNotifierProvider).dispatch(insights);
      await c.read(signalNotifierProvider).dispatch(insights);
      expect(delivered, [target.id]);
    },
  );
  test(
    'strike without saved line produces no card or system warning',
    () async {
      var delivered = 0;
      final c = await _container((title, body, {tag}) async {
        delivered++;
        return true;
      });
      final insights = c
          .read(baseInsightsProvider)
          .where((i) => i.id.startsWith('news-traffic:'))
          .toList();
      expect(insights, isEmpty);
      expect(insights.every((i) => i.notificationEligible == false), isTrue);
      await c.read(signalNotifierProvider).dispatch(insights);
      expect(delivered, 0);
    },
  );
  test(
    'failed system delivery is retried instead of recorded as sent',
    () async {
      var calls = 0;
      final c = await _container((title, body, {tag}) async => ++calls > 1);
      await _saveTrip(c);
      final card = c
          .read(baseInsightsProvider)
          .singleWhere(
            (i) => i.id.startsWith('news-traffic:') && i.planId == 'b',
          );
      await c.read(signalNotifierProvider).dispatch([card]);
      await c.read(signalNotifierProvider).dispatch([card]);
      await c.read(signalNotifierProvider).dispatch([card]);
      expect(calls, 2);
    },
  );
  test(
    'withdrawal resolves exact saved pair and emits one correction',
    () async {
      final delivered = <String>[];
      final c = await _container((title, body, {tag}) async {
        delivered.add(body);
        return true;
      });
      await _saveTrip(c);
      final first = c
          .read(newsTrafficDecisionsProvider)
          .singleWhere((e) => e.planId == 'b');
      await c.read(signalNotifierProvider).dispatch([first.toInsight()]);
      await Future<void>.delayed(Duration.zero);
      (c.read(newsFeedProvider.notifier) as _Feed).replace(
        _feed(status: 'WITHDRAWN', version: 2),
      );
      final second = c
          .read(newsTrafficDecisionsProvider)
          .singleWhere((e) => e.planId == 'b');
      expect(second.decision, NewsTrafficDecision.resolved);
      await c.read(signalNotifierProvider).dispatch([second.toInsight()]);
      await c.read(signalNotifierProvider).dispatch([second.toInsight()]);
      expect(delivered.length, 2);
    },
  );
  test('old saved-route JSON remains valid and has unknown modes', () {
    final old =
        PlanRoute.fromSearch(
            from: _from,
            to: _to,
            origin: 'a',
            destination: 'b',
            originLocation: _from.location!,
            destinationLocation: _to.location!,
            departure: _from.end,
            route: const TravelRoute(
              distanceMeters: 100,
              durationSeconds: 100,
              mode: TravelMode.transit,
            ),
          ).toJson()
          ..remove('modes')
          ..remove('facilityIds')
          ..remove('points');
    expect(PlanRoute.fromJson(old).modes, isEmpty);
  });
  test(
    'reference-only withdrawal does not create a new system correction',
    () async {
      var delivered = 0;
      final c = await _container((title, body, {tag}) async {
        delivered++;
        return true;
      });
      c.read(newsTrafficDecisionsProvider);
      await Future<void>.delayed(Duration.zero);
      (c.read(newsFeedProvider.notifier) as _Feed).replace(
        _feed(status: 'WITHDRAWN', version: 2),
      );
      final resolved = c
          .read(newsTrafficDecisionsProvider)
          .where((e) => e.decision == NewsTrafficDecision.resolved);
      expect(resolved, isEmpty);
      await c
          .read(signalNotifierProvider)
          .dispatch(resolved.map((e) => e.toInsight()).toList());
      expect(delivered, 0);
    },
  );
}
