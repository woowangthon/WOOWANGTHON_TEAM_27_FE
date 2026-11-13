import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:liferadar/data/ai_insights.dart';
import 'package:liferadar/data/calendar_controller.dart';
import 'package:liferadar/data/providers.dart';
import 'package:liferadar/features/event/event_detail_sheet.dart';
import 'package:liferadar_core/demo.dart';
import 'package:liferadar/features/assistant/assistant_screen.dart';
import 'package:liferadar_core/liferadar_core.dart';

import 'app_test.dart' show pumpApp;
import 'contest_test.dart' as fixtures show contest, now;

class _RecordingCalendar extends CalendarController {
  final added = <RadarEvent>[];
  final titles = <String>[];

  @override
  CalendarState build() => const CalendarState(status: CalendarStatus.connected);

  @override
  Future<String?> addEvent(RadarEvent event, {required String title}) async {
    added.add(event);
    titles.add(title);
    return null;
  }
}

/// Gemini 응답을 흉내 낸다 (실제 호출 없음).
GeminiClient _fakeGemini(Map<String, Object> data) => GeminiClient(
  apiKey: 'test',
  client: MockClient(
    (_) async => http.Response.bytes(
      utf8.encode(
        jsonEncode({
          'candidates': [
            {
              'content': {
                'parts': [
                  {'text': jsonEncode(data)},
                ],
              },
            },
          ],
        }),
      ),
      200,
    ),
  ),
);

Future<void> _open(WidgetTester tester) async {
  await tester.tap(find.text('Ask AI'));
  await tester.pumpAndSettle();
  expect(find.byType(AssistantScreen), findsOneWidget);
  expect(find.text('What can I find for you?'), findsOneWidget);
}

void main() {
  for (final useAi in [true, false]) {
    testWidgets('Deadline notices expose detail and confirmed calendar action, AI=$useAi', (tester) async {
      final calendar = _RecordingCalendar();
      final notice = fixtures.contest();
      final stale = RadarEvent.fromJson({
        ...notice.toJson(),
        'id': 'stale-notice',
        'title': {'ko': '오래된 공고', 'en': 'Stale notice'},
        'lastVerifiedAt': fixtures.now.subtract(const Duration(days: 4)).toIso8601String(),
      });
      await pumpApp(tester, now: fixtures.now, interests: ['ai'], overrides: [
        eventsProvider.overrideWithValue([notice, stale]),
        calendarProvider.overrideWith(() => calendar),
        geminiApiProvider.overrideWithValue(useAi
            ? _fakeGemini({'reply': '마감 임박한 공고를 확인해 보세요.', 'event_ids': <String>[], 'actions': <Object>[]})
            : GeminiClient(apiKey: '')),
      ]);
      await _open(tester);
      await tester.enterText(find.byType(TextField), '마감 임박한 공고 알려줘');
      await tester.pump();
      await tester.tap(find.byIcon(Icons.arrow_upward_rounded));
      await tester.pumpAndSettle();
      expect(find.text('Contest fixture'), findsOneWidget);
      expect(find.text('Stale notice'), findsNothing);
      expect(find.textContaining('Application deadline'), findsOneWidget);
      expect(find.text('View on map?'), findsNothing);
      expect(calendar.added, isEmpty);

      await tester.ensureVisible(find.text('Contest fixture'));
      await tester.tap(find.text('Contest fixture'));
      await tester.pumpAndSettle();
      expect(find.byType(EventDetailSheet), findsOneWidget);
      Navigator.of(tester.element(find.byType(EventDetailSheet))).pop();
      await tester.pumpAndSettle();

      final add = find.widgetWithText(FilledButton, 'Add');
      await tester.ensureVisible(add);
      await tester.tap(add);
      await tester.pumpAndSettle();
      expect(calendar.added.single.id, notice.id);
      expect(calendar.titles.single, 'Application deadline: Contest fixture');
      expect(find.text('Added'), findsOneWidget);
    });
  }

  test('Unrelated chat and unavailable categories do not return top events', () {
    final now = DateTime(2026, 11, 6);
    for (final question in ['바보', '안녕하세요', '없는행사이름']) {
      final events = Assistant.retrieve(
        AssistantQuery.parse(question, now: now),
        events: sampleEvents,
        interests: const {'ai'},
        now: now,
      );
      expect(events, isEmpty, reason: question);
    }
    final onlyConcerts = sampleEvents.where((e) => e.category == EventCategory.concert).toList();
    expect(onlyConcerts, isNotEmpty);
    expect(
      Assistant.retrieve(
        AssistantQuery.parse('해커톤', now: now),
        events: onlyConcerts,
        interests: const {'ai'},
        now: now,
      ),
      isEmpty,
    );
  });

  testWidgets('Unknown chat without AI explains availability without event cards', (tester) async {
    await pumpApp(tester, interests: ['ai']);
    await _open(tester);
    await tester.enterText(find.byType(TextField), '바보');
    await tester.pump();
    await tester.tap(find.byIcon(Icons.arrow_upward_rounded));
    await tester.pumpAndSettle();
    expect(find.textContaining('AI chat is unavailable'), findsOneWidget);
    expect(find.textContaining('to your calendar?'), findsNothing);
  });

  testWidgets('AI 비서: 키가 없으면 조건 검색으로 실제 카드를 보여준다', (tester) async {
    await pumpApp(tester, interests: ['ai', 'music']);
    await _open(tester);
    expect(find.text('Any deadlines coming up?'), findsOneWidget); // 추천 질문
    await tester.enterText(find.byType(TextField), 'Busan trip 때 갈 만한 곳?');
    await tester.pump(); // 보내기 버튼 활성화
    await tester.tap(find.byIcon(Icons.arrow_upward_rounded));
    await tester.pumpAndSettle();
    expect(find.text('Filter search'), findsOneWidget);
    expect(find.textContaining('Busan trip'), findsWidgets); // 코드가 읽은 조건
    expect(find.textContaining('(sample)'), findsWidgets); // 부산 샘플 행사 카드
  });

  testWidgets('AI 비서: 제안은 [취소]로 끝나고, 후보 밖 id는 화면에 없다', (tester) async {
    await pumpApp(
      tester,
      interests: ['ai'],
      overrides: [
        geminiApiProvider.overrideWithValue(
          _fakeGemini({
            'reply': 'Busan trip 기간에 AI 엑스포가 있어요.',
            'event_ids': ['ev-busan-ai-expo', 'invented-event'],
            'actions': [
              {'type': 'add_to_calendar', 'event_id': 'ev-busan-ai-expo'},
            ],
          }),
        ),
      ],
    );
    await _open(tester);
    await tester.enterText(find.byType(TextField), 'Busan trip 때 갈 만한 곳?');
    await tester.pump(); // 보내기 버튼 활성화
    await tester.tap(find.byIcon(Icons.arrow_upward_rounded));
    await tester.pumpAndSettle();

    expect(find.text('AI answer'), findsOneWidget);
    expect(find.text('Busan trip 기간에 AI 엑스포가 있어요.'), findsOneWidget);
    expect(find.textContaining('invented-event'), findsNothing);
    final propose = find.textContaining('to your calendar?');
    await tester.scrollUntilVisible(propose, 100, scrollable: find.byType(Scrollable).first);
    expect(propose, findsOneWidget);

    await tester.tap(find.widgetWithText(TextButton, 'Cancel'));
    await tester.pumpAndSettle();
    expect(find.text('Cancelled'), findsOneWidget);
  });
}
