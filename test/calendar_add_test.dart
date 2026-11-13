import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:liferadar/data/calendar_controller.dart';
import 'package:liferadar/features/event/event_actions.dart';
import 'package:liferadar/features/event/event_detail_sheet.dart';
import 'package:liferadar/features/home/home_screen.dart';
import 'package:liferadar/services/calendar_api.dart';
import 'package:liferadar_core/liferadar_core.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'app_test.dart' show pumpApp;
import 'contest_test.dart' as fixtures show contest, now;

/// 첫 추가는 성공, 그다음부터는 "이미 있음" (Google에서 찾은 것처럼).
class _OnceCalendar extends CalendarController {
  int inserts = 0;

  @override
  CalendarState build() => const CalendarState(status: CalendarStatus.connected);

  @override
  Future<String?> addEvent(RadarEvent event, {required String title}) async {
    if (inserts > 0) throw const CalendarAlreadyAdded();
    inserts++;
    return null;
  }
}

void main() {
  test('이미 넣은 행사는 비공개 속성으로 찾는다 (다른 기기에서 넣은 것도)', () async {
    Uri? asked;
    final found = CalendarApi('t', client: MockClient((req) async {
      asked = req.url;
      return http.Response('{"items":[{"id":"x","status":"confirmed","htmlLink":"https://cal/x"}]}', 200);
    }));
    expect(await found.findAdded('ev-1'), 'https://cal/x');
    expect(asked!.queryParameters['privateExtendedProperty'], 'liferadarEventId=ev-1');

    final empty = CalendarApi('t', client: MockClient((_) async => http.Response('{"items":[]}', 200)));
    expect(await empty.findAdded('ev-1'), isNull);

    final cancelled = CalendarApi('t', client: MockClient((_) async =>
        http.Response('{"items":[{"id":"x","status":"cancelled"}]}', 200)));
    expect(await cancelled.findAdded('ev-1'), isNull);
  });

  testWidgets('캘린더에 추가: 성공하면 창이 닫히고 토스트, 두 번째는 "이미 있음"으로 넣지 않는다', (tester) async {
    final calendar = _OnceCalendar();
    final notice = fixtures.contest();
    await pumpApp(tester, now: fixtures.now, interests: ['ai'], overrides: [
      calendarProvider.overrideWith(() => calendar),
    ]);
    final context = tester.element(find.byType(HomeScreen));

    Future<void> openAndAdd() async {
      showEventDetail(context, notice);
      await tester.pumpAndSettle();
      final add = find.widgetWithText(FilledButton, 'Add to calendar').hitTestable();
      final again = find.widgetWithText(FilledButton, 'Added to calendar').hitTestable();
      await tester.tap(add.evaluate().isNotEmpty ? add : again);
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 600));
    }

    await openAndAdd();
    expect(calendar.inserts, 1);
    expect(find.byType(EventDetailSheet), findsNothing); // 닫힘
    expect(find.text('Added to Google Calendar'), findsOneWidget); // 토스트
    final prefs = await SharedPreferences.getInstance();
    expect(prefs.getStringList('calendar_added:guest'), contains(notice.id));

    await tester.pump(const Duration(seconds: 6)); // 토스트가 사라지도록
    await tester.pumpAndSettle();

    await openAndAdd();
    expect(calendar.inserts, 1); // 다시 넣지 않았다
    expect(find.text('Already in your calendar'), findsOneWidget);
    await tester.pump(const Duration(seconds: 6));
    await tester.pumpAndSettle();
  });

  test('두 달짜리 전시는 고른 하루만: 운영 시간이 있으면 그 시간, 없으면 종일', () {
    final base = fixtures.contest().toJson();
    RadarEvent ev(DateTime a, DateTime b) => RadarEvent.fromJson({
      ...base, 'id': 'expo', 'placeless': false, 'deadline': null, 'kind': 'event',
      'start': a.toIso8601String(), 'end': b.toIso8601String(),
    });
    final hours = ev(DateTime(2026, 11, 1, 10), DateTime(2026, 12, 31, 18));
    expect(spansSeveralDays(hours), isTrue);
    final one = visitOn(hours, DateTime(2026, 11, 20));
    expect(one.start, DateTime(2026, 11, 20, 10));
    expect(one.end, DateTime(2026, 11, 20, 18));

    final dates = ev(DateTime(2026, 11, 1), DateTime(2026, 12, 31));
    final day = visitOn(dates, DateTime(2026, 11, 20));
    final body = CalendarApi.eventBody(day, title: '전시');
    expect(body['start'], {'date': '2026-11-20'});
    expect(body['end'], {'date': '2026-11-21'});

    // 자정을 넘는 공연 하나(24시간 이하)는 그대로
    expect(spansSeveralDays(ev(DateTime(2026, 11, 20, 20), DateTime(2026, 11, 21, 1))), isFalse);
  });

  test('새로 고침 중에는 목록을 그대로 둔다 — 스켈레톤은 처음 불러올 때만', () {
    expect(const CalendarState(status: CalendarStatus.connecting).isInitialLoading, isTrue);
    expect(const CalendarState(status: CalendarStatus.syncing).isInitialLoading, isTrue);
    expect(CalendarState(status: CalendarStatus.syncing, lastSync: DateTime(2026, 11, 14)).isInitialLoading, isFalse);
    expect(CalendarState(status: CalendarStatus.connected, lastSync: DateTime(2026, 11, 14)).isInitialLoading, isFalse);
  });
}
