import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:liferadar/data/live_events.dart';
import 'package:liferadar/core/theme.dart';
import 'package:liferadar/data/providers.dart';
import 'package:liferadar/features/discover/discover_screen.dart';
import 'package:liferadar/features/event/event_detail_sheet.dart';
import 'package:liferadar/features/map/map_screen.dart';
import 'package:liferadar/l10n/app_localizations.dart';
import 'package:liferadar/services/calendar_api.dart';
import 'package:liferadar_core/liferadar_core.dart';
import 'package:shared_preferences/shared_preferences.dart';

final now = DateTime.parse('2026-11-12T00:00:00Z');
RadarEvent contest({String? apply, String city = '미확인', bool stale = false}) => RadarEvent(
  id: 'sotong-contest-fixture',
  title: const LocalizedText(ko: '공모전 테스트 공고', en: 'Contest fixture'),
  description: const LocalizedText(ko: '공고 본문', en: 'Application notice'),
  category: EventCategory.contest,
  tags: const ['contest'],
  start: DateTime(2026, 11, 10),
  end: DateTime(2026, 11, 20),
  deadline: DateTime(2026, 11, 20),
  venue: '주관기관 테스트',
  city: city,
  location: const GeoPoint(37.5665, 126.9780),
  placeless: true,
  source: 'sotong-contest',
  sourceName: '소통24 공모전',
  url: 'https://modu.go.kr',
  registerUrl: apply,
  deadlinePrecision: 'date',
  applicationStatus: 'open',
  lastVerifiedAt: stale ? now.subtract(const Duration(hours: 49)) : now,
  eligibilityText: '대한민국 대학생 및 휴학생 (팀 2~4명)',
  audience: 'university',
);
Future<void> pump(WidgetTester tester, Widget child) async {
  SharedPreferences.setMockInitialValues({});
  final prefs = await SharedPreferences.getInstance();
  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        sharedPrefsProvider.overrideWithValue(prefs),
        nowProvider.overrideWithValue(now),
        eventsProvider.overrideWithValue([contest()]),
      ],
      child: MaterialApp(
        theme: buildTheme(Brightness.light),
        locale: const Locale('ko'),
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: Scaffold(body: child),
      ),
    ),
  );
  await tester.pumpAndSettle();
}

void main() {
  testWidgets('map offers a dedicated contest layer', (tester) async {
    await pump(tester, const MapScreen());
    expect(find.text('공모전'), findsOneWidget);
  });
  test('placeless does not imply nationwide; category survives feed/cache', () {
    expect(discoverRegionOf(contest()), '미확인');
    expect(discoverRegionOf(contest(city: '전국')), '전국');
    final e = EventFeed.parse(
      jsonEncode({
        'generatedAt': now.toIso8601String(),
        'events': [contest().toJson()],
        'sources': [],
      }),
    ).events.single;
    expect(e.category, EventCategory.contest);
    expect(e.eligibilityText, contains('휴학생'));
  });
  test('Calendar application deadline is all-day without fake time/place', () {
    final body = CalendarApi.eventBody(contest(), title: '접수 마감: 공모전');
    expect(body['start'], {'date': '2026-11-20'});
    expect(body['end'], {'date': '2026-11-21'});
    expect(body.containsKey('location'), isFalse);
    expect(body['description'], contains('접수 마감'));
    final precise = RadarEvent.fromJson({
      ...contest().toJson(),
      'deadlinePrecision': 'datetime',
      'deadline': '2026-11-20T08:00:00Z',
    });
    expect((CalendarApi.eventBody(precise, title: 'deadline')['start'] as Map)['dateTime'], '2026-11-20T08:00:00.000Z');
  });
  test('contest offline cache survives failure and refresh preserves metadata', () async {
    SharedPreferences.setMockInitialValues({});
    final prefs = await SharedPreferences.getInstance();
    String feed(String at) => jsonEncode({
      'generatedAt': at,
      'sources': [{'id': 'sotong-contest', 'name': '소통24 공모전', 'verifiedAt': at}],
      'events': [
        for (var i = 0; i < 20; i++) {...contest().toJson(), 'id': 'sotong-contest-$i'},
      ],
    });
    final old = EventFeed.parse(feed('2026-11-10T00:00:00Z'));
    expect(await LiveEvents.fetch(prefs, old, client: MockClient((r) async => http.Response('error', 500))), isNull);
    final fresh = await LiveEvents.fetch(
      prefs,
      old,
      client: MockClient(
        (r) async => http.Response(
          feed('2026-11-14T00:00:00Z'),
          200,
          headers: {'content-type': 'application/json; charset=utf-8'},
        ),
      ),
    );
    expect(fresh!.events.first.category, EventCategory.contest);
    expect(EventFeed.parse(prefs.getString(LiveEvents.prefsKey)!).events.first.deadlinePrecision, 'date');
    final initial = await LiveEvents.initial(prefs);
    expect(initial.events.first.eligibilityText, contains('팀 2~4명'));
  });
  test('reviewed BE preview contract preserves actual announcement dates', () {
    final f = File('test/fixtures/sotong-preview.json');
    final events = EventFeed.parse(f.readAsStringSync()).events;
    expect(events, hasLength(4));
    expect(events.every((e) => e.placeless), isTrue);
    expect(events.where((e) => e.title.ko.contains('정원')).single.applicationStatus, 'upcoming');
  });
  testWidgets('discover contest chip and detail use application meaning', (tester) async {
    await pump(tester, const DiscoverScreen());
    expect(find.textContaining('공모전'), findsWidgets);
    expect(find.textContaining('접수 마감'), findsWidgets);
    await tester.tap(find.text('공모전 테스트 공고').first);
    await tester.pumpAndSettle();
    expect(find.text('참가자격'), findsOneWidget);
    expect(find.textContaining('팀 2~4명'), findsWidgets);
    expect(find.text('주관기관 테스트'), findsWidgets);
    expect(find.textContaining('23:59'), findsNothing);
    expect(find.byIcon(Icons.map_outlined), findsNothing);
  });
  testWidgets('stale detail shows delay and no calendar action', (tester) async {
    await pump(tester, EventDetailSheet(event: contest(stale: true)));
    expect(find.textContaining('업데이트 지연'), findsWidgets);
    final button = tester.widget<FilledButton>(find.byType(FilledButton).first);
    expect(button.onPressed, isNull);
  });
}
