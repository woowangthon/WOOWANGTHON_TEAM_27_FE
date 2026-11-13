import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:liferadar/core/notify/notify.dart';
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

class _Google extends GoogleApi {
  @override
  Future<List<DailyWeather>> dailyForecast(
    GeoPoint p, {
    String lang = 'ko',
  }) async => [];
}

Future<ProviderContainer> _container(SystemNotificationSender sender) async {
  // Diagnostic entrypoint deliberately uses memory storage to preserve user data.
  // ignore: invalid_use_of_visible_for_testing_member
  SharedPreferences.setMockInitialValues({'session': '{"kind":"guest"}', 'notify_enabled': true});
  final prefs = await SharedPreferences.getInstance();
  final c = ProviderContainer(
    overrides: [
      sharedPrefsProvider.overrideWithValue(prefs),
      nowProvider.overrideWithValue(DateTime(2026, 11, 9)),
      newsFeedProvider.overrideWith(_Feed.new),
      systemNotificationSenderProvider.overrideWithValue(sender),
      googleApiProvider.overrideWithValue(_Google()),
    ],
  );
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


// Isolated historical fixtures. No calendar, account or production preferences
// are changed. The notification plugin and Android delivery are REAL.
Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await initNotify();
  final results = <String, dynamic>{'permission': notifyPermission(), 'fixtureReplay': true};
  int sent = 0;
  Future<bool> sender(String title, String body, {String? tag}) async {
    final ok = await showSystemNotification('[검증용] $title', '실제 파업·통제 안내가 아닌 이동 경로 알림 시험입니다. $body', tag: 'traffic-verification:$tag');
    if (ok) sent++;
    return ok;
  }
  try {
    final c = await _container(sender);
    results['enabled'] = c.read(notificationsEnabledProvider);
    await _saveTrip(c);
    List<Insight> alerts() => c.read(newsTrafficDecisionsProvider).where((e) => e.visible).map((e) => e.toInsight()).toList();
    final strike = alerts();
    await c.read(signalNotifierProvider).dispatch(strike);
    results['strikeSent'] = sent == 1;
    await c.read(signalNotifierProvider).dispatch(strike);
    results['duplicateSuppressed'] = sent == 1;
    c.dispose();

    final wrong = await _container(sender);
    await _saveTrip(wrong, facilityIds: {'fixture:other'});
    final mismatch = wrong.read(newsTrafficDecisionsProvider).where((e) => e.visible).map((e) => e.toInsight()).toList();
    await wrong.read(signalNotifierProvider).dispatch(mismatch);
    results['otherRouteSuppressed'] = sent == 1;
    wrong.dispose();

    final late = await _container(sender);
    await _saveTrip(late);
    final lateJson = Map<String, dynamic>.from(_feed().trafficImpacts.single.toJson());
    lateJson['period'] = {'start': _time('15:00'), 'end': _time('16:00')};
    (late.read(newsFeedProvider.notifier) as _Feed).replace(NewsFeed(trafficImpacts: [NewsTrafficImpact.fromJson(lateJson)]));
    await late.read(signalNotifierProvider).dispatch(late.read(newsTrafficDecisionsProvider).where((e) => e.visible).map((e) => e.toInsight()).toList());
    results['otherTimeSuppressed'] = sent == 1;
    late.dispose();

    final event = await _container(sender);
    await _saveTrip(event);
    final eventJson = Map<String, dynamic>.from(_feed().trafficImpacts.single.toJson());
    eventJson.addAll({'id': 'fixture-event-closure', 'event_id': 'fixture-event-closure', 'type': 'ROAD_CLOSURE', 'event_name': '서울 행사 도로 통제', 'evidence': [{'quote': '서울 행사로 도로 차량 통제 및 버스 우회 운행'}]});
    (event.read(newsFeedProvider.notifier) as _Feed).replace(NewsFeed(trafficImpacts: [NewsTrafficImpact.fromJson(eventJson)]));
    await event.read(signalNotifierProvider).dispatch(event.read(newsTrafficDecisionsProvider).where((e) => e.visible).map((e) => e.toInsight()).toList());
    results['eventClosureSent'] = sent == 2;
    event.dispose();
    results['sent'] = sent;
    results['passed'] = results['enabled'] == true && results['strikeSent'] == true && results['duplicateSuppressed'] == true && results['otherRouteSuppressed'] == true && results['otherTimeSuppressed'] == true && results['eventClosureSent'] == true;
  } catch (e, stack) {
    results['error'] = '$e';
    debugPrint('$stack');
  }
  debugPrint('TRAFFIC_VERIFY ${jsonEncode(results)}');
  runApp(MaterialApp(home: Scaffold(appBar: AppBar(title: const Text('검증용 이동 경로 알림')), body: SingleChildScrollView(child: Text(const JsonEncoder.withIndent('  ').convert(results))))));
}
