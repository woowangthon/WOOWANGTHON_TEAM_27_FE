import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:liferadar/data/providers.dart';
import 'package:liferadar/data/session.dart';
import 'package:liferadar_core/liferadar_core.dart';
import 'package:liferadar/services/calendar_api.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'app_test.dart' show pumpApp;

Future<ProviderContainer> _container(Map<String, Object> prefsValues) async {
  SharedPreferences.setMockInitialValues(prefsValues);
  final prefs = await SharedPreferences.getInstance();
  final c = ProviderContainer(overrides: [sharedPrefsProvider.overrideWithValue(prefs)]);
  addTearDown(c.dispose);
  return c;
}

const _google = '{"kind":"google","name":"Abbos","email":"Abbos@Example.com"}';

void main() {
  group('계정별 관심사', () {
    test('로그아웃 후 같은 Google 계정으로 다시 들어오면 관심사가 돌아온다', () async {
      final c = await _container({'session': _google});
      await c.read(interestsProvider.notifier).save({'ai', 'music'});

      await c.read(sessionProvider.notifier).signOut();
      await c.read(sessionProvider.notifier).continueAsGuest();
      expect(c.read(interestsProvider), isEmpty, reason: '게스트는 다른 사람 — 섞이면 안 된다');

      // 앱을 다시 열고 같은 계정으로 로그인
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('session', _google);
      final c2 = ProviderContainer(overrides: [sharedPrefsProvider.overrideWithValue(prefs)]);
      addTearDown(c2.dispose);
      expect(c2.read(interestsProvider), {'ai', 'music'});
    });

    test('이전(계정 없는) 키는 한 번 이전된다', () async {
      final c = await _container({
        'session': '{"kind":"guest"}',
        'interests': ['data'],
      });
      expect(c.read(interestsProvider), {'data'});
      final prefs = await SharedPreferences.getInstance();
      expect(prefs.getStringList('interests:guest'), ['data']);
      expect(prefs.getStringList('interests'), isNull);
    });
  });

  group('직접 만든 일정', () {
    Plan plan(String id, {String title = 'Gym'}) => Plan(
          id: id,
          title: title,
          start: DateTime(2026, 11, 10, 9),
          end: DateTime(2026, 11, 10, 10),
          locationText: '',
          city: '',
          note: 'bring shoes',
        );

    test('추가 → 저장 → 수정 → 삭제', () async {
      final c = await _container({'session': '{"kind":"guest"}'});
      final n = c.read(plansProvider.notifier);
      final before = c.read(plansProvider).length;

      await n.saveLocal(plan('local-1'));
      expect(c.read(plansProvider).length, before + 1);

      // 다시 열어도 남아 있다
      final prefs = await SharedPreferences.getInstance();
      final c2 = ProviderContainer(overrides: [sharedPrefsProvider.overrideWithValue(prefs)]);
      addTearDown(c2.dispose);
      final saved = c2.read(plansProvider).firstWhere((p) => p.id == 'local-1');
      expect(saved.source, 'local');
      expect(saved.note, 'bring shoes');

      await c2.read(plansProvider.notifier).saveLocal(plan('local-1', title: 'Gym (legs)'));
      expect(c2.read(plansProvider).where((p) => p.id == 'local-1').single.title, 'Gym (legs)');

      await c2.read(plansProvider.notifier).removeLocal('local-1');
      expect(c2.read(plansProvider).length, before);
    });

    test('수정한 샘플 일정은 원래 샘플을 대체한다', () async {
      final c = await _container({'session': '{"kind":"guest"}'});
      final sample = c.read(plansProvider).first;
      await c.read(plansProvider.notifier).saveLocal(sample.copyWith(title: 'Mine'));
      final same = c.read(plansProvider).where((p) => p.id == sample.id).toList();
      expect(same.single.title, 'Mine');
      expect(same.single.isEditable, isTrue);
    });
  });

  group('Calendar API tanasi', () {
    test('시간 지정 일정은 UTC dateTime, PATCH에서 date를 지운다', () {
      final p = Plan(
        id: 'gcal-abc',
        title: 'Meeting',
        start: DateTime.utc(2026, 11, 10, 1),
        end: DateTime.utc(2026, 11, 10, 2),
        locationText: 'COEX',
        city: 'Seoul',
        source: 'gcal',
      );
      expect(p.calendarEventId, 'abc');
      final post = CalendarApi.planBody(p);
      expect(post['start'], {'dateTime': '2026-11-10T01:00:00.000Z'});
      expect(post['location'], 'COEX');
      final patch = CalendarApi.planBody(p, patch: true);
      expect((patch['start'] as Map).containsKey('date'), isTrue);
      expect((patch['start'] as Map)['date'], isNull);
    });

    test('종일 일정 — date (종료일은 배타적)', () {
      final p = Plan(
        id: 'local-2',
        title: 'Trip',
        start: DateTime(2026, 11, 20),
        end: DateTime(2026, 11, 22),
        locationText: '',
        city: '',
      );
      expect(p.isAllDay, isTrue);
      final body = CalendarApi.planBody(p);
      expect(body['start'], {'date': '2026-11-20'});
      expect(body['end'], {'date': '2026-11-22'});
    });
  });

  testWidgets('내 일정: "+"로 새 일정을 추가한다', (tester) async {
    await pumpApp(tester, interests: ['ai']);
    await tester.tap(find.byIcon(Icons.event_note_outlined).last);
    await tester.pumpAndSettle();

    await tester.tap(find.text('New plan'));
    await tester.pumpAndSettle();
    // 제목 없이는 저장할 수 없다
    await tester.tap(find.text('Save'));
    await tester.pumpAndSettle();
    expect(find.text('Enter a title'), findsOneWidget);

    await tester.enterText(find.widgetWithText(TextField, 'Title'), 'Dentist');
    await tester.tap(find.text('Save'));
    await tester.pumpAndSettle();

    expect(find.text('Plan saved'), findsOneWidget);
    expect(find.text('Dentist'), findsOneWidget);
  });

  testWidgets('프로필: 관심사 목록은 보이지 않고 개수와 "Edit"만', (tester) async {
    await pumpApp(tester, interests: ['ai', 'music', 'food', 'travel', 'pets', 'art', 'fitness']);
    await tester.tap(find.byIcon(Icons.person_outline_rounded).last);
    await tester.pumpAndSettle();
    expect(find.text('7 selected'), findsOneWidget);
    expect(find.text('Pets'), findsNothing);
    await tester.tap(find.text('Edit'));
    await tester.pumpAndSettle();
    expect(find.text('What are you into?'), findsOneWidget); // 수정 화면이 열림
    await tester.scrollUntilVisible(find.text('Pets'), 300, scrollable: find.byType(Scrollable).last);
    expect(find.text('Pets'), findsOneWidget);
  });

  testWidgets('내 일정: 카드 아래 신호 줄, 누르면 일정 창', (tester) async {
    await pumpApp(tester, interests: ['ai', 'music']);
    await tester.tap(find.byIcon(Icons.event_note_outlined).last);
    await tester.pumpAndSettle();
    // Busan trip (11/20) — 그날 근처 콘서트 → 카드에 짧은 참고
    final line = find.textContaining('nearby — expect crowds');
    await tester.scrollUntilVisible(line, 200, scrollable: find.byType(Scrollable).first);
    expect(line, findsOneWidget);

    await tester.tap(find.text('Busan trip'));
    await tester.pumpAndSettle();
    expect(find.text('When'), findsOneWidget);
    await tester.scrollUntilVisible(find.text('Around this plan'), 200, scrollable: find.byType(Scrollable).last);
    expect(find.text('Around this plan'), findsOneWidget);
    expect(find.widgetWithText(FilledButton, 'Edit'), findsOneWidget);
  });

  testWidgets('내 일정: 직접 만든 일정은 상세 창에서 삭제(확인 후), 샘플은 삭제 버튼 없음', (tester) async {
    await pumpApp(tester, interests: ['ai']);
    final container = ProviderScope.containerOf(tester.element(find.byType(Scaffold).first));
    await container.read(plansProvider.notifier).saveLocal(
      Plan(
        id: 'mine',
        title: 'Study group',
        start: DateTime(2026, 11, 7, 15),
        end: DateTime(2026, 11, 7, 17),
        locationText: '',
        city: '',
      ),
    );
    await tester.tap(find.byIcon(Icons.event_note_outlined).last);
    await tester.pumpAndSettle();

    await tester.tap(find.text('Study group'));
    await tester.pumpAndSettle();
    await tester.tap(find.byTooltip('Delete plan'));
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(FilledButton, 'Delete'));
    await tester.pumpAndSettle();
    expect(find.text('Study group'), findsNothing);
    expect(container.read(plansProvider).any((p) => p.id == 'mine'), isFalse);

    await tester.tap(find.text('Busan trip'));
    await tester.pumpAndSettle();
    expect(find.byTooltip('Delete plan'), findsNothing); // 샘플
  });

  testWidgets('내 일정: 월간 보기 — 날짜를 고르면 그날의 일정', (tester) async {
    await pumpApp(tester, interests: ['ai']);
    await tester.tap(find.byIcon(Icons.event_note_outlined).last);
    await tester.pumpAndSettle();
    await tester.tap(find.byTooltip('Month view'));
    await tester.pumpAndSettle();
    expect(find.text('November 2026'), findsOneWidget);
    final list = find.byType(Scrollable).first;
    await tester.scrollUntilVisible(find.text('No plans on this day'), 200, scrollable: list);
    expect(find.text('No plans on this day'), findsOneWidget); // 11월 6일(오늘) — 일정 없음

    final day10 = find.descendant(of: find.byType(GridView), matching: find.text('10'));
    await tester.ensureVisible(day10);
    await tester.pumpAndSettle();
    expect(find.bySemanticsLabel('November 10, 1'), findsOneWidget); // 스크린 리더용 라벨
    await tester.tap(day10);
    await tester.pumpAndSettle();
    await tester.drag(find.byType(ListView).first, const Offset(0, -500));
    await tester.pumpAndSettle();
    expect(find.text('Team meeting'), findsOneWidget);
    final prefs = await SharedPreferences.getInstance();
    expect(prefs.getString('plans_view'), 'month'); // 선택이 기억된다
  });
}
