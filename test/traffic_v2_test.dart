import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:liferadar/data/live_traffic.dart';
import 'package:liferadar/core/theme.dart';
import 'package:liferadar/features/event/traffic_metadata.dart';
import 'package:liferadar/l10n/app_localizations.dart';
import 'package:liferadar_core/liferadar_core.dart';

final clock = DateTime.utc(2026, 11, 11);
TrafficNotice n() => TrafficNotice(
  id: 'u',
  source: 'utic',
  sourceName: '경찰청 UTIC',
  kind: TrafficKind.rally,
  title: '한국어 원문',
  detail: '도로 부분통제',
  start: clock,
  end: null,
  location: const GeoPoint(37.57, 126.98),
  lastSeenAt: clock,
  fetchedAt: clock,
  sourceUpdatedAt: clock.subtract(const Duration(hours: 1)),
  controlEvidence: 'confirmed',
  evidenceText: '부분통제',
  evidenceMethod: 'synthetic',
  timePrecision: 'minute',
);
Map<String, dynamic> feed() => {
  'schemaVersion': 2,
  'generatedAt': clock.toIso8601String(),
  'sources': [
    {'id': 'utic'},
  ],
  'sourceStates': {
    'utic': {'status': 'ok', 'lastSuccessAt': clock.toIso8601String()},
  },
  'notices': [n().toJson()],
};
void main() {
  test('v2 metadata/cache age survives repost; UTIC TTL boundaries use item observation', () {
    final j = feed();
    j['generatedAt'] = clock.add(const Duration(hours: 7)).toIso8601String();
    final f = TrafficFeed.parse(jsonEncode(j));
    expect(f.schemaVersion, 2);
    expect(f.sourceStates['utic']['status'], 'ok');
    expect(f.activeAt(clock.add(const Duration(hours: 6))), hasLength(1));
    expect(f.activeAt(clock.add(const Duration(hours: 6, seconds: 1))), isEmpty);
    expect(f.copyWith().sourceStates, f.sourceStates);
    expect(f.sourceStatesAt(clock.add(const Duration(hours: 7)))['utic']['status'], 'unavailable');
  });
  test('legacy readable, cancelled/incomplete/malformed rows isolated', () {
    final j = feed()
      ..remove('schemaVersion')
      ..remove('sourceStates')
      ..remove('sources');
    final f = TrafficFeed.parse(jsonEncode(j));
    expect(f.schemaVersion, 1);
    final broken = TrafficFeed(
      sourceStates: {
        'bad': 'invalid',
        'clock': {'status': 'ok', 'lastSuccessAt': 'invalid'},
      },
    );
    expect(broken.sourceStatesAt(clock)['clock']['status'], 'unavailable');
    expect(() => TrafficFeed.parse('{"schemaVersion":2,"notices":[]}'), throwsFormatException);
    final v = feed();
    (v['notices'] as List).add({'id': 'broken'});
    expect(TrafficFeed.parse(jsonEncode(v)).notices, hasLength(1));
    final raw = n().toJson()..['status'] = 'cancelled';
    v['notices'] = [raw];
    expect(TrafficFeed.parse(jsonEncode(v)).activeAt(clock), isEmpty);
  });
  test('fake feed failure retains cache; normal empty v2 replaces older feed', () async {
    SharedPreferences.setMockInitialValues({});
    final prefs = await SharedPreferences.getInstance();
    final f = TrafficFeed.parse(jsonEncode(feed()));
    await prefs.setString(LiveTraffic.prefsKey, jsonEncode(feed()));
    final failed = await LiveTraffic.fetch(
      prefs,
      f,
      url: 'https://example.test/feed',
      client: MockClient((_) async => http.Response('error', 500)),
    );
    expect(failed, isNull);
    expect(LiveTraffic.cached(prefs).notices, hasLength(1));
    final j = feed()
      ..['generatedAt'] = clock.add(const Duration(minutes: 1)).toIso8601String()
      ..['notices'] = [];
    final empty = await LiveTraffic.fetch(
      prefs,
      f,
      url: 'https://example.test/feed',
      client: MockClient((_) async => http.Response(jsonEncode(j), 200)),
    );
    expect(empty!.notices, isEmpty);
    expect(LiveTraffic.cached(prefs).notices, isEmpty);
  });
  for (final locale in [const Locale('ko'), const Locale('en')]) {
    testWidgets('traffic metadata ${locale.languageCode}: separate observed/updated labels and Korean original', (
      tester,
    ) async {
      await tester.pumpWidget(
        MaterialApp(
          theme: buildTheme(Brightness.light),
          locale: locale,
          localizationsDelegates: const [
            AppLocalizations.delegate,
            GlobalMaterialLocalizations.delegate,
            GlobalWidgetsLocalizations.delegate,
            GlobalCupertinoLocalizations.delegate,
          ],
          supportedLocales: AppLocalizations.supportedLocales,
          home: Scaffold(body: SingleChildScrollView(child: TrafficMetadata(n(), detailed: true))),
        ),
      );
      expect(find.textContaining(locale.languageCode == 'ko' ? '마지막 확인' : 'Last checked'), findsOneWidget);
      expect(find.textContaining(locale.languageCode == 'ko' ? '원문 갱신' : 'Source updated'), findsOneWidget);
      expect(find.textContaining(locale.languageCode == 'ko' ? '종료 시각 미확인' : 'End time unknown'), findsOneWidget);
      expect(find.text('도로 부분통제'), findsOneWidget);
    });
  }
  test('public withdrawals suppress direct ITS cache across refresh, restart and copyWith', () async {
    SharedPreferences.setMockInitialValues({});
    final prefs = await SharedPreferences.getInstance();
    final at = clock.add(const Duration(minutes: 1));
    final old = n().withMetadata({'source': 'its', 'sourceName': 'ITS', 'sourceRecordId': 'same'});
    final w = TrafficWithdrawal(source: 'its', sourceRecordId: 'same', observedAt: at);
    final raw = jsonEncode({
      'schemaVersion': 2,
      'generatedAt': at.toIso8601String(),
      'sources': [
        {'id': 'its'},
      ],
      'sourceStates': {
        'its': {'status': 'ok', 'lastSuccessAt': at.toIso8601String()},
      },
      'notices': [],
      'withdrawals': [w.toJson()],
    });
    await prefs.setString(LiveTraffic.prefsKey, raw);
    await prefs.setString(
      LiveTraffic.itsPrefsKey,
      jsonEncode({
        'fetchedAt': clock.toIso8601String(),
        'notices': [old.toJson()],
      }),
    );
    final restored = LiveTraffic.cached(prefs);
    expect(restored.its, hasLength(1));
    expect(restored.withdrawals, hasLength(1));
    expect(restored.copyWith().activeAt(at), isEmpty);
    final refetched = old.withMetadata({'lastSeenAt': at.add(const Duration(minutes: 1)).toIso8601String()});
    expect(restored.copyWith(its: [refetched]).activeAt(at.add(const Duration(minutes: 1))), isEmpty);
    final revised = refetched.withMetadata({'sourceUpdatedAt': at.add(const Duration(minutes: 1)).toIso8601String()});
    expect(restored.copyWith(its: [revised]).activeAt(at.add(const Duration(minutes: 1))), hasLength(1));
  });
}
